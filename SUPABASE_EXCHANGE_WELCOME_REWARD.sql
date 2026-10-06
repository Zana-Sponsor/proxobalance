-- New signups only. The Auth INSERT grants one wallet-fee reward atomically
-- with the existing profile creation. No existing accounts are backfilled.
alter table public.ex_user_rewards add column if not exists campaign_key text;
create unique index if not exists ex_user_rewards_campaign_once_idx
  on public.ex_user_rewards(user_id,campaign_key) where campaign_key is not null;
comment on column public.ex_user_rewards.campaign_key is
  'Server-assigned campaign identity. One grant per account and campaign.';

create or replace function public.ex_handle_new_user()
returns trigger language plpgsql security definer set search_path=''
as $fn$
declare
  v_signup timestamptz:=coalesce(new.created_at,now());
  v_reward uuid;
begin
  insert into public.ex_profiles(id,full_name,email)
    values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),new.email)
    on conflict(id) do nothing;
  -- Metadata is used for the display name only, never for reward terms or roles.
  insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,
    used_count,max_amount_iqd,reward_scope,valid_until,active,note,campaign_key,created_at)
    values(new.id,'fee_discount',50,1,0,30000,'wallets',v_signup+interval '7 days',
      true,'پاداشتی هەژماری نوێ: یەک جار، ٥٠٪ لە لێبڕین تا ٣٠٬٠٠٠ دینار، بۆ حەوت ڕۆژ',
      'welcome_signup_v1',v_signup)
    on conflict(user_id,campaign_key) where campaign_key is not null do nothing
    returning id into v_reward;
  -- Reuse the existing deduplicated last-use notification created by the
  -- reward reminder trigger, rather than sending two signup notifications.
  if v_reward is not null then
    update public.ex_notifications set
      title='پاداشتی هەژماری نوێت ئامادەیە',
      message='٥٠٪ داشکاندنی لێبڕینی واڵێتەکان، یەک جار تا بڕی ٣٠٬٠٠٠ دینار. بۆ حەوت ڕۆژ کارایە؛ بڕی زیادە بە لێبڕینی ئاسایی هەژمار دەکرێت.'
      where reward_id=v_reward and reward_alert_kind='last_use';
  end if;
  return new;
end $fn$;
revoke all on function public.ex_handle_new_user() from public,anon,authenticated;
-- Existing owner-only reward SELECT and service-role writes stay in force.
revoke insert,update,delete on public.ex_user_rewards from anon,authenticated;

