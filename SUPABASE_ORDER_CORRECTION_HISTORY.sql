-- Immutable audit history for transaction corrections.
-- The trigger captures the order before an admin correction request and the
-- corrected order after the customer resubmits it, in the same DB transaction.

begin;

create table if not exists public.ex_order_correction_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.ex_orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  correction_number integer not null,
  request text not null,
  requested_by uuid null references auth.users(id) on delete set null,
  requested_at timestamptz not null,
  old_data jsonb not null,
  new_data jsonb null,
  customer_response text null,
  responded_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint ex_order_correction_history_number_check
    check (correction_number between 1 and 20),
  constraint ex_order_correction_history_request_check
    check (char_length(btrim(request)) between 5 and 2000),
  constraint ex_order_correction_history_response_check
    check (customer_response is null or char_length(btrim(customer_response)) between 5 and 2000),
  constraint ex_order_correction_history_order_number_key
    unique (order_id, correction_number)
);

create index if not exists ex_order_correction_history_order_idx
  on public.ex_order_correction_history (order_id, correction_number desc);

create index if not exists ex_order_correction_history_user_idx
  on public.ex_order_correction_history (user_id, requested_at desc);

create index if not exists ex_order_correction_history_requested_by_idx
  on public.ex_order_correction_history (requested_by)
  where requested_by is not null;

create index if not exists ex_order_correction_history_pending_idx
  on public.ex_order_correction_history (requested_at desc)
  where new_data is null;

alter table public.ex_order_correction_history enable row level security;

-- This audit table is server-only. Admin/customer authorization is checked in
-- the Vercel API; public browser clients cannot query or mutate the history.
revoke all on table public.ex_order_correction_history from public, anon, authenticated;
grant select, insert, update, delete on table public.ex_order_correction_history to service_role;

create or replace function public.ex_capture_order_correction_history()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  old_snapshot jsonb;
  new_snapshot jsonb;
begin
  old_snapshot := jsonb_build_object(
    'from_method', old.from_method,
    'to_method', old.to_method,
    'amount', old.amount,
    'total', old.total,
    'fee', old.fee,
    'phone', old.phone,
    'sender_name', old.sender_name,
    'sender_phone', old.sender_phone,
    'receipt_url', old.receipt_url,
    'receipt_hash', old.receipt_hash,
    'transaction_reference', old.transaction_reference,
    'extra_info', old.extra_info,
    'status', old.status
  );

  if new.status = 'پێویستی بە ڕاستکردنەوەیە'
     and new.correction_count > old.correction_count then
    insert into public.ex_order_correction_history (
      order_id,
      user_id,
      correction_number,
      request,
      requested_by,
      requested_at,
      old_data
    ) values (
      new.id,
      new.user_id,
      new.correction_count,
      new.correction_request,
      new.correction_requested_by,
      coalesce(new.correction_requested_at, now()),
      old_snapshot
    );
  end if;

  if old.status = 'پێویستی بە ڕاستکردنەوەیە'
     and new.status = 'ڕاستکراوەتەوە' then
    new_snapshot := jsonb_build_object(
      'from_method', new.from_method,
      'to_method', new.to_method,
      'amount', new.amount,
      'total', new.total,
      'fee', new.fee,
      'phone', new.phone,
      'sender_name', new.sender_name,
      'sender_phone', new.sender_phone,
      'receipt_url', new.receipt_url,
      'receipt_hash', new.receipt_hash,
      'transaction_reference', new.transaction_reference,
      'extra_info', new.extra_info,
      'status', new.status
    );

    update public.ex_order_correction_history
    set new_data = new_snapshot,
        customer_response = new.correction_response,
        responded_at = coalesce(new.correction_responded_at, now())
    where order_id = new.id
      and correction_number = new.correction_count
      and new_data is null;
  end if;

  return new;
end;
$$;

revoke all on function public.ex_capture_order_correction_history() from public, anon, authenticated;

drop trigger if exists ex_orders_capture_correction_history on public.ex_orders;
create trigger ex_orders_capture_correction_history
after update of status, correction_count on public.ex_orders
for each row
execute function public.ex_capture_order_correction_history();

comment on table public.ex_order_correction_history is
  'Server-only immutable audit trail containing the old and new transaction snapshots for every correction cycle.';

commit;
