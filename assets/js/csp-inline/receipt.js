(function(){'use strict';
const p=new URLSearchParams(location.search), fields=['ad_id','date','age','gender','location','device','category','price','discount','total','payment','sponsor','receipt_id'];
let populated=false;for(const key of fields){const value=p.get(key);if(value!==null){document.querySelector('[data-field="'+key+'"]').textContent=value.slice(0,350);populated=true}}
if(populated)document.getElementById('hint').hidden=true;
const button=document.getElementById('download');
button.addEventListener('click',async function(){button.disabled=true;const label=button.textContent;button.textContent='چاوەڕێ بکە…';
try{if(document.fonts)await document.fonts.ready;if(!window.html2canvas||!window.jspdf)throw Error('PDF libraries unavailable');
const node=document.getElementById('receipt');const canvas=await html2canvas(node,{scale:2,backgroundColor:'#ffffff',useCORS:true,logging:false,windowWidth:Math.max(document.documentElement.clientWidth,node.scrollWidth)});
const pdf=new window.jspdf.jsPDF({orientation:'portrait',unit:'mm',format:'a4',compress:true});const margin=9,w=210-2*margin,h=canvas.height*w/canvas.width;const img=canvas.toDataURL('image/jpeg',.95);
if(h<=297-2*margin){pdf.addImage(img,'JPEG',margin,margin,w,h)}
else{const pageH=297-2*margin;let offset=0;while(offset<h){if(offset>0)pdf.addPage();pdf.addImage(img,'JPEG',margin,margin-offset,w,h);offset+=pageH}}
const safe=(p.get('ad_id')||'Proxo').replace(/[^a-zA-Z0-9_-]/g,'').slice(0,40)||'Proxo';pdf.save('Proxo-receipt-'+safe+'.pdf');
}catch(e){console.error(e);alert('نەتوانرا PDF دروست بکرێت. تکایە لە Print → Save as PDF بەکاربهێنە.')}
finally{button.disabled=false;button.textContent=label}
});
})();
