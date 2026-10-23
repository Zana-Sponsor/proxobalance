import { API_VERSION,TikTokError,fail,numeric,fresh,username,schedule,money,fingerprint,canonicalStatus } from './contract.js';

const ORIGIN='https://business-api.tiktok.com';
export const PUBLIC_VIDEO='ITEM_STATUS_HESITATE_RECOMMEND';
export const providerDate=iso=>new Date(iso).toISOString().slice(0,19).replace('T',' ');
const same=(a,b)=>fingerprint(a)===fingerprint(b);
const identityId=value=>typeof value==='string'&&value.length>0&&value.length<=200&&!/[\s\x00-\x1f]/.test(value);
export function tiktokClient({token,fetchImpl=fetch,timeoutMs=12000}={}) {
  if(!token)fail('TIKTOK_ACCESS_TOKEN_NOT_CONFIGURED',{status:503});
  return async(path,params={},method='GET')=>{
    if(!/^[a-z_]+(?:\/[a-z_]+)+\/$/.test(path))fail('INVALID_PROVIDER_PATH');
    if('access_token' in params)fail('INVALID_PROVIDER_PARAMETER');
    const url=new URL(`${ORIGIN}/open_api/${API_VERSION}/${path}`);
    if(method==='GET')for(const[k,v]of Object.entries(params))url.searchParams.set(k,typeof v==='object'?JSON.stringify(v):String(v));
    let response,body;
    try{response=await fetchImpl(url,{method,redirect:'error',signal:AbortSignal.timeout(timeoutMs),headers:{'Access-Token':token,...(method==='POST'?{'Content-Type':'application/json'}:{})},
      ...(method==='POST'?{body:JSON.stringify(params)}:{})});body=await response.json();}
    catch{fail(method==='POST'?'TIKTOK_OUTCOME_UNKNOWN':'TIKTOK_UNAVAILABLE',{uncertain:method==='POST',retryable:true,status:503});}
    if(!response.ok||body?.code!==0){
      if(response.status>=500||response.status===429||typeof body?.code!=='number')fail(method==='POST'?'TIKTOK_OUTCOME_UNKNOWN':'TIKTOK_UNAVAILABLE',{uncertain:method==='POST',retryable:true,status:503});
      // Application error numbers are retained privately, never translated into
      // a permission accusation unless the exact code has been verified.
      const error=new TikTokError('TIKTOK_PROVIDER_REJECTED');error.provider_code=body.code;throw error;
    }
    if(!body.data||typeof body.data!=='object')fail('TIKTOK_RESPONSE_INVALID',{uncertain:method==='POST',status:503});
    return body.data;
  };
}
export function clientFor(account,{env=process.env,fetchImpl=fetch}={}) {
  const key=account?.access_token_env;
  if(typeof key!=='string'||!/^TIKTOK_[A-Z0-9_]{1,100}$/.test(key))fail('TIKTOK_TOKEN_REFERENCE_INVALID',{status:503});
  return tiktokClient({token:env[key],fetchImpl});
}
export function identityParams(account) {
  if(!numeric(account?.advertiser_id)||!identityId(account.identity_id)||!['BC_AUTH_TT','TT_USER'].includes(account.identity_type))fail('TIKTOK_IDENTITY_CONFIGURATION_REQUIRED');
  if(!numeric(account.business_center_id)||!numeric(account.asset_id))fail('TIKTOK_BC_RELATION_INVALID');
  if(account.identity_type==='BC_AUTH_TT'&&(!numeric(account.business_center_id)||account.identity_authorized_bc_id!==account.business_center_id||!numeric(account.asset_id)))fail('TIKTOK_BC_RELATION_INVALID');
  return {advertiser_id:account.advertiser_id,identity_id:account.identity_id,identity_type:account.identity_type,
    ...(account.identity_type==='BC_AUTH_TT'?{identity_authorized_bc_id:account.business_center_id}:{})};
}
export function verifyOwnerBinding(account,{now=Date.now()}={}) {
  const binding=account?.owner_binding_proof;
  // A generic BC QR and request log ID can never populate this evidence.
  // Only an actual correlated provider authorization can populate this proof;
  // there is no independent/manual owner-verification completion shortcut.
  if(!binding||binding.verified!==true||!binding.reference||binding.proxo_user_id!==account.user_id||binding.identity_id!==account.identity_id||
      binding.asset_id!==account.asset_id||binding.business_center_id!==account.business_center_id||binding.advertiser_id!==account.advertiser_id||
      binding.method!=='PROVIDER_CORRELATED_AUTHORIZATION'||
      !fresh(binding.verified_at,now,30*86400000)||username(binding.verified_username)!==username(account.requested_username))fail('TIKTOK_OWNER_BINDING_UNVERIFIED');
}
export function readiness(account,{now=Date.now()}={}) {
  verifyOwnerBinding(account,{now});
  const cap=account.capabilities;
  if(cap.flow!=='UPGRADED_SMART_PLUS_DM'||cap.api_version!==API_VERSION||typeof cap.evidence_reference!=='string'||!cap.evidence_reference.trim()||!fresh(cap.verified_at,now))fail('TIKTOK_CONVERSATION_TUPLE_NOT_VERIFIED');
  if(cap.conversation_allowlisted!==true||cap.adgroup_identity_allowlisted!==true)fail('TIKTOK_CONVERSATION_ALLOWLIST_REQUIRED');
  if(cap.iraq_conversation_verified!==true||cap.targeting_country!=='IQ'||!numeric(cap.iraq_location_id))fail('TIKTOK_IRAQ_CONVERSATION_UNAVAILABLE');
  if(cap.manual_targeting_verified!==true||cap.dm_receiving_verified!==true)fail('TIKTOK_DM_SETTINGS_NOT_VERIFIED');
  if(!numeric(cap.auto_message_id)||!fresh(cap.auto_message_verified_at,now))fail('TIKTOK_WELCOME_MESSAGE_NOT_VERIFIED');
  if(cap.budget?.currency!=='USD'||cap.budget?.mode!=='BUDGET_MODE_TOTAL'||!fresh(cap.budget?.verified_at,now)||!Number.isSafeInteger(cap.budget?.minimum_minor)||cap.budget.minimum_minor<=0)fail('TIKTOK_BUDGET_MINIMUM_NOT_VERIFIED');
  if(cap.spend_guard_verified!==true)fail('TIKTOK_SPEND_GUARD_NOT_VERIFIED');
  return cap;
}
export async function advertiserLinked(api,account) {
  for(let page=1;page<=20;page++) {
    const result=await api('bc/asset/advertiser/assigned/',{bc_id:account.business_center_id,asset_id:account.asset_id,asset_type:'TT_ACCOUNT',page,page_size:50});
    if(!Array.isArray(result.list)||!Number.isInteger(result.page_info?.total_page))fail('TIKTOK_RELATION_RESPONSE_INVALID',{status:503});
    if(result.list.some(a=>a.advertiser_id===account.advertiser_id))return true;
    if(page>=result.page_info.total_page)return false;
  }
  fail('TIKTOK_RELATION_LOOKUP_LIMIT');
}
async function verifyAssetTasks(api,account,type,id) {
  for(let page=1;page<=20;page++) {
    const result=await api('bc/asset/get/',{bc_id:account.business_center_id,asset_type:type,page,page_size:50});
    if(!Array.isArray(result.list)||!Number.isInteger(result.page_info?.total_page))fail('TIKTOK_ASSET_RESPONSE_INVALID',{status:503});
    const asset=result.list.find(a=>a.asset_id===id&&a.asset_type===type);
    if(asset) {
      if(type==='TT_ACCOUNT'&&!['POST','DIRECT_MESSAGE'].every(role=>asset.tt_account_roles?.includes(role)))fail('TIKTOK_BC_ASSET_PERMISSIONS_MISSING');
      if(type==='ADVERTISER'&&!['ADMIN','OPERATOR'].includes(asset.advertiser_role))fail('TIKTOK_ADVERTISER_OPERATOR_REQUIRED');
      return;
    }
    if(page>=result.page_info.total_page)fail('TIKTOK_BC_ASSET_NOT_ASSIGNED');
  }
  fail('TIKTOK_RELATION_LOOKUP_LIMIT');
}
export async function verifyIdentity(api,account,{now=Date.now(),requireReady=true}={}) {
  if(account?.status!=='CONNECTED')fail('TIKTOK_ACCOUNT_NOT_CONNECTED');
  verifyOwnerBinding(account,{now});if(requireReady)readiness(account,{now});
  const [response,linked]=await Promise.all([api('identity/info/',identityParams(account)),advertiserLinked(api,account),
    verifyAssetTasks(api,account,'TT_ACCOUNT',account.asset_id),verifyAssetTasks(api,account,'ADVERTISER',account.advertiser_id)]);
  const identity=response.identity_info;
  if(!identity||identity.identity_id!==account.identity_id||identity.identity_type!==account.identity_type)fail('TIKTOK_IDENTITY_MISMATCH');
  if(username(identity.username)!==username(account.requested_username)||username(identity.username)!==username(account.verified_username))fail('TIKTOK_USERNAME_MISMATCH');
  if(account.identity_type==='BC_AUTH_TT'&&identity.identity_authorized_bc_id!==account.business_center_id)fail('TIKTOK_BC_RELATION_INVALID');
  if(!linked)fail('TIKTOK_ADVERTISER_NOT_LINKED');
  if(identity.available_status!=='AVAILABLE')fail(['NO_VALID_BIND_ACCOUNT','SCOPE_UNAVAILABLE','IS_PRIVATE_ACCOUNT','NOT_BUSINESS_ACCOUNT'].includes(identity.available_status)?`TIKTOK_${identity.available_status}`:'TIKTOK_IDENTITY_UNAVAILABLE');
  if(identity.is_gpppa!==false)fail('TIKTOK_ACCOUNT_ADS_INELIGIBLE');
  if(identity.can_pull_video!==true)fail('TIKTOK_VIDEO_PERMISSION_MISSING');
  if(identity.can_manage_message!==true)fail('TIKTOK_MESSAGE_PERMISSION_MISSING');
  return identity;
}
function safeMediaUrl(value) {
  if(typeof value!=='string')return null;
  try {const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password&&!u.port&&!/^(?:localhost|127\.|10\.|192\.168\.|169\.254\.|\[)/.test(u.hostname)?u.href:null;}catch{return null;}
}
export function publicVideo(item,account) {
  if(item?.item_type!=='VIDEO'||item.status!==PUBLIC_VIDEO||!numeric(item.item_id))return null;
  return {item_id:item.item_id,account_id:account.id,caption:String(item.text||'').slice(0,3000),thumbnail_url:safeMediaUrl(item.video_info?.poster_url),
    preview_url:safeMediaUrl(item.video_info?.url),duration:Number.isFinite(item.video_info?.duration)?item.video_info.duration:null,
    // These reads contain no documented publish time/permalink fields.
    published_at:null,permalink:null,public:true,status:PUBLIC_VIDEO};
}
export async function musicEligible(api,account,itemId,{start_at,end_at},locationId) {
  const music=await api('identity/music/authorization/',{...identityParams(account),item_id:itemId,locations:[locationId],start_time:providerDate(start_at),end_time:providerDate(end_at)});
  const record=music.music_authorization?.find(m=>m.item_id===itemId);
  return !!record&&['WITHOUT_SONG_ID','WITH_FULL_AUTHORIZATION'].includes(record.music_status);
}
export async function listVideos(api,account,{cursor,now=Date.now()}={}) {
  await verifyIdentity(api,account,{now});
  if(cursor!=null&&(typeof cursor!=='string'||!/^\d{1,30}$/.test(cursor)))fail('TIKTOK_CURSOR_INVALID');
  const result=await api('identity/video/get/',{...identityParams(account),item_type:'VIDEO',exclude_adsonly:true,count:10,...(cursor?{cursor}:{})});
  if(!Array.isArray(result.video_list)||typeof result.has_more!=='boolean'||result.has_more&&typeof result.cursor!=='string')fail('TIKTOK_VIDEO_RESPONSE_INVALID',{status:503});
  const window={start_at:new Date(now).toISOString(),end_at:new Date(now+7*86400000).toISOString()};
  // Current public videos are selectable only after music/identity checks. A
  // submitted schedule is checked again, so this cache is never authorization.
  const eligible=await Promise.all(result.video_list.map(async item=>{
    const video=publicVideo(item,account);
    return video&&await musicEligible(api,account,item.item_id,window,account.capabilities.iraq_location_id)?{...video,ad_eligible:true}:null;
  }));
  const videos=eligible.filter(Boolean);
  return {ok:true,account_id:account.id,videos,next_cursor:result.has_more?result.cursor:null,verified_at:new Date(now).toISOString(),expires_at:new Date(now+5*60000).toISOString()};
}
export async function preflight(api,account,ad,{now=Date.now(),acceptedStart}={}) {
  const cap=readiness(account,{now});
  const time=schedule(ad,{now,acceptedStart});
  const [identity,advertiserResponse,videoResponse,welcomeResponse,geography]=await Promise.all([
    verifyIdentity(api,account,{now}),api('advertiser/info/',{advertiser_ids:[account.advertiser_id],fields:['advertiser_id','currency','timezone','display_timezone']}),
    api('identity/video/info/',{...identityParams(account),item_id:ad.tiktok_item_id}),
    api('creative/auto_message/get/',{advertiser_id:account.advertiser_id,auto_message_type:'WELCOME_MESSAGE',auto_message_id:cap.auto_message_id}),verifyIraqTargeting(api,account,ad)]);
  const welcome=(welcomeResponse.list||welcomeResponse.auto_message_list)?.find(m=>m.auto_message_id===cap.auto_message_id);
  if(!welcome||welcome.auto_message_type!=='WELCOME_MESSAGE'||welcome.audit_status!=='PASS')fail('TIKTOK_WELCOME_MESSAGE_UNAVAILABLE');
  const advertiser=advertiserResponse.list?.find(a=>a.advertiser_id===account.advertiser_id);
  if(!advertiser||advertiser.currency!=='USD')fail('TIKTOK_ADVERTISER_CURRENCY_UNSUPPORTED');
  if(!advertiser.display_timezone||advertiser.display_timezone!==cap.advertiser_timezone)fail('TIKTOK_ADVERTISER_TIMEZONE_NOT_VERIFIED');
  const video=publicVideo(videoResponse.video_detail,account);
  if(!video||video.item_id!==ad.tiktok_item_id)fail('TIKTOK_VIDEO_NOT_PUBLIC_OR_AVAILABLE');
  if(!await musicEligible(api,account,video.item_id,time,cap.iraq_location_id))fail('TIKTOK_VIDEO_MUSIC_INELIGIBLE');
  const ages={'18-24':'AGE_18_24','25-34':'AGE_25_34','35-44':'AGE_35_44','45-54':'AGE_45_54','55+':'AGE_55_100'};
  const targeting={location_ids:[cap.iraq_location_id],age_groups:ad.age_groups.includes('all')?Object.values(ages):ad.age_groups.map(v=>ages[v]),
    gender:{all:'GENDER_UNLIMITED',male:'GENDER_MALE',female:'GENDER_FEMALE'}[ad.gender],...(ad.device_type==='all'?{}:{operating_systems:[ad.device_type==='iphone'?'IOS':'ANDROID']})};
  if(ad.location==='kurdistan') {
    const languages=await api('tool/language/',{advertiser_id:account.advertiser_id});
    const english=languages.languages?.find(l=>String(l.name).toLowerCase()==='english'),turkish=languages.languages?.find(l=>String(l.name).toLowerCase()==='turkish');
    if(!english?.code||!turkish?.code||english.code===turkish.code)fail('TIKTOK_LANGUAGE_MAPPING_UNAVAILABLE');
    targeting.languages=[english.code,turkish.code].sort();
  }
  const budget=money(ad,cap.budget.minimum_minor);
  return {authorized:true,ready:true,account_id:account.id,api_version:API_VERSION,flow:cap.flow,verified_at:new Date(now).toISOString(),
    identity:identityParams(account),verified_username:identity.username,item_id:video.item_id,targeting,auto_message_id:cap.auto_message_id,
    advertiser_timezone:advertiser.display_timezone,geography,...time,...budget,declared_budget_usd:budget.tiktok_declared_budget_minor/100};
}
export async function verifyIraqTargeting(api,account,ad) {
  const parameters={advertiser_id:account.advertiser_id,objective_type:'LEAD_GENERATION',promotion_type:'LEAD_GEN_CLICK_TO_TT_DIRECT_MESSAGE',placements:['PLACEMENT_TIKTOK'],
    ...(ad.device_type==='all'?{}:{operating_system:ad.device_type==='iphone'?'IOS':'ANDROID'})};
  const regions=await api('tool/region/',{...parameters,level_range:'TO_COUNTRY',language:'en'});
  const countries=regions.region_info?.filter(r=>r.region_code==='IQ'&&r.level==='COUNTRY');
  if(!Array.isArray(countries)||countries.length!==1||!numeric(countries[0].location_id)||countries[0].location_id!==account.capabilities.iraq_location_id)
    fail('TIKTOK_IRAQ_TARGETING_UNAVAILABLE');
  const tags=await api('tool/targeting/info/',{...parameters,scene:'GEO',targeting_ids:[countries[0].location_id]});
  const matches=tags.targeting_tag_list?.filter(t=>t.targeting_type==='GEO'&&t.geo?.geo_id===countries[0].location_id);
  if(!Array.isArray(matches)||matches.length!==1||matches[0].status_info?.status!=='ENABLED'||matches[0].geo.region_code!=='IQ'||matches[0].geo.geo_type!=='COUNTRY')
    fail('TIKTOK_IRAQ_TARGETING_UNAVAILABLE');
  return {location_id:countries[0].location_id,region_code:'IQ',status:'ENABLED',source:'tool/region/+tool/targeting/info/'};
}
const stageKey={campaign:'campaign_id',adgroup:'adgroup_id',ad:'smart_plus_ad_id'};
export function stageParameters(stage,job) {
  const e=job.evidence,ids=job.provider_ids||{},name=`proxo:${job.id}:${stage}:${fingerprint(job.ad).slice(0,12)}`;
  const common={advertiser_id:e.identity.advertiser_id,operation_status:'DISABLE'};
  // The documented request field is a decimal signed-64-bit idempotency key;
  // it is distinct from TikTok's response log request_id. Ads do not expose it.
  const request_id=BigInt('0x'+fingerprint({job:job.id,stage}).slice(0,15)).toString();
  if(stage==='campaign')return {...common,request_id,campaign_name:name,objective_type:'LEAD_GENERATION',catalog_enabled:false,budget_optimize_on:false,budget_mode:'BUDGET_MODE_INFINITE'};
  if(stage==='adgroup') {
    if(!numeric(ids.campaign))fail('TIKTOK_STAGE_ORDER_INVALID');
    return {...common,request_id,campaign_id:ids.campaign,adgroup_name:name,promotion_type:'LEAD_GEN_CLICK_TO_TT_DIRECT_MESSAGE',optimization_goal:'CONVERSATION',optimization_event:'MESSAGE',
      billing_event:'OCPM',bid_type:'BID_TYPE_NO_BID',placement_type:'PLACEMENT_TYPE_NORMAL',placements:['PLACEMENT_TIKTOK'],
      targeting_optimization_mode:'MANUAL',targeting_spec:e.targeting,budget_mode:'BUDGET_MODE_TOTAL',budget:e.declared_budget_usd,
      schedule_type:'SCHEDULE_START_END',schedule_start_time:providerDate(job.start_at),schedule_end_time:providerDate(job.end_at),
      identity_type:e.identity.identity_type,identity_id:e.identity.identity_id,...(e.identity.identity_authorized_bc_id?{identity_authorized_bc_id:e.identity.identity_authorized_bc_id}:{})};
  }
  if(stage==='ad') {
    if(!numeric(ids.adgroup))fail('TIKTOK_STAGE_ORDER_INVALID');
    const {advertiser_id,...identity}=e.identity;
    return {...common,adgroup_id:ids.adgroup,ad_name:name,creative_list:[{creative_info:{ad_format:'SINGLE_VIDEO',tiktok_item_id:e.item_id,...identity}}],
      auto_message_list:[{auto_message_id:e.auto_message_id}],call_to_action_list:[{call_to_action:'SEND_MESSAGE'}]};
  }
  fail('TIKTOK_STAGE_INVALID');
}
export async function createStage(api,stage,job) {
  const response=await api(`smart_plus/${stage}/create/`,stageParameters(stage,job),'POST');
  if(!numeric(response[stageKey[stage]]))fail('TIKTOK_OUTCOME_UNKNOWN',{uncertain:true,status:503});
  return response[stageKey[stage]];
}
export async function readStage(api,stage,job,id=job.provider_ids?.[stage]) {
  if(!numeric(id))fail('TIKTOK_PROVIDER_ID_MISSING');
  const result=await api(`smart_plus/${stage}/get/`,{advertiser_id:job.evidence.identity.advertiser_id,filtering:{[stageKey[stage]+'s']:[id]},page:1,page_size:100});
  if(!Array.isArray(result.list)||result.list.length!==1||result.list[0][stageKey[stage]]!==id)fail('TIKTOK_PROVIDER_OBJECT_UNAVAILABLE',{retryable:true,status:503});
  const item=result.list[0];
  if(item.advertiser_id!==job.evidence.identity.advertiser_id||stage!=='campaign'&&item.campaign_id!==job.provider_ids.campaign||stage==='ad'&&item.adgroup_id!==job.provider_ids.adgroup)fail('TIKTOK_PROVIDER_CHAIN_MISMATCH',{uncertain:true,status:409});
  return item;
}
export async function reconcileStage(api,stage,job) {
  const expected=stageParameters(stage,job),nameField=stage==='campaign'?'campaign_name':stage==='adgroup'?'adgroup_name':'ad_name';
  const matches=[];
  for(let page=1;page<=20;page++) {
    const result=await api(`smart_plus/${stage}/get/`,{advertiser_id:job.evidence.identity.advertiser_id,page,page_size:100});
    if(!Array.isArray(result.list)||!Number.isInteger(result.page_info?.total_page))fail('TIKTOK_RECONCILIATION_INCOMPLETE',{uncertain:true,status:503});
    matches.push(...result.list.filter(x=>x[nameField]===expected[nameField]));
    if(page>=result.page_info.total_page)break;
    if(page===20)fail('TIKTOK_RECONCILIATION_INCOMPLETE',{uncertain:true,status:503});
  }
  if(matches.length!==1)fail(matches.length?'TIKTOK_DUPLICATE_OBJECTS':'TIKTOK_RECONCILIATION_PENDING',{uncertain:true,status:409});
  const item=await readStage(api,stage,job,matches[0][stageKey[stage]]);
  // Every transmitted semantic field must match; no recreation on omission or
  // provider-normalized differences. An operator can investigate safely.
  for(const [key,value]of Object.entries(expected)) {
    if(key==='request_id')continue;
    if(!same(item[key],value))fail('TIKTOK_RECONCILIATION_MISMATCH',{uncertain:true,status:409});
  }
  return item[stageKey[stage]];
}
export async function pauseGroup(api,job) {
  if(!numeric(job.provider_ids?.adgroup))fail('TIKTOK_PROVIDER_ID_MISSING');
  await api('smart_plus/adgroup/status/update/',{advertiser_id:job.evidence.identity.advertiser_id,adgroup_ids:[job.provider_ids.adgroup],operation_status:'DISABLE'},'POST');
  const observed=await readStage(api,'adgroup',job);
  if(observed.operation_status!=='DISABLE')fail('TIKTOK_STOP_UNCONFIRMED',{uncertain:true,status:409});
  return observed;
}
export async function reportMetrics(api,job) {
  const id=job.provider_ids?.adgroup;
  if(!numeric(id))fail('TIKTOK_PROVIDER_ID_MISSING');
  const report=await api('report/integrated/get/',{advertiser_id:job.evidence.identity.advertiser_id,report_type:'BASIC',data_level:'AUCTION_ADGROUP',
    dimensions:['adgroup_id'],metrics:['spend','impressions','clicks','video_play_actions','reach','conversion'],query_lifetime:true,filtering:[{field_name:'adgroup_ids',filter_type:'IN',filter_value:JSON.stringify([id])},
      {field_name:'adgroup_status',filter_type:'IN',filter_value:JSON.stringify(['STATUS_ALL'])}],page:1,page_size:100});
  if(!Array.isArray(report.list)||report.list.length!==1||report.list[0].dimensions?.adgroup_id!==id||
      !/^\d+(?:\.\d{1,6})?$/.test(String(report.list[0].metrics?.spend)))fail('TIKTOK_SPEND_NOT_AVAILABLE',{retryable:true,status:503});
  const spend=Number(report.list[0].metrics.spend);
  if(!Number.isFinite(spend)||spend<0)fail('TIKTOK_SPEND_NOT_AVAILABLE',{retryable:true,status:503});
  const metrics={};
  for(const [provider,local]of Object.entries({impressions:'impressions',clicks:'clicks',video_play_actions:'video_views',reach:'reach',conversion:'conversions'})) {
    const value=report.list[0].metrics[provider];
    if(value!==undefined&&value!==null&&/^\d+(?:\.0+)?$/.test(String(value))&&Number.isSafeInteger(Number(value)))metrics[local]=Number(value);
  }
  return {spend_usd:spend,metrics};
}
export async function reportSpend(api,job){return (await reportMetrics(api,job)).spend_usd;}
function providerTimestamp(value) {
  if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(value))return null;
  const parsed=Date.parse(value.replace(' ','T')+'Z');
  return Number.isFinite(parsed)&&new Date(parsed).toISOString().slice(0,19).replace('T',' ')===value?new Date(parsed).toISOString():null;
}
export async function observe(api,job,{now=Date.now(),allowMissingSpend=false}={}) {
  const ids=job.provider_ids||{};
  const [campaign,group,ad,report]=await Promise.all([readStage(api,'campaign',job),readStage(api,'adgroup',job),ids.ad?readStage(api,'ad',job):Promise.resolve(null),
    reportMetrics(api,job).then(value=>({value}),error=>({error}))]);
  const chain=[campaign,group,...(ad?[ad]:[])];
  if(chain.some(o=>!['ENABLE','DISABLE'].includes(o.operation_status)))fail('TIKTOK_OPERATION_STATUS_UNKNOWN',{retryable:true,status:503});
  for(const [index,key]of ['campaign','adgroup','ad'].entries()) {
    const changed=providerTimestamp(chain[index]?.modify_time),previous=job.observation?.raw_statuses?.[key]?.modify_time;
    if(changed&&previous&&Date.parse(changed)<Date.parse(previous))fail('TIKTOK_STALE_PROVIDER_OBSERVATION',{retryable:true,status:503});
  }
  if(report.error&&!allowMissingSpend)throw report.error;
  const spend=report.error?null:report.value.spend_usd;
  const rejection=chain.find(o=>['ADGROUP_STATUS_AUDIT_DENY','AD_STATUS_AUDIT_DENY','AD_STATUS_PRIVACY_POLICY_REJECTED'].includes(o.secondary_status));
  const status=rejection?.secondary_status||ad?.secondary_status||group.secondary_status,paused=chain.some(o=>o.operation_status==='DISABLE');
  return {operation_status:paused?'DISABLE':'ENABLE',secondary_status:status,spend_usd:spend,provider_observed_at:new Date(now).toISOString(),
    provider_ad_id:ids.ad||null,provider_adgroup_id:ids.adgroup,paused,chain_paused:chain.every(o=>o.operation_status==='DISABLE'),
    raw_statuses:Object.fromEntries(['campaign','adgroup','ad'].map((key,i)=>[key,chain[i]?{operation_status:chain[i].operation_status,secondary_status:chain[i].secondary_status,
      ...Object.fromEntries(['create_time','modify_time'].flatMap(field=>providerTimestamp(chain[i][field])?[[field,providerTimestamp(chain[i][field])]]:[]))}:null])),
    terminal:['ADGROUP_STATUS_TIME_DONE','AD_STATUS_DONE'].includes(status),metrics:spend===null?{}:report.value.metrics};
}
export async function unlinkAdvertiser(api,account) {
  // REVOKING is committed before this method is called. Broad BC revocation is
  // deliberately absent; historical and unrelated assets remain authorized.
  if(account.status!=='REVOKING')fail('TIKTOK_DISCONNECT_INTENT_REQUIRED');
  if(!await advertiserLinked(api,account))return true;
  await api('bc/asset/advertiser/unassign/',{bc_id:account.business_center_id,asset_id:account.asset_id,asset_type:'TT_ACCOUNT',advertiser_id:account.advertiser_id},'POST');
  if(await advertiserLinked(api,account))fail('TIKTOK_DISCONNECT_UNCONFIRMED',{uncertain:true,status:409});
  return true;
}
export { stageKey, canonicalStatus };
