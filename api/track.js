// api/track.js
//
// The one thing the app was missing: a place where the SERVER sees the visit.
// A static page load never reaches server code, so no IP could be captured.
// The client pings this route on open and on sign-in; Vercel hands us the real
// public IP in the request headers and we write it against the account.
//
import { withSecurity, readJson, json } from './_lib/security.js';

// Event types the browser is allowed to report. The risk score is decided HERE,
// never sent by the client — otherwise anyone could post risk:0 for an attack,
// or risk:100 to get another visitor auto-banned.
const ALLOWED = {
  page_view:    0,
  login:        0,
  signup:       0,
  logout:       0,
  login_failed: 15,
  otp_failed:   20
};

export default withSecurity(async (req, res, { user, log }) => {
  const body = await readJson(req, 4096).catch(() => ({}));
  const type = String(body.type || 'page_view');

  if (!Object.prototype.hasOwnProperty.call(ALLOWED, type)) {
    return json(res, 400, { error: 'Unknown event type' });
  }

  await log({
    type,
    detail: String(body.detail || '').slice(0, 300) || null,
    risk: ALLOWED[type]
  });

  // Nothing useful is returned: this endpoint must not become an oracle that
  // tells a visitor whether they are being watched.
  return json(res, 200, { ok: true });
}, {
  auth: 'optional',      // signed out visitors are logged too, with user_id null
  methods: ['POST'],
  autoLog: false         // the handler writes its own event; don't double-log
});
