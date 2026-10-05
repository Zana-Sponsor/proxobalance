-- Exchange orders are created by /api/orders after authentication, live wallet/rate
-- checks, receipt deduplication and server-side calculation. The reward trigger
-- then applies the customer's eligible fee reward in the same transaction.
--
-- REVOKE at table level does not remove old column-level INSERT grants.
-- Close both paths without changing SELECT, admin column UPDATE permissions,
-- server-role access, customer data, rewards or balances.
revoke insert on table public.ex_orders from public, anon, authenticated;

do $guard$
declare
  columns_sql text;
begin
  select string_agg(format('%I', attname), ', ' order by attnum)
    into columns_sql
    from pg_attribute
   where attrelid = 'public.ex_orders'::regclass
     and attnum > 0 and not attisdropped;

  execute format(
    'revoke insert (%s) on table public.ex_orders from public, anon, authenticated',
    columns_sql
  );

  if has_any_column_privilege('authenticated', 'public.ex_orders', 'INSERT')
     or has_any_column_privilege('anon', 'public.ex_orders', 'INSERT') then
    raise exception 'Legacy direct order INSERT permission remains';
  end if;
  if not has_table_privilege('service_role', 'public.ex_orders', 'INSERT') then
    raise exception 'Authenticated server order creation must remain available';
  end if;
  if not has_table_privilege('authenticated', 'public.ex_orders', 'SELECT') then
    raise exception 'Customer order-history read permission must remain available';
  end if;
end
$guard$;
