/* Customer receipt, based exclusively on an order already loaded for the signed-in user.
   Kurdish Sorani labels and native RTL rendering; the PDF retains glyphs as an image. */
'use strict';
const pbReceiptIcon='<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12m-4-4 4 4 4-4M5 18v3h14v-3"/></svg>';
function pbReceiptLabel(label,value,ltr){
  const row=document.createElement('div');
  row.className='pb-rrow';
  const key=document.createElement('span');key.className='pb-rkey';key.textContent=label;
  const val=document.createElement('span');val.className='pb-rval';val.textContent=value==null?'—':String(value);
  if(ltr){val.dir='ltr';val.style.unicodeBidi='isolate';}
  row.append(key,val);
  return row;
}
function pbReceiptMethod(key){return typeof methodLabel==='function'?methodLabel(key):String(key||'—');}
function pbReceiptWhen(value){return typeof txWhen==='function'?txWhen(value,true):String(value||'—');}
function pbReceiptAmount(value,method){
  const n=Number(value);
  const display=Number.isFinite(n)?Math.floor(n).toLocaleString('en-US'):'—';
  return display+(method==='USDT'?' $':' د.ع');
}
function pbBuildReceipt(order){
  const box=document.createElement('article');
  box.className='pb-receipt-print';box.dir='rtl';box.setAttribute('aria-label','پسووڵەی مامەڵە');
  const head=document.createElement('header');head.className='pb-rhead';
  const title=document.createElement('h2');title.textContent='پسووڵەی مامەڵە';
  const logo=document.createElement('strong');logo.textContent='Proxo';logo.dir='ltr';
  head.append(title,logo);box.append(head);
  const id=document.createElement('div');id.className='pb-rsection';
  const idtitle=document.createElement('h3');idtitle.textContent='زانیاری مامەڵە';
  id.append(idtitle,
    pbReceiptLabel('ئایدی مامەڵە',typeof orderCodeOf==='function'?orderCodeOf(order):order.order_code||order.id,true),
    pbReceiptLabel('بەرواری ناردن',pbReceiptWhen(order.created_at)),
    pbReceiptLabel('دۆخی مامەڵە',order.status||'—'));
  if(order.decided_at && (order.status==='پەسەندکرا'||order.status==='ڕەتکرا')){
    id.append(pbReceiptLabel('بەرواری بڕیار',pbReceiptWhen(order.decided_at)));
  }
  box.append(id);
  const payments=document.createElement('section');payments.className='pb-rsection';
  const payTitle=document.createElement('h3');payTitle.textContent='وردەکاری ئاڵوگۆڕ';
  payments.append(payTitle,
    pbReceiptLabel('لە ڕێگای',pbReceiptMethod(order.from_method)),
    pbReceiptLabel('بۆ ڕێگای',pbReceiptMethod(order.to_method)),
    pbReceiptLabel('بڕی نێردراو',pbReceiptAmount(order.amount,order.from_method),true),
    pbReceiptLabel('بڕی وەرگیراو',pbReceiptAmount(order.total,order.to_method),true));
  if(order.from_method!=='USDT'&&order.to_method!=='USDT'&&Number(order.amount)>Number(order.total)){
    payments.append(pbReceiptLabel('بڕی لێبڕین',
      pbReceiptAmount(Number(order.amount)-Number(order.total),'IQD'),true));
  }
  box.append(payments);
  const detail=document.createElement('section');detail.className='pb-rsection';
  const detailTitle=document.createElement('h3');detailTitle.textContent='زانیاری پارەدان';
  detail.append(detailTitle);
  if(order.phone)detail.append(pbReceiptLabel('ژمارەی وەرگر',order.phone,true));
  if(order.sender_phone)detail.append(pbReceiptLabel('ژمارەی نێرەر',order.sender_phone,true));
  if(order.admin_note)detail.append(pbReceiptLabel('تێبینی',order.admin_note));
  detail.append(pbReceiptLabel('سەرچاوە','Proxo Balance'));
  box.append(detail);
  const footer=document.createElement('p');footer.className='pb-rfooter';
  footer.textContent='ئەم پسووڵەیە لە زانیارییە تۆمارکراوەکانی مامەڵەکەت دروستکراوە. دۆخی مامەڵە بەپێی دوایین زانیاری پیشان دەدرێت.';
  box.append(footer);
  return box;
}
async function downloadTransactionReceipt(orderId){
  const order=_orders.find(o=>String(o.id)===String(orderId));
  if(!order){showToast('مامەڵەکە نەدۆزرایەوە','error');return;}
  const name='Proxo-pswla-'+String(typeof orderCodeOf==='function'?orderCodeOf(order):order.id).replace(/[^A-Za-z0-9_-]/g,'');
  const source=pbBuildReceipt(order);
  source.classList.add('pb-receipt-capture');
  /* Keep it at a renderable viewport position. A -10000px offset breaks
     html2canvas layout and can leave Kurdish letters clipped or distorted. */
  source.style.cssText='position:fixed;inset:0 auto auto 0;width:720px;max-width:none;z-index:-1;pointer-events:none;';
  document.body.append(source);
  try{
    if(!window.html2canvas||!window.jspdf?.jsPDF)throw new Error('PDF_LIBRARIES_UNAVAILABLE');
    if(document.fonts){
      await document.fonts.load('400 14px Rabar','پسووڵەی مامەڵە');
      await document.fonts.load('500 14px Rabar','زانیاری مامەڵە');
      await document.fonts.ready;
      if(!document.fonts.check('400 14px Rabar','پسووڵە')){
        throw new Error('KURDISH_FONT_UNAVAILABLE');
      }
    }
    const canvas=await window.html2canvas(source,{
      scale:3,backgroundColor:'#ffffff',useCORS:true,logging:false,
      windowWidth:780,scrollX:0,scrollY:0,
      onclone:doc=>{
        const copy=doc.querySelector('.pb-receipt-capture');
        if(copy)copy.style.cssText='position:absolute;inset:0 auto auto 0;width:720px;max-width:none;z-index:0;pointer-events:none;';
      }
    });
    if(!canvas.width||!canvas.height)throw new Error('EMPTY_PDF_CAPTURE');
    const pdf=new window.jspdf.jsPDF({unit:'mm',format:'a4',compress:true});
    const mmWidth=190,mmAvailableHeight=277;
    const maxPagePixels=Math.floor(mmAvailableHeight*canvas.width/mmWidth);
    /* Prefer the bottom of a whole receipt row or section. Never shear the
       same JPEG across pages: that blurs Sorani glyphs and splits baselines. */
    const base=source.getBoundingClientRect();
    const ratio=canvas.height/base.height;
    const edges=[...source.querySelectorAll('.pb-rhead,.pb-rsection h3,.pb-rrow,.pb-rfooter')]
      .map(el=>Math.round((el.getBoundingClientRect().bottom-base.top)*ratio))
      .filter(y=>y>0&&y<=canvas.height).sort((a,b)=>a-b);
    let top=0;
    while(top<canvas.height){
      let bottom=Math.min(top+maxPagePixels,canvas.height);
      if(bottom<canvas.height){
        const safe=edges.filter(y=>y>top+maxPagePixels*.4&&y<=bottom-18).pop();
        if(safe)bottom=safe;
      }
      if(bottom<=top)throw new Error('INVALID_PDF_PAGE');
      const part=document.createElement('canvas');
      part.width=canvas.width;part.height=bottom-top;
      const ctx=part.getContext('2d',{alpha:false});
      if(!ctx)throw new Error('PDF_CANVAS_UNAVAILABLE');
      ctx.fillStyle='#ffffff';ctx.fillRect(0,0,part.width,part.height);
      ctx.drawImage(canvas,0,top,canvas.width,part.height,0,0,part.width,part.height);
      if(top)pdf.addPage();
      pdf.addImage(part.toDataURL('image/png'),'PNG',10,10,mmWidth,part.height*mmWidth/part.width);
      top=bottom;
    }
    pdf.save(name+'.pdf');
    showToast('پسووڵەکە دابەزێنرا','success');
  }catch(err){
    console.error('Receipt PDF error',err);
    /* Native print retains the browser's Kurdish shaping when the font or
       third-party PDF libraries cannot be used. */
    const printWindow=window.open('','_blank');
    if(printWindow){
      printWindow.document.open();
      printWindow.document.write('<!doctype html><html lang="ku" dir="rtl"><head><meta charset="utf-8"><title>پسووڵەی مامەڵە</title>'+
        '<style>'+pbReceiptPrintCSS()+'<\/style></head><body>'+source.outerHTML.replace(/style="[^"]*"/,'')+
        '<script>window.onload=async function(){if(document.fonts)await document.fonts.ready;window.print()}<\/script></body></html>');
      printWindow.document.close();
      showToast('لە چاپکردنەوە «Save as PDF» هەڵبژێرە','info');
    }else showToast('داگرتنی PDF سەرکەوتوو نەبوو؛ تکایە دووبارە هەوڵ بدەرەوە','error');
  }finally{source.remove();}
}
function pbReceiptPrintCSS(){
  return '@font-face{font-family:Rabar;src:url(https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2) format(woff2);font-weight:300 800;font-display:swap}'+
  'body{margin:0;padding:24px;background:#fff;font-family:Rabar,Tahoma,Arial,sans-serif;direction:rtl}'+
  '.pb-receipt-print{max-width:720px;margin:auto;padding:30px;border:1px solid #e8edf3;border-radius:26px;box-sizing:border-box;color:#253246}'+
  '.pb-rhead{display:flex;justify-content:space-between;align-items:center;padding-bottom:18px;border-bottom:1px solid #e8edf3}'+
  '.pb-rhead h2{font-weight:500;font-size:16px;flex:1;text-align:center}.pb-rhead strong{color:#1685fa;font:bold 25px Arial}'+
  '.pb-rsection{padding:14px 0 10px;border-bottom:1px solid #e8edf3}'+
  '.pb-rsection h3{color:#1685fa;font-size:15px;font-weight:500;text-align:center}'+
  '.pb-rrow{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);align-items:start;gap:18px;padding:11px 4px;font-size:14px;line-height:1.75}'+
  '.pb-rkey{color:#64748b;text-align:right;min-width:0}.pb-rval{color:#253246;font-weight:500;text-align:left;min-width:0;overflow-wrap:anywhere}.pb-rval[dir=ltr]{direction:ltr;unicode-bidi:isolate}'+
  '.pb-rfooter{padding-top:17px;font-size:12px;line-height:1.85;text-align:center;color:#64748b}'+
  '@media print{body{padding:8px}.pb-receipt-print{border:0;border-radius:0}}';
}
