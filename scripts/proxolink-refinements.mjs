// Only the approved V5 typography/wrapping/spacing/press deltas. The eight
// reusable source documents are supplied privately and never committed here.
export const TEMPLATE_ORDER=['dark','light','classic','pill','card','neon','zoom','banner'];
export function refineTemplate(source,key) {
  if(!TEMPLATE_ORDER.includes(key)||!source.includes('{{NAME}}')
    ||!source.includes('{{BIO}}')||!/<\/head>/i.test(source)
    ||source.includes('data-proxo-refinement'))throw Error('Invalid v1 refinement input');
  const name=key==='classic'?20:18;
  const css=`<style data-proxo-refinement="v5-2">
.name,.uname,.hdr-name{font-size:${name}px;font-weight:500;line-height:1.6;overflow-wrap:anywhere;max-width:100%;}
.desc,.ubio,.hdr-bio{font-weight:400;overflow-wrap:anywhere;text-wrap:balance;}
.desc,.ubio{max-width:36ch;margin-inline:auto;}
.hdr-info{min-width:0;}
.hdr-bio{max-width:36ch;}
.btn,.btn-classic,.pl-lbl,.tt-pill,.tt-badge,.tt-sm,.tt-classic,.btn-confirm,.modal-ok,.footer small{font-weight:400;}
.pl-lbl{font-size:16px;min-width:0;overflow-wrap:anywhere;}
.btn,.btn-classic,.pl-btn,.tt-pill,.tt-badge,.tt-sm,.tt-classic,.btn-confirm,.modal-ok{transition:transform 130ms ease,opacity 130ms ease;}
.btn:active,.btn-classic:active,.pl-btn:active,.tt-pill:active,.tt-badge:active,.tt-sm:active,.tt-classic:active,.btn-confirm:active,.modal-ok:active{transform:scale(.985);}
${key==='dark'||key==='light'?'.grid{margin-top:28px;}\n':''}${key==='banner'?'@media(max-width:374px){.hdr{padding:22px 16px;gap:12px;}}\n':''}
@media(prefers-reduced-motion:reduce){*,*::before,*::after{animation:none!important;transition:none!important;}.btn:active,.btn-classic:active,.pl-btn:active,.tt-pill:active,.tt-badge:active,.tt-sm:active,.tt-classic:active,.btn-confirm:active,.modal-ok:active{transform:none;}}
</style>`;
  return source
    .replaceAll('family=Inter:wght@600&display=swap','family=Inter:wght@400;500;600&display=swap')
    // Retired modal treatments are unreachable; remove them only in new v2
    // copies. Historical v1 objects and customer platform JSON stay intact.
    .replace(/#tg(?:\s+i)?\s*\{[^}]*\}/g,'')
    .replace(/\.(?:btn-confirm\.confirm-te|modal-ok\.ok-te)\s*\{[^}]*\}/g,'')
    .replaceAll("if(n==='telegram')cls='ok-te';",'')
    .replace(/<\/head>/i,css+'</head>');
}
