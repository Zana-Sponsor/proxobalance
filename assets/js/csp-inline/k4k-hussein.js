/* ── مەبەستەکان: دەتوانیت دەق و ئیمۆجییەکان بگۆڕیت ── */
const INTENTS=[
  {emoji:'🏷️',label:'داواکردنی نرخ',msg:'سڵاو، دەمەوێت نرخەکان بزانم 🙏'},
  {emoji:'📦',label:'داواکاری و کڕین',msg:'سڵاو، دەمەوێت داواکارییەک بکەم'},
  {emoji:'❓',label:'پرسیارێکی تر',msg:'سڵاو، پرسیارێکم هەیە دەربارەی بەرهەم/خزمەتگوزارییەکەتان'}
];

/* ── TikTok pixel ── */
!function(w,d,t){w.TiktokAnalyticsObject=t;var ttq=w[t]=w[t]||[];ttq.methods=['page','track','identify','instances','debug','on','off','once','ready','alias','group','enableCookie','disableCookie','holdConsent','revokeConsent','grantConsent'];ttq.setAndDefer=function(t,e){t[e]=function(){t.push([e].concat(Array.prototype.slice.call(arguments,0)));};};for(var i=0;i<ttq.methods.length;i++)ttq.setAndDefer(ttq,ttq.methods[i]);ttq.instance=function(t){for(var e=ttq._i[t]||[],n=0;n<ttq.methods.length;n++)ttq.setAndDefer(e,ttq.methods[n]);return e;};ttq.load=function(e,n){var r='https://analytics.tiktok.com/i18n/pixel/events.js';ttq._i=ttq._i||{};ttq._i[e]=[];ttq._i[e]._u=r;ttq._t=ttq._t||{};ttq._t[e]=+new Date;ttq._o=ttq._o||{};ttq._o[e]=n||{};var s=d.createElement('script');s.type='text/javascript';s.async=!0;s.src=r+'?sdkid='+e+'&lib='+t;var x=d.getElementsByTagName('script')[0];x.parentNode.insertBefore(s,x);};ttq.load('D6BIIA3C77U1CE9DCUMG');ttq.page();}(window,document,'ttq');

(function(){
  var sw=document.getElementById('sw'),sheet=document.getElementById('sheet'),
      scrim=document.getElementById('scrim'),
      opts=document.getElementById('opts'),no=document.getElementById('s-no');
  var app='',baseUrl='',noText=false,videoLink='',opener=null;

  function buzz(n){if(navigator.vibrate)navigator.vibrate(n);}

  /* ── لینکی ڤیدیۆ لە ?vid=...&user=... ← دەخرێتە کۆتایی نامەکە ── */
  (function(){
    var p=new URLSearchParams(location.search),
        vid=p.get('vid'),user=p.get('user');
    if(!vid||!user)return;
    videoLink='https://www.tiktok.com/@'+user+'/video/'+vid;
  })();

  /* ── شەپۆلی دەست‌لێدان ── */
  function ripple(e){
    var el=e.currentTarget,r=el.getBoundingClientRect(),
        size=Math.max(r.width,r.height),
        x=(e.clientX||r.left+r.width/2)-r.left,
        y=(e.clientY||r.top+r.height/2)-r.top;
    var s=document.createElement('span');
    s.className='rip';
    s.style.width=s.style.height=size+'px';
    s.style.left=(x-size/2)+'px';
    s.style.top=(y-size/2)+'px';
    el.appendChild(s);
    setTimeout(function(){s.remove();},1000);
  }

  /* ── دیالۆگ ── */
  function buildOptions(){
    opts.innerHTML='';
    INTENTS.forEach(function(it){
      var b=document.createElement('button');
      b.className='opt';
      b.innerHTML='<span class="opt-ico">'+it.emoji+'</span>'+
                  '<span class="opt-lbl">'+it.label+'</span>'+
                  '<i class="fas fa-chevron-left opt-chev"></i>';
      b.addEventListener('pointerdown',ripple);
      b.addEventListener('click',function(){pick(it.msg);});
      opts.appendChild(b);
    });
  }

  function openSheet(btn){
    app=btn.dataset.app;baseUrl=btn.dataset.url;noText=btn.dataset.notext==='1';opener=btn;
    buildOptions();
    sheet.classList.remove('loaded');
    sw.classList.add('open');sw.setAttribute('aria-hidden','false');
    document.body.classList.add('locked');
    buzz(18);
    setTimeout(function(){sheet.classList.add('loaded');},550);
  }

  function closeSheet(){
    sw.classList.remove('open');
    sw.setAttribute('aria-hidden','true');
    document.body.classList.remove('locked');
    if(opener)opener.focus({preventScroll:true});
  }

  /* ── هەڵبژاردنی مەبەست ← دروستکردنی نامە ← ناردن ── */
  function pick(msg){
    var url=baseUrl;
    if(!noText){
      if(videoLink)msg=videoLink+'\n\n'+msg;
      url+=(baseUrl.indexOf('?')>-1?'&':'?')+'text='+encodeURIComponent(msg);
    }
    var lt=localStorage.getItem('tt_ct'),ct=Date.now();
    if(window.ttq&&(!lt||ct-lt>86400000)){
      ttq.track('Contact',{content_id:'contact_button',content_name:app});
      localStorage.setItem('tt_ct',ct);
    }
    buzz(12);closeSheet();
    setTimeout(function(){window.location.href=url;},560);
  }

  document.querySelectorAll('.pl-btn').forEach(function(b){
    b.addEventListener('click',function(){
      /* تیلیگرام: بێ نامە، ڕاستەوخۆ دەکرێتەوە */
      if(b.dataset.direct==='1'){
        var lt=localStorage.getItem('tt_ct'),ct=Date.now();
        if(window.ttq&&(!lt||ct-lt>86400000)){
          ttq.track('Contact',{content_id:'contact_button',content_name:b.dataset.app});
          localStorage.setItem('tt_ct',ct);
        }
        buzz(12);window.location.href=b.dataset.url;return;
      }
      openSheet(b);
    });
  });

  no.addEventListener('click',closeSheet);
  scrim.addEventListener('click',closeSheet);
  document.addEventListener('keydown',function(e){
    if(e.key==='Escape'&&sw.classList.contains('open'))closeSheet();
  });

  /* ── ڕێگری لە کۆپیکردن ── */
  ['copy','cut','contextmenu','selectstart','dragstart'].forEach(function(ev){
    document.addEventListener(ev,function(e){e.preventDefault();},{passive:false});
  });

  setTimeout(function(){
    var s=document.querySelector('.shine');if(s)s.classList.add('no-sh');
  },10000);
})();
