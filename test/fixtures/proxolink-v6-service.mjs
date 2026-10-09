import {randomUUID} from 'node:crypto';
export const OWNER='11111111-1111-4111-8111-111111111111',OTHER='99999999-9999-4999-8999-999999999999';
export function localService({onRequest}={}) {
  const rows=[],writes=[],events=[],ads=[];let tick=0;
  function matches(row,url) {
    for(const [key,value] of url.searchParams){
      if(['select','order','limit','or'].includes(key))continue;
      if(value.startsWith('eq.')&&String(row[key])!==value.slice(3))return false;
      if(value==='is.null'&&row[key]!=null)return false;
    }return true;
  }
  const selected=(row,url)=>{const cols=url.searchParams.get('select');return !cols||cols==='*'?{...row}:
    Object.fromEntries(cols.split(',').map(k=>[k,row[k]===undefined?null:row[k]]));};
  async function fetcher(raw,options={}) {
    const url=new URL(raw);if(onRequest)return onRequest(url,options,{rows,writes,events});
    if(url.pathname==='/auth/v1/user')return options.headers?.Authorization==='Bearer other-token'?Response.json({id:OTHER}):Response.json({id:OWNER});
    if(url.pathname==='/rest/v1/pa_contact_events'){events.push(JSON.parse(options.body));return new Response(null,{status:201});}
    if(url.pathname==='/rest/v1/proxolink_publish_attempts')return new Response(null,{status:201});
    if(url.pathname==='/rest/v1/pa_ads')return Response.json(ads.filter(r=>matches(r,url)).map(r=>selected(r,url)));
    if(url.pathname==='/rest/v1/proxolink_cards'){
      const method=options.method||'GET',body=options.body?JSON.parse(options.body):null;
      if(method==='POST'){
        if(rows.some(r=>r.user_id===body.user_id&&r.client_request_id===body.client_request_id))return Response.json({code:'23505'},{status:409});
        const row={moderation_status:'pending',id:randomUUID(),created_at:new Date().toISOString(),updated_at:new Date(Date.now()+ ++tick).toISOString(),card_number:rows.length+1,...body};
        rows.push(row);writes.push({method,body});return Response.json([selected(row,url)],{status:201});
      }
      const found=rows.filter(r=>matches(r,url));
      if(method==='PATCH'){
        writes.push({method,body});for(const r of found)Object.assign(r,body,{updated_at:new Date(Date.now()+ ++tick).toISOString()});
      }
      if(method==='DELETE'){writes.push({method,body});for(const r of found)rows.splice(rows.indexOf(r),1);}
      return Response.json(found.map(r=>selected(r,url)));
    }
    if(url.pathname.startsWith('/storage/'))return new Response('missing',{status:404});
    throw Error('Unexpected fixture endpoint: '+url.pathname);
  }
  return {fetcher,rows,writes,events,ads};
}
export function pagePayload(type,providers,extra={}) {
  const destinations={whatsapp:'07501234567',viber:'+9647501234567',instagram:'proxo_iq',telegram:'proxo_iq',korek:'07501234567',asiacell:'07701234567',
    talabat:'https://iraq.talabat.com/iraq/restaurant/proxo',toters:'https://www.totersapp.com/restaurant/proxo',
    lezzoo:'https://www.lezzoo.com/restaurant/proxo',wade:'https://wadedelivery.com/restaurant/proxo',
    google_play:'https://play.google.com/store/apps/details?id=com.proxo.app',app_store:'https://apps.apple.com/us/app/proxo/id123456789'};
  return {client_request_id:randomUUID(),page_kind:type,name:'Proxo '+type,bio:'بایۆ Proxo 2026',template_key:'pill-white',template_version:6,
    card_language:'ku',color_theme:'purple',avatar_path:null,
    settings:{providers:providers.map((provider_key,sort_order)=>({provider_key,destination_url:destinations[provider_key],enabled:true,sort_order}))},...extra};
}
export function response(){return {statusCode:0,headers:{},setHeader(k,v){this.headers[k.toLowerCase()]=v;},end(body=''){this.body=body;}};}
export async function invoke(handler,op,{method='GET',body={},query={},auth='user-token'}={}) {
  const res=response();await handler({method,query:{op,...query},body,url:'/api/proxolink',headers:auth?{authorization:'Bearer '+auth}:{},socket:{remoteAddress:'127.0.0.1'}},res);
  return {status:res.statusCode,headers:res.headers,body:res.body,json:()=>JSON.parse(res.body)};
}
export function configFromHtml(html){return JSON.parse(html.match(/<script type="application\/json" id="proxo-config">([\s\S]*?)<\/script>/)[1]);}
