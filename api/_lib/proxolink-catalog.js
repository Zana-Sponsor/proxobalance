export const TEMPLATE_KEYS = ['pill','pill-mint','pill-dark','pill-white'];
export const TEMPLATE_VERSION = 4;
export const PROVIDERS = {
  wa:{type:'whatsapp',group:'contact',hosts:['wa.me','api.whatsapp.com','www.whatsapp.com']},
  tg:{type:'telegram',group:'contact',hosts:['t.me','telegram.me','telegram.org']},
  vb:{type:'viber',group:'contact',hosts:['viber.com']},
  ph:{type:'korek',group:'contact',hosts:[]},
  as:{type:'asiacell',group:'contact',hosts:[]},
  ig:{type:'instagram',group:'contact',hosts:['instagram.com']},
  talabat:{type:'talabat',group:'food',hosts:['talabat.com']},
  lezzoo:{type:'lezzoo',group:'food',hosts:['lezzoo.com','lezzoodevs.com']},
  toters:{type:'toters',group:'food',hosts:['totersapp.com','toters.com']},
  wade:{type:'wade',group:'food',hosts:['wadedelivery.com','trytiptop.com']},
  app_store:{type:'app_store',group:'download',hosts:['apps.apple.com']},
  google_play:{type:'google_play',group:'download',hosts:['play.google.com']},
};
export const PLATFORM_ALIASES = {whatsapp:'wa',telegram:'tg',viber:'vb',instagram:'ig',phone:'ph',korek:'ph',asya:'as',asiacell:'as',...Object.fromEntries(Object.keys(PROVIDERS).map(id=>[id,id]))};
export const LEGACY_TEMPLATE_MAP = {dark:'pill-dark',light:'pill-white',classic:'pill-white',card:'pill-white',neon:'pill-mint',zoom:'pill',banner:'pill'};
export function normalizedDigits(value){return String(value).replace(/[٠-٩۰-۹]/g,c=>String(c.charCodeAt(0)-(c<='٩'?1632:1776)));}
export function destination(id,value){
  const p=PROVIDERS[id];if(!p||typeof value!=='string')return null;
  let s=normalizedDigits(value).trim();if(!s||s.length>2048)return null;
  if(['wa','vb','ph','as'].includes(id)&&!s.includes('://')){
    let n=s.replace(/^tel:/i,'').replace(/[\s()-]/g,'');if(/^07\d{9}$/.test(n))n='+964'+n.slice(1);
    if(!/^\+?[1-9]\d{6,14}$/.test(n))return null;
    if(id==='wa')return 'https://wa.me/'+n.replace(/^\+/,'');
    if(id==='vb')return 'viber://chat?number='+encodeURIComponent('+'+n.replace(/^\+/,''));
    return 'tel:'+n;
  }
  if(['tg','ig'].includes(id)&&!s.includes('://')){
    s=s.replace(/^@/,'');if(!/^[a-zA-Z0-9._]{1,40}$/.test(s))return null;
    return (id==='tg'?'https://t.me/':'https://www.instagram.com/')+encodeURIComponent(s);
  }
  try{
    const u=new URL(s);
    if(id==='vb'&&u.protocol==='viber:'){
      const n=u.searchParams.get('number')||'';
      if(u.hostname==='chat'&&!u.pathname&&!u.hash&&!u.username&&!u.password&&[...u.searchParams.keys()].every(k=>k==='number')&&/^\+?[1-9]\d{6,14}$/.test(n))return 'viber://chat?number='+encodeURIComponent(n);
      return null;
    }
    if(u.protocol!=='https:'||u.username||u.password||(u.port&&u.port!=='443')||!p.hosts.some(h=>u.hostname===h||u.hostname.endsWith('.'+h)))return null;
    if(id==='app_store'&&!/\/id\d+/.test(u.pathname))return null;
    if(id==='google_play'&&(!/^\/store\/apps\/details\/?$/.test(u.pathname)||!u.searchParams.get('id')))return null;
    return u.href;
  }catch{return null;}
}
