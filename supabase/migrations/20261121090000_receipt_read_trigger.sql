-- Receipt reading, done entirely in Supabase (schema and save RPC: 20261121080000).
-- When an order gets a receipt (a new order, or a new receipt in a correction), the trigger
-- asks the Edge Function receipt-read to read it (pg_net, after the transaction commits).
-- The panel's «دووبارە خوێندنەوە» calls ex_receipt_read_queue through the server.
-- The reader key travels in the x-receipt-key header; it is kept in Vault as
-- 'receipt_read_key' (added on the server, not in the repository), and only its sha256 is in
-- ex_receipt_read_keys. Nothing here can stop an order: every failure is swallowed.

create extension if not exists pg_net with schema extensions;

create or replace function public.ex_receipt_read_queue(p_order_id uuid)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_id bigint;
begin
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'receipt_read_key' limit 1;
  if v_key is null or p_order_id is null then return null; end if;
  select net.http_post(
    url := 'https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',
    body := jsonb_build_object('order_id', p_order_id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-receipt-key', v_key),
    timeout_milliseconds := 10000
  ) into v_id;
  return v_id;
exception when others then
  return null;
end;
$$;
revoke all on function public.ex_receipt_read_queue(uuid) from public, anon, authenticated;
grant execute on function public.ex_receipt_read_queue(uuid) to service_role;

create or replace function public.ex_orders_queue_receipt_read()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.receipt_url is not null
     and (tg_op = 'INSERT' or new.receipt_url is distinct from old.receipt_url) then
    perform public.ex_receipt_read_queue(new.id);
  end if;
  return null;
exception when others then
  return null;
end;
$$;
revoke all on function public.ex_orders_queue_receipt_read() from public, anon, authenticated;

drop trigger if exists trg_ex_orders_zz_receipt_read on public.ex_orders;
create trigger trg_ex_orders_zz_receipt_read
  after insert or update of receipt_url on public.ex_orders
  for each row execute function public.ex_orders_queue_receipt_read();
