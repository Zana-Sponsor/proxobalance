/* Same-origin IP gate before application authentication. */
(function(){
 'use strict';
 let pending=null;
 function blocked(){location.replace('/ip-blocked.html');return false;}
 async function check(){
  if(pending)return pending;
  pending=(async()=>{
   try{const r=await fetch('/api/access',{cache:'no-store'});if(r.status===403)return blocked();if(!r.ok)throw new Error('Access unavailable');return true;}
   catch(e){return false;}
   finally{pending=null;}
  })();
  const ok=await pending;
  if(!ok&&!location.pathname.includes('ip-blocked')){
   const el=document.getElementById('authErr')||document.getElementById('authMsgEmail');
   if(el){el.textContent='نەتوانرا پەیوەندی بکرێت؛ تکایە دووبارە هەوڵ بدەرەوە.';el.style.display='block';}
  }
  return ok;
 }
 window.ProxoAccess={check};
 window.trackAuthAttempt=async function(email,purpose){
  try{const r=await fetch('/api/track',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({type:'login_attempt',detail:String(email).trim().toLowerCase().slice(0,254),purpose}),keepalive:true});if(r.status===403)blocked();}catch(_){}
 };
 document.addEventListener('DOMContentLoaded',()=>check());
})();
