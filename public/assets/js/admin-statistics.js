/* Admin-only statistics view. Uses the panel's existing authenticated Supabase client,
   normalized report builder and server-side pricing RPCs. No new privileges. */
'use strict';
let _sxAds=[],_sxReports=[],_sxFilter='all',_sxLimit=60,_sxBusy=false,_sxPartial=false,_sxLoaded=false;
function sxEsc(v){return String(v==null?'':v).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]});}
function sxNumber(v,d){const n=Number(v);return v==null||!Number.isFinite(n)?'—':n.toLocaleString('en-US',{minimumFractionDigits:d||0,maximumFractionDigits:d||0});}
function sxMoney(v){return v==null?'—':'$'+sxNumber(v,2);}
function sxSum(list,key){let total=0,count=0;list.forEach(function(r){const v=r.report[key];if(v!=null&&Number.isFinite(Number(v))){total+=Number(v);count++;}});return count?total:null;}
function sxVisible(){
  const q=(document.getElementById('sxSearch')?.value||'').trim().toLowerCase().replace(/^#/,'');
  return _sxReports.filter(function(r){const a=r.ad;if(_sxFilter!=='all'&&a.status!==_sxFilter)return false;
    if(!q)return true;return [a.public_ad_id,a.ad_number,a.title,a.tiktok_ad_id,a.status].join(' ').toLowerCase().includes(q);
  });
}
function sxSetFilter(value){_sxFilter=value;_sxLimit=60;sxRender();}
function sxDate(v){if(!v)return '—';const d=new Date(v);return Number.isNaN(d.getTime())?'—':d.toLocaleString('en-GB',{day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'});}
function sxField(title,value,suffix){return '<div class="sx-metric"><div class="name">'+title+'</div><div class="number">'+value+'</div>'+(suffix?'<div class="suffix">'+suffix+'</div>':'')+'</div>';}
function sxRow(title,value){return '<div><span class="name">'+title+'</span><span class="number">'+value+'</span></div>';}
async function loadStatistics(){
  if(_sxBusy)return;_sxBusy=true;_sxLoaded=false;
  const el=document.getElementById('sxList'),stamp=document.getElementById('sxUpdated');
  if(el)el.innerHTML='<div class="sx-state"><i class="fas fa-circle-notch fa-spin"></i> بارکردنی ئامارەکان...</div>';
  try{
    if(!sb)throw Error('پەیوەندیی داتابەیس بەردەست نییە');
    const all=[],pageSize=500,maxRows=10000;let page=0,more=true;
    while(more&&all.length<maxRows){
      const res=await sb.from('pa_ads').select('*').order('created_at',{ascending:false}).range(page*pageSize,(page+1)*pageSize-1);
      if(res.error)throw res.error;
      const batch=res.data||[];all.push.apply(all,batch);more=batch.length===pageSize;page++;
    }
    _sxPartial=more;_sxAds=all;
    _sxReports=all.map(function(a){return {ad:a,report:buildNormalizedAdReport(a,null,{scope:'admin'})};});
    _sxLoaded=true;_sxLimit=60;
    if(stamp)stamp.textContent='دوایین بارکردن: '+sxDate(new Date());
    sxRender();
  }catch(e){if(el)el.innerHTML='<div class="sx-state" role="alert">نەتوانرا ئامارەکان باربکرێن: '+sxEsc(e.message)+'</div>';
    const count=document.getElementById('sxCount');if(count)count.textContent='داتا بەردەست نییە';
  }finally{_sxBusy=false;}
}
function sxRender(){
  if(!_sxLoaded)return;
  const list=sxVisible(),metrics=document.getElementById('sxMetrics'),wrap=document.getElementById('sxList'),count=document.getElementById('sxCount'),warn=document.getElementById('sxWarning');
  if(count)count.textContent=sxNumber(list.length)+' ڕیکلام لە '+sxNumber(_sxReports.length);
  const impr=sxSum(list,'impressions_total'),views=sxSum(list,'video_views_total'),clicks=sxSum(list,'clicks_total'),spend=sxSum(list,'spend_total'),conv=sxSum(list,'conversions_total');
  const ctr=impr>0&&clicks!=null?clicks/impr*100:null,cpc=clicks>0&&spend!=null?spend/clicks:null,cpm=impr>0&&spend!=null?spend/impr*1000:null;
  if(metrics)metrics.innerHTML=sxField('کۆی ڕیکلامەکان',sxNumber(list.length))+sxField('بینین (Impressions)',sxNumber(impr))+
    sxField('بینینی ڤیدیۆ',sxNumber(views))+sxField('کلیک',sxNumber(clicks))+sxField('خەرجکراو',sxMoney(spend))+
    sxField('CTR',ctr==null?'—':sxNumber(ctr,2)+'%')+sxField('CPC',sxMoney(cpc))+sxField('CPM',sxMoney(cpm))+
    sxField('ئەنجامەکان',sxNumber(conv));
  if(warn)warn.textContent=_sxPartial?'تێبینی: تەنها 10,000 ڕیکلامی نوێترین بارکراون. ئامار و فایلەکان تەنها ئەمانە دەگرنەوە.':'— واتە ئامارەکە هێشتا لە TikTok سینک نەکراوە. کۆی ئامارەکان لە داتای ئەو ڕیکلامانەی ئێستا پاڵاوتراون هەژمار دەکرێت.';
  if(!wrap)return;
  if(!list.length){wrap.innerHTML='<div class="sx-state">هیچ ڕیکلامێک لەم پاڵاوتنەدا نەدۆزرایەوە.</div>';return;}
  wrap.innerHTML=list.slice(0,_sxLimit).map(function(item){
    const a=item.ad,r=item.report,id=sxEsc(a.id),pub=sxEsc((typeof _adminPublicAdIdLabel==='function'?_adminPublicAdIdLabel(a):a.public_ad_id)||'—');
    const rate=typeof adRateFor==='function'?adRateFor(a):null,price=typeof adPriceLabel==='function'?adPriceLabel(a):'—';
    return '<article class="sx-ad"><div class="sx-ad-top"><div style="min-width:0;flex:1"><div class="sx-ad-title">'+sxEsc(a.title||'ڕیکلامی بێ ناو')+'</div><div class="sx-ad-id" dir="ltr">'+pub+'</div></div>'+
      '<span class="badge '+sxEsc(a.status||'')+'">'+sxEsc(typeof statusKu==='function'?statusKu(a.status):a.status||'—')+'</span></div>'+
      '<div class="sx-ad-stats">'+sxRow('بینین',sxNumber(r.impressions_total))+sxRow('کلیک',sxNumber(r.clicks_total))+
      sxRow('CTR',r.ctr_percent==null?'—':sxNumber(r.ctr_percent,2)+'%')+sxRow('خەرجکراو',sxMoney(r.spend_total))+
      sxRow('بینینی ڤیدیۆ',sxNumber(r.video_views_total))+sxRow('CPC',sxMoney(r.cpc))+
      sxRow('CPM',sxMoney(r.cpm))+sxRow('نرخی ڕیکلام',sxEsc(price))+'</div>'+
      '<div class="sx-ad-foot"><span class="sx-foot-meta">نرخ: '+(rate==null?'—':sxNumber(rate)+' IQD / $1')+' · دوایین ئامار: '+sxEsc(sxDate(a.data_updated_at||a.last_sync))+'</span>'+
      '<div class="sx-actions"><button type="button" class="sx-btn" data-sx-edit="'+id+'"><i class="fas fa-pen"></i> دەستکاری نرخ</button>'+
      '<button type="button" class="sx-btn primary" data-sx-csv="'+id+'"><i class="fas fa-download"></i> ڕاپۆرت</button></div></div></article>';
  }).join('')+(list.length>_sxLimit?'<button type="button" class="sx-btn" style="width:100%" id="sxMore">بینینی ڕیکلامی زیاتر ('+sxNumber(list.length-_sxLimit)+')</button>':'');
  const more=document.getElementById('sxMore');if(more)more.addEventListener('click',function(){_sxLimit+=60;sxRender();});
}
function sxCsvCell(v){let s=String(v==null?'':v);if(/^[=+\-@\t\r]/.test(s))s="'"+s;return '"'+s.replace(/"/g,'""')+'"';}
function sxExport(kind,oneId){
  if(!_sxLoaded){showToast('سەرەتا ئامارەکان باربکە','rd');return;}
  const list=oneId?_sxReports.filter(function(r){return r.ad.id===oneId;}):sxVisible();
  if(!list.length){showToast('هیچ داتایەک نییە بۆ داگرتن','rd');return;}
  const cols=[['public_ad_id','Ad ID'],['title','Ad title'],['internal_status','Status'],['impressions_total','Impressions'],['video_views_total','Video views'],['clicks_total','Clicks'],['ctr_percent','CTR %'],['cpc','CPC USD'],['cpm','CPM USD'],['spend_total','Spend USD'],['conversions_total','Conversions'],['data_updated_at','Updated at']];
  const rows=list.map(function(x){return cols.map(function(c){return x.report[c[0]];});});
  const name='Proxo-statistics-'+(oneId?'ad-':'')+(typeof _rptToday==='function'?_rptToday():new Date().toISOString().slice(0,10));
  if(kind==='csv'){
    const text='\ufeff'+[cols.map(function(c){return c[1];}),...rows].map(function(row){return row.map(sxCsvCell).join(',');}).join('\r\n');
    _rptDownload(text,name+'.csv','text/csv;charset=utf-8;');showToast('CSV دابەزێنرا','gr');return;
  }
  if(kind==='xlsx'){
    if(typeof XLSX==='undefined'){showToast('ئێکسڵ بار نەبووە','rd');return;}
    const wb=XLSX.utils.book_new(),ws=XLSX.utils.aoa_to_sheet([cols.map(function(c){return c[1];}),...rows]);
    ws['!cols']=cols.map(function(c){return {wch:c[0]==='title'?35:21};});
    XLSX.utils.book_append_sheet(wb,ws,'Ad statistics');XLSX.writeFile(wb,name+'.xlsx');showToast('Excel دابەزێنرا','gr');return;
  }
  if(kind==='pdf'){
    if(!window.jspdf?.jsPDF){showToast('PDF بار نەبووە','rd');return;}
    const pdf=new window.jspdf.jsPDF({orientation:'landscape',unit:'mm',format:'a4',compress:true});
    pdf.setFont('helvetica','bold');pdf.setFontSize(19);pdf.setTextColor(22,133,250);pdf.text('Proxo',12,16);
    pdf.setFontSize(12);pdf.setTextColor(32,45,66);pdf.text('Ad statistics',45,16);
    pdf.setFontSize(9);pdf.text(new Date().toISOString().slice(0,10)+'  |  '+list.length+' ads',12,24);
    const pdfColumns=[0,2,3,5,6,7,8,9].map(function(i){return cols[i][1];});
    const pdfRows=rows.map(function(row){return [0,2,3,5,6,7,8,9].map(function(i){
      const v=row[i];return v==null?'—':typeof v==='number'?sxNumber(v,i===6||i===7||i===8||i===9?2:0):String(v).replace(/[^\x20-\x7e]/g,'').slice(0,24);
    });});
    if(typeof pdf.autoTable!=='function'){showToast('PDF Table بار نەبووە','rd');return;}
    pdf.autoTable({startY:30,head:[pdfColumns],body:pdfRows,styles:{font:'helvetica',fontSize:8,cellPadding:3,overflow:'linebreak'},headStyles:{fillColor:[22,133,250]},margin:{left:11,right:11},theme:'grid'});
    pdf.save(name+'.pdf');showToast('PDF دابەزێنرا','gr');
  }
}
function sxEditPrice(id){const item=_sxReports.find(function(r){return r.ad.id===id;});if(!item)return;
  window._sxPriceFocus=(typeof _adminPublicAdId==='function'?_adminPublicAdId(item.ad):item.ad.public_ad_id)||item.ad.title||'';
  goPage('adPricing');
}
document.addEventListener('click',function(e){const edit=e.target.closest('[data-sx-edit]');if(edit){sxEditPrice(edit.dataset.sxEdit);return;}
  const csv=e.target.closest('[data-sx-csv]');if(csv)sxExport('csv',csv.dataset.sxCsv);
});
