/* Re-read authoritative rows on change, reconnect and page resume.
 * A job coalesces bursts and repeats once if a change arrives during a read. */
'use strict';
const ProxoLive=(()=>{
 let client=null,channel=null,scope=null,owner=null,bindings=[],status='CLOSED',epoch=0;
 const jobs=new Map();
 function stop(){
  ++epoch;
  for(const job of jobs.values())clearTimeout(job.timer);jobs.clear();
  if(channel&&client)Promise.resolve(client.removeChannel(channel)).catch(()=>{});
  channel=null;owner=null;bindings=[];status='CLOSED';
 }
 function queue(key,read){
  if(!owner)return;
  const activeOwner=owner,activeScope=scope,activeEpoch=epoch;
  const existing=jobs.get(key);
  if(existing){existing.again=true;return;}
  const job={again:false,timer:null};jobs.set(key,job);
  job.timer=setTimeout(async()=>{
   do{
    job.again=false;
    if(owner!==activeOwner||scope!==activeScope||epoch!==activeEpoch)break;
    try{await read();}catch(e){console.warn('Live refresh failed:',key,e?.message);}
   }while(job.again&&owner===activeOwner&&scope===activeScope&&epoch===activeEpoch);
   if(jobs.get(key)===job)jobs.delete(key);
  },80);
 }
 function refresh(){
  if(document.visibilityState==='hidden'||!owner)return;
  for(const binding of bindings)queue(binding.key,binding.read);
 }
 function start(sb,nextScope,nextOwner,nextBindings){
  if(channel&&owner===nextOwner&&scope===nextScope)return;
  stop();if(!nextOwner||!sb)return;
  client=sb;scope=nextScope;owner=nextOwner;bindings=nextBindings;
  const activeOwner=owner,activeScope=scope,activeEpoch=epoch;
  channel=sb.channel('exchange_live_'+scope+'_'+owner);
  for(const binding of bindings){
   for(const event of binding.events||['INSERT','UPDATE']){
    channel.on('postgres_changes',{event,schema:'public',table:binding.table,
      ...(binding.filter?{filter:binding.filter}:{})},()=>{
       if(owner===activeOwner&&scope===activeScope&&epoch===activeEpoch)queue(binding.key,binding.read);
      });
   }
  }
  channel.subscribe(nextStatus=>{
   if(owner!==activeOwner||scope!==activeScope||epoch!==activeEpoch)return;
   status=nextStatus;
   if(status==='SUBSCRIBED')refresh();
  });
 }
 document.addEventListener('visibilitychange',refresh);
 window.addEventListener('online',refresh);
 window.addEventListener('focus',refresh);
 window.setInterval(()=>{if(status!=='SUBSCRIBED')refresh();},15000);
 return {start,stop,refresh,queue};
})();
