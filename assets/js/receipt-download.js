/* Customer receipt, refreshed from the signed-in customer's own saved order.
   Native print-to-PDF preserves searchable Kurdish Sorani lettering and RTL shaping. */
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
function pbReceiptNumber(value,whole=false){
  const n=value===null||value===undefined||value===''||!['number','string'].includes(typeof value)||
    (typeof value==='string'&&!/^\d+(?:\.\d+)?$/.test(value))?NaN:Number(value);
  return Number.isFinite(n)&&n>=0&&(!whole||(Number.isSafeInteger(n)&&n<=1000000000))?n:null;
}
function pbReceiptAmount(value,method){
  const n=pbReceiptNumber(value),display=n===null?'—':n.toLocaleString('en-US');
  return display+(method==='USDT'?' $':' د.ع');
}
function pbReceiptRefunds(order,payout){
  const full=!!(order.balance_refunded_at||order.balance_refund_case_id);
  const expected=pbReceiptNumber(order.total,true),cumulative=pbReceiptNumber(order.shortfall_refunded_iqd,true);
  const hasSettlement=[order.payout_settlement_id,order.payout_iqd,order.payout_rounding_iqd].some(v=>v!==null&&v!==undefined);
  const automatic=payout?.settled?payout.remainder_iqd:hasSettlement?null:0;
  const iqd=typeof ProxoPayoutRounding==='object'&&ProxoPayoutRounding.appliesTo(order.to_method);
  if(full){
    // A full return credits the original principal, not the net recipient total.
    // Its order markers do not prove that the external payout was zero.
    const principal=pbReceiptNumber(order.amount,true);
    const saved=order.status==='ڕەتکرا'&&iqd&&order.from_method!=='USDT'&&principal>0&&
      /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(String(order.balance_refund_case_id||''))&&
      typeof order.balance_refunded_at==='string'&&Number.isFinite(Date.parse(order.balance_refunded_at));
    return {full:true,automatic:null,manual:null,total:saved?principal:null,sent:null};
  }
  if(!(cumulative>0||automatic>0))return null;
  const valid=order.status==='پەسەندکرا'&&iqd&&expected!==null&&cumulative!==null&&
    automatic!==null&&cumulative>=automatic&&cumulative<=expected&&(!hasSettlement||payout?.settled);
  return {full:false,automatic,manual:valid?cumulative-automatic:null,
    total:valid?cumulative:null,sent:valid?expected-cumulative:null};
}
function pbBuildReceipt(order){
  const payout=typeof ProxoPayoutRounding==='object'?ProxoPayoutRounding.forOrder(order):null;
  const rounded=!order.balance_refunded_at&&payout&&(payout.planned||payout.has_settlement);
  const refunds=pbReceiptRefunds(order,payout);
  const box=document.createElement('article');
  box.className='pb-receipt-print';box.dir='rtl';box.setAttribute('aria-label','پسووڵەی مامەڵە');
  const head=document.createElement('header');head.className='pb-rhead';
  const title=document.createElement('h2');title.textContent='پسووڵەی مامەڵە';
  const logo=document.createElement('strong');logo.textContent='Proxo';logo.dir='ltr';
  head.append(title,logo);box.append(head);
  const id=document.createElement('div');id.className='pb-rsection';
  const idtitle=document.createElement('h3');idtitle.textContent='زانیاری مامەڵە';
  id.append(idtitle,
    pbReceiptLabel('ژمارەی مامەڵە',typeof orderCodeOf==='function'?orderCodeOf(order):order.order_code||order.id,true),
    pbReceiptLabel('بەرواری داواکاری',pbReceiptWhen(order.created_at)),
    pbReceiptLabel('دۆخی مامەڵە',refunds?.full?'پارە گەڕێندراوەتەوە بۆ باڵانس':order.status||'—'));
  if(order.decided_at && (order.status==='پەسەندکرا'||order.status==='ڕەتکرا')){
    id.append(pbReceiptLabel('بەرواری بڕیار',pbReceiptWhen(order.decided_at)));
  }
  box.append(id);
  const payments=document.createElement('section');payments.className='pb-rsection';
  const payTitle=document.createElement('h3');payTitle.textContent='وردەکاری ئاڵوگۆڕ';
  payments.append(payTitle,
    pbReceiptLabel('ڕێگای ناردن',pbReceiptMethod(order.from_method)),
    pbReceiptLabel('ڕێگای وەرگرتن',pbReceiptMethod(order.to_method)),
    pbReceiptLabel('بڕی سەرەکی داواکاری',pbReceiptAmount(order.amount,order.from_method),true),
    pbReceiptLabel(rounded||refunds?'بڕی سەرەکی دوای لێبڕین':'بڕی وەرگیراو',pbReceiptAmount(order.total,order.to_method),true));
  if(rounded){
    payments.append(pbReceiptLabel('بڕی ناردنی دیاریکراو بۆ وەرگر',pbReceiptAmount(payout.payout_iqd,'IQD'),true));
    if(payout.planned)payments.append(pbReceiptLabel('گەڕاندنەوە بۆ باڵانس دوای پەسەندکردن',pbReceiptAmount(payout.remainder_iqd,'IQD'),true));
    if(payout.valid&&payout.payout_iqd===0)payments.append(pbReceiptLabel('ناردنی دەرەکی','هیچ ناردنێکی دەرەکی ئەنجام نادرێت'));
    if(payout.planned&&payout.valid&&payout.remainder_iqd>0)payments.append(pbReceiptLabel('دۆخی گەڕاندنەوە','چاوەڕوانی پەسەندکردنی مامەڵەیە؛ هێشتا بۆ باڵانس تۆمار نەکراوە'));
  }
  const principal=pbReceiptNumber(order.amount),originalTotal=pbReceiptNumber(order.total);
  if(order.from_method!=='USDT'&&order.to_method!=='USDT'&&principal!==null&&originalTotal!==null&&principal>originalTotal){
    payments.append(pbReceiptLabel('بڕی لێبڕین',
      pbReceiptAmount(principal-originalTotal,'IQD'),true));
  }
  box.append(payments);
  if(refunds){
    const section=document.createElement('section');section.className='pb-rsection pb-rrefund';
    const heading=document.createElement('h3');heading.textContent='گەڕاندنەوە بۆ باڵانسی هەژمار';
    section.append(heading,pbReceiptLabel('جۆری گەڕاندنەوە',refunds.full?'گەڕاندنەوەی تەواوی مامەڵە':
      refunds.automatic>0&&refunds.manual>0?'خۆکار و بڕی کەم نێردراو':
      refunds.automatic>0?'گەڕاندنەوەی خۆکار':refunds.manual>0?'گەڕاندنەوەی بڕی کەم نێردراو':'وردەکاری بەردەست نییە'));
    if(refunds.automatic>0)section.append(pbReceiptLabel('گەڕاندنەوەی خۆکار بۆ باڵانسی هەژمار',pbReceiptAmount(refunds.automatic,'IQD'),true));
    if(!refunds.full&&(refunds.manual===null||refunds.manual>0))section.append(pbReceiptLabel('بڕی کەم نێردراو کە ئادمین گەڕاندوویەتییەوە',pbReceiptAmount(refunds.manual,'IQD'),true));
    section.append(pbReceiptLabel('کۆی گەڕاوە بۆ باڵانسی هەژمار',pbReceiptAmount(refunds.total,'IQD'),true));
    if(!refunds.full)section.append(pbReceiptLabel('بڕی نێردراوی هەژمارکراو بۆ وەرگر',pbReceiptAmount(refunds.sent,'IQD'),true));
    else section.append(pbReceiptLabel('بڕی نێردراو بۆ وەرگر','تۆمار نەکراوە'));
    if(refunds.full&&order.balance_refunded_at)section.append(pbReceiptLabel('بەرواری گەڕاندنەوە',pbReceiptWhen(order.balance_refunded_at)));
    const note=document.createElement('p');note.className='pb-rnote';
    note.textContent=refunds.total===null?'وردەکاری بڕی گەڕاوە تەواو نییە؛ بۆ پشتڕاستکردنەوە پەیوەندی بە پشتگیری بکە.':
      refunds.full?'بڕی گەڕاوە بڕی سەرەکی مامەڵەیە. بڕی ناردن بۆ وەرگر لە زانیارییە بەردەستەکاندا تۆمار نەکراوە.':
      'بڕی نێردراوی هەژمارکراو = بڕی سەرەکی دوای لێبڕین - کۆی گەڕاوە بۆ باڵانس. ئەمە هەموو گەڕاندنەوە تۆمارکراوەکان لەخۆ دەگرێت؛ بڕی دیاریکراوی سەرەتا لە سەرەوە پیشان دراوە.';
    section.append(note);box.append(section);
  }
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
let _pbReceiptBusy=false;
/* Native browser PDF is primary: it preserves Kurdish shaping and selectable
   letters, instead of flattening them with html2canvas/jspdf. This function
   runs inside the direct click handler to avoid popup blocking. */
async function downloadTransactionReceipt(orderId){
  if(_pbReceiptBusy)return;
  const owner=typeof curUser==='object'&&curUser?.id;
  const cached=_orders.find(o=>String(o.id)===String(orderId)&&o.user_id===owner);
  if(!owner||!cached){showToast('مامەڵەکە نەدۆزرایەوە','error');return;}
  _pbReceiptBusy=true;
  let printWindow=null;
  try{
    printWindow=window.open('','_blank');
    if(printWindow){
      printWindow.document.open();
      printWindow.document.write('<!doctype html><html lang="ku" dir="rtl"><head><meta charset="utf-8"><title>Proxo</title></head><body><p>دوایین زانیاریی مامەڵە بار دەکرێت...</p></body></html>');
      printWindow.document.close();
    }
    const {data:order,error}=await sb.from('ex_orders').select('*').eq('id',cached.id).eq('user_id',owner).maybeSingle();
    if(error||!order||order.id!==cached.id||order.user_id!==owner||curUser?.id!==owner)throw new Error('RECEIPT_REFRESH_FAILED');
    if(printWindow?.closed)return;
    const receipt=pbBuildReceipt(order);
    if(!printWindow){
      /* Print in the same tab if a browser blocks opening a new window. */
      const printStyle=document.createElement('style');
      printStyle.textContent=pbReceiptPrintCSS()+
        '@media print{body>*:not(.pb-receipt-print){display:none!important}'+
        '.pb-receipt-print{display:block!important;position:static!important;'+
        'width:auto!important;max-width:none!important;box-shadow:none!important}}';
      document.head.append(printStyle);
      document.body.append(receipt);
      let cleaned=false;
      const cleanup=()=>{if(cleaned)return;cleaned=true;receipt.remove();printStyle.remove();};
      window.addEventListener('afterprint',cleanup,{once:true});
      try{
        if(document.fonts){await document.fonts.load('400 14px Rabar','پسووڵەی مامەڵە');await document.fonts.ready;}
        if(curUser?.id!==owner)throw new Error('RECEIPT_OWNER_CHANGED');
        window.print();
        showToast('بۆ PDF، «Save as PDF» هەڵبژێرە','info');
      }catch(error){cleanup();console.error('Receipt print error',error);showToast('چاپکردنی پسووڵە سەرکەوتوو نەبوو','error');}
      return;
    }
    const name='Proxo-pswla-'+String(typeof orderCodeOf==='function'?orderCodeOf(order):order.id).replace(/[^A-Za-z0-9_-]/g,'');
    const html='<!doctype html><html lang="ku" dir="rtl"><head><meta charset="utf-8">'+
      '<meta name="viewport" content="width=device-width,initial-scale=1">'+
      '<title>'+name+'</title><style>'+pbReceiptPrintCSS()+'</style></head>'+
      '<body>'+receipt.outerHTML+
      '<script>window.addEventListener("load",async function(){'+
      'try{if(document.fonts){await document.fonts.load("400 14px Rabar","پسووڵەی مامەڵە");'+
      'await document.fonts.load("500 14px Rabar","زانیاری مامەڵە");await document.fonts.ready;}}catch(e){}'+
      'window.focus();window.print();});<\/script></body></html>';
    printWindow.document.open();
    printWindow.document.write(html);
    printWindow.document.close();
    showToast('بۆ داگرتنی PDF، «Save as PDF» هەڵبژێرە','info');
  }catch(err){
    console.error('Native Kurdish receipt PDF error',err);
    try{printWindow.close();}catch(_){}
    showToast('نەتوانرا دوایین زانیاریی مامەڵە بۆ پسووڵە بار بکرێت؛ تکایە دووبارە هەوڵ بدەرەوە','error');
  }finally{_pbReceiptBusy=false;}
}
function pbReceiptPrintCSS(){
  return '@font-face{font-family:Rabar;src:url(https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2) format(woff2);font-weight:300 800;font-display:swap}'+
  'body{margin:0;padding:24px;background:#fff;font-family:Rabar,Tahoma,Arial,sans-serif;direction:rtl}'+
  '.pb-receipt-print{max-width:720px;margin:auto;padding:30px;border:1px solid #e8edf3;border-radius:26px;box-sizing:border-box;color:#253246}'+
  '.pb-rhead{display:grid;grid-template-columns:minmax(0,1fr) auto minmax(0,1fr);align-items:center;gap:8px;padding-bottom:18px;border-bottom:1px solid #e8edf3}'+
  '.pb-rhead h2{grid-column:1/-1;grid-row:1;font-weight:500;font-size:16px;text-align:center}.pb-rhead strong{grid-column:3;grid-row:1;justify-self:end;color:#1685fa;font:bold 25px Arial}'+
  '.pb-rsection{padding:14px 0 10px;border-bottom:1px solid #e8edf3}'+
  '.pb-rsection h3{color:#1685fa;font-size:15px;font-weight:500;text-align:center}'+
  '.pb-rrefund{border-top:2px solid #0b8a66}.pb-rrefund h3{color:#087757}.pb-rnote{margin:10px 4px 4px;color:#64748b;font-size:12px;line-height:1.85;text-align:right;overflow-wrap:anywhere}'+
  '.pb-rrow{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);align-items:start;gap:18px;padding:11px 4px;font-size:14px;line-height:1.75}'+
  '.pb-rkey{color:#64748b;text-align:right;min-width:0}.pb-rval{color:#253246;font-weight:500;text-align:left;min-width:0;overflow-wrap:anywhere}.pb-rval[dir=ltr]{direction:ltr;unicode-bidi:isolate}'+
  '.pb-rfooter{padding-top:17px;font-size:12px;line-height:1.85;text-align:center;color:#64748b}'+
  '@page{size:A4;margin:12mm}@media print{html,body{width:auto!important;max-width:100%!important;background:#fff;print-color-adjust:exact;-webkit-print-color-adjust:exact}body{padding:0}.pb-receipt-print{border:0;border-radius:0;padding:0;max-width:none}.pb-rhead{padding-bottom:10px}.pb-rhead h2{margin:10px 0}.pb-rsection{padding:8px 0}.pb-rsection h3{margin:8px 0}.pb-rrow{padding:5px 4px;line-height:1.55}.pb-rfooter{padding-top:10px}.pb-rhead,.pb-rrow,.pb-rsection,.pb-rfooter{break-inside:avoid;page-break-inside:avoid}.pb-rsection h3{break-after:avoid;page-break-after:avoid}}';
}
