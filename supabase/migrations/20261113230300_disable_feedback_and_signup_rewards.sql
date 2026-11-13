-- Stop future rewards for submitting transaction feedback and for signing up.
-- Keep rating ownership/status validation and new-user profile creation intact.
-- Existing reward rows/history are intentionally preserved.

create or replace function public.ex_award_order_feedback_reward()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_order record;
begin
  select id,user_id,status into v_order
    from public.ex_orders
   where id=new.order_id and user_id=new.user_id
   for share;
  if not found or v_order.status is distinct from 'پەسەندکرا' then
    raise exception 'FEEDBACK_REQUIRES_APPROVED_OWN_ORDER' using errcode='42501';
  end if;
  return new;
end
$function$;
revoke all on function public.ex_award_order_feedback_reward() from public,anon,authenticated;

-- The trigger remains in place as an approved-owner guard, but no longer grants
-- an ex_user_rewards row when feedback is inserted.

create or replace function public.ex_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  insert into public.ex_profiles(id,full_name,email)
    values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),new.email)
    on conflict(id) do nothing;
  return new;
end
$function$;
revoke all on function public.ex_handle_new_user() from public,anon,authenticated;

-- Keep the auth.users trigger: it still creates profiles. No welcome reward or
-- reward notification is issued for newly created accounts.
