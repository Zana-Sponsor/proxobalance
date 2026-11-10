// Manual add / refund / deduct of a customer's balance from the admin panel.
// Everything goes through /api/admin (actions balance_manual_*): the browser never
// chooses the acting admin, and the database enforces permission, caps and idempotency.
(function(){
  'use strict';
  var MODES={
    add:{label:'زیادکردن',verb:'زیاد دەکرێت',sign:1,btn:'پێداچوونەوەی زیادکردن'},
    refund:{label:'گەڕاندنەوە',verb:'دەگەڕێتەوە بۆ باڵانس',sign:1,btn:'پێداچوونەوەی گەڕاندنەوە'},
    deduct:{label:'کەمکردنەوە',verb:'کەم دەکرێتەوە',sign:-1,btn:'پێداچوونەوەی کەمکردنەوە'}
  };
  var KIND={admin_credit:'add',admin_refund:'refund',admin_debit:'deduct'};
  var ERR_FALLBACK='کردارەکە ئەنجام نەدرا؛ دووبارە هەوڵ بدەرەوە.';
  var MAX_OP=10000000;
  var acct=null, mode='add', pending=null, busy=false, searchSeq=0;

  function $(id){return document.getElementById(id);}
  function money(n){return Number(n||0).toLocaleString('en-US')+' د.ع';}
  function e(s){return typeof esc==='function'?esc(s):String(s==null?'':s).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];});}
  function when(s){return s?e(new Date(s).toLocaleString('en-GB')):'—';}
  function digits(v){
    return String(v==null?'':v).replace(/[٠-٩]/g,function(c){return String(c.charCodeAt(0)-0x660);})
      .replace(/[۰-۹]/g,function(c){return String(c.charCodeAt(0)-0x6f0);}).replace(/[^0-9]/g,'');
  }
  function amount(){var d=digits($('bmAmount').value);return d?parseInt(d,10):0;}
  function can(){return typeof staffCan!=='function'||staffCan('refunds');}
  function toast(t,k){if(typeof showToast==='function')showToast(t,k||'');}
  function api(a,p){return adminApiRequest(a,p||{});}
  function newKey(){
    if(window.crypto&&crypto.randomUUID)return crypto.randomUUID();
    var b=new Uint8Array(16);crypto.getRandomValues(b);b[6]=(b[6]&15)|64;b[8]=(b[8]&63)|128;
    var h=Array.prototype.map.call(b,function(x){return ('0'+x.toString(16)).slice(-2);}).join('');
    return h.slice(0,8)+'-'+h.slice(8,12)+'-'+h.slice(12,16)+'-'+h.slice(16,20)+'-'+h.slice(20);
  }
  function fields(){
    return {user_id:acct&&acct.user_id,mode:mode,amount_iqd:amount(),note:$('bmNote').value.trim(),
      order_code:mode==='refund'?$('bmOrder').value.trim().toUpperCase():''};
  }
  function validate(){
    if(!acct)return 'سەرەتا هەژمارێک هەڵبژێرە.';
    var f=fields();
    if(!f.amount_iqd||f.amount_iqd<1||f.amount_iqd>MAX_OP)return 'بڕەکە دەبێت لە 1 بۆ '+MAX_OP.toLocaleString('en-US')+' دینار بێت.';
    if(mode==='deduct'&&f.amount_iqd>Number(acct.available_iqd||0))return 'باڵانسی ئەم هەژمارە بەشی ئەم بڕە ناکات ('+money(acct.available_iqd)+').';
    if(f.note.length<5)return 'هۆکارەکە بنووسە (لانی کەم ٥ پیت).';
    return '';
  }
  function syncSubmit(){
    var ok=can()&&!!acct&&!busy&&amount()>0&&$('bmNote').value.trim().length>=5;
    $('bmSubmit').disabled=!ok;
  }
  function setMode(m){
    mode=m;
    Array.prototype.forEach.call(document.querySelectorAll('#bmForm .bm-mode'),function(b){
      var on=b.getAttribute('data-mode')===m;b.classList.toggle('on',on);b.setAttribute('aria-selected',on?'true':'false');
    });
    $('bmPanel').setAttribute('data-mode',m);
    $('bmOrderWrap').hidden=m!=='refund';
    $('bmSubmit').textContent=MODES[m].btn;
    $('bmError').textContent='';
    hideReview();syncSubmit();
  }
  function hideReview(){$('bmReview').hidden=true;$('bmForm').classList.remove('is-reviewing');}

  function showTotals(t){
    t=t||{};
    var el=$('bmTotals');
    el.innerHTML=
      '<div class="bm-stat add"><span>زیادکراو ئەمڕۆ</span><b>'+money(t.today_added)+'</b></div>'+
      '<div class="bm-stat ref"><span>گەڕێنراو ئەمڕۆ</span><b>'+money(t.today_refunded)+'</b></div>'+
      '<div class="bm-stat ded"><span>کەمکراوە ئەمڕۆ</span><b>'+money(t.today_deducted)+'</b></div>'+
      '<div class="bm-stat lim"><span>سنووری ماوەی ئەمڕۆی تۆ</span><b>'+money(t.my_remaining)+'</b></div>';
  }
  function logRows(rows){
    if(!rows||!rows.length)return '<div class="empty">هیچ کردارێکی دەستی تۆمار نەکراوە</div>';
    return '<table class="bm-table"><thead><tr><th>جۆر</th><th>هەژمار</th><th>بڕ</th><th>باڵانس دوای کردار</th><th>هۆکار</th><th>بەڕێوەبەر</th><th>کات</th></tr></thead><tbody>'+
      rows.map(function(r){
        var m=KIND[r.kind]||'add',neg=Number(r.delta_iqd)<0;
        return '<tr><td><span class="bm-tag '+m+'">'+MODES[m].label+'</span></td>'+
          '<td>'+e(r.customer_name||r.customer_username||r.user_id)+(r.customer_username?'<div class="bm-mini" dir="ltr">@'+e(r.customer_username)+'</div>':'')+'</td>'+
          '<td class="bm-num '+(neg?'neg':'pos')+'" dir="ltr">'+(neg?'−':'+')+Math.abs(Number(r.delta_iqd||0)).toLocaleString('en-US')+'</td>'+
          '<td dir="ltr">'+(r.balance_after_iqd==null?'—':Number(r.balance_after_iqd).toLocaleString('en-US'))+'</td>'+
          '<td>'+e(r.note||'—')+(r.order_code?'<div class="bm-mini" dir="ltr">'+e(r.order_code)+'</div>':'')+'</td>'+
          '<td>'+e(r.admin_name||'—')+'</td><td>'+when(r.created_at)+'</td></tr>';
      }).join('')+'</tbody></table>';
  }
  async function loadLog(){
    var box=$('bmLog');
    try{
      var d=await api('balance_manual_overview',{user_id:acct?acct.user_id:null,limit:30});
      box.innerHTML=logRows(d.rows);showTotals(d.totals);
      $('bmLogTitle').textContent=acct?'کردارە دەستییەکانی ئەم هەژمارە':'دوایین کردارە دەستییەکان';
    }catch(err){
      box.innerHTML='<div class="empty">'+e(err.message||ERR_FALLBACK)+'</div>';
    }
  }

  async function search(){
    var q=$('bmSearch').value.trim(),box=$('bmResults');
    if(q.length<2){box.innerHTML='<div class="bm-hint">لانی کەم ٢ پیت بنووسە.</div>';return;}
    var seq=++searchSeq;
    box.innerHTML='<div class="bm-hint">گەڕان...</div>';
    try{
      var rows=await api('balance_manual_find',{query:q});
      if(seq!==searchSeq)return;
      if(!rows.length){box.innerHTML='<div class="bm-hint">هیچ هەژمارێک نەدۆزرایەوە.</div>';return;}
      box.innerHTML=rows.map(function(r,i){
        return '<button type="button" class="bm-res" role="option" data-i="'+i+'">'+
          '<span class="bm-res-main"><b>'+e(r.full_name||r.username||r.email||'—')+'</b>'+
          '<small dir="ltr">'+e([r.username?'@'+r.username:'',r.phone||'',r.email||''].filter(Boolean).join(' · '))+'</small></span>'+
          '<span class="bm-res-bal" dir="ltr">'+Number(r.available_iqd||0).toLocaleString('en-US')+'</span></button>';
      }).join('');
      box._rows=rows;
    }catch(err){
      if(seq===searchSeq)box.innerHTML='<div class="bm-hint err">'+e(err.message||ERR_FALLBACK)+'</div>';
    }
  }
  function pick(row){
    acct=row;pending=null;
    $('bmResults').innerHTML='';$('bmResults')._rows=null;
    $('bmAccount').hidden=false;$('bmForm').hidden=false;
    $('bmAccName').textContent=row.full_name||row.username||row.email||'—';
    $('bmAccSub').textContent=[row.username?'@'+row.username:'',row.phone||'',row.email||''].filter(Boolean).join(' · ');
    $('bmAccBal').textContent=money(row.available_iqd);
    $('bmSuccess').hidden=true;
    hideReview();syncSubmit();loadLog();
  }
  function clearAcct(){
    acct=null;pending=null;
    $('bmAccount').hidden=true;$('bmForm').hidden=true;hideReview();
    $('bmAmount').value='';$('bmNote').value='';$('bmOrder').value='';$('bmError').textContent='';
    loadLog();
  }

  function review(ev){
    if(ev)ev.preventDefault();
    var err=$('bmError');err.textContent='';
    if(!can()){err.textContent='مۆڵەتی گۆڕینی باڵانسی هەژمارەکانت نییە.';return;}
    var bad=validate();if(bad){err.textContent=bad;return;}
    var f=fields(),after=Number(acct.available_iqd||0)+MODES[mode].sign*f.amount_iqd;
    $('bmReviewList').innerHTML=
      '<div><dt>هەژمار</dt><dd>'+e(acct.full_name||acct.username||acct.email)+'</dd></div>'+
      '<div><dt>کردار</dt><dd><span class="bm-tag '+mode+'">'+MODES[mode].label+'</span></dd></div>'+
      '<div><dt>بڕ</dt><dd dir="ltr">'+(MODES[mode].sign<0?'−':'+')+f.amount_iqd.toLocaleString('en-US')+' IQD</dd></div>'+
      '<div><dt>باڵانسی ئێستا</dt><dd dir="ltr">'+Number(acct.available_iqd||0).toLocaleString('en-US')+'</dd></div>'+
      '<div class="strong"><dt>باڵانسی دوای کردار</dt><dd dir="ltr">'+after.toLocaleString('en-US')+'</dd></div>'+
      (f.order_code?'<div><dt>مامەڵە</dt><dd dir="ltr">'+e(f.order_code)+'</dd></div>':'')+
      '<div class="wide"><dt>هۆکار</dt><dd>'+e(f.note)+'</dd></div>';
    $('bmReviewNote').textContent=mode==='deduct'
      ?'ئەم بڕە لە باڵانسی کڕیار کەم دەکرێتەوە و ئاگادارکردنەوەی بۆ دەنێردرێت.'
      :'ئەم بڕە بۆ باڵانسی کڕیار تۆمار دەکرێت و ئاگادارکردنەوەی بۆ دەنێردرێت.';
    $('bmReview').hidden=false;$('bmForm').classList.add('is-reviewing');
    $('bmConfirm').className='modal-btn bm-confirm '+mode;
    $('bmConfirm').focus();
  }

  async function confirmIt(){
    if(busy)return;
    var bad=validate();if(bad){$('bmError').textContent=bad;hideReview();return;}
    var f=fields(),fp=JSON.stringify(f);
    // A retry of the exact same operation keeps its key, so a lost reply cannot post twice.
    if(!pending||pending.fp!==fp)pending={fp:fp,key:newKey()};
    busy=true;$('bmConfirm').disabled=true;$('bmConfirm').textContent='تۆمار دەکرێت...';syncSubmit();
    try{
      var r=await api('balance_manual_adjust',{user_id:f.user_id,mode:f.mode,amount_iqd:f.amount_iqd,note:f.note,
        order_code:f.order_code||null,request_key:pending.key,confirmed:true});
      var label=MODES[f.mode].label;
      acct.available_iqd=r.balance_after_iqd;$('bmAccBal').textContent=money(r.balance_after_iqd);
      pending=null;hideReview();
      $('bmAmount').value='';$('bmNote').value='';$('bmOrder').value='';
      var ok=$('bmSuccess');ok.hidden=false;
      ok.innerHTML='<b>'+label+'ی '+money(f.amount_iqd)+' تۆمار کرا</b><span>باڵانسی نوێی هەژمار: <bdi dir="ltr">'+
        Number(r.balance_after_iqd||0).toLocaleString('en-US')+'</bdi> د.ع'+(r.duplicate?' · ئەم کردارە پێشتر تۆمار کرابوو':'')+'</span>';
      toast(label+'ی باڵانس تۆمار کرا','gr');
      if(typeof loadBalanceAdmin==='function'&&_origLoad)_origLoad();
      loadLog();
    }catch(err){
      var definite=err&&err.status&&err.status<500;
      if(definite&&err.status!==409)pending=null;
      $('bmError').textContent=(err&&err.message||ERR_FALLBACK)+((!err.status||err.status>=500)?' بۆ دووبارە هەوڵدان هەمان زانیاری بەکاربهێنە.':'');
      hideReview();
    }finally{
      busy=false;$('bmConfirm').disabled=false;$('bmConfirm').textContent='پشتڕاستکردنەوە و تۆمارکردن';syncSubmit();
    }
  }

  var _origLoad=null;
  function init(){
    if(!$('bmPanel'))return;
    $('bmSearchBtn').addEventListener('click',search);
    $('bmSearch').addEventListener('keydown',function(ev){if(ev.key==='Enter'){ev.preventDefault();search();}});
    $('bmResults').addEventListener('click',function(ev){
      var b=ev.target.closest&&ev.target.closest('.bm-res');if(!b)return;
      var rows=$('bmResults')._rows||[];var r=rows[Number(b.getAttribute('data-i'))];if(r)pick(r);
    });
    $('bmAccClear').addEventListener('click',clearAcct);
    Array.prototype.forEach.call(document.querySelectorAll('#bmForm .bm-mode'),function(b){
      b.addEventListener('click',function(){setMode(b.getAttribute('data-mode'));});
    });
    $('bmAmount').addEventListener('input',function(){
      var d=digits(this.value);this.value=d?parseInt(d,10).toLocaleString('en-US'):'';
      $('bmError').textContent='';hideReview();syncSubmit();
    });
    $('bmChips').addEventListener('click',function(ev){
      var b=ev.target.closest&&ev.target.closest('button[data-v]');if(!b)return;
      $('bmAmount').value=Number(b.getAttribute('data-v')).toLocaleString('en-US');hideReview();syncSubmit();
    });
    ['bmNote','bmOrder'].forEach(function(id){$(id).addEventListener('input',function(){$('bmError').textContent='';hideReview();syncSubmit();});});
    $('bmForm').addEventListener('submit',review);
    $('bmConfirm').addEventListener('click',confirmIt);
    $('bmBack').addEventListener('click',function(){hideReview();$('bmAmount').focus();});
    $('bmLogRefresh').addEventListener('click',loadLog);
    setMode('add');
    // Refreshing the balance board also refreshes this section.
    if(typeof window.loadBalanceAdmin==='function'){
      _origLoad=window.loadBalanceAdmin;
      window.loadBalanceAdmin=function(){loadLog();return _origLoad.apply(this,arguments);};
    }
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();
