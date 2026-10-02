/* Proxo Balance • optional exchange UX feedback.
 * The existing app.js remains the only writer of wallets, rates, validation
 * and order submission. This file only decorates the three-step progress
 * display and highlights the currently selected quick amount. */
(function(){
  'use strict';

  function initExchangeUX(){
    var home=document.getElementById('pageHome');
    if(!home || !home.querySelector('.ux-progress')) return;
    var stages=Array.prototype.slice.call(home.querySelectorAll('.ux-progress-item'));
    var from=home.querySelector('#from');
    var to=home.querySelector('#receiveVia');
    var amount=home.querySelector('#amt');
    var phone=home.querySelector('#userPhone');
    var destination=home.querySelector('#myNum');
    var file=home.querySelector('#fileInput');
    var fileError=home.querySelector('#fileInputError');
    var picker=home.querySelector('.file-picker');
    var quick=Array.prototype.slice.call(home.querySelectorAll('.quick-amount-btn'));
    var scheduled=false;

    function valueOf(el){return el && el.value ? String(el.value).trim() : '';}

    function refresh(){
      scheduled=false;
      var amountText=valueOf(amount).replace(/,/g,'');
      var amountNum=Number(amountText);
      var fromKey=valueOf(from);
      var toKey=valueOf(to);
      var destText=destination ? destination.textContent.trim() : '';
      var destinationReady=!!destText &&
        destText!=='—' && destText!=='---' &&
        destination && !destination.classList.contains('locked-text');
      var sendEntered=!!fromKey && destinationReady &&
        Number.isFinite(amountNum) && amountNum>0;

      var recipient=valueOf(phone);
      var recipientEntered=toKey==='QiCard'
        ? recipient.length>=6
        : /^07[0-9]{9}$/.test(recipient);
      var receiveEntered=!!toKey && toKey!==fromKey && recipientEntered;

      var proofEntered=!!(file && file.files && file.files.length) &&
        !(fileError && fileError.textContent.trim());
      var complete=[sendEntered,receiveEntered,proofEntered];
      var current=complete.indexOf(false);
      if(current===-1) current=2;

      stages.forEach(function(el,i){
        var active=i===current;
        el.classList.toggle('is-current',active);
        el.classList.toggle('is-complete',!!complete[i]);
        if(active) el.setAttribute('aria-current','step');
        else el.removeAttribute('aria-current');
      });
      if(picker) picker.classList.toggle('ux-has-file',proofEntered);

      quick.forEach(function(btn){
        var raw=btn.textContent.replace(/,/g,'').trim();
        var selected=!!amountText && raw===amountText;
        btn.classList.toggle('is-selected',selected);
        btn.setAttribute('aria-pressed',selected?'true':'false');
      });
    }

    function schedule(){
      if(scheduled) return;
      scheduled=true;
      window.requestAnimationFrame(refresh);
    }

    home.addEventListener('input',function(ev){
      if(ev.target && (ev.target.id==='amt'||ev.target.id==='userPhone'||
          ev.target.id==='userSenderPhone')) schedule();
    });
    home.addEventListener('change',function(ev){
      if(ev.target && (ev.target.id==='from'||ev.target.id==='receiveVia'||
          ev.target.id==='fileInput'||ev.target.id==='amt')) schedule();
    });
    document.addEventListener('click',function(ev){
      if(ev.target && ev.target.closest &&
        ev.target.closest('.quick-amount-btn,.xc-swap-btn,.sheet-option')) schedule();
    });
    ['fromTriggerLabel','receiveViaTriggerLabel','myNum',
     'filePickerName','fileInputError'].forEach(function(id){
      var el=document.getElementById(id);
      if(el && typeof MutationObserver==='function'){
        new MutationObserver(schedule).observe(el,{
          childList:true,characterData:true,subtree:true
        });
      }
    });
    window.addEventListener('pageshow',schedule);
    refresh();
  }

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',initExchangeUX,{once:true});
  }else{
    initExchangeUX();
  }
})();
