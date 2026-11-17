import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const migration = read('supabase/migrations/20261117102943_admin_whatsapp_all_verified_numbers.sql');
const admin = read('assets/js/exchange-whatsapp-admin.js');
const html = read('exchange-admin.html');
const workflow = read('.github/workflows/exchange-production-smoke.yml');

test('admin subscriber RPC lists every verified, valid profile and defaults missing settings to off', () => {
  assert.match(migration, /from public\.ex_profiles p\s+left join public\.ex_whatsapp_settings s on s\.user_id = p\.id/i);
  assert.match(migration, /p\.phone_verified_at is not null/i);
  assert.match(migration, /public\.ex_wa_normalize_phone\(p\.phone\) is not null/i);
  assert.match(migration, /coalesce\(s\.enabled, false\) as enabled/i);
  assert.match(migration, /coalesce\(s\.created_at, p\.created_at\)/i);
});

test('admin toggles verify the customer number, update or create settings, and retain the admin audit trail', () => {
  assert.match(migration, /if v_phone is null then\s+raise exception 'phone_not_verified'/i);
  assert.match(migration, /insert into public\.ex_whatsapp_settings \(user_id, phone, enabled\)/i);
  assert.match(migration, /on conflict \(user_id\) do update/i);
  assert.match(migration, /insert into public\.ex_whatsapp_consent_log \(user_id, enabled, phone, changed_by\)/i);
  assert.match(admin, /adminApiRequest\('whatsapp_set', \{ user_id: userId, enabled \}\)/);
  assert.match(migration, /revoke all on function public\.ex_admin_whatsapp_set\(uuid, boolean, uuid\) from public, anon, authenticated;/i);
  assert.match(migration, /grant execute on function public\.ex_admin_whatsapp_set\(uuid, boolean, uuid\) to service_role;/i);
});

test('super-admin panel explains the verified list and future-only customer order notifications', () => {
  assert.match(html, /ژمارە پشتڕاستکراوەکانی کڕیار/);
  assert.match(html, /کۆنترۆڵەکە تەنها بۆ نامەکانی داهاتووە/);
  assert.match(html, /exchange-whatsapp-admin\.js\?v=4/);
  assert.match(admin, /پشتڕاستکراوە/);
  assert.match(html, /data-wasf="on"/);
  assert.match(html, /data-wasf="off"/);
  assert.match(workflow, /exchange-whatsapp-admin\.js\?v=4/);
});
