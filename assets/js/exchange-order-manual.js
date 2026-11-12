/* Manual order control for the admin panel:
   change status (any of the five), edit every editable field, hide an order for the customer
   or delete it permanently. Nothing here notifies the customer unless the admin ticks the
   "send notification" box on a status change. Every rule is enforced again by the database
   (ex_admin_order_set_status / ex_admin_order_update / ex_admin_order_delete). */
(function(){
  'use strict';
  var STATUSES=['چاوەڕوانە','پێویستی بە ڕاستکردنەوەیە','ڕاستکراوەتەوە','پەسەندکرا','ڕەتکرا'];
  var FIELDS=[
    {k:'order_code',l:'کۆدی مامەڵە',t:'text',ltr:1},
    {k:'from_method',l:'ڕێگای ناردن',t:'method'},
    {k:'to_method',l:'ڕێگای وەرگرتن',t:'method'},
    {k:'amount',l:'بڕی نێردراو',t:'number'},
    {k:'total',l:'بڕی وەرگیراو (دوای لێبڕین)',t:'number'},
    {k:'phone',l:'ژمارەی وەرگر',t:'text',ltr:1},
    {k:'sender_name',l:'ناوی نێرەر',t:'text'},
    {k:'sender_phone',l:'ژمارەی نێرەر',t:'text',ltr:1},
    {k:'transaction_reference',l:'ژمارەی ئاماژەی مامەڵە',t:'text',ltr:1},
    {k:'receipt_url',l:'بەستەری وێنەی وەسڵ',t:'text',ltr:1},
    {k:'receipt_hash',l:'هاشی وەسڵ',t:'text',ltr:1},
    {k:'payout_receipt_url',l:'بەستەری وەسڵی پارەدان',t:'text',ltr:1},
    {k:'extra_info',l:'زانیاری زیادە',t:'area'},
    {k:'admin_note',l:'تێبینی ئادمین',t:'area'},
    {k:'created_at',l:'کاتی دروستکردن',t:'date'},
    {k:'decided_at',l:'کاتی بڕیار',t:'date'}
  ];
  var ACTION_LABEL={status:'گۆڕینی دۆخ',edit:'دەستکاری',hide:'شاردنەوە لای بەکارھێنەر',unhide:'گێڕانەوە بۆ بەکارھێنەر','delete':'سڕینەوەی هەمیشەیی'};
  var busy=false;

  function $(id){return document.getElementById(id);}
  function E(s){return typeof esc==='function'?esc(s):String(s==null?'':s);}
  function find(id){return (typeof allOrders!=='undefined'?allOrders:[]).find(function(o){return String(o.id)===String(id);});}
  function isHidden(o){return !!(o&&o.user_deleted_at);}
  function locks(o){
    var all=FIELDS.map(function(f){return f.k;}),open=all.slice();
    var why='';
    if(o.payout_settlement_id){open=['extra_info','admin_note','created_at'];why='پارەدانی ئەم مامەڵەیە ئەنجامدراوە؛ تەنها تێبینی، زانیاری زیادە و کاتی دروستکردن دەگۆڕدرێن.';}
    else if(o.balance_refunded_at){open=['extra_info','admin_note','created_at','decided_at','sender_name','sender_phone','transaction_reference','payout_receipt_url','order_code'];why='ئەم مامەڵەیە گەڕاندنەوەی تێدا کراوە؛ زانیارییە دارایییەکان ناگۆڕدرێن.';}
    else if(Number(o.shortfall_refunded_iqd||0)>0){open=['extra_info','admin_note','created_at','decided_at','sender_name','sender_phone','payout_receipt_url'];why='قەرەبووی کەمی نێردراوی تێدا کراوە؛ زانیارییە دارایییەکان ناگۆڕدرێن.';}
    else if(o.from_method==='AccountBalance'){open=all.filter(function(k){return ['from_method','to_method','amount','total'].indexOf(k)<0;});why='ئەم مامەڵەیە لە باڵانسی هەژمار نێردراوە؛ بڕ و ڕێگاکان ناگۆڕدرێن.';}
    return {locked:all.filter(function(k){return open.indexOf(k)<0;}),why:why};
  }
  function statusLocked(o){
    if(o.payout_settlement_id)return 'پارەدانی ئەم مامەڵەیە ئەنجامدراوە و دۆخەکەی ناگۆڕدرێت. دەتوانیت لای بەکارھێنەر بیشاریتەوە.';
    if(o.balance_refunded_at)return 'ئەم مامەڵەیە گەڕاندنەوەی تێدا کراوە و دۆخەکەی ناگۆڕدرێت.';
    if(Number(o.shortfall_refunded_iqd||0)>0)return 'قەرەبووی کەمی نێردراوی تێدا کراوە و دۆخەکەی ناگۆڕدرێت.';
    return '';
  }
  function pad(n){return (n<10?'0':'')+n;}
  function toLocalInput(iso){
    if(!iso)return '';var d=new Date(iso);if(isNaN(d))return '';
    return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate())+'T'+pad(d.getHours())+':'+pad(d.getMinutes());
  }
  function note(cls,html){return '<div class="om-note '+cls+'">'+html+'</div>';}
  function ensureModal(){
    if($('moOrderManual'))return;
    var d=document.createElement('div');d.className='overlay';d.id='moOrderManual';
    d.innerHTML='<div class="modal wide"><div class="modal-hdr"><h3 id="omTitle"></h3><div class="modal-close" onclick="closeMo(\'moOrderManual\')"><i class="fas fa-xmark"></i></div></div><div id="omBody"></div></div>';
    document.body.appendChild(d);
  }

  function buttonsHTML(o){
    var id=E(o.id);
    return '<section class="om-box" id="omBox"><h4><i class="fas fa-sliders"></i> کۆنتڕۆڵی دەستی مامەڵە</h4>'+
      (isHidden(o)?note('warn','<i class="fas fa-eye-slash"></i> ئەم مامەڵەیە لای بەکارھێنەر شاردراوەتەوە ('+E(typeof fmtDateTime==='function'?fmtDateTime(o.user_deleted_at):o.user_deleted_at)+').'):'')+
      '<div class="om-btns">'+
      '<button type="button" class="act-btn cy" onclick="ProxoOrderManual.open(\'status\',\''+id+'\')"><i class="fas fa-shuffle"></i> گۆڕینی دۆخ</button>'+
      '<button type="button" class="act-btn yw" onclick="ProxoOrderManual.open(\'edit\',\''+id+'\')"><i class="fas fa-pen"></i> دەستکاری</button>'+
      (isHidden(o)?'<button type="button" class="act-btn dark" onclick="ProxoOrderManual.restore(\''+id+'\')"><i class="fas fa-eye"></i> پیشاندانەوە بۆ بەکارھێنەر</button>':'')+
      '<button type="button" class="act-btn rd" onclick="ProxoOrderManual.open(\'delete\',\''+id+'\')"><i class="fas fa-trash"></i> سڕینەوە</button>'+
      '</div><p class="om-hint">هیچ ئاگادارکردنەوەیەک بۆ بەکارھێنەر نانێردرێت مەگەر خۆت لە گۆڕینی دۆخدا هەڵیبژێریت.</p>'+
      '<div id="omHistory" class="om-history"></div></section>';
  }

  function open(mode,id){
    var o=find(id);if(!o){showToast('مامەڵەکە نەدۆزرایەوە','rd');return;}
    ensureModal();
    var body=mode==='status'?statusForm(o):mode==='edit'?editForm(o):deleteForm(o);
    $('omTitle').textContent=({status:'گۆڕینی دۆخی ',edit:'دەستکاری ',delete:'سڕینەوەی '})[mode]+fmtCode(orderCodeOf(o));
    $('omBody').innerHTML=body;
    openMo('moOrderManual');
    if(mode==='delete')bindDeleteForm();
  }

  // ── status ──
  function statusForm(o){
    var lock=statusLocked(o);
    var opts=STATUSES.map(function(s){return '<option value="'+E(s)+'"'+(s===o.status?' selected':'')+'>'+E(s)+'</option>';}).join('');
    return (lock?note('warn','<i class="fas fa-lock"></i> '+E(lock)):'')+
      '<label class="modal-lbl">دۆخی نوێ</label><select class="minp" id="omStatus"'+(lock?' disabled':'')+'>'+opts+'</select>'+
      '<label class="modal-lbl">هۆکار / تێبینی</label>'+
      '<textarea class="minp mta" id="omReason" maxlength="500" placeholder="هۆکاری نوێ بنووسە... (دەتوانیت بەتاڵی بهێڵیت)">'+E(o.admin_note||'')+'</textarea>'+
      '<label class="om-check"><input type="checkbox" id="omClear"> لادانی هۆکاری ئێستا (هیچ هۆکارێک نەمێنێت)</label>'+
      '<label class="om-check"><input type="checkbox" id="omNotify"> ئاگادارکردنەوە بنێرە بۆ بەکارھێنەر دەربارەی ئەم گۆڕانکارییە</label>'+
      '<p class="om-hint">ئەگەر نیشانە نەکەیت، بەکارھێنەر هیچ ئاگادارکردنەوەیەک وەرناگرێت.</p>'+
      '<div id="omErr" class="balance-credit-error" role="alert"></div>'+
      '<button type="button" class="modal-btn dark" id="omSubmit" onclick="ProxoOrderManual.saveStatus(\''+E(o.id)+'\')"'+(lock?' disabled':'')+'><i class="fas fa-check"></i> پاشەکەوتکردن</button>';
  }
  function saveStatus(id){
    if(busy)return;var o=find(id);if(!o)return;
    var status=$('omStatus').value,clear=$('omClear').checked,notify=$('omNotify').checked;
    var reason=$('omReason').value.trim();
    if(clear)reason='';
    var payload={order_id:id,status:status,reason:reason,clear_reason:clear,notify:notify};
    var sameReason=clear?!o.admin_note:(reason===(o.admin_note||'')||!reason);
    if(status===o.status&&sameReason){showErr('هیچ گۆڕانکارییەک نەکراوە');return;}
    run('order_set_status',payload,function(res){
      if(res&&res.order)merge(res.order);
      showToast(res&&res.notified?'دۆخ گۆڕدرا و بەکارھێنەر ئاگادارکرایەوە':'دۆخ گۆڕدرا (بێ ئاگادارکردنەوە)','gr');
    },id);
  }

  // ── edit ──
  function methodOptions(cur){
    var keys=[],seen={};
    (typeof allWallets!=='undefined'?allWallets:[]).forEach(function(w){if(w.key&&!seen[w.key]){seen[w.key]=1;keys.push([w.key,w.name||w.key]);}});
    ['USDT','AccountBalance'].forEach(function(k){if(!seen[k]){seen[k]=1;keys.push([k,k==='AccountBalance'?'باڵانسی هەژمار':k]);}});
    if(cur&&!seen[cur])keys.push([cur,cur]);
    return keys.map(function(p){return '<option value="'+E(p[0])+'"'+(p[0]===cur?' selected':'')+'>'+E(p[1])+' ('+E(p[0])+')</option>';}).join('');
  }
  function editForm(o){
    var L=locks(o),lockSet=L.locked;
    var rows=FIELDS.map(function(f){
      var v=o[f.k],dis=lockSet.indexOf(f.k)>=0?' disabled':'',id='omf_'+f.k,input;
      if(f.t==='method')input='<select class="minp" id="'+id+'"'+dis+'>'+methodOptions(v)+'</select>';
      else if(f.t==='area')input='<textarea class="minp mta" id="'+id+'"'+dis+' maxlength="2000">'+E(v||'')+'</textarea>';
      else if(f.t==='date')input='<input class="minp" type="datetime-local" id="'+id+'"'+dis+' value="'+E(toLocalInput(v))+'">';
      else if(f.t==='number')input='<input class="minp" dir="ltr" inputmode="decimal" id="'+id+'"'+dis+' value="'+E(v==null?'':v)+'">';
      else input='<input class="minp"'+(f.ltr?' dir="ltr"':'')+' id="'+id+'"'+dis+' value="'+E(v==null?'':v)+'">';
      return '<div class="om-field'+(f.t==='area'?' full':'')+'"><label class="modal-lbl">'+E(f.l)+'</label>'+input+'</div>';
    }).join('');
    return (L.why?note('warn','<i class="fas fa-lock"></i> '+E(L.why)):'')+
      note('info','<i class="fas fa-circle-info"></i> بڕی لێبڕین خۆکارانە دەژمێردرێت (بڕی نێردراو − بڕی وەرگیراو). تەنها ئەو خانانەی گۆڕاون دەنێردرێن. هیچ ئاگادارکردنەوەیەک نانێردرێت.')+
      '<div class="om-grid">'+rows+'</div>'+
      '<label class="modal-lbl">هۆکاری دەستکاری (بۆ تۆماری ناوخۆ)</label><textarea class="minp mta" id="omReason" maxlength="500" placeholder="بۆ نموونە: ڕاستکردنەوەی بڕ بەپێی وەسڵ"></textarea>'+
      '<div id="omErr" class="balance-credit-error" role="alert"></div>'+
      '<button type="button" class="modal-btn dark" id="omSubmit" onclick="ProxoOrderManual.saveEdit(\''+E(o.id)+'\')"><i class="fas fa-floppy-disk"></i> پاشەکەوتکردنی گۆڕانکارییەکان</button>';
  }
  function saveEdit(id){
    if(busy)return;var o=find(id);if(!o)return;
    var lockSet=locks(o).locked,fields={};
    FIELDS.forEach(function(f){
      if(lockSet.indexOf(f.k)>=0)return;
      var el=$('omf_'+f.k);if(!el)return;
      var raw=el.value.trim(),old=o[f.k];
      if(f.t==='date'){
        var ms=raw?new Date(raw).getTime():null,oms=old?new Date(old).getTime():null;
        if(ms!==null&&isNaN(ms))return;
        if(ms===oms||(ms!==null&&oms!==null&&Math.abs(ms-oms)<60000))return;
        fields[f.k]=raw?new Date(raw).toISOString():null;
      }else if(f.t==='number'){
        if(raw===''){fields[f.k]=null;return;}
        var n=Number(raw.replace(/,/g,''));
        if(!isFinite(n)){showErr(f.l+': ژمارەکە دروست نییە');fields.__bad=1;return;}
        if(n!==Number(old))fields[f.k]=n;
      }else{
        if(raw!==String(old==null?'':old))fields[f.k]=raw===''?null:raw;
      }
    });
    if(fields.__bad)return;
    if(!Object.keys(fields).length){showErr('هیچ گۆڕانکارییەک نەکراوە');return;}
    run('order_update',{order_id:id,fields:fields,reason:$('omReason').value.trim()},function(res){
      if(res&&res.order)merge(res.order);
      showToast('مامەڵەکە دەستکاری کرا (بێ ئاگادارکردنەوە)','gr');
    },id);
  }

  // ── delete ──
  function deleteForm(o){
    var code=orderCodeOf(o),hidden=isHidden(o);
    return note('info','<i class="fas fa-bell-slash"></i> هیچ ئاگادارکردنەوەیەک بۆ بەکارھێنەر نانێردرێت.')+
      '<label class="om-opt"><input type="radio" name="omMode" value="user" '+(hidden?'disabled':'checked')+'> <span><b>شاردنەوە تەنها لای بەکارھێنەر</b><small>لە مێژووی بەکارھێنەر نامێنێت، بەڵام لە پانێڵ و ڕاپۆرتەکان دەمێنێتەوە و دەگەڕێتەوە.</small></span></label>'+
      '<label class="om-opt danger"><input type="radio" name="omMode" value="permanent" '+(hidden?'checked':'')+'> <span><b>سڕینەوەی هەمیشەیی</b><small>مامەڵەکە لە داتابەیس دەسڕێتەوە و ناگەڕێتەوە (کۆپییەکی تۆماری ناوخۆ دەمێنێت). ئەگەر پارەدان، گەڕاندنەوە یان باڵانسی پێوە بەستراو بێت ناسڕدرێتەوە.</small></span></label>'+
      '<label class="modal-lbl">هۆکار (بۆ تۆماری ناوخۆ)</label><textarea class="minp mta" id="omReason" maxlength="500" placeholder="دەتوانیت بەتاڵی بهێڵیت"></textarea>'+
      '<div id="omPermBox" style="display:none"><label class="modal-lbl">بۆ دڵنیابوونەوە کۆدی مامەڵەکە بنووسە: <b dir="ltr">'+E(code)+'</b></label><input class="minp" dir="ltr" id="omConfirmCode" autocomplete="off"></div>'+
      '<div id="omErr" class="balance-credit-error" role="alert"></div>'+
      '<button type="button" class="modal-btn rd" id="omSubmit" onclick="ProxoOrderManual.saveDelete(\''+E(o.id)+'\')"><i class="fas fa-trash"></i> جێبەجێکردن</button>'+
      '';
  }
  function bindDeleteForm(){
    var radios=document.querySelectorAll('input[name="omMode"]');
    function sync(){var m=document.querySelector('input[name="omMode"]:checked');var box=$('omPermBox');if(box)box.style.display=m&&m.value==='permanent'?'block':'none';}
    radios.forEach(function(r){r.addEventListener('change',sync);});sync();
  }
  function saveDelete(id){
    if(busy)return;var o=find(id);if(!o)return;
    var m=document.querySelector('input[name="omMode"]:checked');if(!m){showErr('جۆری سڕینەوە هەڵبژێرە');return;}
    var mode=m.value;
    if(mode==='permanent'&&String($('omConfirmCode').value||'').trim().toUpperCase()!==String(orderCodeOf(o)).toUpperCase()){
      showErr('کۆدی مامەڵەکە بە دروستی بنووسە');return;}
    run('order_delete',{order_id:id,mode:mode,reason:$('omReason').value.trim()},function(){
      if(mode==='permanent'){
        if(typeof allOrders!=='undefined'){var i=allOrders.findIndex(function(x){return String(x.id)===String(id);});if(i>=0)allOrders.splice(i,1);}
        showToast('مامەڵەکە بە تەواوی سڕایەوە','rd');
      }else{
        var x=find(id);if(x){x.user_deleted_at=new Date().toISOString();}
        showToast('مامەڵەکە لای بەکارھێنەر شاردرایەوە','gr');
      }
    },id,mode==='permanent');
  }
  function restore(id){
    var o=find(id);if(!o)return;
    confirm2('پیشاندانەوە بۆ بەکارھێنەر','مامەڵەکە دووبارە لە مێژووی بەکارھێنەر دەردەکەوێتەوە (بێ ئاگادارکردنەوە).','fas fa-eye','#10b981',function(){
      run('order_delete',{order_id:id,mode:'restore'},function(){
        var x=find(id);if(x){x.user_deleted_at=null;x.user_deleted_by=null;}
        showToast('مامەڵەکە بۆ بەکارھێنەر گەڕایەوە','gr');
      },id);
    });
  }

  // ── plumbing ──
  function showErr(t){var e=$('omErr');if(e){e.textContent=t;e.style.display='block';}else showToast(t,'rd');}
  function merge(row){
    if(typeof allOrders==='undefined'||!row)return;
    var i=allOrders.findIndex(function(x){return String(x.id)===String(row.id);});
    if(i>=0)allOrders[i]=Object.assign({},allOrders[i],row);
  }
  async function run(action,payload,onOk,id,gone){
    busy=true;var b=$('omSubmit');if(b)b.disabled=true;var e=$('omErr');if(e)e.style.display='none';
    try{
      var res=await adminApiRequest(action,payload);
      onOk(res);
      closeMo('moOrderManual');
      if(gone){closeMo('moOrderDetail');}
      else if(typeof showOrderDetail==='function'&&find(id)){showOrderDetail(id);}
      if(typeof renderOrders==='function'){renderOrders((($('orderSearch')||{}).value||'').toLowerCase());}
      if(typeof refreshOrdersEverywhere==='function')refreshOrdersEverywhere();
    }catch(err){
      showErr((err&&err.message)||'کردارەکە ئەنجام نەدرا');
      if(b)b.disabled=false;
    }finally{busy=false;}
  }

  function historyLine(r){
    var who=(typeof _profMap!=='undefined'&&_profMap[r.admin_id]&&(_profMap[r.admin_id].full_name||_profMap[r.admin_id].email))||'ئادمین';
    var det='';
    if(r.action==='status'&&r.old_data&&r.new_data){
      det=E(r.old_data.status)+' ← '+E(r.new_data.status)+(r.notified?' · ئاگادارکرایەوە':' · بێ ئاگادارکردنەوە');
    }else if(r.action==='edit'&&r.new_data){
      det=Object.keys(r.new_data).map(function(k){
        var f=FIELDS.filter(function(x){return x.k===k;})[0];
        if(k==='fee')f={l:'لێبڕین'};
        var ov=r.old_data&&r.old_data[k],nv=r.new_data[k];
        return E((f&&f.l)||k)+': '+E(ov==null?'—':String(ov).slice(0,40))+' ← '+E(nv==null?'—':String(nv).slice(0,40));
      }).join(' | ');
    }else if(r.action==='delete')det='سڕایەوە';
    return '<li><b>'+E(ACTION_LABEL[r.action]||r.action)+'</b> <span>'+E(who)+' · '+E(typeof fmtDateTime==='function'?fmtDateTime(r.created_at):r.created_at)+'</span>'+
      (det?'<div dir="auto">'+det+'</div>':'')+(r.reason?'<em>هۆکار: '+E(r.reason)+'</em>':'')+'</li>';
  }
  async function loadHistory(id){
    var box=$('omHistory');if(!box)return;
    try{
      var rows=await adminApiRequest('order_actions_list',{order_id:id});
      box=$('omHistory');if(!box)return;
      box.innerHTML=Array.isArray(rows)&&rows.length?'<h5>مێژووی کردارە دەستییەکان</h5><ul>'+rows.map(historyLine).join('')+'</ul>':'';
    }catch(err){var b2=$('omHistory');if(b2)b2.innerHTML='';}
  }

  window.ProxoOrderManual={buttonsHTML:buttonsHTML,open:open,saveStatus:saveStatus,saveEdit:saveEdit,saveDelete:saveDelete,restore:restore,loadHistory:loadHistory,isHidden:isHidden,_locks:locks,_statusLocked:statusLocked};
})();
