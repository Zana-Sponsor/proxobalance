-- Keep the server-side admin report without exposing auth.users through public.
create or replace view public.pa_transactions_with_email
with (security_invoker=true)
as
select
  t.id, t.user_id, t.amount, t.method, t.receipt_url, t.receipt_b64,
  t.status, t.created_at, t.kind, t.ad_number, t.note, t.deposit_number,
  t.type, t.receiver_email, t.receiver_id, t.sender_email, t.sender_id,
  t.fee, p.email::varchar(255) as email
from public.pa_transactions t
left join public.profiles p on p.id=t.user_id;

revoke all on public.pa_transactions_with_email from public,anon,authenticated;
grant select on public.pa_transactions_with_email to service_role;
