-- Report attribution only: retain approved fees, date bounds and staff visibility.
CREATE OR REPLACE FUNCTION public.ex_admin_deduction_stats(p_from date DEFAULT NULL::date, p_to date DEFAULT NULL::date, p_limit integer DEFAULT 300)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if not public.ex_staff_has('view') then raise exception 'STAFF_PERMISSION_REQUIRED' using errcode='42501';end if;
 if p_from is not null and p_to is not null and p_from>p_to then
   raise exception using errcode='22023',message='INVALID_DATE_RANGE';
 end if;
 with approved as (
   select o.id,o.order_code,o.order_number,o.from_method,o.to_method,
     o.amount,o.total,o.fee as deduction_iqd,o.handled_by,
     nullif(btrim(p.full_name),'') as handling_admin_name,
     coalesce(o.decided_at,o.created_at) accounted_at
   from public.ex_orders o
   left join public.ex_profiles p on p.id=o.handled_by
   where o.status='پەسەندکرا'
     and (public.ex_is_super_admin() or o.handled_by=auth.uid())
     and (p_from is null or (coalesce(o.decided_at,o.created_at) at time zone 'Asia/Baghdad')::date>=p_from)
     and (p_to is null or (coalesce(o.decided_at,o.created_at) at time zone 'Asia/Baghdad')::date<=p_to)
 ), overview as (
   select count(*) approved_orders,count(deduction_iqd) recorded_orders,
      coalesce(sum(deduction_iqd),0) total_deduction_iqd,
      avg(deduction_iqd) avg_deduction_iqd,
      coalesce(sum(deduction_iqd) filter(where
        (accounted_at at time zone 'Asia/Baghdad')::date =
        (now() at time zone 'Asia/Baghdad')::date),0) today_deduction_iqd,
      coalesce(sum(deduction_iqd) filter(where
        date_trunc('month',accounted_at at time zone 'Asia/Baghdad') =
        date_trunc('month',now() at time zone 'Asia/Baghdad')),0) month_deduction_iqd
   from approved
 )
 select pg_catalog.jsonb_build_object(
   'scope',case when public.ex_is_super_admin() then 'all' else 'own' end,
   'approved_orders',v.approved_orders,
   'recorded_orders',v.recorded_orders,
   'unrecorded_orders',v.approved_orders-v.recorded_orders,
   'total_deduction_iqd',v.total_deduction_iqd,
   'today_deduction_iqd',v.today_deduction_iqd,
   'month_deduction_iqd',v.month_deduction_iqd,
   'avg_deduction_iqd',v.avg_deduction_iqd,
   'by_method',(
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'method',q.to_method,'approved_orders',q.approved_orders,
        'recorded_orders',q.recorded_orders,'deduction_iqd',q.deduction_iqd)
        order by q.deduction_iqd desc,q.to_method),'[]'::jsonb)
      from (select to_method,count(*) approved_orders,count(deduction_iqd) recorded_orders,
        coalesce(sum(deduction_iqd),0) deduction_iqd from approved group by to_method) q
   ),
   'by_admin',(
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(q)
        order by q.deduction_iqd desc,q.handling_admin_name,q.handled_by),'[]'::jsonb)
      from (select handled_by,handling_admin_name,count(*) approved_orders,
        count(deduction_iqd) recorded_orders,coalesce(sum(deduction_iqd),0) deduction_iqd
        from approved group by handled_by,handling_admin_name) q
   ),
   'orders',(
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(q)
         order by q.accounted_at desc,q.id desc),'[]'::jsonb)
      from (select id,order_code,order_number,from_method,to_method,amount,total,
         deduction_iqd,accounted_at,handled_by,handling_admin_name from approved
         order by accounted_at desc,id desc
         limit least(greatest(coalesce(p_limit,300),1),500)) q
   )
 ) into result from overview v;
 return result;
end;
$function$;


revoke all on function public.ex_admin_deduction_stats(date,date,integer) from public,anon;
grant execute on function public.ex_admin_deduction_stats(date,date,integer) to authenticated,service_role;
