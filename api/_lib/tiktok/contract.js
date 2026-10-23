import { MetaError, fail, canonical, fingerprint } from '../meta/contract.js';
export { MetaError as TikTokError, fail, fingerprint };
export const API_VERSION='v1.3';
export const uuid=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(v);
export const numeric=v=>typeof v==='string'&&/^\d{1,40}$/.test(v);
export const fresh=(at,now=Date.now(),ttl=86400000)=>Number.isFinite(Date.parse(at))&&Date.parse(at)<=now&&now-Date.parse(at)<ttl;
export function username(value) {
  if(typeof value!=='string')fail('TIKTOK_USERNAME_INVALID');
  const result=value.trim().replace(/^@/,'').toLowerCase();
  if(!/^[a-z0-9._]{2,24}$/.test(result))fail('TIKTOK_USERNAME_INVALID');return result;
}
export function normalizeAd(input,{now=Date.now(),recovering=false}={}) {
  const keys=['title','goal','message_destination','tiktok_account_id','tiktok_item_id','category','age_groups','gender','location','device_type','customer_note','daily_budget','days','payment_method','start_date','start_time','start_immediately'];
  if(!input||typeof input!=='object'||Array.isArray(input)||Object.keys(input).some(k=>!keys.includes(k)))fail('INVALID_INPUT');
  if(input.goal!=='messages'||input.message_destination!=='direct_message')fail('TIKTOK_CONVERSATION_ONLY');
  if(!uuid(input.tiktok_account_id)||!numeric(input.tiktok_item_id))fail('TIKTOK_ACCOUNT_VIDEO_REQUIRED');
  if(typeof input.title!=='string'||!input.title.trim()||[...input.title.trim()].length>120)fail('INVALID_NAME');
  if(typeof input.category!=='string'||input.category.length>80)fail('INVALID_CATEGORY');
  if(!Array.isArray(input.age_groups)||!input.age_groups.length||new Set(input.age_groups).size!==input.age_groups.length||
      input.age_groups.some(v=>!['all','18-24','25-34','35-44','45-54','55+'].includes(v))||input.age_groups.length>1&&input.age_groups.includes('all'))fail('INVALID_AGE');
  if(!['all','male','female'].includes(input.gender)||!['all','iraq','kurdistan'].includes(input.location)||!['all','iphone','android'].includes(input.device_type))fail('INVALID_TARGETING');
  if(![10,20,50,100,200,500,1000].includes(input.daily_budget)||!Number.isInteger(input.days)||input.days<1||input.days>7)fail('INVALID_BUDGET');
  if(!['app_balance','fastpay'].includes(input.payment_method))fail('UNSUPPORTED_PAYMENT_METHOD');
  if(typeof input.customer_note!=='string'||input.customer_note.length>500)fail('INVALID_NOTE');
  if(typeof input.start_immediately!=='boolean')fail('INVALID_SCHEDULE');
  if(!input.start_immediately) {
    if(!/^\d{4}-\d{2}-\d{2}$/.test(input.start_date)||!/^\d{2}:\d{2}(?::\d{2})?$/.test(input.start_time))fail('INVALID_SCHEDULE');
    const start=Date.parse(`${input.start_date}T${input.start_time}+03:00`);
    if(!Number.isFinite(start)||!recovering&&(start<=now||start>now+90*86400000))fail('INVALID_SCHEDULE');
    // Date.parse normalizes impossible dates; require the exact Baghdad date.
    if(new Date(start+3*3600000).toISOString().slice(0,10)!==input.start_date)fail('INVALID_SCHEDULE');
  }
  return canonical({...input,title:input.title.trim(),age_groups:[...input.age_groups].sort(),
    ...(input.start_immediately?{start_date:null,start_time:null}:{}),customer_note:input.customer_note.trim()});
}
export function schedule(ad,{now=Date.now(),acceptedStart}={}) {
  const start=acceptedStart?Date.parse(acceptedStart):ad.start_immediately?now:Date.parse(`${ad.start_date}T${ad.start_time}+03:00`);
  if(!Number.isFinite(start))fail('INVALID_SCHEDULE');
  return {start_at:new Date(start).toISOString(),end_at:new Date(start+ad.days*86400000).toISOString(),timezone:'Asia/Baghdad'};
}
export function money(ad,minMinor) {
  const total=ad.daily_budget*ad.days*100;
  if(!Number.isSafeInteger(minMinor)||minMinor<=0)fail('TIKTOK_BUDGET_MINIMUM_NOT_VERIFIED');
  return {proxo_total_budget_minor:total,tiktok_declared_budget_minor:Math.max(total,minMinor),spend_stop_threshold_minor:Math.floor(total*95/100)};
}
export function canonicalStatus({operation_status,secondary_status,stop_confirmed=false,completion_reason}) {
  if(['ADGROUP_STATUS_TIME_DONE','AD_STATUS_DONE'].includes(secondary_status))return 'completed';
  if(['ADGROUP_STATUS_AUDIT_DENY','AD_STATUS_AUDIT_DENY','AD_STATUS_PRIVACY_POLICY_REJECTED'].includes(secondary_status))return 'rejected';
  if(operation_status==='DISABLE')return stop_confirmed&&completion_reason==='BUDGET_THRESHOLD'?'completed':'paused';
  if(['ADGROUP_STATUS_AUDIT','AD_STATUS_AUDIT','ADGROUP_STATUS_REAUDIT','AD_STATUS_REAUDIT','AD_STATUS_PRIVACY_POLICY_AUDIT'].includes(secondary_status))return 'review';
  if(['ADGROUP_STATUS_NOT_START','AD_STATUS_NOT_START'].includes(secondary_status))return 'scheduled';
  if(operation_status==='ENABLE'&&['ADGROUP_STATUS_DELIVERY_OK','AD_STATUS_DELIVERY_OK','AD_STATUS_DELIVERY_AND_REAUDIT','AD_STATUS_REVIEW_PARTIALLY_APPROVED'].includes(secondary_status))return 'active';
  return null; // Unknown provider states preserve the last trusted app status.
}
