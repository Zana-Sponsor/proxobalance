-- New explicit TikTok page types only. Legacy clients, direct-message quote
-- validation, pricing, wallet writes and idempotent submission remain delegated
-- to the existing implementation. This migration does not enable any feature.
begin;

alter function public.pa_create_ad(jsonb,numeric,uuid,text,numeric)
  rename to pa_create_ad_before_typed_pages;
revoke all on function public.pa_create_ad_before_typed_pages(jsonb,numeric,uuid,text,numeric)
  from public,anon,authenticated,service_role;

create function public.pa_create_ad(
  p_ad jsonb,p_cost_usd numeric,p_promo_id uuid default null,
  p_promo_code text default null,p_promo_discount numeric default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  u uuid:=auth.uid();
  kind text;
  expected_kind text;
  asset uuid;
begin
  if p_ad ? 'tiktok_ad_type' then
    if u is null then return jsonb_build_object('ok',false,'code','NOT_AUTHENTICATED'); end if;
    kind:=p_ad->>'tiktok_ad_type';
    if kind is null or kind not in ('contact','views','restaurant','app_download')
      or coalesce(p_ad->>'message_destination','external_contact')<>'external_contact'
      or coalesce(p_ad->>'platform','TIKTOK')<>'TIKTOK'
      or p_ad->>'goal' is distinct from (case when kind='views' then 'views' else 'messages' end)
      or p_ad->>'category' is distinct from (case kind
        when 'restaurant' then 'food_beverage' when 'app_download' then 'games_apps' else 'other' end)
    then return jsonb_build_object('ok',false,'code','INVALID_AD_TYPE'); end if;

    if kind='views' then
      if nullif(p_ad->>'asset_id','') is not null or nullif(p_ad->>'card_id','') is not null then
        return jsonb_build_object('ok',false,'code','INVALID_ASSET');
      end if;
    else
      expected_kind:=case kind when 'restaurant' then 'order' when 'app_download' then 'download' else 'contact' end;
      begin asset:=nullif(p_ad->>'asset_id','')::uuid;
      exception when invalid_text_representation then
        return jsonb_build_object('ok',false,'code','INVALID_ASSET');
      end;
      -- Lock the eligible row until the existing financial transaction ends.
      -- Deactivation/archive/type changes cannot race the accepted purchase.
      perform 1 from public.proxolink_cards c
        where c.id=asset and c.user_id=u
          and coalesce(c.page_kind,'contact')=expected_kind
          and c.status='active' and c.publish_status='ready' and c.archived_at is null
        for share;
      if not found then return jsonb_build_object('ok',false,'code','INVALID_ASSET'); end if;
    end if;
  end if;
  return public.pa_create_ad_before_typed_pages(p_ad,p_cost_usd,p_promo_id,p_promo_code,p_promo_discount);
end $$;

-- Keep the pre-existing server-only entry boundary; clients still submit via
-- pa_submit_ad and its unchanged idempotency, pricing and outbox transaction.
revoke all on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric) from public,anon,authenticated;
grant execute on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric) to service_role;
commit;
