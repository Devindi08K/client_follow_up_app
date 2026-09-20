import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import {
  sendEmail,
  portalLink,
  missingItemsEmailHtml,
  postmarkToken,
} from "./email";

initializeApp();

const db = getFirestore();
const bucket = getStorage().bucket();

const MAX_FILE_BYTES = 10 * 1024 * 1024; // 10MB, per product spec edge case

/**
 * Looks up a request document anywhere in the requests collection group
 * (businesses/{id}/clients/{id}/requests) by its secureToken, and validates
 * it's still usable.
 * Throws HttpsError for every "not usable" case so callers get a clean
 * client-side error instead of leaking internal state.
 */
async function findRequestByToken(secureToken: string) {
  if (!secureToken || typeof secureToken !== "string") {
    throw new HttpsError("invalid-argument", "A secureToken is required.");
  }

  const snap = await db
    .collectionGroup("requests")
    .where("secureToken", "==", secureToken)
    .limit(1)
    .get();

  if (snap.empty) {
    throw new HttpsError("not-found", "This link is no longer valid.");
  }

  const requestDoc = snap.docs[0];
  const data = requestDoc.data();

  const tokenExpiresAt = data.tokenExpiresAt as Timestamp | undefined;
  if (tokenExpiresAt && tokenExpiresAt.toMillis() < Date.now()) {
    throw new HttpsError("permission-denied", "This link has expired.");
  }

  if (data.status === "cancelled") {
    throw new HttpsError(
      "permission-denied",
      "This request has been closed by the business."
    );
  }

  return requestDoc;
}

/**
 * getRequestByToken — unauthenticated, called by the client web portal on load.
 * Returns everything the portal needs to render: business identity + items.
 */
export const getRequestByToken = onCall(
  { cors: true },
  async (request) => {
    const { secureToken } = request.data as { secureToken: string };
    const requestDoc = await findRequestByToken(secureToken);
    const requestData = requestDoc.data();

    const businessRef = requestDoc.ref.parent.parent!.parent.parent!; // clients/{id} -> businesses/{id}
    const businessSnap = await businessRef.get();
    const business = businessSnap.exists ? businessSnap.data()! : {};

    const itemsSnap = await requestDoc.ref.collection("items").orderBy("name").get();
    const items = itemsSnap.docs.map((d) => {
      const it = d.data();
      return {
        id: d.id,
        name: it.name,
        instructions: it.instructions ?? null,
        type: it.type,
        status: it.status,
        submittedAt: it.submittedAt ? it.submittedAt.toMillis() : null,
      };
    });

    return {
      requestId: requestDoc.id,
      status: requestData.status,
      businessName: business.name ?? "Your service provider",
      businessLogoUrl: business.logoUrl ?? null,
      items,
    };
  }
);

/**
 * getUploadUrl — unauthenticated. Issues a short-lived signed URL the portal
 * can PUT a file to directly, without ever touching Firestore/Storage rules
 * for anonymous clients. Client validates size client-side first (10MB) but
 * we also cap it here via a Content-Length constraint on the signed URL.
 */
export const getUploadUrl = onCall({ cors: true }, async (request) => {
  const { secureToken, itemId, fileName, contentType } = request.data as {
    secureToken: string;
    itemId: string;
    fileName: string;
    contentType: string;
  };

  if (!itemId || !fileName) {
    throw new HttpsError("invalid-argument", "itemId and fileName are required.");
  }

  const requestDoc = await findRequestByToken(secureToken);

  const itemRef = requestDoc.ref.collection("items").doc(itemId);
  const itemSnap = await itemRef.get();
  if (!itemSnap.exists) {
    throw new HttpsError("not-found", "That item does not exist on this request.");
  }
  if (itemSnap.data()!.type !== "file") {
    throw new HttpsError("failed-precondition", "This item does not accept file uploads.");
  }

  const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
  const storagePath = `requestUploads/${requestDoc.id}/${itemId}/${Date.now()}_${safeName}`;
  const file = bucket.file(storagePath);

  const [uploadUrl] = await file.getSignedUrl({
    version: "v4",
    action: "write",
    expires: Date.now() + 10 * 60 * 1000, // 10 minutes
    contentType: contentType || "application/octet-stream",
    extensionHeaders: {
      "x-goog-content-length-range": `0,${MAX_FILE_BYTES}`,
    },
  });

  return {
    uploadUrl,
    storagePath,
    // Client sends storagePath back in submitItem; we resolve the
    // download URL server-side so nothing public/guessable is required.
  };
});

/**
 * submitItem — unauthenticated. Marks an item received (file or text),
 * and flips the parent request to "complete" once every item is in.
 */
export const submitItem = onCall({ cors: true }, async (request) => {
  const { secureToken, itemId, storagePath, textAnswer } = request.data as {
    secureToken: string;
    itemId: string;
    storagePath?: string;
    textAnswer?: string;
  };

  if (!itemId) {
    throw new HttpsError("invalid-argument", "itemId is required.");
  }
  if (!storagePath && !textAnswer) {
    throw new HttpsError(
      "invalid-argument",
      "Provide either a storagePath (file) or textAnswer (text)."
    );
  }

  const requestDoc = await findRequestByToken(secureToken);
  const itemRef = requestDoc.ref.collection("items").doc(itemId);
  const itemSnap = await itemRef.get();

  if (!itemSnap.exists) {
    throw new HttpsError("not-found", "That item does not exist on this request.");
  }

  const update: Record<string, unknown> = {
    status: "received",
    submittedAt: FieldValue.serverTimestamp(),
  };

  if (storagePath) {
    const file = bucket.file(storagePath);
    const [fileUrl] = await file.getSignedUrl({
      version: "v4",
      action: "read",
      expires: Date.now() + 365 * 24 * 60 * 60 * 1000, // 1 year read link
    });
    update.fileUrl = fileUrl;
    update.textAnswer = null;
  } else {
    update.textAnswer = textAnswer;
    update.fileUrl = null;
  }

  await itemRef.update(update);

  // Check whether every item on this request is now received.
  const allItemsSnap = await requestDoc.ref.collection("items").get();
  const allReceived = allItemsSnap.docs.every((d) => d.data().status === "received");

  if (allReceived) {
    await requestDoc.ref.update({ status: "complete" });

    // Lightweight in-app notification flag for the business dashboard.
    const businessRef = requestDoc.ref.parent.parent!.parent.parent!;
    await businessRef.set(
      {
        lastCompletedNotificationAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  return { status: allReceived ? "complete" : "pending" };
});

/**
 * onRequestCreated — fires the moment the Flutter app writes a new request
 * doc (createRequest is still client-side; this is what makes "Create & send"
 * actually send something). Sends the initial "here's what we need" email.
 */
export const onRequestCreated = onDocumentCreated(
  {
    document: "businesses/{businessId}/clients/{clientId}/requests/{requestId}",
    secrets: [postmarkToken],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const requestRef = snap.ref;
    const requestData = snap.data();
    const clientRef = requestRef.parent.parent!;
    const businessRef = clientRef.parent.parent!;

    try {
      const [clientSnap, businessSnap, itemsSnap] = await Promise.all([
        clientRef.get(),
        businessRef.get(),
        requestRef.collection("items").get(),
      ]);

      if (!clientSnap.exists || !clientSnap.data()?.email) {
        logger.warn(`onRequestCreated: client ${clientRef.id} has no email, skipping send.`);
        return;
      }

      const missingItemNames = itemsSnap.docs
        .filter((d) => d.data().status !== "received")
        .map((d) => d.data().name as string);

      if (missingItemNames.length === 0) return;

      const link = portalLink(requestData.secureToken);

      await sendEmail({
        to: clientSnap.data()!.email,
        subject: `Action needed: ${businessSnap.data()?.name ?? "Your provider"} needs a few things from you`,
        htmlBody: missingItemsEmailHtml({
          businessName: businessSnap.data()?.name ?? "Your service provider",
          clientName: clientSnap.data()!.name ?? "there",
          missingItemNames,
          link,
          isFirstEmail: true,
        }),
      });

      await requestRef.collection("reminders").add({
        sentAt: FieldValue.serverTimestamp(),
        channel: "email",
        missingItemsAtSendTime: missingItemNames,
        messageContent: "Initial request notification",
      });

      await requestRef.update({ lastReminderSentAt: FieldValue.serverTimestamp() });
    } catch (err) {
      logger.error("onRequestCreated failed", err);
    }
  }
);

/**
 * dailyReminderJob — runs once a day. Sends the next cadence email
 * (Day 1 / 3 / 7 from creation, per the fixed MVP cadence) for any request
 * that's due and still incomplete. Marks a request "overdue" once the
 * cadence is exhausted and items are still missing.
 */
export const dailyReminderJob = onSchedule(
  {
    schedule: "every day 09:00",
    timeZone: "Asia/Colombo",
    secrets: [postmarkToken],
  },
  async () => {
    const now = Timestamp.now();

    const dueSnap = await db
      .collectionGroup("requests")
      .where("status", "in", ["pending", "overdue"])
      .where("nextReminderDueAt", "<=", now)
      .get();

    for (const requestDoc of dueSnap.docs) {
      const requestData = requestDoc.data();
      const clientRef = requestDoc.ref.parent.parent!;
      const businessRef = clientRef.parent.parent!;

      try {
        const [clientSnap, businessSnap, itemsSnap] = await Promise.all([
          clientRef.get(),
          businessRef.get(),
          requestDoc.ref.collection("items").get(),
        ]);

        if (!clientSnap.exists || !clientSnap.data()?.email) continue;

        const missingItemNames = itemsSnap.docs
          .filter((d) => d.data().status !== "received")
          .map((d) => d.data().name as string);

        if (missingItemNames.length === 0) {
          // Everything got done since this was scheduled — nothing to send.
          await requestDoc.ref.update({ nextReminderDueAt: null });
          continue;
        }

        await sendEmail({
          to: clientSnap.data()!.email,
          subject: `Reminder: ${businessSnap.data()?.name ?? "Your provider"} is still waiting on you`,
          htmlBody: missingItemsEmailHtml({
            businessName: businessSnap.data()?.name ?? "Your service provider",
            clientName: clientSnap.data()!.name ?? "there",
            missingItemNames,
            link: portalLink(requestData.secureToken),
            isFirstEmail: false,
          }),
        });

        await requestDoc.ref.collection("reminders").add({
          sentAt: FieldValue.serverTimestamp(),
          channel: "email",
          missingItemsAtSendTime: missingItemNames,
          messageContent: "Cadence reminder",
        });

        const cadence: number[] = requestData.reminderCadence ?? [1, 3, 7];
        const createdAt: Timestamp | undefined = requestData.createdAt;
        const nextStep = computeNextReminder(cadence, createdAt);

        await requestDoc.ref.update({
          lastReminderSentAt: FieldValue.serverTimestamp(),
          nextReminderDueAt: nextStep ?? null,
          status: nextStep ? requestData.status : "overdue",
        });
      } catch (err) {
        logger.error(`dailyReminderJob failed for request ${requestDoc.id}`, err);
      }
    }
  }
);

function computeNextReminder(
  cadence: number[],
  createdAt: Timestamp | undefined
): Timestamp | null {
  if (!createdAt) return null;

  const daysSinceCreation =
    (Date.now() - createdAt.toMillis()) / (24 * 60 * 60 * 1000);

  const sorted = [...cadence].sort((a, b) => a - b);
  const nextDay = sorted.find((d) => d > daysSinceCreation + 0.5); // small buffer

  if (nextDay === undefined) return null;

  const nextDate = new Date(createdAt.toMillis() + nextDay * 24 * 60 * 60 * 1000);
  return Timestamp.fromDate(nextDate);
}