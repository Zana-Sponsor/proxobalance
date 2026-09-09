-- Proxo Balance transaction correction workflow
-- Admin requests a correction on an exchange order; the owner can safely
-- resubmit only the recipient/sender numbers, receipt, and a short response.

begin;

alter table public.ex_orders
  add column if not exists correction_request text null,
  add column if not exists correction_requested_at timestamptz null,
  add column if not exists correction_requested_by uuid null references auth.users(id) on delete set null,
  add column if not exists correction_response text null,
  add column if not exists correction_responded_at timestamptz null,
  add column if not exists correction_count integer not null default 0;

alter table public.ex_orders
  drop constraint if exists ex_orders_status_check,
  drop constraint if exists ex_orders_correction_request_check,
  drop constraint if exists ex_orders_correction_response_check,
  drop constraint if exists ex_orders_correction_count_check;

alter table public.ex_orders
  add constraint ex_orders_status_check
    check (status in (
      'چاوەڕوانە',
      'پێویستی بە ڕاستکردنەوەیە',
      'ڕاستکراوەتەوە',
      'پەسەندکرا',
      'ڕەتکرا'
    )),
  add constraint ex_orders_correction_request_check
    check (correction_request is null or char_length(btrim(correction_request)) between 5 and 2000),
  add constraint ex_orders_correction_response_check
    check (correction_response is null or char_length(btrim(correction_response)) between 5 and 2000),
  add constraint ex_orders_correction_count_check
    check (correction_count between 0 and 20);

create index if not exists ex_orders_correction_queue_idx
  on public.ex_orders (status, correction_responded_at desc)
  where status in ('پێویستی بە ڕاستکردنەوەیە', 'ڕاستکراوەتەوە');

create index if not exists ex_orders_correction_requested_by_idx
  on public.ex_orders (correction_requested_by)
  where correction_requested_by is not null;

comment on column public.ex_orders.correction_request is
  'Admin instructions describing which transaction fields the customer must correct.';
comment on column public.ex_orders.correction_response is
  'Customer explanation submitted with the corrected transaction data.';

-- An earlier draft attached the workflow to support cases. No support-case
-- correction data existed when this migration was prepared, so remove only
-- those unused draft fields and restore the ordinary support statuses.
update public.ex_support_cases
set status = 'in_progress'
where status in ('needs_correction', 'corrected');

alter table public.ex_support_cases
  drop constraint if exists ex_support_cases_status_check,
  drop constraint if exists ex_support_cases_correction_request_check,
  drop constraint if exists ex_support_cases_customer_response_check;

alter table public.ex_support_cases
  add constraint ex_support_cases_status_check
    check (status in ('open', 'in_progress', 'resolved', 'closed'));

alter table public.ex_support_cases
  drop column if exists correction_request,
  drop column if exists correction_requested_at,
  drop column if exists customer_response,
  drop column if exists customer_responded_at;

commit;
