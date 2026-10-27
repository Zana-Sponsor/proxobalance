/** Synthetic-only SQL builder, shared by disposable PGlite and PostgreSQL tests. */
import fs from 'node:fs/promises';
const read=path=>fs.readFile(new URL('../'+path,import.meta.url),'utf8');
export async function fastpayDatabaseFixtureSql(){
 const checkout=await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
 const sql=[
  await read('test/fixtures/secure-operations-database.sql'),
  await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'),
  await read('test/fixtures/legacy-fastpay-baseline.sql'),
  'create unique index legacy_fixture_order_unique on public.pa_transactions(fastpay_order_id);',
  checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('),checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')),
 ];
 for(const name of (await fs.readdir(new URL('../proxo_app/supabase/migrations/',import.meta.url))).filter(n=>/^2026102[23].*\.sql$/.test(n)).sort())
  sql.push(await read('proxo_app/supabase/migrations/'+name));
 sql.push(await read('proxo_app/supabase/migrations/20261026213026_fastpay_unstarted_attempt_closure.sql'));
 return sql.join('\n');
}
export const legacyCheckoutMigrationSql=()=>read('proxo_app/supabase/migrations/20261026214905_legacy_fastpay_durable_checkout.sql');
