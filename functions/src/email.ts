import { defineSecret, defineString } from "firebase-functions/params";

export const brevoApiKey = defineSecret("BREVO_API_KEY");
export const emailFrom = defineString("EMAIL_FROM", {
  default: "reminders@example.com",
});
export const emailFromName = defineString("EMAIL_FROM_NAME", {
  default: "Client Follow-Up",
});
export const portalBaseUrl = defineString("PORTAL_BASE_URL", {
  default: "https://client-follow-up-app-eb46b.web.app",
});

export async function sendEmail(opts: {
  to: string;
  subject: string;
  htmlBody: string;
}): Promise<void> {
  const res = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "api-key": brevoApiKey.value(),
    },
    body: JSON.stringify({
      sender: { email: emailFrom.value(), name: emailFromName.value() },
      to: [{ email: opts.to }],
      subject: opts.subject,
      htmlContent: opts.htmlBody,
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Brevo send failed (${res.status}): ${text}`);
  }
}

export function portalLink(secureToken: string): string {
  return `${portalBaseUrl.value()}/?token=${secureToken}`;
}

export function missingItemsEmailHtml(opts: {
  businessName: string;
  clientName: string;
  missingItemNames: string[];
  link: string;
  isFirstEmail: boolean;
}): string {
  const itemsHtml = opts.missingItemNames.map((n) => `<li>${escapeHtml(n)}</li>`).join("");
  const intro = opts.isFirstEmail
    ? `${escapeHtml(opts.businessName)} needs a few things from you:`
    : `Just a reminder — ${escapeHtml(opts.businessName)} is still waiting on:`;

  return `
    <p>Hi ${escapeHtml(opts.clientName)},</p>
    <p>${intro}</p>
    <ul>${itemsHtml}</ul>
    <p><a href="${opts.link}">Click here to complete your request</a></p>
    <p>This link is unique to you — no account or password needed.</p>
  `;
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}