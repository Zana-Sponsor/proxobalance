import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

// v55: working hours open and close a switch by themselves.
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const sql = read('supabase/migrations/20261115234929_working_hours.sql');

test('database: hours act only at an opening or closing time and never undo a hand change', () => {
  assert.match(sql, /continue when s\.last_state is not distinct from v_state;/);
  // closing: only a switch that is on, marked as closed by the hours
  assert.match(sql, /set paused = true, message = v_msg, paused_source = 'schedule', updated_at = now\(\), updated_by = null\n\s+where key = s\.key and not paused;/);
  // opening: only what the hours closed
  assert.match(sql, /where key = p_key and paused and paused_source = 'schedule';/);
  // a hand change is marked as the admin's
  assert.match(sql, /paused_source = 'admin',\n\s+updated_at = now\(\),\n\s+updated_by = p_admin/);
  // Baghdad time; a closing time at or before the opening time ends the next day
  assert.match(sql, /\(p_now at time zone 'Asia\/Baghdad'\)/);
  assert.match(sql, /else \(x\.d = any\(p_days\) and x\.tm >= p_open\) or \(x\.yd = any\(p_days\) and x\.tm < p_close\)/);
  assert.match(sql, /perform cron\.schedule\('ex-site-schedule', '\* \* \* \* \*', 'select public\.ex_site_schedule_tick\(\)'\);/);
  // private: the panel reaches it only through /api/admin
  assert.match(sql, /alter table public\.ex_site_schedules enable row level security;\nrevoke all on public\.ex_site_schedules from anon, authenticated;/);
  assert.match(sql, /grant execute on function public\.ex_admin_site_schedule_save\(text, time, time, smallint\[\], text, boolean, uuid\) to service_role;/);
  assert.doesNotMatch(sql, /ex_rates|rate_value|grant execute on function public\.ex_admin_site_schedule_save\([^)]*\) to authenticated/);
});

test('admin API: hours are checked before they are saved; full admins only', () => {
  const admin = read('api-handlers/admin.js');
  assert.match(admin, /'site_controls','site_control_set','site_schedule_save','site_schedule_delete'\]\.includes\(action\)&&profile\.role!=='super_admin'/);
  assert.match(admin, /const TIME = \/\^\(\[01\]\\d\|2\[0-3\]\):\[0-5\]\\d\$\/;/);
  assert.match(admin, /if \(!SITE_KEYS\.includes\(key\) \|\| !TIME\.test\(String\(open_at\)\) \|\| !TIME\.test\(String\(close_at\)\) \|\| open_at === close_at\)/);
  assert.match(admin, /db\.from\('ex_site_schedules'\)\.select\('key,open_at,close_at,days,message,is_active,last_state,updated_at'\)/);
  assert.match(admin, /schedules: schedules\.error \? \[\] : \(schedules\.data \|\| \[\]\)/);
});

// the panel's words match what customers read
function words() {
  const js = read('assets/js/exchange-site-pause-admin.js');
  const days = js.slice(js.indexOf('  const DAYS = '), js.indexOf('\n', js.indexOf('  const DAYS = ')));
  const start = js.indexOf('  function daysText(');
  const end = js.indexOf('\n  }\n', js.indexOf('  function autoText(')) + 4;
  const ctx = vm.createContext({});
  vm.runInContext(days + '\n' + js.slice(start, end) + '\nthis.daysText = daysText; this.autoText = autoText;', ctx);
  return ctx;
}

test('panel: hours read the same as the customer message', () => {
  const { daysText, autoText } = words();
  assert.equal(daysText([0, 1, 2, 3, 4, 5, 6]), 'هەموو ڕۆژێک');
  assert.equal(daysText([0, 1, 2, 3, 4, 6]), 'جگە لە هەینی');
  assert.equal(daysText([1, 0, 6]), 'شەممە، یەکشەممە، دووشەممە');
  assert.equal(autoText('09:00', '00:00', [0, 1, 2, 3, 4, 5, 6]), 'کاتی کار: 09:00 تا 00:00');
  assert.equal(autoText('09:00', '17:00', [0, 1, 2, 3, 4, 6]), 'کاتی کار: جگە لە هەینی، 09:00 تا 17:00');
  assert.equal(autoText('09:00', '17:00', [6, 0, 1]), 'کاتی کار: شەممە، یەکشەممە، دووشەممە، 09:00 تا 17:00');
  const html = read('exchange-admin.html');
  assert.match(html, /<div id="psHours"><\/div>/);
  assert.match(html, /<div class="overlay" id="moSiteHours">/);
  assert.match(html, /<input class="minp" type="time" id="phOpen" dir="ltr" step="60" oninput="previewSiteHours\(\)">/);
  assert.match(html, /exchange-site-pause-admin\.js\?v=3/);
  const js = read('assets/js/exchange-site-pause-admin.js');
  assert.match(js, /if \(r\.paused_source === 'schedule'\) return '<span class="ps-state off">داخراوە بەپێی کاتژمێری کار<\/span>';/);
  assert.match(js, /await adminApiRequest\('site_schedule_save', body\);/);
});
