(function(){
  var SB_URL=atob('aHR0cHM6Ly9weWN4dXVnb2Jsa3NsdndlYnh1dS5zdXBhYmFzZS5jbw==');
  var SB_KEY=atob('ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnBjM01pT2lKemRYQmhZbUZ6WlNJc0luSmxaaUk2SW5CNVkzaDFkV2R2WW14cmMyeDJkMlZpZUhWMUlpd2ljbTlzWlNJNkltRnViMjRpTENKcFlYUWlPakUzT0RZeU1UazNPVGtzSW1WNGNDSTZNakV3TVRjNU5UYzVPWDAuVlJSd3hubnVMc19XT1J1VlVPM29YM0NMeHJQdGdHX3Vld0lKYUdyem5fcw==');
  // same project (Exchange) and same stored session as the main site
  var sb=window.supabase.createClient(SB_URL,SB_KEY,{auth:{persistSession:true,autoRefreshToken:true,storageKey:'zex_sb_session'}});
  var $=function(id){return document.getElementById(id)};
  var LABEL={add:'زیادکردنی باڵانس',refund:'گەڕاندنەوەی باڵانس',deduct:'کەمکردنەوەی باڵانس'};
  var KIND={admin_credit:'زیادکردنی باڵانس',admin_refund:'گەڕاندنەوەی باڵانس (بەڕێوەبەر)',admin_debit:'کەمکردنەوەی باڵانس',verified_refund:'گەڕاندنەوەی مامەڵە',shortfall_refund:'گەڕاندنەوەی پاشماوە',order_debit:'بەکارهێنان بۆ مامەڵە',payout_hold:'پارەی ناردن (ڕاگیراو)',payout_cancel:'هەڵوەشاندنەوەی ناردن',payout_paid:'ناردن'};
  var ERR={ADMIN_REQUIRED:'تەنها بەڕێوەبەر دەتوانێت ئەم کردارە بکات.',ACCOUNT_NOT_FOUND:'ئەم هەژمارە نەدۆزرایەوە.',AMOUNT_INVALID:'بڕەکە دەبێت لە ١ بۆ ١٠,٠٠٠,٠٠٠ دینار بێت.',NOTE_REQUIRED:'هۆکار پێویستە و دەبێت لانی کەم ٥ پیت بێت.',ORDER_NOT_FOUND:'ئەم کۆدی مامەڵەیە بۆ ئەم هەژمارە نەدۆزرایەوە.',INSUFFICIENT_BALANCE:'باڵانسی ئەم هەژمارە بەشی ئەم بڕە ناکات.',DAILY_LIMIT_EXCEEDED:'سنووری ڕۆژانەی کردارەکانی باڵانس تەواو بووە (٥٠,٠٠٠,٠٠٠ دینار).',REQUEST_KEY_REUSED:'ئەم کردارە پێشتر تۆمار کراوە. لاپەڕەکە نوێ بکەرەوە.',MODE_INVALID:'جۆری کردار هەڵەیە.',AUTH_REQUIRED:'تکایە دووبارە بچۆ ژوورەوە.'};
  var cur=null, mode='add', pending=null, busy=false;

  function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function iqd(n){return Number(n||0).toLocaleString('en-US')+' IQD'}
  function digits(s){return String(s||'').replace(/[٠-٩]/g,function(d){return '٠١٢٣٤٥٦٧٨٩'.indexOf(d)}).replace(/[^0-9]/g,'')}
  function amount(){var v=digits($('amt').value);return v?parseInt(v,10):0}
  function toast(t,k){var el=$('toast');el.className=k||'';el.firstElementChild.textContent=t;el.style.display='flex';clearTimeout(toast._t);toast._t=setTimeout(function(){el.style.display='none'},3200)}
  function errText(e){var m=String((e&&(e.message||e.details))||'');for(var k in ERR){if(m.indexOf(k)>-1)return ERR[k]}return 'کردارەکە سەرنەکەوت. دووبارە هەوڵبدەرەوە.'}
  function when(iso){var d=new Date(iso);if(isNaN(d))return '';var p=function(n){return String(n).padStart(2,'0')};return d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate())+' '+p(d.getHours())+':'+p(d.getMinutes())}
  function uuid(){return (crypto&&crypto.randomUUID)?crypto.randomUUID():'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,function(c){var r=Math.random()*16|0;return (c==='x'?r:(r&3|8)).toString(16)})}

  async function boot(){
    try{
      var s=await sb.auth.getSession();
      var u=s&&s.data&&s.data.session&&s.data.session.user;
      if(!u){$('gateMsg').innerHTML='پێویستە سەرەتا بچیتە ژوورەوە. <br><a href="/" style="color:var(--accent)">گەڕانەوە بۆ ماڵپەڕ</a>';return}
      var p=await sb.from('ex_profiles').select('is_admin,is_banned').eq('id',u.id).maybeSingle();
      if(!p.data||!p.data.is_admin||p.data.is_banned){$('gateMsg').textContent='تەنها بەڕێوەبەر دەتوانێت ئەم لاپەڕەیە بەکاربهێنێت.';return}
      $('gate').hidden=true;$('app').hidden=false;
    }catch(e){$('gateMsg').textContent='نەتوانرا پەیوەندی بکرێت. دووبارە هەوڵبدەرەوە.'}
  }

  async function search(){
    var q=$('q').value.trim();
    var box=$('results');
    if(q.length<2){box.innerHTML='<div class="empty">لانی کەم ٢ پیت بنووسە.</div>';return}
    box.innerHTML='<div class="empty">دەگەڕێت...</div>';
    var r=await sb.rpc('ex_admin_find_accounts',{p_query:q});
    if(r.error){box.innerHTML='<div class="err">'+esc(errText(r.error))+'</div>';return}
    var rows=r.data||[];
    if(!rows.length){box.innerHTML='<div class="empty">هیچ هەژمارێک نەدۆزرایەوە.</div>';return}
    box.innerHTML=rows.map(function(a,i){
      return '<button type="button" data-i="'+i+'"><span><b>'+esc(a.full_name||'—')+'</b><small class="ltr">@'+esc(a.username||'')+' · '+esc(a.phone||a.email||'')+'</small></span><span class="bal ltr">'+esc(iqd(a.available_iqd))+'</span></button>';
    }).join('');
    box._rows=rows;
  }

  function pick(a){
    cur={id:a.user_id,name:a.full_name,username:a.username,phone:a.phone,email:a.email,bal:Number(a.available_iqd||0)};
    $('results').innerHTML='';
    $('acctCard').hidden=false;$('histCard').hidden=false;
    $('aName').textContent=cur.name||'—';
    $('aSub').textContent='@'+(cur.username||'')+' · '+(cur.phone||cur.email||'');
    $('amt').value='';$('note').value='';$('ord').value='';$('formErr').hidden=true;
    setMode('add');paint();loadHist();
    $('acctCard').scrollIntoView({behavior:'smooth',block:'start'});
  }

  function setMode(m){
    mode=m;
    [].forEach.call($('seg').children,function(b){b.classList.toggle('on',b.dataset.m===m)});
    $('orderBox').hidden=(m!=='refund');
    paint();
  }

  function paint(){
    if(!cur)return;
    $('aBal').textContent=iqd(cur.bal);
    var a=amount(),n=$('note').value.trim();
    var after=mode==='deduct'?cur.bal-a:cur.bal+a;
    var pv=$('preview');pv.className='preview';
    if(!a){pv.textContent='بڕەکە بنووسە بۆ بینینی باڵانسی نوێ.'}
    else if(after<0){pv.className='preview bad';pv.textContent='باڵانسی ئەم هەژمارە بەشی ئەم بڕە ناکات.'}
    else{pv.innerHTML=LABEL[mode]+': <b class="ltr">'+esc(iqd(a))+'</b> — باڵانسی نوێ: <b class="ltr">'+esc(iqd(after))+'</b>'}
    $('goBtn').disabled=busy||!a||after<0||a>10000000||n.length<5;
  }

  async function loadHist(){
    var box=$('hist');box.innerHTML='<div class="empty">بار دەکرێت...</div>';
    var r=await sb.rpc('ex_admin_balance_history',{p_user_id:cur.id,p_limit:15});
    if(r.error){box.innerHTML='<div class="err">'+esc(errText(r.error))+'</div>';return}
    var rows=r.data||[];
    if(!rows.length){box.innerHTML='<div class="empty">هیچ جووڵەیەک نییە.</div>';return}
    box.innerHTML=rows.map(function(x){
      var d=Number(x.delta_iqd||0);
      var sub=[x.order_code?('مامەڵە '+x.order_code):'',x.note||''].filter(Boolean).join(' · ');
      return '<div class="h"><div class="t"><b>'+esc(KIND[x.kind]||x.kind)+'</b>'+(sub?'<small>'+esc(sub)+'</small>':'')+'<small class="ltr">'+esc(when(x.created_at))+'</small></div><div class="a '+(d>=0?'pos':'neg')+'">'+(d>=0?'+':'−')+esc(iqd(Math.abs(d)))+'</div></div>';
    }).join('');
  }

  function openConfirm(){
    var a=amount(),n=$('note').value.trim(),o=$('ord').value.trim().toUpperCase();
    var after=mode==='deduct'?cur.bal-a:cur.bal+a;
    $('cTitle').textContent=LABEL[mode];
    $('cSum').innerHTML='<div><span>هەژمار</span><span>'+esc(cur.name||'')+' <bdi dir="ltr">(@'+esc(cur.username||'')+')</bdi></span></div>'
      +'<div><span>کردار</span><span>'+LABEL[mode]+'</span></div>'
      +'<div><span>بڕ</span><span class="ltr">'+esc(iqd(a))+'</span></div>'
      +'<div><span>باڵانسی ئێستا</span><span class="ltr">'+esc(iqd(cur.bal))+'</span></div>'
      +'<div><span>باڵانسی نوێ</span><span class="ltr">'+esc(iqd(after))+'</span></div>'
      +(mode==='refund'&&o?'<div><span>مامەڵە</span><span class="ltr">'+esc(o)+'</span></div>':'')
      +'<div><span>هۆکار</span><span>'+esc(n)+'</span></div>';
    $('cWarn').textContent=mode==='deduct'
      ?'ئەم بڕە لە باڵانسی بەکارهێنەر کەم دەکرێتەوە و ئاگادارکردنەوەی بۆ دەچێت. تۆمار دەکرێت و ناتوانرێت بسڕدرێتەوە.'
      :'ئەم بڕە دەچێتە سەر باڵانسی بەکارهێنەر و ئاگادارکردنەوەی بۆ دەچێت. تۆمار دەکرێت و ناتوانرێت بسڕدرێتەوە.';
    $('cErr').hidden=true;$('confirm').classList.add('open');
  }

  async function execute(){
    if(busy)return;
    var a=amount(),n=$('note').value.trim(),o=$('ord').value.trim().toUpperCase();
    var sig=[cur.id,mode,a,n,mode==='refund'?o:''].join('|');
    if(!pending||pending.sig!==sig)pending={sig:sig,key:uuid()};      // a retry of the same operation reuses its key → never doubles
    busy=true;$('cYes').disabled=true;$('cYes').textContent='دەسپێدەکات...';$('cErr').hidden=true;
    var r=await sb.rpc('ex_admin_adjust_balance',{p_user_id:cur.id,p_mode:mode,p_amount_iqd:a,p_note:n,p_request_key:pending.key,p_order_code:(mode==='refund'&&o)?o:null});
    busy=false;$('cYes').disabled=false;$('cYes').textContent='پشتڕاستکردنەوە و جێبەجێکردن';
    if(r.error){$('cErr').textContent=errText(r.error);$('cErr').hidden=false;return}
    pending=null;
    var res=r.data||{};
    cur.bal=Number(res.balance_after_iqd!=null?res.balance_after_iqd:cur.bal);
    $('confirm').classList.remove('open');
    $('amt').value='';$('note').value='';$('ord').value='';
    paint();loadHist();
    toast(res.duplicate?'ئەم کردارە پێشتر تۆمار کرابوو':'بە سەرکەوتوویی جێبەجێ کرا — باڵانسی نوێ: '+iqd(cur.bal),'ok');
  }

  $('qBtn').onclick=search;
  $('q').addEventListener('keydown',function(e){if(e.key==='Enter'){e.preventDefault();search()}});
  $('results').addEventListener('click',function(e){var b=e.target.closest('button[data-i]');if(!b)return;pick($('results')._rows[+b.dataset.i])});
  $('seg').addEventListener('click',function(e){var b=e.target.closest('button');if(b)setMode(b.dataset.m)});
  $('amt').addEventListener('input',function(){var v=digits(this.value);this.value=v?parseInt(v,10).toLocaleString('en-US'):'';paint()});
  $('note').addEventListener('input',paint);
  $('chips').innerHTML=[5000,10000,25000,50000,100000].map(function(v){return '<button type="button" data-v="'+v+'">'+v.toLocaleString('en-US')+'</button>'}).join('');
  $('chips').addEventListener('click',function(e){var b=e.target.closest('button');if(!b)return;$('amt').value=Number(b.dataset.v).toLocaleString('en-US');paint()});
  $('goBtn').onclick=openConfirm;
  $('cNo').onclick=function(){if(!busy)$('confirm').classList.remove('open')};
  $('cYes').onclick=execute;
  $('confirm').addEventListener('click',function(e){if(e.target===this&&!busy)this.classList.remove('open')});
  boot();
})();
