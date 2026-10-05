-- Run against the Exchange project after SUPABASE_EXCHANGE_SERVER_ONLY_ORDERS.sql.
-- Read-only catalog assertions: no customer, order, reward or balance is created.
do $test$
declare
  table_name text;
  role_name text;
  privilege_name text;
begin
  foreach role_name in array array['anon', 'authenticated'] loop
    if has_any_column_privilege(role_name, 'public.ex_orders', 'INSERT') then
      raise exception '% can bypass /api/orders using a column INSERT grant', role_name;
    end if;
    foreach table_name in array array[
      'ex_user_rewards', 'ex_reward_usages', 'ex_customer_balances',
      'ex_balance_journal', 'ex_balance_entries', 'ex_refund_cases',
      'ex_payout_requests'
    ] loop
      foreach privilege_name in array array['INSERT', 'UPDATE'] loop
        if has_any_column_privilege(role_name, 'public.' || table_name, privilege_name) then
          raise exception '% has direct % access to %', role_name, privilege_name, table_name;
        end if;
      end loop;
      if has_table_privilege(role_name, 'public.' || table_name, 'DELETE') then
        raise exception '% has direct DELETE access to %', role_name, table_name;
      end if;
    end loop;
  end loop;
  if not has_table_privilege('service_role', 'public.ex_orders', 'INSERT') then
    raise exception 'Server cannot create orders';
  end if;
  if not has_table_privilege('authenticated', 'public.ex_orders', 'SELECT') then
    raise exception 'Customer cannot read order history';
  end if;
  if not has_column_privilege('authenticated', 'public.ex_orders', 'admin_note', 'UPDATE')
     or not has_column_privilege('authenticated', 'public.ex_orders', 'payout_receipt_url', 'UPDATE') then
    raise exception 'Existing admin notes/receipt upload permissions changed';
  end if;
end
$test$;
