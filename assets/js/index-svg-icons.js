/* Proxo Balance inline SVG icon renderer.
   Replaces external icon-font/mask spans with real accessible inline SVG elements. */
(function(){
'use strict';
const S={
 arrow:'<path d="m9 18 6-6-6-6"/>',
 arrowBack:'<path d="m15 18-6-6 6-6"/>',
 down:'<path d="m6 9 6 6 6-6"/>',
 up:'<path d="m6 15 6-6 6 6"/>',
 transfer:'<path d="M4 7h15m0 0-3-3m3 3-3 3M20 17H5m0 0 3 3m-3-3 3-3"/>',
 vertical:'<path d="M8 4v15m0 0-3-3m3 3 3-3M16 20V5m0 0-3 3m3-3 3 3"/>',
 user:'<circle cx="12" cy="8" r="4"/><path d="M4.5 21a7.5 7.5 0 0 1 15 0"/>',
 userPlus:'<circle cx="10" cy="8" r="4"/><path d="M3 21a7 7 0 0 1 14 0M19 8v6m-3-3h6"/>',
 check:'<path d="m5 12 4 4L19 6"/>',
 checkCircle:'<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
 close:'<circle cx="12" cy="12" r="9"/><path d="m9 9 6 6m0-6-6 6"/>',
 info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/>',
 warning:'<path d="M12 3 2.8 20h18.4L12 3Z"/><path d="M12 9v5m0 3h.01"/>',
 shield:'<path d="M12 3 5 6v5c0 4.7 2.9 8.2 7 10 4.1-1.8 7-5.3 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-5"/>',
 lock:'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>',
 key:'<circle cx="8" cy="15" r="4"/><path d="m11 12 8-8m-3 3 2 2"/>',
 bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
 history:'<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l3 2"/>',
 receipt:'<path d="M6 3h12v18l-3-2-3 2-3-2-3 2V3Z"/><path d="M9 8h6M9 12h6M9 16h4"/>',
 wallet:'<path d="M4 6h14a2 2 0 0 1 2 2v11H6a2 2 0 0 1-2-2V6Z"/><path d="M4 7c0-2 1-3 3-3h10v4M15 12h5"/>',
 card:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h4"/>',
 upload:'<path d="M12 21V8m-5 5 5-5 5 5M5 4h14"/>',
 download:'<path d="M12 3v13m-5-5 5 5 5-5M5 21h14"/>',
 image:'<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="9" r="2"/><path d="m5 17 4-4 3 3 2-2 5 5"/>',
 edit:'<path d="M4 20h4L19 9l-4-4L4 16v4Z"/><path d="m13 7 4 4"/>',
 save:'<path d="M5 3h12l2 2v16H5V3Z"/><path d="M8 3v6h8V3M8 21v-7h8v7"/>',
 search:'<circle cx="11" cy="11" r="7"/><path d="m16 16 5 5"/>',
 graph:'<path d="M4 19V5m0 14h16M7 15l4-4 3 2 5-6"/>',
 dollar:'<circle cx="12" cy="12" r="9"/><path d="M15 8.5c-.7-1-1.8-1.5-3-1.5-1.7 0-3 1-3 2.4 0 3.6 6 1.7 6 5.2 0 1.4-1.3 2.4-3 2.4-1.3 0-2.5-.5-3.2-1.5M12 5v14"/>',
 phone:'<path d="M6 3h4l2 5-2.4 2.4a16 16 0 0 0 4 4L16 12l5 2v4a3 3 0 0 1-3 3C10 20 4 14 3 6a3 3 0 0 1 3-3Z"/>',
 mail:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m4 7 8 6 8-6"/>',
 headset:'<path d="M4 14v-2a8 8 0 0 1 16 0v2M4 14h4v6H6a2 2 0 0 1-2-2v-4Zm16 0h-4v6h2a2 2 0 0 0 2-2v-4Z"/>',
 power:'<path d="M12 3v9M6.6 6.6a8 8 0 1 0 10.8 0"/>',
 refresh:'<path d="M20 7v5h-5M4 17v-5h5"/><path d="M18.5 9A7 7 0 0 0 6 6.5L4 9m2 6a7 7 0 0 0 12 2l2-2"/>',
 copy:'<rect x="8" y="8" width="12" height="12" rx="2"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
 calendar:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M8 3v4m8-4v4M3 10h18"/>',
 clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
 plus:'<path d="M12 5v14M5 12h14"/>'
};
const A={
'history-linear':'history','history-2-linear':'history','clock-circle-linear':'clock',
'close-circle-linear':'close','gallery-linear':'image','gallery-add-linear':'image',
'upload-minimalistic-linear':'upload','upload-linear':'upload','download-minimalistic-linear':'download',
'check-circle-linear':'checkCircle','check-read-linear':'checkCircle','verified-check-linear':'checkCircle',
'plain-2-linear':'arrow','transfer-horizontal-linear':'transfer','transfer-vertical-linear':'vertical',
'letter-linear':'mail','arrow-left-linear':'arrowBack','alt-arrow-left-linear':'arrowBack',
'arrow-right-linear':'arrow','alt-arrow-right-linear':'arrow','alt-arrow-down-linear':'down',
'user-linear':'user','user-id-linear':'user','user-plus-rounded-linear':'userPlus','user-check-rounded-linear':'user',
'lock-linear':'lock','key-linear':'key','shield-check-linear':'shield','shield-warning-linear':'warning','shield-linear':'shield',
'refresh-linear':'refresh','bill-list-linear':'receipt','graph-up-linear':'graph','bell-linear':'bell',
'copy-linear':'copy','magnifer-linear':'search','dollar-minimalistic-linear':'dollar','dollar-linear':'dollar',
'banknote-2-linear':'wallet','wallet-linear':'wallet','sale-linear':'dollar','info-circle-linear':'info',
'danger-triangle-linear':'warning','calendar-linear':'calendar','pen-linear':'edit','diskette-linear':'save',
'headphones-round-linear':'headset','power-linear':'power','card-linear':'card','eye-linear':'info','eye-closed-linear':'info','sun-linear':'info','moon-linear':'info','phone-linear':'phone','chat-round-dots-linear':'mail','wi-fi-router-minimalistic-linear':'wallet','wi-fi-router-round-linear':'wallet','wi-fi-router-linear':'wallet','bolt-linear':'graph','buildings-2-linear':'wallet','banknote-linear':'wallet','bell-off-linear':'bell','graph-down-linear':'graph','lock-unlocked-linear':'lock','magic-stick-3-linear':'plus','user-rounded-linear':'user','tuning-2-linear':'edit'
};
function convert(node){
 const cls=[...node.classList].find(c=>c.indexOf('icon--solar--')===0);if(!cls)return;
 const solar=cls.slice(13),key=A[solar]||'info';
 const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');
 svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('fill','none');svg.setAttribute('stroke','currentColor');
 svg.setAttribute('stroke-width','1.7');svg.setAttribute('stroke-linecap','round');svg.setAttribute('stroke-linejoin','round');
 svg.setAttribute('aria-hidden','true');svg.setAttribute('focusable','false');
 svg.classList.add('icn','pb-svg-icon','pb-svg-'+key);
 if(node.classList.contains('icn-sm'))svg.classList.add('icn-sm');
 if(node.classList.contains('icn-xl'))svg.classList.add('icn-xl');
 if(node.classList.contains('icn-spin'))svg.classList.add('icn-spin');
 svg.innerHTML=S[key]||S.info;node.replaceWith(svg);
}
function scan(root=document){
 if(root.matches?.('[class*="icon--solar--"]'))convert(root);
 root.querySelectorAll?.('[class*="icon--solar--"]').forEach(convert);
}
scan();
new MutationObserver(records=>{for(const r of records)for(const n of r.addedNodes)if(n.nodeType===1)scan(n);})
 .observe(document.documentElement,{childList:true,subtree:true});
window.PBSvgIcons={scan};
})();