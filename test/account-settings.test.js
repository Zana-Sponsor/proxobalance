import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

// v42: name, number and password each on their own screen; WhatsApp only to the verified account number.
const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const app = readFileSync(new URL('../assets/js/app.js', import.meta.url), 'utf8');
const wa = readFileSync(new URL('../assets/js/whatsapp-notify.js', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../supabase/migrations/20261115010000_account_name_phone_rules.sql', import.meta.url), 'utf8');

test('name, number, e-mail and password are separate screens with their own routes under the profile tab', () => {
  for (const [id, route] of [['pageAccountName', 'account-name'], ['pageChangePhone', 'change-phone'], ['pageChangeEmail', 'change-email'], ['pageChangePassword', 'change-password']]) {
    assert.match(html, new RegExp(`<section class="page acx-page" id="${id}" data-route="${route}">`));
    assert.match(app, new RegExp(`'${route}':'${id}'`));
    assert.match(html, new RegExp(`onclick="navigate\\('${route}'\\)"`));
  }
  assert.match(app, /'account-name','change-phone','change-email','change-password'\]\.includes\(route\)\) return 'profile'/);
  // the old shared form (name + number + one save button) is gone
  assert.doesNotMatch(html, /id="pfPhone"|id="pfSaveBtn"|id="waPhone"/);
  assert.doesNotMatch(app, /async function saveProfile/);
});

test('a new number is verified with a WhatsApp code sent to it; the password screen goes through the server', () => {
  assert.match(app, /pxAuthApi\('phone_change_start',\{phone,password\},true\)/);
  assert.match(app, /pxAuthApi\('phone_change_finish',\{phone:_cp\.phone,code\},true\)/);
  assert.match(app, /pxAuthApi\('password_change',\{current,password\},true\)/);
  assert.match(html, /<div class="acx-phone"><span class="acx-cc"[^>]*><svg class="iq-flag"[\s\S]*?\+964<\/b><\/span><input class="acx-input" id="cpPhone"/);
  // blocked changes show a calm notice with the date, not an error
  assert.match(app, /ئێستا ناتوانیت ناوی هەژمار بگۆڕیت/);
  assert.match(app, /ئێستا ناتوانیت ژمارەی مۆبایل بگۆڕیت/);
  assert.match(app, /ناتوانیت ناوی هەژمار بگۆڕیت/);
});

test('WhatsApp has no number of its own: only the verified account number, one account per number', () => {
  assert.doesNotMatch(wa, /p_phone/);
  assert.match(wa, /navigate\('change-phone'\)/);
  assert.match(sql, /create unique index if not exists ex_profiles_verified_phone_uniq\s+on public\.ex_profiles \(phone\) where phone_verified_at is not null/);
  assert.match(sql, /where p\.id = new\.user_id and p\.phone_verified_at is not null and not p\.is_banned/);
  assert.match(sql, /raise exception 'phone_not_verified'/);
});

test('database rules: name and number once every 30 days, name fixed after verification, number only from the server', () => {
  assert.match(sql, /message = 'PROFILE_NAME_COOLDOWN'/);
  assert.match(sql, /old\.name_changed_at \+ interval '30 days'/);
  assert.match(sql, /v\.phone_changed_at \+ interval '30 days' > now\(\)/);
  assert.match(sql, /message = 'PROFILE_NAME_LOCKED_BY_KYC'/);
  assert.match(sql, /if not v_backend then\s+new\.phone\s+:= old\.phone;/);
  assert.match(sql, /revoke all on function public\.ex_account_phone_set\(uuid, text\)\s+from public, anon, authenticated;/);
  assert.match(sql, /check \(purpose in \('signup', 'login', 'reset', 'change_phone'\)\)/);
});

test('v43: an e-mail next to the number; sign in and reset with either; admins can change both', () => {
  const sql43 = readFileSync(new URL('../supabase/migrations/20261115020000_account_email_and_admin_contact.sql', import.meta.url), 'utf8');
  const admin = readFileSync(new URL('../assets/js/admin.js', import.meta.url), 'utf8');
  assert.match(app, /pxAuthApi\('email_change_start',\{email,password\},true\)/);
  assert.match(app, /pxAuthApi\('email_change_finish',\{email:_ce\.email,code\},true\)/);
  assert.match(sql43, /create unique index if not exists ex_profiles_verified_email_uniq\s+on public\.ex_profiles \(lower\(email\)\) where email_verified_at is not null/);
  assert.match(sql43, /create or replace function public\.ex_auth_resolve\(p_identifier text\)/);
  assert.match(sql43, /new\.email\s+:= old\.email;\s+new\.email_verified_at := old\.email_verified_at;/);
  assert.match(admin, /adminApiRequest\('account_contact_update',\{user_id:userId,email:email\|\|null,phone:phone\|\|null\}\)/);
  assert.match(admin, /adminApiRequest\('account_set_password', \{ user_id:userId, password:pass \}\)/);
});

test('v44: plain Kurdish labels, no explanations, and a new code only after the old one expired', () => {
  const sql44 = readFileSync(new URL('../supabase/migrations/20261115030000_codes_resend_after_expiry.sql', import.meta.url), 'utf8');
  const auth = readFileSync(new URL('../api-handlers/auth.js', import.meta.url), 'utf8');
  for (const id of ['authPhone', 'signupPhone', 'forgotPhone', 'cpPhone']) assert.match(html, new RegExp(`id="${id}"[^>]*placeholder="750 123 4567"|placeholder="750 123 4567"[^>]*id="${id}"`));
  assert.doesNotMatch(html, /ئیمەیڵی Gmail|example@gmail\.com|class="acx-hint"|class="auth-hint"|class="wa-hint"|Spam/);
  assert.doesNotMatch(app, /تەنها ئیمەیڵی Gmail|7XX XXX XXXX|07XX XXX XXXX/);
  assert.match(app, /startOtpTimer\(pxSecondsLeft\(expiresAt,channel==='whatsapp'\?300:600\)\)/);
  assert.match(auth, /if \(issued\?\.active\) return \{ channel: 'whatsapp'/);
  assert.match(sql44, /message = 'CODE_STILL_VALID'/);
  assert.match(sql44, /before insert on public\.ex_otp_codes/);
});

test('v47: every profile screen starts with the same toolbar (back right, centered title) and no subtitle', () => {
  const css = readFileSync(new URL('../assets/css/profile-screens.css', import.meta.url), 'utf8');
  for (const id of ['pageProfile', 'pageAccountName', 'pageChangePhone', 'pageChangeEmail', 'pageChangePassword', 'pageDeleteAccount', 'pageVerify', 'pageSupport', 'pageBalance', 'pageChanges']) {
    const start = html.indexOf(`id="${id}"`);
    const section = html.slice(start, html.indexOf('</section>', start));
    assert.match(section, /^[^>]*>\s*<div class="pfx-bar">\s*<button type="button" class="pfx-bar-btn"/, id);
    assert.doesNotMatch(section, /class="page-head|class="acx-bar"|class="dax-bar"/, id);
  }
  assert.match(css, /body #mainApp \.pfx-bar h2 \{[^}]*font-size: 16px;[^}]*font-weight: 700;/);
  assert.match(css, /body #mainApp \.pfx-bar \{ margin-bottom: 14px !important; \}/);
  assert.match(html, /\/assets\/css\/profile-screens\.css\?v=1/);
});

test('v48: the code screens offer "send again" only after the code expired, and the confirm button never stays busy', () => {
  const css = readFileSync(new URL('../assets/css/auth-otp.css', import.meta.url), 'utf8');
  for (const p of ['otp', 'fp']) {
    // the button starts hidden with the real `hidden` attribute (CSS can no longer show it early)
    assert.match(html, new RegExp(`id="${p}ResendBtn" onclick="${p === 'otp' ? 'resendOtp' : 'fpResendOtp'}\\(\\)" hidden>دووبارە ناردنەوە</button>`));
    assert.match(html, new RegExp(`<span class="otp-wait" id="${p}TimerWrap">دووبارە ناردنەوە لە <b id="${p}TimerVal" dir="ltr">`));
  }
  assert.match(css, /:is\(\.otp-wait, \.otp-again-btn\)\[hidden\] \{ display: none !important; \}/);
  assert.match(app, /if\(!btn\|\|btn\.disabled\|\|btn\.hidden\) return;\s+\/\/ only after the code expired/);
  assert.match(app, /function startOtpTimer\(seconds\)\{ clearInterval\(_otpTimer\); otpVerifyIdle\('otpVerifyBtn'\);/);
  assert.match(app, /function fpStartTimer\(sec\)\{ clearInterval\(_fpTimer\); otpVerifyIdle\('fpVerifyBtn'\);/);
  assert.doesNotMatch(app, /ICON\.check\+' دڵنیاکردنەوە'/);
  assert.match(app, /if\(alreadySent\) showOtpMsg\('کۆدی پێشوو هێشتا کاردەکات','ok'\)/);
  // no explanations under the auth titles
  assert.doesNotMatch(html, /بەخێربێیتەوە\. بۆ بەردەوامبوون|زانیارییەکانت بنووسە بۆ|بۆ وەرگرتنی کۆد\./);
  assert.match(html, /id="authName">/);
  assert.match(html, /\/assets\/css\/auth-otp\.css\?v=1/);
});
