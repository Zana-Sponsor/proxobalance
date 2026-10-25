/* Read-only refund export. Each measured DOM page is rendered as one complete A4 page. */
let _balanceRefundReportBusy=false;
const BALANCE_REFUND_REPORT_MAX_RECORDS=2000;
function balanceRefundReportOwner(){return typeof adminUser!=='undefined'?adminUser?.id:null;}
function balanceRefundReportAllowed(){return !!balanceRefundReportOwner()&&typeof staffCan==='function'&&staffCan('refunds');}
function balanceRefundReportControls(){
  const button=document.getElementById('balanceRefundReportBtn');
  if(button){button.disabled=_balanceRefundReportBusy||!balanceRefundReportAllowed();button.setAttribute('aria-busy',String(_balanceRefundReportBusy));}
  for(const id of ['balanceRefundReportFrom','balanceRefundReportTo']){
    const input=document.getElementById(id);if(input)input.disabled=_balanceRefundReportBusy;
  }
}
function balanceRefundReportStatus(message){
  const el=document.getElementById('balanceRefundReportStatus');if(el)el.textContent=message;
}
function balanceRefundReportCheckOwner(owner){
  if(owner!==balanceRefundReportOwner()||!balanceRefundReportAllowed())throw Error('دەسترسی هەژمار گۆڕاوە؛ بە هەژماری مۆڵەتپێدراو دووبارە ڕاپۆرتەکە دابگرە.');
}
function balanceRefundReportRange(){
  const read=id=>{
    const value=(document.getElementById(id)?.value||'').trim();
    if(!value)return null;
    const parsed=new Date(value+'T00:00:00Z');
    if(!/^\d{4}-\d{2}-\d{2}$/.test(value)||!Number.isFinite(parsed.getTime())||parsed.toISOString().slice(0,10)!==value)
      throw Error('بەروارێکی دروست هەڵبژێرە.');
    return value;
  };
  const from=read('balanceRefundReportFrom'),to=read('balanceRefundReportTo');
  if(from&&to&&from>to)throw Error('بەرواری دەستپێک نابێت دوای بەرواری کۆتایی بێت.');
  return {date_from:from,date_to:to};
}
function balanceRefundReportCorrupt(){return Error('تۆمارەکانی ڕاپۆرت یەک ناگرنەوە یان لە کاتی بارکردندا گۆڕاون؛ دووبارە ڕاپۆرتەکە دابگرە.');}
async function balanceFetchRefundReport(range,owner){
  const report={refunds:[],shortfalls:[],orders:Object.create(null),profiles:Object.create(null),snapshot:null};
  const seen=new Set();let page=0;
  while(true){
    balanceRefundReportCheckOwner(owner);
    if(page>BALANCE_REFUND_REPORT_MAX_RECORDS)throw balanceRefundReportCorrupt();
    const payload={...range,page};if(report.snapshot)payload.snapshot=report.snapshot;
    const data=await adminApiRequest('balance_refund_report',payload);
    balanceRefundReportCheckOwner(owner);
    if(!data||data.page!==page||!Array.isArray(data.refunds)||!Array.isArray(data.shortfalls)||
      typeof data.snapshot!=='string'||!Number.isFinite(new Date(data.snapshot).getTime())||
      new Date(data.snapshot).toISOString()!==data.snapshot||
      (report.snapshot&&report.snapshot!==data.snapshot)||
      !(data.next_page===null||data.next_page===page+1)||data.has_more!==(data.next_page!==null)||
      !data.orders||typeof data.orders!=='object'||Array.isArray(data.orders)||
      !data.profiles||typeof data.profiles!=='object'||Array.isArray(data.profiles))throw balanceRefundReportCorrupt();
    report.snapshot=data.snapshot;
    for(const kind of ['refunds','shortfalls'])for(const row of data[kind]){
      if(!row||typeof row.id!=='string'||!row.id||typeof row.order_id!=='string'||!row.order_id)throw balanceRefundReportCorrupt();
      const key=kind+':'+row.id;
      // An offset shifted by a late commit can hide a row as well as repeat one.
      // Ask for a fresh export instead of silently producing a partial report.
      if(seen.has(key))throw balanceRefundReportCorrupt();
      seen.add(key);report[kind].push(row);
    }
    Object.assign(report.orders,data.orders);Object.assign(report.profiles,data.profiles);
    if(seen.size>BALANCE_REFUND_REPORT_MAX_RECORDS)
      throw Error('تۆمارەکان لە '+BALANCE_REFUND_REPORT_MAX_RECORDS.toLocaleString('en-US')+' زیاترە؛ ماوەیەکی کورتتر هەڵبژێرە و ڕاپۆرتەکە دابگرە.');
    balanceRefundReportStatus('بارکردنی تۆمارەکانی گەڕاندنەوە: '+seen.size.toLocaleString('en-US'));
    if(data.next_page===null)return report;
    if(data.refunds.length+data.shortfalls.length===0)throw balanceRefundReportCorrupt();
    page=data.next_page;
  }
}
function balanceRefundReportRecords(report){
  const name=id=>{const p=report.profiles[id]||{};return String(p.full_name||p.username||id||'تۆمار نەکراوە');};
  const wallet=value=>{
    if(value===null||value===undefined||value===''||!['number','string'].includes(typeof value)||
      (typeof value==='string'&&!/^\d+$/.test(value)))return null;
    const amount=Number(value);return Number.isSafeInteger(amount)&&amount>=0?amount:null;
  };
  const rows=[];const seen=new Set();
  for(const [kind,list] of [['full',report.refunds],['shortfall',report.shortfalls]])for(const row of list){
    const key=kind+':'+row.id;
    if(seen.has(key))throw balanceRefundReportCorrupt();seen.add(key);
    const order=report.orders[row.order_id]||{},amounts=balanceRefundAmounts(row,kind,order);
    if(amounts.credited===null||!Number.isSafeInteger(amounts.credited)||amounts.credited<=0||typeof row.created_at!=='string'||
      !Number.isFinite(new Date(row.created_at).getTime()))throw balanceRefundReportCorrupt();
    const shortfall=kind==='shortfall',automatic=shortfall&&balanceIsAutomaticRefund(row),actor=shortfall?row.admin_id:row.verified_by;
    const storedOrder=shortfall&&row.order_snapshot&&typeof row.order_snapshot==='object'?row.order_snapshot:order;
    const reference=String(shortfall?row.verification_reference||'':row.bank_verification_reference||'');
    rows.push({kind,automatic,id:String(row.id),orderId:String(row.order_id),orderCode:String(row.order_code||order.order_code||row.order_id),
      customerId:String(row.user_id||''),customer:name(row.user_id),phone:String(row.customer_phone||order.phone||''),
      adminId:String(actor||''),admin:name(actor),createdAt:row.created_at,journalId:String(row.journal_id||''),
      reason:String(shortfall?row.reason||'':row.failure_reason||'').replace(/\s+/g,' ').trim(),
      reference:automatic||(shortfall&&reference.toLowerCase()==='shortfall:'+String(row.request_key).toLowerCase())?'':reference,
      fromMethod:String(storedOrder.from_method||order.from_method||''),toMethod:String(storedOrder.to_method||order.to_method||''),
      balanceBefore:shortfall?wallet(row.balance_before_iqd):null,balanceAfter:shortfall?wallet(row.balance_after_iqd):null,
      confirmedFailed:!shortfall&&row.refund_kind==='failed_payout'&&row.confirmed_payout_failed===true,
      ...amounts});
  }
  rows.sort((a,b)=>new Date(b.createdAt)-new Date(a.createdAt)||a.kind.localeCompare(b.kind)||a.id.localeCompare(b.id));
  return rows;
}
function balanceRefundReportMoney(value){return value===null?'تۆمار نەکراوە':Number(value).toLocaleString('en-US')+' د.ع';}
function balanceRefundReportTime(value){
  return new Date(value).toLocaleString('en-GB',{timeZone:'Asia/Baghdad',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'});
}
function balanceRefundReportScope(range){
  if(!range.date_from&&!range.date_to)return 'هەموو مێژووی گەڕاندنەوەکان';
  return (range.date_from?'لە '+range.date_from:'لە سەرەتای مێژوو')+(range.date_to?' تا '+range.date_to:' تا ئێستا');
}
function balanceRefundReportCard(row,index){
  const money=value=>esc(balanceRefundReportMoney(value));
  const metric=(label,value,credit=false)=>'<div'+(credit?' class="balance-refund-pdf-credit"':'')+'><span>'+esc(label)+'</span><strong>'+money(value)+'</strong></div>';
  const explanation=row.automatic?(row.sent===0?
    'بڕی پاش لێبڕین لە ١٬٠٠٠ دینار کەمترە؛ ناردنی دەرەکی نییە و هەمووی بۆ باڵانسی هەژمار گەڕێندراوەتەوە.':
    'بڕی ناردن بۆ هەزاری تەواو دیاری کراوە و پاشماوەکە لە کاتی پەسەندکردندا بە ئۆتۆماتیکی بۆ باڵانسی هەژمار گەڕێندراوەتەوە.'):
    row.kind==='shortfall'?
    'نێردراو هەژمارکراوە: بڕی پاش لێبڕین − کۆی گەڕاوەکان تا ئەم تۆمارە.':
    row.confirmedFailed?'ناردنی پارە بە پشتڕاستکراوی شکستی هێناوە؛ گەڕاوەی ئەم جارە بڕی پارەی وەرگیراوە.':
    'ڕەتکردنەوەکە بڕی نێردراو و نەنێردراو دیاری ناکات؛ ئەم دوو بڕە لەم تۆمارەدا بەردەست نین.';
  return '<article class="balance-refund-pdf-card" data-refund-case="'+esc(row.kind+':'+row.id)+'">'+
    '<div class="balance-refund-pdf-card-head"><div><span class="balance-refund-pdf-kind">'+index+'. '+
      (row.automatic?'گەڕاندنەوەی ئۆتۆماتیکی پاشماوە':row.kind==='shortfall'?'گەڕاندنەوەی بڕی کەم نێردراو':'گەڕاندنەوەی تەواو')+'</span><strong dir="ltr">'+esc(row.orderCode)+'</strong></div>'+
      '<bdi dir="ltr">'+esc(balanceRefundReportTime(row.createdAt))+'</bdi></div>'+
    '<div class="balance-refund-pdf-people"><div>کڕیار: <b>'+esc(row.customer)+'</b>'+(row.phone?' · <bdi dir="ltr">'+esc(row.phone)+'</bdi>':'')+'</div>'+
      '<div>ئادمین: <b>'+esc(row.admin)+'</b></div></div>'+
    '<div class="balance-refund-pdf-metrics">'+metric('بڕی پاش لێبڕین پێش گەڕاندنەوە',row.expected)+
      metric(row.automatic?'بڕی نێردراو (هەزاری تەواو)':row.kind==='shortfall'?'بڕی نێردراو (هەژمارکراو)':'بڕی نێردراو',row.sent)+
      metric(row.kind==='shortfall'?'نەنێردراو تا ئەم تۆمارە':'بڕی نەنێردراو',row.unpaid)+metric('گەڕاوەی ئەم جارە بۆ باڵانس',row.credited,true)+'</div>'+
    (row.fromMethod||row.toMethod?'<p class="balance-refund-pdf-detail">ڕێگای مامەڵە: <bdi>'+esc(row.fromMethod||'—')+'</bdi> ← <bdi>'+esc(row.toMethod||'—')+'</bdi></p>':'')+
    (row.balanceBefore!==null&&row.balanceAfter!==null?'<p class="balance-refund-pdf-detail">باڵانسی پێش گەڕاندنەوە: '+money(row.balanceBefore)+' · باڵانسی دوای گەڕاندنەوە: '+money(row.balanceAfter)+'</p>':'')+
    '<p class="balance-refund-pdf-detail"><b>هۆکار: </b>'+esc(row.reason||'تۆمار نەکراوە')+'</p>'+
    (row.reference?'<p class="balance-refund-pdf-detail">بەڵگەی تۆمارکراو: <bdi>'+esc(row.reference)+'</bdi></p>':'')+
    '<p class="balance-refund-pdf-note">'+esc(explanation)+'</p>'+
    '<div class="balance-refund-pdf-audit"><div>ناسنامەی گەڕاندنەوە: <bdi dir="ltr">'+esc(row.id)+'</bdi></div>'+
      '<div>تۆماری دارایی: <bdi dir="ltr">'+esc(row.journalId||'تۆمار نەکراوە')+'</bdi></div>'+
      '<div>مامەڵە: <bdi dir="ltr">'+esc(row.orderId)+'</bdi></div>'+
      '<div>ئادمین: <bdi dir="ltr">'+esc(row.adminId||'تۆمار نەکراوە')+'</bdi></div></div></article>';
}
function balanceRefundReportPage(source,report,rows,range,page,totalCredit){
  source.innerHTML='<header class="balance-refund-pdf-header"><div class="balance-refund-pdf-heading">'+
    '<h1>ڕاپۆرتی گەڕاندنەوەی پارە</h1><span class="balance-refund-pdf-brand" dir="ltr">Proxo Balance</span></div>'+
    '<p>'+esc(balanceRefundReportScope(range))+' · بەرواری گەڕاندنەوە / کاتی بەغدا</p>'+
    '<p>تۆمارەکان تا: <bdi dir="ltr">'+esc(balanceRefundReportTime(report.snapshot))+'</bdi> · لاپەڕە '+page+'</p></header>'+
    (page===1?'<section class="balance-refund-pdf-summary"><div><span>کۆی تۆمارەکان</span><strong>'+rows.length.toLocaleString('en-US')+'</strong></div>'+
      '<div><span>گەڕاندنەوەی بەشێک لە بڕ</span><strong>'+rows.filter(r=>r.kind==='shortfall').length.toLocaleString('en-US')+'</strong></div>'+
      '<div><span>گەڕاندنەوەی تەواو</span><strong>'+rows.filter(r=>r.kind==='full').length.toLocaleString('en-US')+'</strong></div>'+
      '<div><span>کۆی پارەی گەڕاوە بۆ باڵانس</span><strong>'+esc(balanceRefundReportMoney(totalCredit))+'</strong></div>'+
      '<p class="balance-refund-pdf-summary-note">تۆماری پاشماوەی ئۆتۆماتیکی: '+rows.filter(r=>r.automatic).length.toLocaleString('en-US')+'. کۆی پارە تەنها لە بڕی هەر گەڕاندنەوەیەک پێکهاتووە؛ بڕە کۆکراوەکانی هەمان مامەڵە دووبارە کۆ ناکرێنەوە.</p></section>':'')+
    '<div class="balance-refund-pdf-records"></div><footer class="balance-refund-pdf-footer">وردەکاریی هەر گەڕاندنەوەیەک بە جیا تۆمار کراوە.</footer>';
  return source.querySelector('.balance-refund-pdf-records');
}
async function balanceCreateRefundPdf(report,rows,range,owner){
  let totalCredit=0;for(const row of rows){totalCredit+=row.credited;if(!Number.isSafeInteger(totalCredit))throw balanceRefundReportCorrupt();}
  const source=document.createElement('div');source.className='balance-refund-pdf';source.dir='rtl';source.lang='ku';
  document.body.appendChild(source);
  try{
    if(document.fonts)await document.fonts.ready;
    const pdf=new window.jspdf.jsPDF({unit:'mm',format:'a4',compress:true});
    let page=1,captured=0,container=balanceRefundReportPage(source,report,rows,range,page,totalCredit);
    const fits=()=>container.scrollHeight<=container.clientHeight+1;
    const capture=async()=>{
      balanceRefundReportCheckOwner(owner);balanceRefundReportStatus('دروستکردنی PDF — لاپەڕە '+page);
      const canvas=await window.html2canvas(source,{backgroundColor:'#ffffff',scale:2,useCORS:true,logging:false,windowWidth:1200,windowHeight:1200});
      balanceRefundReportCheckOwner(owner);
      if(captured++)pdf.addPage();
      pdf.addImage(canvas.toDataURL('image/jpeg',.94),'JPEG',0,0,210,297);
      canvas.width=1;canvas.height=1;
    };
    for(let i=0;i<rows.length;i++){
      const holder=document.createElement('div');holder.innerHTML=balanceRefundReportCard(rows[i],i+1);
      const card=holder.firstElementChild;container.appendChild(card);
      if(!fits()){
        card.remove();
        if(!container.children.length&&page!==1)throw Error('وردەکاریی مامەڵەی '+rows[i].orderCode+' لە یەک پەڕەدا جێ نابێتەوە؛ ڕاپۆرتەکە دروست نەکرا.');
        await capture();page++;
        container=balanceRefundReportPage(source,report,rows,range,page,totalCredit);container.appendChild(card);
        if(!fits())throw Error('وردەکاریی مامەڵەی '+rows[i].orderCode+' لە یەک پەڕەدا جێ نابێتەوە؛ ڕاپۆرتەکە دروست نەکرا.');
      }
    }
    await capture();
    for(let number=1;number<=captured;number++){
      pdf.setPage(number);pdf.setFont('helvetica','normal');pdf.setFontSize(8);pdf.setTextColor(100,116,139);
      pdf.text('Proxo Balance  |  '+number+' / '+captured,105,293,{align:'center'});
    }
    balanceRefundReportCheckOwner(owner);
    const name='Proxo-Balance-refunds-'+(range.date_from||'all')+'-'+(range.date_to||report.snapshot.slice(0,10))+'.pdf';
    await pdf.save(name,{returnPromise:true});return captured;
  }finally{source.remove();}
}
async function exportBalanceRefundPdf(){
  if(_balanceRefundReportBusy)return;
  const error=document.getElementById('balanceRefundReportError');if(error)error.textContent='';
  balanceRefundReportStatus('');
  if(!balanceRefundReportAllowed()){if(error)error.textContent='مۆڵەتی داگرتنی ڕاپۆرتی گەڕاندنەوەی پارەت نییە.';return;}
  if(!window.html2canvas||!window.jspdf?.jsPDF){if(error)error.textContent='کتێبخانەی PDF بار نەبووە؛ پەڕەکە نوێ بکەرەوە و دووبارە هەوڵ بدە.';return;}
  let range;try{range=balanceRefundReportRange();}catch(e){if(error)error.textContent=e.message;return;}
  const owner=balanceRefundReportOwner();_balanceRefundReportBusy=true;balanceRefundReportControls();
  try{
    const report=await balanceFetchRefundReport(range,owner),rows=balanceRefundReportRecords(report);
    if(!rows.length){balanceRefundReportStatus('هیچ گەڕاندنەوەیەک لەم ماوەیەدا تۆمار نەکراوە.');return;}
    const pages=await balanceCreateRefundPdf(report,rows,range,owner);
    balanceRefundReportStatus('PDF ئامادەکرا: '+rows.length.toLocaleString('en-US')+' تۆمار لە '+pages.toLocaleString('en-US')+' پەڕەدا.');
    if(typeof showToast==='function')showToast('ڕاپۆرتی گەڕاندنەوەکان داگیرا','gr');
  }catch(e){balanceRefundReportStatus('');if(error)error.textContent=e.message||'ڕاپۆرتەکە دروست نەکرا؛ دووبارە هەوڵ بدە.';}
  finally{_balanceRefundReportBusy=false;balanceRefundReportControls();}
}
for(const id of ['balanceRefundReportFrom','balanceRefundReportTo'])document.getElementById(id)?.addEventListener('change',()=>{
  if(_balanceRefundReportBusy)return;balanceRefundReportStatus('');
  const error=document.getElementById('balanceRefundReportError');if(error)error.textContent='';
});
if(typeof pageConfig!=='undefined'&&pageConfig.balance){
  const originalBalanceRefundReportLoad=pageConfig.balance.load;
  pageConfig.balance.load=function(){balanceRefundReportControls();return originalBalanceRefundReportLoad?.();};
}
