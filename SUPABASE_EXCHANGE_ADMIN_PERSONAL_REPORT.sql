CREATE OR REPLACE FUNCTION public.ex_staff_profile_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if tg_op='INSERT' and not public.ex_is_backend_request() then new.staff_permissions:=null;end if;
 if tg_op='UPDATE' and old.role='user' and new.role='admin' then
  new.staff_permissions:=coalesce(new.staff_permissions,array['view','approve_orders']::text[]);
 end if;
 if tg_op='UPDATE' and new.staff_permissions is distinct from old.staff_permissions then
  if not public.ex_is_backend_request() and not public.ex_is_super_admin() then
   raise exception 'SUPER_ADMIN_REQUIRED' using errcode='42501';end if;
  if old.role='super_admin' or new.role='super_admin' or old.id=auth.uid() then
   raise exception 'STAFF_PERMISSION_TARGET_FORBIDDEN' using errcode='42501';end if;
 end if;
 return new;
end $function$;
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
     o.amount,o.total,o.fee as deduction_iqd,
     coalesce(o.decided_at,o.created_at) accounted_at
   from public.ex_orders o
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
   'orders',(
      select coalesce(pg_catalog.jsonb_agg(pg_catalog.to_jsonb(q)
         order by q.accounted_at desc,q.id desc),'[]'::jsonb)
      from (select id,order_code,order_number,from_method,to_method,amount,total,
         deduction_iqd,accounted_at from approved
         order by accounted_at desc,id desc
         limit least(greatest(coalesce(p_limit,300),1),500)) q
   )
 ) into result from overview v;
 return result;
end;
$function$;

