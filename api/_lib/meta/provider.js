import { createHmac } from 'node:crypto';
import { API_VERSION, MetaError, fail, normalizeUrl, fingerprint, destinationType, pricing } from './contract.js';

const GRAPH = 'https://graph.facebook.com';
const numeric = value => typeof value === 'string' && /^\d+$/.test(value);
const recent = (value, now, ttl = 86400000) => Number.isFinite(Date.parse(value)) && Date.parse(value) <= now && now - Date.parse(value) < ttl;
const same = (a,b) => fingerprint(a) === fingerprint(b);
const sorted = v => [...(v || [])].sort();
const accountId = c => 'act_' + String(c.ad_account_id || '').replace(/^act_/, '');
const edges = { campaign:'campaigns',adset:'adsets',creative:'adcreatives',ad:'ads' };

// No caller can change the host/version or supply access tokens in request data.
export function graphClient({ token, appSecret, fetchImpl = fetch, timeoutMs = 15000 }) {
  if (!token || typeof token !== 'string') fail('META_ACCESS_TOKEN_NOT_CONFIGURED', {status:503});
  return async function graph(path, params = {}, { method = 'GET' } = {}) {
    if (!/^[a-zA-Z0-9_/-]+$/.test(path) || path.includes('..')) fail('INVALID_PROVIDER_PATH');
    const url = new URL(`${GRAPH}/${API_VERSION}/${path.replace(/^\//,'')}`);
    const values = new URLSearchParams();
    for (const [k,v] of Object.entries(params)) {
      if (['access_token','appsecret_proof'].includes(k)) fail('INVALID_PROVIDER_PARAMETER');
      values.set(k, typeof v === 'object' ? JSON.stringify(v) : String(v));
    }
    if (appSecret) values.set('appsecret_proof',createHmac('sha256',appSecret).update(token).digest('hex'));
    if (method === 'GET') url.search = values.toString();
    let res, data;
    try {
      res = await fetchImpl(url,{method,redirect:'error',signal:AbortSignal.timeout(timeoutMs),
        headers:{Authorization:`Bearer ${token}`,...(method === 'POST' ? {'Content-Type':'application/x-www-form-urlencoded'} : {})},
        ...(method === 'POST' ? {body:values.toString()} : {})});
      data = await res.json();
    } catch { fail(method === 'POST' ? 'PROVIDER_OUTCOME_UNKNOWN' : 'PROVIDER_UNAVAILABLE', {uncertain:method === 'POST',retryable:true,status:503}); }
    if (!res.ok || data?.error) {
      const code = Number(data?.error?.code);
      if ([190,102].includes(code)) fail('META_TOKEN_INVALID', {status:422});
      if ([10,200,294].includes(code)) fail('META_PERMISSION_MISSING');
      if (res.status >= 500 || res.status === 429 || data?.error?.is_transient) fail(method === 'POST' ? 'PROVIDER_OUTCOME_UNKNOWN' : 'PROVIDER_UNAVAILABLE',{uncertain:method === 'POST',retryable:true,status:503});
      fail(code === 100 ? 'PROVIDER_OBJECT_OR_PARAMETER_UNAVAILABLE' : 'PROVIDER_REJECTED');
    }
    return data;
  };
}

// Cursor-only pagination: never follow provider paging URLs carrying token data.
async function collect(graph,path,params,{maxPages=5,find}={}) {
  let after;
  for (let page=0;page<maxPages;page++) {
    const result = await graph(path,{...params,limit:100,...(after?{after}:{})});
    if (!Array.isArray(result.data)) fail('PROVIDER_RESPONSE_INVALID',{status:503});
    if (find) { const match = result.data.find(find); if (match) return match; }
    if (!result.paging?.next) return null;
    after=result.paging?.cursors?.after;
    if (typeof after !== 'string' || after.length>4096) fail('PROVIDER_PAGINATION_UNAVAILABLE',{retryable:true,status:503});
  }
  fail('PROVIDER_LOOKUP_LIMIT_REACHED');
}

export async function resolveRedirect(input,{fetchImpl=fetch}={}) {
  let url = normalizeUrl(input);
  const needsRedirect = value => /\/share(?:\/|\?)|\/share\//.test(value) || new URL(value).hostname === 'fb.watch';
  if (!needsRedirect(url)) return url;
  for (let i=0;i<4;i++) {
    let response;
    try { response=await fetchImpl(url,{method:'GET',redirect:'manual',signal:AbortSignal.timeout(5000),headers:{Accept:'text/html'}}); }
    catch { fail('POST_LINK_REDIRECT_UNAVAILABLE'); }
    // A short link returning a login/HTML page is not evidence of ownership.
    if (![301,302,303,307,308].includes(response.status)) fail('POST_DIRECT_LINK_REQUIRED');
    const location=response.headers.get('location');
    if (!location) fail('POST_DIRECT_LINK_REQUIRED');
    url=normalizeUrl(new URL(location,url).href);
    if (!needsRedirect(url)) return url;
  }
  fail('POST_REDIRECT_LIMIT_REACHED');
}

function fbIdentity(value) {
  const url=new URL(value);
  const part=url.pathname.match(/\/(?:posts|videos|reel)\/([^/]+)/)?.[1];
  return part || url.searchParams.get('story_fbid') || url.searchParams.get('v') || null;
}
function equalPostUrl(a,b) {
  try {
    a=normalizeUrl(a); b=normalizeUrl(b);
    if (a===b) return true;
    const ua=new URL(a),ub=new URL(b);
    if (ua.hostname==='www.facebook.com' && ub.hostname==='www.facebook.com') {
      const ia=fbIdentity(a),ib=fbIdentity(b); return !!ia && ia===ib;
    }
    return false;
  } catch { return false; }
}

export async function resolvePost(graph,page,url,{maxPages=5}={}) {
  const instagram=new URL(url).hostname==='www.instagram.com';
  let post;
  if (instagram) {
    if (!numeric(page.instagram_id)) fail('INSTAGRAM_NOT_LINKED');
    post=await collect(graph,`${page.instagram_id}/media`,{fields:'id,permalink,media_type,owner'},{maxPages,find:p=>equalPostUrl(p.permalink,url)});
    if (!post) fail('POST_NOT_FOUND_IN_ACCESSIBLE_MEDIA');
    // Refresh the concrete object; a URL/shortcode alone is never an object ID.
    post=await graph(String(post.id),{fields:'id,permalink,media_type,owner'});
    if (String(post.owner?.id || post.owner || '')!==page.instagram_id) fail('INSTAGRAM_OWNER_MISMATCH');
    if (!equalPostUrl(post.permalink,url)) fail('POST_IDENTITY_MISMATCH');
    return {id:String(post.id),owner_id:page.instagram_id,kind:'INSTAGRAM',media_type:post.media_type,permalink:normalizeUrl(post.permalink)};
  }
  const identity=fbIdentity(url);
  if (identity && /^\d+$/.test(identity)) {
    post=await graph(`${page.id}_${identity}`,{fields:'id,from,permalink_url,attachments{media_type,type}'});
  } else {
    // Opaque pfbid values are matched against accessible permalinks. They are
    // never appended to a Page ID or sent as a canonical Graph object ID.
    post=await collect(graph,`${page.id}/posts`,{fields:'id,from,permalink_url,attachments{media_type,type}'},{maxPages,find:p=>equalPostUrl(p.permalink_url,url)});
    if (!post) fail('POST_NOT_FOUND_IN_ACCESSIBLE_FEED');
  }
  if (String(post.from?.id)!==page.id || !String(post.id).startsWith(`${page.id}_`)) fail('POST_PAGE_MISMATCH');
  if (!equalPostUrl(post.permalink_url,url)) fail('POST_IDENTITY_MISMATCH');
  if (!/^\d+_\d+$/.test(String(post.id))) fail('POST_CANONICAL_ID_UNAVAILABLE');
  const media=post.attachments?.data?.[0];
  return {id:String(post.id),owner_id:page.id,kind:'FACEBOOK',media_type:String(media?.media_type||media?.type||'UNKNOWN').toUpperCase(),permalink:normalizeUrl(post.permalink_url)};
}

export function selectTuple(configuration,post,capabilities,{now=Date.now()}={}) {
  const tuple=(capabilities.tuples||[]).find(t => t.api_version===API_VERSION && t.objective===configuration.objective &&
    same(sorted(t.destinations),sorted(configuration.destinations)) && same(sorted(t.placements),configuration.placements) &&
    t.post_id===post.id && t.post_kind===post.kind && t.post_media_type===post.media_type &&
    t.verified===true && recent(t.verified_at,now));
  if (!tuple) fail('EXISTING_POST_TUPLE_NOT_VERIFIED');
  const expectedGoal={MESSAGES:'CONVERSATIONS',VIDEO_VIEWS:'THRUPLAY',VIDEO_ENGAGEMENT:'POST_ENGAGEMENT'}[configuration.objective];
  if (tuple.campaign_objective!=='OUTCOME_ENGAGEMENT' || tuple.optimization_goal!==expectedGoal || tuple.billing_event!=='IMPRESSIONS') fail('UNSUPPORTED_PROVIDER_TUPLE');
  if (configuration.objective.startsWith('VIDEO_') && !['VIDEO','REEL','REELS'].includes(post.media_type)) fail('VIDEO_POST_REQUIRED');
  if (tuple.creative_mode!==(post.kind==='FACEBOOK'?'FACEBOOK_EXISTING':'INSTAGRAM_EXISTING')) fail('EXISTING_POST_CREATIVE_UNSUPPORTED');
  if ((configuration.destinations||[]).length>1 && tuple.existing_post_multidestination!==true) fail('EXISTING_POST_MULTIDESTINATION_UNSUPPORTED');
  return tuple;
}

export async function preflight(configuration,connection,{graph,fetchImpl=fetch,now=Date.now()}={}) {
  const c=connection,cap=c?.capabilities;
  if (!c || c.status!=='authorized' || !numeric(String(c.page_id)) || !numeric(String(c.ad_account_id).replace(/^act_/,'')) || !cap) fail('META_CONNECTION_REQUIRED');
  if (!recent(c.verified_at,now) || !Number.isFinite(Date.parse(c.expires_at)) || Date.parse(c.expires_at)<=now || cap.api_version!==API_VERSION) fail('META_CONNECTION_VERIFICATION_REQUIRED');
  if (!numeric(cap.system_user_id) || !numeric(cap.business_id)) fail('META_ASSET_ASSIGNMENT_NOT_CONFIGURED',{status:503});
  const aliases=(cap.page_urls||[]).map(url=>normalizeUrl(url,'page'));
  if (!aliases.includes(configuration.page_url)) fail('PAGE_NOT_IN_AUTHORIZED_CONNECTION');
  const permission=await graph('me/permissions');
  const granted=new Set((permission.data||[]).filter(p=>p.status==='granted').map(p=>p.permission));
  if (!['ads_management','business_management','pages_read_engagement'].every(p=>granted.has(p))) fail('META_PERMISSION_MISSING');
  const actor=await graph('me',{fields:'id'});
  if (String(actor.id)!==cap.system_user_id) fail('META_BACKEND_ACTOR_MISMATCH');
  const assignedPage=await collect(graph,`${cap.system_user_id}/assigned_pages`,{business:cap.business_id,fields:'id,tasks'}, {find:p=>String(p.id)===String(c.page_id)});
  if (!assignedPage) fail('PAGE_NOT_ASSIGNED_TO_BACKEND');
  if (!(assignedPage.tasks||[]).some(t=>['ADVERTISE','MANAGE'].includes(t))) fail('PAGE_ADVERTISE_TASK_MISSING');
  const assignedAccount=await collect(graph,`${cap.system_user_id}/assigned_ad_accounts`,{business:cap.business_id,fields:'id,tasks'}, {find:a=>String(a.id).replace(/^act_/,'')===String(c.ad_account_id).replace(/^act_/, '')});
  if (!assignedAccount || !(assignedAccount.tasks||[]).some(t=>['ADVERTISE','MANAGE'].includes(t))) fail('AD_ACCOUNT_ADVERTISE_TASK_MISSING');
  const account=await graph(accountId(c),{fields:'id,account_id,account_status,currency,timezone_name'});
  if (account.currency!=='USD') fail('AD_ACCOUNT_CURRENCY_UNSUPPORTED');
  if (account.account_status!==1) fail('AD_ACCOUNT_NOT_ACTIVE');
  const pageData=await graph(String(c.page_id),{fields:'id,link,instagram_business_account'});
  if (String(pageData.id)!==String(c.page_id)) fail('PAGE_IDENTITY_MISMATCH');
  const page={id:String(c.page_id),instagram_id:String(pageData.instagram_business_account?.id||'')};
  const needsInstagram=configuration.placements.includes('instagram') || configuration.destinations?.includes('INSTAGRAM_DIRECT');
  if (needsInstagram && (!page.instagram_id || page.instagram_id!==String(c.instagram_account_id))) fail('INSTAGRAM_NOT_LINKED');
  if (configuration.destinations?.includes('MESSENGER') && !(cap.messenger?.enabled===true && recent(cap.messenger.verified_at,now))) fail('MESSENGER_CAPABILITY_NOT_VERIFIED');
  let whatsapp=null;
  if (configuration.destinations?.includes('WHATSAPP')) {
    const link=cap.whatsapp;
    if (!numeric(String(c.whatsapp_phone_number_id)) || link?.page_id!==page.id || link?.phone_number_id!==String(c.whatsapp_phone_number_id) || !recent(link.verified_at,now)) fail('WHATSAPP_PAGE_LINK_NOT_VERIFIED');
    const number=await graph(String(c.whatsapp_phone_number_id),{fields:'id,display_phone_number,verified_name'});
    if (String(number.id)!==String(c.whatsapp_phone_number_id) || !number.verified_name) fail('WHATSAPP_NUMBER_NOT_VERIFIED');
    const digits=String(number.display_phone_number||'').replace(/\D/g,'');
    if (!/^\d{8,15}$/.test(digits) || digits!==String(link.phone_number).replace(/\D/g,'')) fail('WHATSAPP_NUMBER_MISMATCH');
    whatsapp={id:String(number.id),phone_number:digits};
  }
  const postUrl=await resolveRedirect(configuration.post_url,{fetchImpl});
  const post=await resolvePost(graph,page,postUrl);
  const tuple=selectTuple(configuration,post,cap,{now});
  const location=cap.locations?.[configuration.targeting.location];
  if (!location || !recent(location.verified_at,now,30*86400000) || !location.geo_locations || !Object.keys(location.geo_locations).length) fail('TARGETING_LOCATION_NOT_CONFIGURED');
  if (configuration.targeting.location==='all' && !same(location.geo_locations,{countries:['IQ']})) fail('ALL_IRAQ_TARGETING_INVALID');
  if (configuration.targeting.location!=='all' && (location.country!=='IQ' || !Array.isArray(location.geo_locations.cities) || location.geo_locations.cities.length!==1 || !numeric(String(location.geo_locations.cities[0].key)) || Object.keys(location.geo_locations).some(k=>k!=='cities'))) fail('CITY_TARGETING_NOT_VERIFIED');
  const targeting={geo_locations:location.geo_locations,publisher_platforms:configuration.placements,
    age_min:configuration.targeting.age_min,age_max:configuration.targeting.age_max,
    ...(configuration.targeting.gender==='ALL'?{}:{genders:[configuration.targeting.gender==='MALE'?1:2]})};
  // Placement inventory and any mandatory account options are verified for this
  // exact post/tuple by the server operator, never accepted from the client.
  for (const key of ['facebook_positions','instagram_positions','device_platforms']) if (tuple[key]) targeting[key]=tuple[key];
  return {authorized:true,ready:true,connection_id:c.id,api_version:API_VERSION,verified_at:new Date(now).toISOString(),
    page,post,whatsapp,account:{id:accountId(c),currency:account.currency,timezone_name:account.timezone_name},
    tuple:{campaign_objective:tuple.campaign_objective,optimization_goal:tuple.optimization_goal,billing_event:tuple.billing_event,creative_mode:tuple.creative_mode,
      existing_post_multidestination:tuple.existing_post_multidestination===true},targeting,
    ...(configuration.destinations?{destination_type:destinationType(configuration.destinations)}:{})};
}

export function providerParameters(stage,job,evidence) {
  const config=job.configuration, ids=job.provider_ids||{}, budget=pricing(config);
  const name=`proxo:${job.id}:${stage}:${fingerprint(config).slice(0,12)}`;
  if (stage==='campaign') return {name,objective:evidence.tuple.campaign_objective,special_ad_categories:[],status:'PAUSED'};
  if (stage==='adset') {
    if (!ids.campaign) fail('PROVIDER_STAGE_ORDER_INVALID');
    const start=job.effective_start_at||job.start_at, end=job.effective_end_at||job.end_at;
    if (!Number.isFinite(Date.parse(start)) || !Number.isFinite(Date.parse(end)) || Date.parse(end)-Date.parse(start)!==config.duration_days*86400000) fail('ACCEPTED_SCHEDULE_MISSING');
    return {name,campaign_id:ids.campaign,status:'PAUSED',lifetime_budget:budget.media_budget_minor,
      start_time:start,end_time:end,bid_strategy:'LOWEST_COST_WITHOUT_CAP',billing_event:evidence.tuple.billing_event,
      optimization_goal:evidence.tuple.optimization_goal,targeting:evidence.targeting,
      promoted_object:{page_id:evidence.page.id},...(evidence.destination_type?{destination_type:evidence.destination_type}:{})};
  }
  if (stage==='creative') {
    const creative={name,...(evidence.post.kind==='FACEBOOK'?{object_story_id:evidence.post.id}:{object_id:evidence.page.id,source_instagram_media_id:evidence.post.id}),
      ...(config.placements.includes('instagram')||evidence.post.kind==='INSTAGRAM'?{instagram_user_id:evidence.page.instagram_id}:{})};
    const ctas=(config.destinations||[]).map(destination=>({type:destination==='WHATSAPP'?'WHATSAPP_MESSAGE':destination==='INSTAGRAM_DIRECT'?'INSTAGRAM_MESSAGE':'MESSAGE_PAGE',
      value:{app_destination:destination,...(destination==='WHATSAPP'?{link:`https://wa.me/${evidence.whatsapp.phone_number}`}:
        destination==='INSTAGRAM_DIRECT'?{link:'https://www.instagram.com'}:{link:`https://www.facebook.com/${evidence.page.id}`})}}));
    if (ctas.length>1) {
      if (!evidence.tuple.existing_post_multidestination) fail('EXISTING_POST_MULTIDESTINATION_UNSUPPORTED');
      creative.asset_feed_spec={optimization_type:'DOF_MESSAGING_DESTINATION',call_to_actions:ctas};
    } else if(ctas.length) creative.call_to_action=ctas[0];
    return creative;
  }
  if (stage==='ad') {
    if (!ids.adset||!ids.creative) fail('PROVIDER_STAGE_ORDER_INVALID');
    return {name,adset_id:ids.adset,creative:{creative_id:ids.creative},status:'PAUSED'};
  }
  fail('INVALID_PROVIDER_STAGE');
}

export async function createStage(graph,stage,job,evidence) {
  const result=await graph(`${evidence.account.id}/${edges[stage]}`,providerParameters(stage,job,evidence),{method:'POST'});
  if (!numeric(String(result.id))) fail('PROVIDER_OUTCOME_UNKNOWN',{uncertain:true,status:503});
  return String(result.id);
}

export async function reconcileStage(graph,stage,job,evidence) {
  const expected=providerParameters(stage,job,evidence);
  let matches=[],after;
  // A missing match is not proof of non-creation (propagation/pagination). It
  // must stay unresolved; only a single exact object is eligible for adoption.
  const fields={campaign:'id,name,objective,special_ad_categories,status',
    adset:'id,name,campaign_id,lifetime_budget,start_time,end_time,destination_type,status,bid_strategy,optimization_goal,billing_event,targeting,promoted_object',
    creative:'id,name,object_id,object_story_id,source_instagram_media_id,instagram_user_id,call_to_action,asset_feed_spec',ad:'id,name,adset_id,creative,status'}[stage];
  for(let i=0;i<10;i++) {
    const list=await graph(`${evidence.account.id}/${edges[stage]}`,{fields,limit:100,...(after?{after}:{})});
    if(!Array.isArray(list.data)) fail('PROVIDER_RESPONSE_INVALID',{status:503});
    matches.push(...list.data.filter(item=>item.name===expected.name));
    if(!list.paging?.next) break;
    after=list.paging?.cursors?.after;
    if(!after||i===9) fail('PROVIDER_RECONCILIATION_INCOMPLETE',{status:503});
  }
  if(matches.length!==1) fail(matches.length?'PROVIDER_DUPLICATE_OBJECTS':'PROVIDER_RECONCILIATION_PENDING',{uncertain:true,status:409});
  // Re-read the individual candidate, then compare every meaningful requested
  // field. Names alone (even deterministic names) are not provider proof.
  const m=await graph(String(matches[0].id),{fields});
  const verified=m.name===expected.name&&(stage==='campaign'?m.objective===expected.objective&&m.status==='PAUSED'&&same(m.special_ad_categories,expected.special_ad_categories):
    stage==='adset'?String(m.campaign_id)===expected.campaign_id&&Number(m.lifetime_budget)===expected.lifetime_budget&&m.status==='PAUSED'&&
      Date.parse(m.start_time)===Date.parse(expected.start_time)&&Date.parse(m.end_time)===Date.parse(expected.end_time)&&(!expected.destination_type||m.destination_type===expected.destination_type)&&
      m.bid_strategy===expected.bid_strategy&&m.optimization_goal===expected.optimization_goal&&m.billing_event===expected.billing_event&&
      same(m.targeting,expected.targeting)&&same(m.promoted_object,expected.promoted_object):
    stage==='creative'?String(m.object_story_id||m.source_instagram_media_id)===(expected.object_story_id||expected.source_instagram_media_id)&&
      (!expected.object_id||String(m.object_id)===expected.object_id)&&(!expected.instagram_user_id||String(m.instagram_user_id)===expected.instagram_user_id)&&
      (!expected.call_to_action||same(m.call_to_action,expected.call_to_action))&&(!expected.asset_feed_spec||same(m.asset_feed_spec,expected.asset_feed_spec)):
    String(m.adset_id)===expected.adset_id&&String(m.creative?.id)===expected.creative.creative_id&&m.status==='PAUSED');
  if(!verified||!numeric(String(m.id))) fail('PROVIDER_RECONCILIATION_MISMATCH',{uncertain:true,status:409});
  return String(m.id);
}

export async function observeChain(graph,job,{now=Date.now()}={}) {
  const ids=job.provider_ids||{}, observations={};
  for(const stage of ['campaign','adset','ad']) if(ids[stage]) observations[stage]=await graph(ids[stage],{fields:stage==='ad'?'id,status,effective_status,ad_review_feedback':'id,status,effective_status'});
  // Insights use lifetime totals, not a fabricated zero on missing/error data.
  let spend=null;
  if(ids.campaign) {
    const report=await graph(`${ids.campaign}/insights`,{fields:'spend',date_preset:'maximum'});
    if(!Array.isArray(report.data)) fail('PROVIDER_RESPONSE_INVALID',{status:503});
    if(report.data.length===1 && /^\d+(?:\.\d{1,2})?$/.test(String(report.data[0].spend))) spend=Math.round(Number(report.data[0].spend)*100);
  } else if(!Object.values(ids).length) spend=0;
  const paused=Object.keys(observations).length>0 && Object.values(observations).every(o=>['PAUSED','DELETED','ARCHIVED'].includes(o.status));
  const ad=observations.ad;
  return {provider_status:ad?.effective_status||observations.campaign?.effective_status||'NOT_CREATED',
    chain_paused:paused,spend_minor:spend,review_status:ad?.effective_status||null,
    terminal_failure:ad?.effective_status==='DISAPPROVED',verified_at:new Date(now).toISOString()};
}

export { edges, accountId };
