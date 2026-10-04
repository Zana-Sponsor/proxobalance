-- Execute after the cutover SQL inside an explicit test transaction.
-- The final ROLLBACK discards all customer/card/token/event changes.

do $test$
declare v_a public.pa_ad_contact_links%rowtype;v_b public.pa_ad_contact_links%rowtype;
begin
 select * into v_a from public.pa_ad_contact_links l
 where exists(select 1 from public.pa_ad_contact_links x where x.card_id=l.card_id and x.ad_id<>l.ad_id) limit 1;
 select * into v_b from public.pa_ad_contact_links where card_id=v_a.card_id and ad_id<>v_a.ad_id limit 1;
 if v_a.id is null or v_b.id is null then raise exception 'No independent same-card ad fixture'; end if;
 insert into public.pa_contact_events(ad_contact_link_id,event_type,button_type,ip_address,ip_hash,session_id,user_agent,created_at)
 values(v_a.id,'page_view',null,'8.8.8.8','test-hash','77777777-7777-4777-8777-777777777777','test-browser',now()-interval '31 days'),
 (v_a.id,'button_click','whatsapp','8.8.8.8',null,null,null,now()),
 (v_b.id,'button_click','tiktok','8.8.8.8',null,null,null,now());
 if exists(select 1 from public.pa_contact_events where ip_address is not null) then raise exception 'Raw IP retained';end if;
 perform proxolink_private.retain_contact_events();
 if exists(select 1 from public.pa_contact_events where created_at<now()-interval '30 days' and (ip_hash is not null or user_agent is not null or session_id is not null)) then raise exception 'Visitor retention failed'; end if;
 perform set_config('proxolink.verify_ad_a',v_a.ad_id::text,true);
 perform set_config('proxolink.verify_ad_b',v_b.ad_id::text,true);
 perform set_config('request.jwt.claim.sub',v_a.owner_user_id::text,true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub',v_a.owner_user_id,'role','authenticated')::text,true);
end $test$;
set local role service_role;
do $test$
declare v_a jsonb;v_b jsonb;
begin
 v_a=public.proxolink_ad_summary(current_setting('proxolink.verify_ad_a')::uuid);
 v_b=public.proxolink_ad_summary(current_setting('proxolink.verify_ad_b')::uuid);
 if v_a->>'page_views'<>'1' or v_a->>'button_clicks'<>'1' or v_a->'buttons'->>'whatsapp'<>'1' or v_a->'buttons'->>'tiktok'<>'0' then raise exception 'Ad A attribution failed'; end if;
 if v_b->>'page_views'<>'0' or v_b->>'button_clicks'<>'1' or v_b->'buttons'->>'whatsapp'<>'0' or v_b->'buttons'->>'tiktok'<>'1' then raise exception 'Ad B attribution failed'; end if;
 perform set_config('request.jwt.claim.sub','99999999-9999-4999-8999-999999999999',true);
 perform set_config('request.jwt.claims','{"sub":"99999999-9999-4999-8999-999999999999","role":"authenticated"}',true);
 begin
  perform public.proxolink_ad_summary(current_setting('proxolink.verify_ad_a')::uuid);
  raise exception 'Another owner read private ad totals';
 exception when raise_exception then if sqlerrm<>'NOT_FOUND' then raise; end if;
 end;
end $test$;
reset role;
set local role authenticated;
do $test$ begin
 begin
  perform public.proxolink_ad_summary(current_setting('proxolink.verify_ad_a')::uuid);
  raise exception 'Ordinary client accessed hidden analytics';
 exception when insufficient_privilege then null;
 end;
end $test$;
reset role;
select 'passed' attribution_same_card_two_ads,'passed' cross_owner_access,'passed' client_analytics_blocked,'passed' raw_ip_blocking,'passed' visitor_retention,'rolled_back' customer_changes;
rollback;
