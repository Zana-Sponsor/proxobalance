/* Proxo Balance — verified profit ledger (IQD), authenticated Exchange admin only.
   Historical fee fields are not used as profit. All writes go through admin-guarded RPCs. */
'use strict';
let _profitData=null,_profitSaving=new Set();
function profitEsc(value){return String(value==null?'':value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));}
function profitNum(v,places=0){if(v==null||v==='')return '—';const n=Number(v);return Number.isFinite(n)?n.toLocaleString('en-US',{minimumFractionDigits:places,maximumFractionDigits:places}):'—';}
function profitMoney(v){return v==null?'—':profitNum(v,2)+' د.ع';}
function profitMethod(k){return typeof exMethod==='function'?exMethod(k):k||'—';}
function profitTime(v){return typeof exDate==='function'?exDate(v):v||'—';}
function profitCard(label,value,icon,note=''){return '<article class="ex-card proxo-profit-card"><div class="ex-label"><i class="fas '+icon+'" aria-hidden="true"></i> '+label+'</div><div class="ex-value">'+value+'</div>'+(note?'<div class="profit-help">'+note+'</div>':'')+'</article>';}
function profitShowMessage(message,ok){const el=document.getElementById('profitMessage');if(!el)return;el.hidden=false;el.classList.toggle('error',!ok);el.textContent=message;}
async function loadProfitStats(){
  const area=document.getElementById('profitOrders');if(area)area.innerHTML='<div class="ex-note"><i class="fas fa-circle-notch fa-spin"></i> بارکردنی قازانج...</div>';
  const from=document.getElementById('profitFrom')?.value||null,to=document.getElementById('profitTo')?.value||null;
  if(from&&to&&from>to){profitShowMessage('ڕێکەوتی دەستپێک دەبێت پێش ڕێکەوتی کۆتایی بێت.',false);return}
  try{
    const {data,error}=await sb.rpc('ex_admin_profit_stats',{p_from:from,p_to:to,p_limit:500});
    if(error)throw error;
    _profitData=data;const msg=document.getElementById('profitMessage');if(msg)msg.hidden=true;
    renderProfitStats(data);
    const stamp=document.getElementById('profitStamp');if(stamp)stamp.textContent='دوایین نوێکردنەوە: '+profitTime(new Date());
  }catch(e){
    if(area)area.innerHTML='<div class="ex-note" role="alert">هەڵە لە بارکردنی ئاماری قازانج: '+profitEsc(e.message)+'</div>';
    profitShowMessage('بارکردنی قازانج سەرکەوتوو نەبوو: '+e.message,false);
  }
}
function renderProfitStats(data){
  const approved=Number(data.approved_orders)||0,recorded=Number(data.recorded_orders)||0,missing=Number(data.unrecorded_orders)||0;
  const hasRecord=recorded>0,sums=(key)=>hasRecord?profitMoney(data[key]):'—';
  const overview=document.getElementById('profitOverview');
  if(overview)overview.innerHTML=
    profitCard('قازانجی تۆمارکراو',sums('total_profit_iqd'),'fa-chart-line','داهات − تێچوو')+
    profitCard('قازانجی ئەمڕۆ',sums('today_profit_iqd'),'fa-calendar-day','بەپێی کاتی بەغدا')+
    profitCard('قازانجی ئەم مانگە',sums('month_profit_iqd'),'fa-calendar','بەپێی کاتی بەغدا')+
    profitCard('ناوەندی قازانج',hasRecord?profitMoney(data.avg_profit_iqd):'—','fa-coins','بۆ هەر مامەڵەی تۆمارکراو')+
    profitCard('کۆی داهات',sums('gross_income_iqd'),'fa-wallet','تەنها داهاتی تۆمارکراو')+
    profitCard('کۆی تێچوو',sums('operating_cost_iqd'),'fa-money-bill-transfer','تەنها تێچووی تۆمارکراو')+
    profitCard('مامەڵە پەسەندکراوەکان',profitNum(approved),'fa-circle-check')+
    profitCard('بێ تۆماری قازانج',profitNum(missing),'fa-clock','تۆمارکراو: '+profitNum(recorded));
  const byMethod=document.getElementById('profitMethods');const groups=data.profit_by_method||[];
  if(byMethod)byMethod.innerHTML=groups.length?groups.map(row=>'<article class="ex-card proxo-profit-card"><div class="ex-label">'+profitEsc(profitMethod(row.method))+'</div>'+
    '<div class="ex-value">'+(Number(row.recorded_orders)>0?profitMoney(row.total_profit_iqd):'—')+'</div>'+
    '<div class="profit-help">'+profitNum(row.recorded_orders)+' تۆمارکراو / '+profitNum(row.approved_orders)+' پەسەندکراو</div></article>').join(''):'<div class="ex-note">مامەڵەی پەسەندکراو لەم ماوەیەدا نییە.</div>';
  const notice=document.getElementById('profitNotice');if(notice)notice.textContent=
    missing?'تێبینی: '+profitNum(missing)+' مامەڵەی پەسەندکراو هێشتا قازانجی تۆمار نەکراوە. بڕی نیشاندراو تەنها کۆی تۆمارە پڕکراوەکانە و ناتوانرێت وەک قازانجی تەواوی بازرگانی دابنرێت.':
      'هەموو مامەڵە پەسەندکراوەکان لەم ماوەیەدا تۆماری قازانجیان هەیە.';
  const rows=data.orders||[],wrap=document.getElementById('profitOrders'),count=document.getElementById('profitCount');
  if(count)count.textContent=profitNum(rows.length)+' نیشاندراو لە '+profitNum(approved)+' پەسەندکراو';
  if(!wrap)return;if(!rows.length){wrap.innerHTML='<div class="ex-note">هیچ مامەڵەی پەسەندکراو نییە.</div>';return}
  wrap.innerHTML=rows.map(row=>{
    const id=profitEsc(row.id),code=profitEsc(row.order_code||row.order_number||row.id),done=row.net_profit_iqd!=null;
    return '<article class="profit-order" data-profit-id="'+id+'"><div class="profit-order-head"><div><div class="profit-order-title">'+
      profitEsc(profitMethod(row.from_method))+' ← '+profitEsc(profitMethod(row.to_method))+'</div><div class="profit-order-id" dir="ltr">'+code+
      '</div></div><span class="profit-chip '+(done?'recorded':'missing')+'">'+(done?'تۆمارکراو':'تۆمار نەکراوە')+'</span></div>'+
      '<div class="profit-order-summary"><div><div class="ex-label">بڕی نێردراو</div><b>'+profitNum(row.amount,2)+'</b></div>'+
      '<div><div class="ex-label">وەرگیراو</div><b>'+profitNum(row.total,2)+'</b></div>'+
      '<div><div class="ex-label">قازانجی پاک</div><b class="profit-net">'+(done?profitMoney(row.net_profit_iqd):'—')+'</b></div></div>'+
      '<form class="profit-edit" data-profit-form="'+id+'"><label>داهاتی ئەم مامەڵەیە (IQD)<input required type="number" inputmode="decimal" step=".01" min="0" max="999999999999999" name="income" value="'+(row.gross_income_iqd==null?'':profitEsc(row.gross_income_iqd))+'" placeholder="بڕی داهات" dir="ltr"></label>'+
      '<label>تێچووی ئەم مامەڵەیە (IQD)<input required type="number" inputmode="decimal" step=".01" min="0" max="999999999999999" name="cost" value="'+(row.operating_cost_iqd==null?'0':profitEsc(row.operating_cost_iqd))+'" placeholder="0" dir="ltr"></label>'+
      '<label class="profit-note-field">تێبینی (ئارەزوومەندانە)<input type="text" name="note" maxlength="500" value="'+profitEsc(row.note||'')+'" placeholder="سەرچاوەی داهات و تێچوو"></label>'+
      '<button type="submit" class="ex-btn primary" '+(done?'aria-label="نوێکردنەوەی قازانجی مامەڵە"':'')+'><i class="fas fa-floppy-disk"></i> '+(done?'نوێکردنەوە':'پاشەکەوتکردن')+'</button></form>'+
      '<div class="profit-date">ڕێکەوتی مامەڵە: '+profitEsc(profitTime(row.accounted_at))+'</div></article>';
  }).join('')+(approved>rows.length?'<div class="ex-note">تەنها 500 مامەڵە نیشاندەدرێت؛ بۆ مەودایەکی دیاریکراو ڕێکەوتەکان بەکاربهێنە.</div>':'');
}
document.addEventListener('submit',async e=>{
  const form=e.target.closest('[data-profit-form]');if(!form)return;e.preventDefault();
  const id=form.dataset.profitForm;
  if(_profitSaving.has(id))return;
  const income=form.elements.income.value.trim(),cost=form.elements.cost.value.trim(),note=form.elements.note.value.trim();
  if(income===''||cost===''||![income,cost].every(x=>Number.isFinite(Number(x))&&Number(x)>=0&&Number(x)<=999999999999999)){
    profitShowMessage('داهات و تێچووی دروست بە دینار بنووسە.',false);return;
  }
  const button=form.querySelector('button[type=submit]');_profitSaving.add(id);button.disabled=true;
  try{
    const {error}=await sb.rpc('ex_admin_save_order_profit',{
      p_order_id:id,p_gross_income_iqd:Number(income),p_operating_cost_iqd:Number(cost),p_note:note||null
    });
    if(error)throw error;
    showToast('قازانجی مامەڵە پاشەکەوتکرا','gr');await loadProfitStats();
  }catch(err){profitShowMessage('هەڵە لە پاشەکەوتکردن: '+err.message,false);
    button.disabled=false;
  }finally{_profitSaving.delete(id)}
});
function profitExcelSafe(v){const s=String(v==null?'':v);return /^[=+\-@\t\r]/.test(s)?"'"+s:s}
function profitCsv(v){return '"'+profitExcelSafe(v).replace(/"/g,'""')+'"'}
function profitExport(format){
  if(!_profitData)return showToast('سەرەتا ئامارەکانی قازانج باربکە','rd');
  const rows=_profitData.orders||[];if(!rows.length)return showToast('داتایەک نییە بۆ داگرتن','rd');
  const columns=[['order_code','Order'],['from_method','From'],['to_method','To'],['amount','Amount sent'],['total','Amount received'],
    ['gross_income_iqd','Income IQD'],['operating_cost_iqd','Cost IQD'],['net_profit_iqd','Net profit IQD'],['accounted_at','Date']];
  const table=[columns.map(x=>x[1]),...rows.map(o=>columns.map(([k])=>o[k]??''))];
  const name='Proxo-Balance-profit-'+new Date().toISOString().slice(0,10);
  if(format==='csv'){
    const content='\ufeff'+table.map(r=>r.map(profitCsv).join(',')).join('\r\n');
    if(typeof exDownload==='function')exDownload(content,name+'.csv','text/csv;charset=utf-8;');
    else{const blob=new Blob([content],{type:'text/csv;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=name+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1200)}
    return showToast('CSV دابەزێنرا','gr');
  }
  if(format==='xlsx'){
    if(typeof XLSX==='undefined')return showToast('کتێبخانەی Excel بار نەبووە','rd');
    const wb=XLSX.utils.book_new(),sheet=XLSX.utils.aoa_to_sheet(table.map(r=>r.map(profitExcelSafe)));
    sheet['!cols']=columns.map(c=>({wch:c[0]==='order_code'?23:19}));
    XLSX.utils.book_append_sheet(wb,sheet,'Verified profit');XLSX.writeFile(wb,name+'.xlsx');
    return showToast('Excel دابەزێنرا','gr');
  }
  if(format==='pdf')profitExportPdf(name);
}
async function profitExportPdf(name){
  if(!window.jspdf?.jsPDF||!window.html2canvas)return showToast('کتێبخانەی PDF بار نەبووە','rd');
  const d=_profitData,source=document.createElement('div');source.className='ex-pdf-source';source.dir='rtl';
  const fields=[['قازانجی تۆمارکراو',d.recorded_orders?profitMoney(d.total_profit_iqd):'—'],
    ['کۆی داهات',d.recorded_orders?profitMoney(d.gross_income_iqd):'—'],
    ['کۆی تێچوو',d.recorded_orders?profitMoney(d.operating_cost_iqd):'—'],
    ['مامەڵەی بێ تۆمار',profitNum(d.unrecorded_orders)]];
  const groups=(d.profit_by_method||[]).map(r=>'<tr><td>'+profitEsc(profitMethod(r.method))+'</td><td>'+profitNum(r.recorded_orders)+'</td><td>'+profitMoney(r.total_profit_iqd)+'</td></tr>').join('');
  const latest=(d.orders||[]).filter(o=>o.net_profit_iqd!=null).slice(0,20);
  source.innerHTML='<div class="ex-head"><h3>ڕاپۆرتی قازانج</h3><div class="ex-logo">Proxo</div></div>'+
    '<div class="ex-title">پوختەی قازانج (IQD)</div><div class="ex-grid">'+fields.map(x=>profitCard(x[0],x[1],'fa-chart-line')).join('')+'</div>'+
    '<div class="ex-title">قازانج بەپێی ڕێگا</div><table><thead><tr><th>ڕێگا</th><th>ژمارەی تۆمارکراو</th><th>قازانج (IQD)</th></tr></thead><tbody>'+groups+'</tbody></table>'+
    '<div class="ex-title">مامەڵە تۆمارکراوەکان (تا 20)</div><table><thead><tr><th>ئایدی</th><th>داهات</th><th>تێچوو</th><th>قازانج</th></tr></thead><tbody>'+
    latest.map(o=>'<tr><td dir="ltr">'+profitEsc(o.order_code||o.order_number||o.id)+'</td><td>'+profitMoney(o.gross_income_iqd)+'</td><td>'+profitMoney(o.operating_cost_iqd)+'</td><td>'+profitMoney(o.net_profit_iqd)+'</td></tr>').join('')+'</tbody></table>'+
    '<div class="ex-note">بڕەکان تەنها بۆ مامەڵە پەسەندکراوە تۆمارکراوەکانن. بۆ هەموو داتا Excel یان CSV دابگرە.</div>';
  document.body.appendChild(source);
  try{
    if(document.fonts)await document.fonts.ready;
    const canvas=await html2canvas(source,{backgroundColor:'#fff',scale:2,useCORS:true,logging:false,windowWidth:850});
    const doc=new window.jspdf.jsPDF({unit:'mm',format:'a4',compress:true});
    const margin=10,width=210-2*margin,height=canvas.height*width/canvas.width,page=297-2*margin,img=canvas.toDataURL('image/jpeg',.93);
    for(let offset=0;offset<height;offset+=page){if(offset)doc.addPage();doc.addImage(img,'JPEG',margin,margin-offset,width,height)}
    doc.save(name+'.pdf');showToast('PDF دابەزێنرا','gr');
  }catch(e){console.error(e);showToast('دروستکردنی PDF سەرکەوتوو نەبوو','rd')}finally{source.remove()}
}
pageConfig.profit={title:'ئاماری قازانج',sub:'داهات، تێچوو، قازانجی پاک و مێژووی مامەڵەکان',load:()=>loadProfitStats()};
