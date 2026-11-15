// WhatsApp order notifications — customer opt-in.
// Messages go ONLY to the account's verified mobile number (the one proved with a
// WhatsApp code at sign-up or on the "/change-phone" screen). There is no separate
// WhatsApp number any more, and a verified number belongs to one account only.
// Settings live in Supabase (ex_whatsapp_settings, every change also in ex_whatsapp_consent_log).
(function(){
  'use strict';
  const state = { loaded:false, enabled:false, phone:null, verified:false, busy:false };

  const $ = (id) => document.getElementById(id);

  // +9647501234567 -> 07501234567 (how Iraqi users read their number)
  function displayPhone(phone){
    if(!phone) return '';
    return /^\+964\d{10}$/.test(phone) ? '0' + phone.slice(4) : phone;
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
      if(state.loaded && !state.verified){
        sub.textContent = 'سەرەتا ژمارەی مۆبایلەکەت پشتڕاست بکەرەوە';
      }else if(state.enabled && state.phone){
        sub.innerHTML = 'چالاکە بۆ ژمارەی <span dir="ltr">' + displayPhone(state.phone) + '</span>';
      }else{
        sub.textContent = 'کاتێک داواکارییەکەت پەسەند یان ڕەت دەکرێتەوە';
      }
    }
  }

  function apply(data){
    if(!data) return;
    state.enabled = !!data.enabled;
    state.phone = data.phone || null;
    state.verified = !!data.verified && !!data.phone;
    state.loaded = true;
    render();
  }

  function errorText(err){
    const m = String((err && (err.message || err.details)) || '');
    if(/phone_not_verified|phone_required/.test(m)) return 'سەرەتا ژمارەی مۆبایلەکەت پشتڕاست بکەرەوە.';
    if(/not_authenticated|JWT/i.test(m)) return 'تکایە دووبارە بچۆ ژوورەوە.';
    return 'نەتوانرا پاشەکەوت بکرێت؛ تکایە دووبارە هەوڵ بدەرەوە.';
  }

  async function save(enabled){
    const { data, error } = await sb.rpc('ex_set_whatsapp_settings', { p_enabled: !!enabled });
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
    // no verified account number yet: explain, then send them to verify it
    if(!state.verified){ window.openWhatsappSheet(); return; }
    const next = !state.enabled;
    state.busy = true; state.enabled = next; render();
    try{
      await save(next);
      if(typeof showToast === 'function') showToast(next ? 'ئاگاداری واتسئاپ چالاک کرا بۆ ' + displayPhone(state.phone) + '.' : 'ئاگاداری واتسئاپ ناچالاک کرا.', 'success');
    }catch(err){
      state.enabled = !next;
      if(/phone_not_verified/.test(String((err && err.message) || ''))){ state.verified = false; window.openWhatsappSheet(); }
      else if(typeof showToast === 'function') showToast(errorText(err), 'error');
    }finally{
      state.busy = false; render();
    }
  };

  window.whatsappClearError = function(){
    const e = $('waError');
    if(e){ e.textContent = ''; e.classList.remove('show'); }
  };

  window.openWhatsappSheet = function(){
    const sheet = $('whatsappSheet');
    if(!sheet || !curUser) return;
    window.whatsappClearError();
    openSheet(sheet);
  };
  window.closeWhatsappSheet = function(){
    const sheet = $('whatsappSheet');
    if(sheet && sheet.classList.contains('open')) closeSheet(sheet);
  };

  // "Verify my number" → the number screen
  window.submitWhatsappSheet = function(ev){
    if(ev) ev.preventDefault();
    window.closeWhatsappSheet();
    if(typeof navigate === 'function') navigate('change-phone');
  };
})();
