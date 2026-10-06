/* Proxo Balance — true deduction from approved IQD exchange orders.
   Historical fees use the original saved fee in Supabase, with the handling admin. */
'use strict';
let _profitData=null,_profitLoadId=0;
function profitAdminName(o){return String(o?.handling_admin_name||'').trim()||'نەدیاریکراو';}
function profitScope(d){if(d.report_unassigned)return 'مامەڵەکانی بێ ئادمینی دیاریکراو';if(d.report_admin_id)return 'قازانجی لێبڕینی ئادمین: '+profitAdminName({handling_admin_name:d.report_admin_name});return d.scope==='all'?'قازانجی لێبڕینی هەموو ئادمینەکان':'قازانجی لێبڕینی مامەڵەکانی خۆت';}
function profitEsc(v){return String(v==null?'':v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));}
function profitNum(v,d=0){if(v==null||!Number.isFinite(Number(v)))return '—';return Number(v).toLocaleString('en-US',{minimumFractionDigits:d,maximumFractionDigits:d});}
function profitMoney(v){return v==null?'—':profitNum(v,2)+' د.ع';}
function profitMethod(m){return typeof exMethod==='function'?exMethod(m):m||'—';}
function profitTime(v){return typeof exDate==='function'?exDate(v):v||'—';}
function profitCard(label,value,icon,note=''){return '<article class="ex-card proxo-profit-card"><div class="ex-label"><i class="fas '+icon+'"></i> '+label+'</div><div class="ex-value" dir="ltr">'+value+'</div>'+(note?'<div class="profit-help">'+note+'</div>':'')+'</article>';}
function profitShowMessage(msg){const el=document.getElementById('profitMessage');if(el){el.hidden=false;el.textContent=msg;}}
function profitSetAdminFilter(choices,selected,scope){
  const wrap=document.getElementById('profitAdminFilter'),el=document.getElementById('profitAdmin');if(!el)return;
  if(wrap)wrap.hidden=scope!=='all';
  const admins=scope==='all'?choices:[];
  el.innerHTML='<option value="">هەموو ئادمینەکان</option>'+admins.map(a=>'<option value="'+profitEsc(a.handled_by||'unassigned')+'">'+profitEsc(profitAdminName(a))+'</option>').join('');
  el.value=scope==='all'?selected:'';
}
async function profitFetch(limit,selected=''){
  const from=document.getElementById('profitFrom')?.value||null,to=document.getElementById('profitTo')?.value||null;
  if(from&&to&&from>to)throw Error('ڕێکەوتی دەستپێک دەبێت پێش ڕێکەوتی کۆتایی بێت.');
  const {data:global,error}=await sb.rpc('ex_admin_deduction_stats',{p_from:from,p_to:to,p_limit:selected?1:limit});
  if(error)throw error;
  const choices=[...(global.by_admin||[])];
  if(global.scope!=='all'||!selected)return {data:global,choices,selected:''};
  const {data,error:filterError}=await sb.rpc('ex_admin_deduction_stats_filtered',{p_from:from,p_to:to,p_limit:limit,p_admin_id:selected==='unassigned'?null:selected,p_unassigned:selected==='unassigned'});
  if(filterError)throw filterError;
  if(!choices.some(x=>(x.handled_by||'unassigned')===selected))choices.push({handled_by:data.report_admin_id,handling_admin_name:data.report_admin_name});
  return {data,choices,selected};
}
async function loadProfitStats(){
  const loadId=++_profitLoadId,selected=document.getElementById('profitAdmin')?.value||'';
  _profitData=null;
  const wrap=document.getElementById('profitOrders');
  if(wrap)wrap.innerHTML='<div class="ex-note">ئاماری لێبڕین بار دەکرێت...</div>';
  try{
    const result=await profitFetch(500,selected);if(loadId!==_profitLoadId)return;
    const {data,choices}=result;_profitData=data;
    profitSetAdminFilter(choices,result.selected,data.scope);
    const msg=document.getElementById('profitMessage');if(msg)msg.hidden=true;
    renderProfitStats(data);
    const stamp=document.getElementById('profitStamp');
    if(stamp)stamp.textContent='دوایین نوێکردنەوە: '+profitTime(new Date());
  }catch(e){if(loadId!==_profitLoadId)return;if(wrap)wrap.innerHTML='<div class="ex-note" role="alert">'+profitEsc(e.message)+'</div>';profitShowMessage('هەڵە لە بارکردنی ئامار: '+e.message);}
}
function renderProfitStats(d){
  const scope=document.getElementById('profitScope');if(scope)scope.textContent=profitScope(d);
  const admins=document.getElementById('profitAdminSummary');
  if(admins){admins.hidden=d.scope!=='all';admins.innerHTML=d.scope==='all'?'<div class="ex-title">قازانج بەپێی ئادمین</div><div class="ex-grid">'+(d.by_admin||[]).map(x=>'<article class="ex-card"><div class="ex-label"><bdi>'+profitEsc(profitAdminName(x))+'</bdi></div><div class="ex-value" dir="ltr">'+(Number(x.recorded_orders)?profitMoney(x.deduction_iqd):'—')+'</div><div class="profit-help">'+profitNum(x.approved_orders)+' مامەڵە</div></article>').join('')+'</div>':'';}
  const approved=Number(d.approved_orders)||0,recorded=Number(d.recorded_orders)||0,missing=Number(d.unrecorded_orders)||0;
  const main=document.getElementById('profitOverview');
  if(main)main.innerHTML=
    profitCard('کۆی لێبڕینی مامەڵەکان',recorded?profitMoney(d.total_deduction_iqd):'—','fa-coins','تەنها مامەڵە پەسەندکراوەکان')+
    profitCard('لێبڕینی ئەمڕۆ',recorded?profitMoney(d.today_deduction_iqd):'—','fa-calendar-day','بەپێی کاتی بەغدا')+
    profitCard('لێبڕینی ئەم مانگە',recorded?profitMoney(d.month_deduction_iqd):'—','fa-chart-line')+
    profitCard('ناوەندی لێبڕین',recorded?profitMoney(d.avg_deduction_iqd):'—','fa-percent','بۆ هەر مامەڵەی تۆمارکراو')+
    profitCard('مامەڵە پەسەندکراوەکان',profitNum(approved),'fa-circle-check')+
    profitCard('مامەڵەی بێ لێبڕینی تۆمارکراو',profitNum(missing),'fa-clock');
  const groups=document.getElementById('profitMethods');
  if(groups)groups.innerHTML=(d.by_method||[]).length?(d.by_method||[]).map(x=>
    '<article class="ex-card proxo-profit-card"><div class="ex-label">'+profitEsc(profitMethod(x.method))+'</div>'+
    '<div class="ex-value" dir="ltr">'+(Number(x.recorded_orders)?profitMoney(x.deduction_iqd):'—')+'</div>'+
    '<div class="profit-help">'+profitNum(x.recorded_orders)+' لە '+profitNum(x.approved_orders)+' مامەڵە</div></article>').join(''):'<div class="ex-note">لەو ماوەیەدا مامەڵەی پەسەندکراو نییە.</div>';
  const notice=document.getElementById('profitNotice');
  if(notice)notice.textContent=missing?
    profitNum(missing)+' مامەڵە لێبڕینی دیاریکراویان نییە (بۆ نموونە گۆڕینی دراوی جیاواز). لە کۆی دیناردا تێکەڵ ناکرێن.':
    'لێبڕین لە بڕی تۆمارکراوی هەر مامەڵەی پەسەندکراو هەژمار کراوە؛ نرخەکانی ئێستا بەکارنەهاتوون.';
  const rows=d.orders||[],counter=document.getElementById('profitCount'),wrap=document.getElementById('profitOrders');
  if(counter)counter.textContent=profitNum(rows.length)+' لە '+profitNum(approved)+' مامەڵە';
  if(!wrap)return;
  wrap.innerHTML=rows.length?rows.map(o=>
    '<article class="profit-order"><div class="profit-order-head"><div><div class="profit-order-title">'+profitEsc(profitMethod(o.from_method))+' ← '+profitEsc(profitMethod(o.to_method))+'</div>'+
    '<div class="profit-order-id" dir="ltr">'+profitEsc(o.order_code||'—')+'</div></div>'+
    '<span class="profit-chip '+(o.deduction_iqd==null?'missing':'recorded')+'">'+(o.deduction_iqd==null?'بەردەست نییە':'پەسەندکراو')+'</span></div>'+
    '<div class="profit-order-summary"><div><div class="ex-label">بڕی نێردراو</div><b dir="ltr">'+profitNum(o.amount,2)+'</b></div>'+
    '<div><div class="ex-label">بڕی وەرگیراو</div><b dir="ltr">'+profitNum(o.total,2)+'</b></div>'+
    '<div><div class="ex-label">لێبڕین</div><b class="profit-net" dir="ltr">'+profitMoney(o.deduction_iqd)+'</b></div></div>'+
    '<div class="profit-date">ئادمین: <bdi>'+profitEsc(profitAdminName(o))+'</bdi> · '+profitEsc(profitTime(o.accounted_at))+'</div></article>').join('')+
    (approved>rows.length?'<div class="ex-note">500 مامەڵەی دوایین نیشاندەدرێن. بۆ ماوەی دیاریکراو پاڵاوتنی ڕێکەوت بەکاربهێنە.</div>':''):
    '<div class="ex-note">هیچ مامەڵەیەک لەم ماوەیەدا نییە.</div>';
}
function profitExport(kind){
  if(!_profitData||String(_profitData.report_admin_id||(_profitData.report_unassigned?'unassigned':''))!==(document.getElementById('profitAdmin')?.value||''))return showToast('سەرەتا ئاماری لێبڕین باربکە','rd');
  const d=_profitData,rows=d.orders||[];
  if(!rows.length)return showToast('هیچ مامەڵەیەک بۆ داگرتن نییە','rd');
  const fields=[['order_code','Order'],['from_method','From'],['to_method','To'],['amount','Sent'],['total','Received'],['deduction_iqd','Deduction IQD'],['accounted_at','Date'],['handling_admin_name','ناوی ئادمین']];
  const safe=v=>{const x=String(v==null?'':v);return /^[=+\-@\t\r]/.test(x)?"'"+x:x};
  const table=[fields.map(x=>x[1]),...rows.map(o=>fields.map(([k])=>safe(k==='handling_admin_name'?profitAdminName(o):o[k])))];
  const filename='Proxo-Balance-deductions-'+(d.report_admin_id?profitAdminName({handling_admin_name:d.report_admin_name}).replace(/[\\/:*?"<>|\x00-\x1f]/g,'_').slice(0,80)+'-':d.report_unassigned?'unassigned-':'')+new Date().toISOString().slice(0,10);
  if(kind==='csv'){
    const quote=x=>'"'+safe(x).replace(/"/g,'""')+'"';
    exDownload('\ufeff'+table.map(r=>r.map(quote).join(',')).join('\r\n'),filename+'.csv','text/csv;charset=utf-8');
    return;
  }
  if(kind==='xlsx'){
    if(!window.XLSX)return showToast('Excel بار نەبووە','rd');
    const workbook=XLSX.utils.book_new(),sheet=XLSX.utils.aoa_to_sheet(table);
    sheet['!cols']=fields.map(x=>({wch:x[0]==='handling_admin_name'?28:x[0]==='order_code'?25:19}));
    XLSX.utils.book_append_sheet(workbook,sheet,'Deductions');XLSX.writeFile(workbook,filename+'.xlsx');return;
  }
  if(kind==='pdf')profitExportPdf(filename);
}
async function profitExportPdf(name){
  if(!window.jspdf?.jsPDF||!window.html2canvas)return showToast('PDF بار نەبووە','rd');
  const d=_profitData,source=document.createElement('div');source.className='ex-pdf-source';source.dir='rtl';
  source.innerHTML='<div class="ex-head"><h3>ڕاپۆرتی لێبڕین</h3><div class="ex-logo">Proxo</div></div>'+
    '<div class="ex-note">'+profitEsc(profitScope(d))+'</div><div class="ex-title">پوختەی لێبڕین</div><div class="ex-grid">'+
    profitCard('کۆی لێبڕین',profitMoney(d.total_deduction_iqd),'fa-coins')+
    profitCard('مامەڵەی پەسەندکراو',profitNum(d.approved_orders),'fa-circle-check')+
    profitCard('لێبڕینی ئەمڕۆ',profitMoney(d.today_deduction_iqd),'fa-calendar-day')+
    profitCard('لێبڕینی ئەم مانگە',profitMoney(d.month_deduction_iqd),'fa-chart-line')+'</div>'+
    '<div class="ex-title">لێبڕین بەپێی ڕێگا</div><table><thead><tr><th>ڕێگا</th><th>مامەڵەکان</th><th>لێبڕین (IQD)</th></tr></thead><tbody>'+
    (d.by_method||[]).map(x=>'<tr><td>'+profitEsc(profitMethod(x.method))+'</td><td>'+profitNum(x.recorded_orders)+'</td><td>'+profitMoney(x.deduction_iqd)+'</td></tr>').join('')+'</tbody></table>'+
    (d.scope==='all'?'<div class="ex-title">قازانج بەپێی ئادمین</div><table><thead><tr><th>ناوی ئادمین</th><th>مامەڵەکان</th><th>لێبڕین (IQD)</th></tr></thead><tbody>'+
      (d.by_admin||[]).map(x=>'<tr><td>'+profitEsc(profitAdminName(x))+'</td><td>'+profitNum(x.approved_orders)+'</td><td>'+(Number(x.recorded_orders)?profitMoney(x.deduction_iqd):'—')+'</td></tr>').join('')+'</tbody></table>':'')+
    '<div class="ex-title">دوایین مامەڵەکان (تا 20)</div><table><thead><tr><th>ئایدی</th><th>نێردراو</th><th>وەرگیراو</th><th>لێبڕین</th><th>ناوی ئادمین</th></tr></thead><tbody>'+
    (d.orders||[]).slice(0,20).map(x=>'<tr><td dir="ltr">'+profitEsc(x.order_code||'—')+'</td><td>'+profitNum(x.amount)+'</td><td>'+profitNum(x.total)+'</td><td>'+profitMoney(x.deduction_iqd)+'</td><td>'+profitEsc(profitAdminName(x))+'</td></tr>').join('')+'</tbody></table>'+
    '<div class="ex-note">ئەم PDFـە پوختە و 20 مامەڵەی دوایین دەگرێتەوە؛ CSV / Excel بۆ داتای وردەکاری بەکاربهێنە.</div>';
  document.body.appendChild(source);
  try{
    if(document.fonts)await document.fonts.ready;
    const canvas=await html2canvas(source,{backgroundColor:'#fff',scale:2,useCORS:true,logging:false,windowWidth:850});
    const pdf=new window.jspdf.jsPDF({unit:'mm',format:'a4',compress:true}),margin=10,w=190,h=canvas.height*w/canvas.width,page=277,img=canvas.toDataURL('image/jpeg',.93);
    for(let offset=0;offset<h;offset+=page){if(offset)pdf.addPage();pdf.addImage(img,'JPEG',margin,margin-offset,w,h);}
    pdf.save(name+'.pdf');
  }catch(e){console.error(e);showToast('دروستکردنی PDF سەرکەوتوو نەبوو','rd');}
  finally{source.remove();}
}
async function loadProfitQuick(){
  const el=document.getElementById('profitDashSummary');if(!el)return;
  try{
    const {data,error}=await sb.rpc('ex_admin_deduction_stats',{p_from:null,p_to:null,p_limit:1});
    if(error)throw error;const has=Number(data.recorded_orders)>0;
    el.innerHTML=profitCard('کۆی لێبڕین',has?profitMoney(data.total_deduction_iqd):'—','fa-coins')+
      profitCard('لێبڕینی ئەمڕۆ',has?profitMoney(data.today_deduction_iqd):'—','fa-calendar-day')+
      profitCard('لێبڕینی ئەم مانگە',has?profitMoney(data.month_deduction_iqd):'—','fa-chart-line')+
      profitCard('مامەڵە پەسەندکراوەکان',profitNum(data.approved_orders),'fa-circle-check');
  }catch(e){el.innerHTML='<div class="ex-note" role="status">'+profitEsc(e.message)+'</div>';}
}
pageConfig.profit={title:'ئاماری لێبڕین',sub:'لێبڕینی مامەڵە پەسەندکراوەکان لە دیناری عێراقی',load:()=>loadProfitStats()};
const originalProfitDashboardLoad=pageConfig.dashboard.load;
pageConfig.dashboard.load=()=>{if(originalProfitDashboardLoad)originalProfitDashboardLoad();loadProfitQuick();};

