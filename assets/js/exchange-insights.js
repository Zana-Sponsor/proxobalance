/* Proxo Balance exchange admin insights.
   Reads ex_orders and ex_rates using the existing authenticated admin session;
   writes only through existing openRateModal / saveRate UI. */
'use strict';
const exStatsState={rows:[],filter:'all',limit:60,loaded:false,partial:false,busy:false,rateCount:null};
function exSafe(v){return String(v==null?'':v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));}
function exNum(v,d=0){const n=Number(v);return v==null||!Number.isFinite(n)?'—':n.toLocaleString('en-US',{minimumFractionDigits:d,maximumFractionDigits:d});}
function exAmount(v){return v==null||!Number.isFinite(Number(v))?'—':exNum(v,2);}
function exDate(v){if(!v)return '—';const d=new Date(v);return Number.isNaN(d.getTime())?'—':d.toLocaleString('en-GB',{day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});}
function exDateKey(v){const d=new Date(v);if(Number.isNaN(d.getTime()))return '';const p=n=>String(n).padStart(2,'0');return d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate());}
function exMethod(m){return String((typeof METHOD_META!=='undefined'&&METHOD_META[m]?.label)||m||'—');}
function exCode(o){return o?.order_code||'—';}
function exStatus(s){return s===STATUS_APPROVED?'پەسەندکرا':s===STATUS_REJECTED?'ڕەتکرا':s===STATUS_PENDING?'چاوەڕوان':s===STATUS_CORRECTED?'ڕاستکراوەتەوە':s===STATUS_NEEDS_CORRECTION?'پێویستی بە ڕاستکردنەوەیە':s||'—';}
function exCard(label,value){return '<div class="ex-card"><div class="ex-label">'+label+'</div><div class="ex-value">'+value+'</div></div>';}
function exFiltered(){
  const q=(document.getElementById('exSearch')?.value||'').trim().toLowerCase().replace(/^#/,'');
  const from=document.getElementById('exFromDate')?.value||'',to=document.getElementById('exToDate')?.value||'';
  return exStatsState.rows.filter(o=>(exStatsState.filter==='all'||o.status===exStatsState.filter)&&
    (!from||exDateKey(o.created_at)>=from)&&(!to||exDateKey(o.created_at)<=to)&&
    (!q||[exCode(o),o.order_number,o.id,o.from_method,o.to_method,o.status].join(' ').toLowerCase().includes(q)));
}
async function exLoadStatistics(){
  if(exStatsState.busy)return;
  exStatsState.busy=true;exStatsState.loaded=false;
  const list=document.getElementById('exOrderList');
  if(list)list.innerHTML='<div class="loading"><i class="fas fa-circle-notch fa-spin"></i> بارکردنی ئامارەکان...</div>';
  try{
    if(!sb)throw Error('داتابەیس پەیوەست نەبووە');
    const rows=[],size=500,max=10000;let more=true,p=0;
    while(more&&rows.length<max){
      const {data,error}=await sb.from('ex_orders').select('id,order_code,order_number,from_method,to_method,amount,total,status,created_at').order('created_at',{ascending:false}).range(p*size,(p+1)*size-1);
      if(error)throw error;const batch=data||[];rows.push(...batch);more=batch.length===size;p++;
    }
    exStatsState.rows=rows;exStatsState.partial=more;exStatsState.loaded=true;exStatsState.limit=60;
    const {data:rates,error:rateError}=await sb.from('ex_rates').select('id,is_active');
    exStatsState.rateCount=rateError?null:(rates||[]).filter(r=>r.is_active).length;
    const stamp=document.getElementById('exLastLoaded');if(stamp)stamp.textContent='دوایین نوێکردنەوە: '+exDate(new Date());
    exStatsRender();
  }catch(e){if(list)list.innerHTML='<div class="ex-note" role="alert">هەڵەی بارکردنی ئامارەکان: '+exSafe(e.message)+'</div>';
    const count=document.getElementById('exResultCount');if(count)count.textContent='ئامارەکان بەردەست نین';
  }finally{exStatsState.busy=false;}
}
function exSetFilter(v){exStatsState.filter=v;exStatsState.limit=60;exStatsRender();}
function exStatsRender(){
  if(!exStatsState.loaded)return;
  const rows=exFiltered(),n=rows.length,approved=rows.filter(o=>o.status===STATUS_APPROVED),pending=rows.filter(o=>[STATUS_PENDING,STATUS_CORRECTED,STATUS_NEEDS_CORRECTION].includes(o.status)),rejected=rows.filter(o=>o.status===STATUS_REJECTED);
  const summary=document.getElementById('exSummary');
  if(summary)summary.innerHTML=exCard('کۆی مامەڵەکان',exNum(n))+exCard('پەسەندکراو',exNum(approved.length))+exCard('چاوەڕوان / پێویستی بە پشکنین',exNum(pending.length))+
    exCard('ڕەتکراو',exNum(rejected.length))+exCard('ڕێژەی پەسەندکردن',n?exNum(approved.length/n*100,1)+'%':'—')+exCard('ڕێگای چالاک',exStatsState.rateCount==null?'—':exNum(exStatsState.rateCount));
  const byMethod=new Map();
  approved.forEach(o=>{const method=o.to_method||'نەزانراو',v=Number(o.total);let current=byMethod.get(method)||{method,count:0,total:0,values:0};
    current.count++;if(o.total!=null&&Number.isFinite(v)){current.total+=v;current.values++}byMethod.set(method,current)});
  const groups=document.getElementById('exMethodTotals');
  if(groups)groups.innerHTML=byMethod.size?[...byMethod.values()].sort((a,b)=>b.count-a.count).map(g=>
    '<div class="ex-card"><div class="ex-label">وەرگیراو لە '+exSafe(exMethod(g.method))+' · '+exNum(g.count)+' مامەڵە</div><div class="ex-value">'+(g.values?exAmount(g.total):'—')+'</div></div>').join(''):'<div class="ex-note">هیچ مامەڵەیەکی پەسەندکراو لەم پاڵاوتنەدا نییە.</div>';
  const count=document.getElementById('exResultCount');if(count)count.textContent=exNum(n)+' لە '+exNum(exStatsState.rows.length);
  const warning=document.getElementById('exStatsNotice');if(warning)warning.textContent=(exStatsState.partial?'تەنها 10,000 مامەڵەی دوایین بارکراون؛ ڕاپۆرت و ئامارەکان ئەمانە دەگرنەوە. ':'')+
    'کۆی بڕەکان بە ڕێگای وەرگرتن جیاکراونەتەوە؛ بەهای ڕێگا و دراوی جیاواز لە یەک کۆدا تێکەڵ نەکراون.';
  const container=document.getElementById('exOrderList');if(!container)return;
  if(!rows.length){container.innerHTML='<div class="ex-note">هیچ مامەڵەیەک بۆ ئەم پاڵاوتنە نییە.</div>';return;}
  container.innerHTML=rows.slice(0,exStatsState.limit).map(o=>
    '<article class="ex-order"><div class="ex-order-header"><div><div class="ex-order-title">'+exSafe(exMethod(o.from_method))+' ← '+exSafe(exMethod(o.to_method))+
    '</div><div class="ex-order-code" dir="ltr">'+exSafe(exCode(o))+'</div></div><span class="badge '+exSafe(o.status===STATUS_APPROVED?'approved':o.status===STATUS_REJECTED?'rejected':'pending')+'">'+exSafe(exStatus(o.status))+'</span></div>'+
    '<div class="ex-order-details"><div><div class="ex-label">بڕی نێردراو</div><div class="ex-value">'+exAmount(o.amount)+'</div><div class="ex-label">'+exSafe(exMethod(o.from_method))+'</div></div>'+
    '<div><div class="ex-label">بڕی وەرگیراو</div><div class="ex-value">'+exAmount(o.total)+'</div><div class="ex-label">'+exSafe(exMethod(o.to_method))+'</div></div>'+
    '<div><div class="ex-label">ڕێکەوت</div><div class="ex-value" style="font-size:13px">'+exSafe(exDate(o.created_at))+'</div></div></div>'+
    '<div class="ex-order-footer"><span>مامەڵەی ئاڵوگۆڕ</span><button type="button" class="ex-btn" data-ex-order="'+exSafe(o.id)+'"><i class="fas fa-eye"></i> وردەکاری</button></div></article>').join('')+
    (rows.length>exStatsState.limit?'<button type="button" class="ex-btn" style="width:100%" id="exShowMore">بینینی زیاتر ('+exNum(rows.length-exStatsState.limit)+')</button>':'');
  document.getElementById('exShowMore')?.addEventListener('click',()=>{exStatsState.limit+=60;exStatsRender()});
}
async function exOpenOrder(id){
  try{
    const {data,error}=await sb.from('ex_orders').select('*').eq('id',id).maybeSingle();
    if(error)throw error;if(!data)throw Error('مامەڵەکە نەدۆزرایەوە');
    const profiles=typeof loadProfilesFor==='function'?await loadProfilesFor([data.user_id]):{};
    const full={...data,profile:profiles?.[data.user_id]||null};
    const idx=allOrders.findIndex(o=>String(o.id)===String(id));
    if(idx>=0)allOrders[idx]=full;else allOrders.push(full);
    showOrderDetail(id);
  }catch(e){showToast('هەڵە لە بینینی مامەڵە: '+e.message,'rd')}
}
document.addEventListener('click',e=>{const b=e.target.closest('[data-ex-order]');if(b)exOpenOrder(b.dataset.exOrder)});
function exExcelSafe(v){const s=String(v==null?'':v);return /^[=+\-@\t\r]/.test(s)?"'"+s:s;}
function exCsvValue(v){return '"'+exExcelSafe(v).replace(/"/g,'""')+'"';}
function exDownload(text,name,mime){const blob=new Blob([text],{type:mime}),url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download=name;document.body.appendChild(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1200);}
function exExport(kind){
  if(!exStatsState.loaded){showToast('سەرەتا ئامارەکان باربکە','rd');return}
  const rows=exFiltered();if(!rows.length){showToast('هیچ مامەڵەیەک نییە بۆ داگرتن','rd');return}
  const fields=[['order_code','ئایدی مامەڵە'],['from_method','ڕێگای ناردن'],['to_method','ڕێگای وەرگرتن'],['amount','بڕی نێردراو'],['total','بڕی وەرگیراو'],['status','بار'],['created_at','ڕێکەوت']];
  const table=[fields.map(x=>x[1]),...rows.map(o=>fields.map(([k])=>o[k]??''))];
  const filename='Proxo-Balance-statistics-'+exDateKey(new Date());
  if(kind==='csv'){exDownload('\ufeff'+table.map(row=>row.map(exCsvValue).join(',')).join('\r\n'),filename+'.csv','text/csv;charset=utf-8');showToast('CSV ئامادەکرا','gr');return}
  if(kind==='xlsx'){if(typeof XLSX==='undefined')return showToast('کتێبخانەی Excel بار نەبووە','rd');
    const workbook=XLSX.utils.book_new(),sheet=XLSX.utils.aoa_to_sheet([table[0],...table.slice(1).map(row=>row.map(exExcelSafe))]);
    sheet['!cols']=[{wch:22},{wch:18},{wch:18},{wch:19},{wch:19},{wch:27},{wch:23}];
    XLSX.utils.book_append_sheet(workbook,sheet,'Exchange orders');XLSX.writeFile(workbook,filename+'.xlsx');showToast('Excel ئامادەکرا','gr');return;
  }
  if(kind==='pdf')exExportPdf(rows,filename);
}
async function exExportPdf(rows,filename){
  if(!window.html2canvas||!window.jspdf?.jsPDF)return showToast('کتێبخانەی PDF بار نەبووە','rd');
  const source=document.createElement('div');source.className='ex-pdf-source';source.dir='rtl';
  const approved=rows.filter(o=>o.status===STATUS_APPROVED),byMethod=new Map();
  approved.forEach(o=>{const k=o.to_method||'—',v=Number(o.total),p=byMethod.get(k)||{count:0,sum:0};
    p.count++;if(o.total!=null&&Number.isFinite(v))p.sum+=v;byMethod.set(k,p)});
  const groups=[...byMethod].map(([method,p])=>'<tr><td>'+exSafe(exMethod(method))+'</td><td>'+exNum(p.count)+'</td><td>'+exAmount(p.sum)+'</td></tr>').join('');
  source.innerHTML='<div class="ex-head"><h3>ڕاپۆرتی ئامارەکان</h3><div class="ex-logo">Proxo</div></div>'+
    '<div class="ex-title">پوختەی مامەڵەکان</div><div class="ex-grid">'+exCard('کۆی مامەڵەکان',exNum(rows.length))+exCard('پەسەندکراو',exNum(approved.length))+
    exCard('چاوەڕوان',exNum(rows.filter(o=>[STATUS_PENDING,STATUS_CORRECTED,STATUS_NEEDS_CORRECTION].includes(o.status)).length))+exCard('ڕەتکراو',exNum(rows.filter(o=>o.status===STATUS_REJECTED).length))+'</div>'+
    '<div class="ex-title">کۆی پەسەندکراو بەپێی ڕێگای وەرگرتن</div><table><thead><tr><th>ڕێگا</th><th>ژمارە</th><th>بڕی وەرگیراو</th></tr></thead><tbody>'+groups+'</tbody></table>'+
    '<div class="ex-title">دواترین مامەڵەکان (تا 20 مامەڵە)</div><table><thead><tr><th>ئایدی</th><th>لە / بۆ</th><th>بڕی نێردراو</th><th>بڕی وەرگیراو</th><th>بار</th></tr></thead><tbody>'+
    rows.slice(0,20).map(o=>'<tr><td dir="ltr">'+exSafe(exCode(o))+'</td><td>'+exSafe(exMethod(o.from_method))+' / '+exSafe(exMethod(o.to_method))+'</td><td>'+exAmount(o.amount)+'</td><td>'+exAmount(o.total)+'</td><td>'+exSafe(exStatus(o.status))+'</td></tr>').join('')+
    '</tbody></table><div class="ex-note">ڕاپۆرتی PDF پوختەی مامەڵەکان و 20 مامەڵەی دوایین دەگرێتەوە. بۆ لیستی تەواو Excel یان CSV دابگرە.</div>';
  document.body.appendChild(source);
  try{
    if(document.fonts)await document.fonts.ready;
    const canvas=await html2canvas(source,{backgroundColor:'#ffffff',scale:2,useCORS:true,logging:false,windowWidth:850});
    const pdf=new window.jspdf.jsPDF({unit:'mm',format:'a4',compress:true});
    const margin=10,width=210-2*margin,height=canvas.height*width/canvas.width,pageHeight=297-2*margin,img=canvas.toDataURL('image/jpeg',.93);
    for(let offset=0;offset<height;offset+=pageHeight){if(offset)pdf.addPage();pdf.addImage(img,'JPEG',margin,margin-offset,width,height)}
    pdf.save(filename+'.pdf');showToast('PDF ئامادەکرا','gr');
  }catch(e){console.error(e);showToast('هەڵە لە دروستکردنی PDF','rd')}finally{source.remove()}
}
function exRenderRateCards(){
  const wrap=document.getElementById('exRatesQuick');if(!wrap)return;
  if(!allRates?.length){wrap.innerHTML='<div class="ex-note">هێشتا هیچ نرخێک زیاد نەکراوە.</div>';return}
  wrap.innerHTML=(typeof filteredAdminRates==='function'?filteredAdminRates():allRates).map(r=>'<article class="ex-rate"><div class="ex-rate-top"><h4>'+exSafe(exMethod(r.from_method))+' ← '+exSafe(exMethod(r.to_method))+'</h4>'+
    '<span class="badge '+(r.is_active?'approved':'rejected')+'">'+(r.is_active?'چالاک':'ناچالاک')+'</span></div>'+
    '<div class="ex-value">'+(r.rate_type==='fee_percent'?exNum(r.rate_value,2)+'%':r.rate_type==='fee_fixed'?exNum(r.rate_value,2):'×'+exNum(r.rate_value,4))+'</div>'+
    '<small>'+exSafe(typeof rateTypeLabel==='function'?rateTypeLabel(r.rate_type):r.rate_type)+'</small>'+
    '<div class="ex-actions" style="margin-top:13px"><button type="button" class="ex-btn primary" data-ex-rate="'+exSafe(r.id)+'"><i class="fas fa-pen"></i> دەستکاری نرخ</button></div></article>').join('');
}
document.addEventListener('click',e=>{const b=e.target.closest('[data-ex-rate]');if(!b)return;const rate=allRates.find(r=>String(r.id)===b.dataset.exRate);if(rate)openRateModal(rate)});
if(typeof loadRates==='function'){
  const originalExchangeLoadRates=loadRates;
  loadRates=async function(){await originalExchangeLoadRates();exRenderRateCards()};
}
pageConfig.statistics={title:'ئامارەکانی ئاڵوگۆڕ',sub:'ڕاپۆرت، پاڵاوتن، کۆی مامەڵەکان و داگرتنی ئامار',load:()=>exLoadStatistics()};

