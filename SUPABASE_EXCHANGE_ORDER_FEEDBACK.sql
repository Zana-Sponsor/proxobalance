-- One customer rating and optional comment per approved exchange order.
create table if not exists public.ex_order_feedback (
  order_id uuid primary key references public.ex_orders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(btrim(comment)) <= 1000),
  created_at timestamptz not null default now()
);

create index if not exists ex_order_feedback_user_created_idx
  on public.ex_order_feedback (user_id, created_at desc);

alter table public.ex_order_feedback enable row level security;

revoke all on public.ex_order_feedback from anon, public;
grant select, insert on public.ex_order_feedback to authenticated;

create policy ex_order_feedback_select_own_or_staff
  on public.ex_order_feedback for select to authenticated
  using (user_id = (select auth.uid()) or (select public.ex_staff_has('view')));

create policy ex_order_feedback_insert_approved_own
  on public.ex_order_feedback for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.ex_orders o
      where o.id = order_id
        and o.user_id = (select auth.uid())
        and o.status = 'پەسەندکرا'
    )
  );

comment on table public.ex_order_feedback is
  'One immutable customer rating and comment for each approved exchange order.';
comment on column public.ex_order_feedback.rating is
  'Customer rating from one to five stars.';
comment on column public.ex_order_feedback.comment is
  'Optional customer comment, limited to 1000 characters.';
