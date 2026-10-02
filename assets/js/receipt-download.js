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
  const source=pbBuildReceipt(order);source.classList.add('pb-receipt-capture');
  source.style.position='fixed';source.style.left='-10000px';source.style.top='0';source.style.width='720px';
  document.body.append(source);
  try{
    if(!window.html2canvas||!window.jspdf?.jsPDF){
      throw new Error('PDF_LIBRARIES_UNAVAILABLE');
    }
    if(document.fonts)await document.fonts.ready;
    const canvas=await window.html2canvas(source,{scale:2,backgroundColor:'#fff',useCORS:true,logging:false,windowWidth:780});
    if(!canvas.width||!canvas.height)throw new Error('EMPTY_PDF_CAPTURE');
    const pdf=new window.jspdf.jsPDF({unit:'mm',format:'a4',compress:true});
    const width=190,height=canvas.height*width/canvas.width,onePage=277;
    const image=canvas.toDataURL('image/jpeg',.96);
    for(let offset=0;offset<height;offset+=onePage){
      if(offset)pdf.addPage();
      pdf.addImage(image,'JPEG',10,10-offset,width,height);
    }
    pdf.save(name+'.pdf');
    showToast('پسووڵەکە دابەزێنرا','success');
  }catch(err){
    console.error('Receipt PDF error',err);
    /* Printing is a supported fallback when the remote PDF libraries are blocked. */
    const printWindow=window.open('','_blank');
    if(printWindow){
      printWindow.document.open();
      printWindow.document.write('<!doctype html><html lang="ku" dir="rtl"><head><meta charset="utf-8"><title>پسووڵەی مامەڵە</title>'+
        '<style>'+pbReceiptPrintCSS()+'<\/style></head><body>'+source.outerHTML.replace(/style="position:[^"]*"/,'')+
        '<script>window.onload=function(){window.print()}<\/script></body></html>');
      printWindow.document.close();
      showToast('لە چاپکردنەوە «Save as PDF» هەڵبژێرە','info');
    }else showToast('داگرتنی PDF سەرکەوتوو نەبوو؛ تکایە دووبارە هەوڵ بدەرەوە','error');
  }finally{source.remove();}
}
function pbReceiptPrintCSS(){
  return 'body{margin:0;padding:24px;background:#fff;font-family:Rabar,Tahoma,Arial,sans-serif}'+
  '.pb-receipt-print{max-width:720px;margin:auto;padding:30px;border:1px solid #e8edf3;border-radius:26px;box-sizing:border-box;color:#253246}'+
  '.pb-rhead{display:flex;justify-content:space-between;align-items:center;padding-bottom:18px;border-bottom:1px solid #e8edf3}'+
  '.pb-rhead h2{font-weight:500;font-size:16px;flex:1;text-align:center}.pb-rhead strong{color:#1685fa;font:bold 25px Arial}'+
  '.pb-rsection{padding:14px 0 10px;border-bottom:1px solid #e8edf3}'+
  '.pb-rsection h3{color:#1685fa;font-size:15px;font-weight:500;text-align:center}'+
  '.pb-rrow{display:flex;gap:20px;justify-content:space-between;padding:9px 0;font-size:14px;line-height:1.7}'+
  '.pb-rkey{color:#64748b}.pb-rval{color:#253246;font-weight:500;text-align:left;overflow-wrap:anywhere}'+
  '.pb-rfooter{padding-top:17px;font-size:12px;line-height:1.85;text-align:center;color:#64748b}'+
  '@media print{body{padding:8px}.pb-receipt-print{border:0;border-radius:0}}';
}
