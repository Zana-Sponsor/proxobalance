// WhatsApp order-approved notifications — customer opt-in.
// Settings live in Supabase (ex_whatsapp_settings, every change also in ex_whatsapp_consent_log).
// When an order is approved, the database queues a message only for customers who switched this on;
// n8n picks it up and sends the approved Wevlix template.
(function(){
  'use strict';
  const state = { loaded:false, enabled:false, phone:null, suggested:null, busy:false };

  const $ = (id) => document.getElementById(id);

  // +9647501234567 -> 07501234567 (how Iraqi users read their number)
  function displayPhone(phone){
    if(!phone) return '';
    return /^\+964\d{10}$/.test(phone) ? '0' + phone.slice(4) : phone;
  }
  // light client check; the database normalises and validates again
  function looksValid(raw){
    const d = String(raw || '')
      .replace(/[٠-٩]/g, c => String(c.charCodeAt(0) - 0x0660))
      .replace(/[۰-۹]/g, c => String(c.charCodeAt(0) - 0x06F0))
      .replace(/[^0-9+]/g, '');
    return /^07\d{9}$/.test(d) || /^7\d{9}$/.test(d) || /^(\+|00)?964\d{10}$/.test(d) || /^(\+|00)[1-9]\d{7,14}$/.test(d);
  }

  function render(){
    const sw = $('waSwitch'), sub = $('waSub'), row = $('waRow');
    if(!sw) return;
    sw.setAttribute('aria-checked', state.enabled ? 'true' : 'false');
    sw.classList.toggle('is-on', state.enabled);
    sw.classList.toggle('is-busy', state.busy);
    sw.disabled = state.busy;
    if(row) row.classList.toggle('is-on', state.enabled);
    if(sub){
      if(state.enabled && state.phone){
        sub.innerHTML = 'چالاکە بۆ ژمارەی <span dir="ltr">' + displayPhone(state.phone) + '</span>';
      }else{
        sub.textContent = 'کاتێک داواکارییەکەت پەسەند دەکرێت';
      }
    }
  }

  function apply(data){
    if(!data) return;
    state.enabled = !!data.enabled;
    state.phone = data.phone || null;
    state.suggested = data.suggested_phone || null;
    state.loaded = true;
    render();
  }

  function errorText(err){
    const m = String((err && (err.message || err.details)) || '');
    if(/invalid_phone/.test(m)) return 'ژمارەکە دروست نییە. بە شێوەی 07501234567 بینووسە.';
    if(/phone_required/.test(m)) return 'تکایە سەرەتا ژمارەی واتسئاپەکەت بنووسە.';
    if(/not_authenticated|JWT/i.test(m)) return 'تکایە دووبارە بچۆ ژوورەوە.';
    return 'نەتوانرا پاشەکەوت بکرێت؛ تکایە دووبارە هەوڵ بدەرەوە.';
  }

  async function save(enabled, phone){
    const args = { p_enabled: !!enabled };
    if(phone) args.p_phone = phone;
    const { data, error } = await sb.rpc('ex_set_whatsapp_settings', args);
    if(error) throw error;
    apply(data);
    return data;
  }

  window.loadWhatsappSettings = async function(){
    if(typeof sb === 'undefined' || !sb || !curUser) return;
    try{
      const { data, error } = await sb.rpc('ex_my_whatsapp_settings');
      if(error) throw error;
      apply(data);
    }catch(_){ /* keep the last known state */ }
  };

  window.toggleWhatsappNotify = async function(){
    if(state.busy || !curUser) return;
    if(!state.loaded) await window.loadWhatsappSettings();
    // switching on without a saved number: ask for it first
    if(!state.enabled && !state.phone){ window.openWhatsappSheet(); return; }
    const next = !state.enabled;
    state.busy = true; state.enabled = next; render();
    try{
      await save(next);
      if(typeof showToast === 'function') showToast(next ? 'ئاگاداری واتسئاپ چالاک کرا.' : 'ئاگاداری واتسئاپ ناچالاک کرا.', 'success');
    }catch(err){
      state.enabled = !next;
      if(typeof showToast === 'function') showToast(errorText(err), 'error');
    }finally{
      state.busy = false; render();
    }
  };

  window.whatsappClearError = function(){
    const e = $('waError'), f = $('waField');
    if(e){ e.textContent = ''; e.classList.remove('show'); }
    if(f) f.classList.remove('is-error');
  };
  function showError(text){
    const e = $('waError'), f = $('waField');
    if(e){ e.textContent = text; e.classList.add('show'); }
    if(f) f.classList.add('is-error');
  }

  window.openWhatsappSheet = function(){
    const sheet = $('whatsappSheet');
    if(!sheet || !curUser) return;
    const input = $('waPhone');
    if(input) input.value = displayPhone(state.phone || state.suggested || '');
    const btn = $('waSubmit');
    if(btn){ btn.disabled = false; btn.textContent = state.enabled ? 'پاشەکەوتکردنی ژمارە' : 'چالاککردنی ئاگاداری'; }
    window.whatsappClearError();
    openSheet(sheet);
    setTimeout(() => { try{ input && input.focus({ preventScroll:true }); }catch(_){} }, 320);
  };
  window.closeWhatsappSheet = function(){
    const sheet = $('whatsappSheet');
    if(sheet && sheet.classList.contains('open')) closeSheet(sheet);
  };

  window.submitWhatsappSheet = async function(ev){
    if(ev) ev.preventDefault();
    if(state.busy) return;
    const input = $('waPhone'), btn = $('waSubmit');
    const raw = input ? input.value.trim() : '';
    if(!raw){ showError('تکایە ژمارەی واتسئاپەکەت بنووسە.'); return; }
    if(!looksValid(raw)){ showError('ژمارەکە دروست نییە. بە شێوەی 07501234567 بینووسە.'); return; }
    const wasEnabled = state.enabled;
    state.busy = true; render();
    if(btn){ btn.disabled = true; btn.textContent = 'کەمێک چاوەڕێ بکە...'; }
    try{
      await save(true, raw);
      window.closeWhatsappSheet();
      if(typeof showToast === 'function') showToast(wasEnabled ? 'ژمارەی واتسئاپ نوێ کرایەوە.' : 'ئاگاداری واتسئاپ چالاک کرا.', 'success');
    }catch(err){
      showError(errorText(err));
    }finally{
      state.busy = false; render();
      if(btn){ btn.disabled = false; btn.textContent = state.enabled ? 'پاشەکەوتکردنی ژمارە' : 'چالاککردنی ئاگاداری'; }
    }
  };
})();
