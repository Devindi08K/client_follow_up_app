"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.portalBaseUrl = exports.emailFrom = exports.postmarkToken = void 0;
exports.sendEmail = sendEmail;
exports.portalLink = portalLink;
exports.missingItemsEmailHtml = missingItemsEmailHtml;
const params_1 = require("firebase-functions/params");
exports.postmarkToken = (0, params_1.defineSecret)("POSTMARK_SERVER_TOKEN");
exports.emailFrom = (0, params_1.defineString)("EMAIL_FROM", {
    default: "reminders@example.com",
});
exports.portalBaseUrl = (0, params_1.defineString)("PORTAL_BASE_URL", {
    default: "https://client-follow-up-app-eb46b.web.app",
});
async function sendEmail(opts) {
    const res = await fetch("https://api.postmarkapp.com/email", {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
            "X-Postmark-Server-Token": exports.postmarkToken.value(),
        },
        body: JSON.stringify({
            From: exports.emailFrom.value(),
            To: opts.to,
            Subject: opts.subject,
            HtmlBody: opts.htmlBody,
            MessageStream: "outbound",
        }),
    });
    if (!res.ok) {
        const text = await res.text();
        throw new Error(`Postmark send failed (${res.status}): ${text}`);
    }
}
function portalLink(secureToken) {
    return `${exports.portalBaseUrl.value()}/?token=${secureToken}`;
}
function missingItemsEmailHtml(opts) {
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
function escapeHtml(str) {
    return str
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}
//# sourceMappingURL=email.js.map