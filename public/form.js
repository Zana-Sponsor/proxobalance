(() => {
  'use strict';

  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const $ = (id) => document.getElementById(id);

  const loadingState = $('loadingState');
  const errorState = $('errorState');
  const errorMessage = $('errorMessage');
  const formCard = $('formCard');
  const successState = $('successState');
  const formTitle = $('formTitle');
  const formDescription = $('formDescription');
  const hero = $('hero');
  const productImage = $('productImage');
  const fieldsRoot = $('fields');
  const leadForm = $('leadForm');
  const submitButton = $('submitButton');

  const pathParts = location.pathname.split('/').filter(Boolean);
  const formId = pathParts[0] === 'form' ? pathParts[1] : '';
  const params = new URLSearchParams(location.search);
  const adId = params.get('ad') || '';

  function show(el) {
    [loadingState, errorState, formCard, successState].forEach(x => x.classList.add('hidden'));
    el.classList.remove('hidden');
  }

  function fail(message) {
    errorMessage.textContent = message || 'تکایە دواتر هەوڵ بدەرەوە.';
    show(errorState);
  }

  function inputType(fieldType) {
    if (fieldType === 'phone') return 'tel';
    if (fieldType === 'email') return 'email';
    if (fieldType === 'number') return 'number';
    return 'text';
  }

  function buildField(field) {
    const wrap = document.createElement('div');
    wrap.className = 'field';

    const label = document.createElement('label');
    label.htmlFor = 'f_' + field.id;
    label.textContent = field.label || '';
    if (field.required) {
      const mark = document.createElement('span');
      mark.className = 'required';
      mark.textContent = '*';
      label.appendChild(mark);
    }

    let control;
    if (field.field_type === 'textarea') {
      control = document.createElement('textarea');
    } else if (field.field_type === 'select') {
      control = document.createElement('select');
      const empty = document.createElement('option');
      empty.value = '';
      empty.textContent = field.placeholder || 'هەڵبژێرە';
      control.appendChild(empty);
      const opts = Array.isArray(field.options) ? field.options : [];
      opts.forEach(value => {
        const option = document.createElement('option');
        option.value = String(value);
        option.textContent = String(value);
        control.appendChild(option);
      });
    } else {
      control = document.createElement('input');
      control.type = inputType(field.field_type);
      if (field.field_type === 'phone') control.inputMode = 'tel';
      if (field.field_type === 'number') control.inputMode = 'decimal';
    }

    control.id = 'f_' + field.id;
    control.name = field.field_key;
    control.dataset.fieldKey = field.field_key;
    control.dataset.fieldType = field.field_type;
    control.required = !!field.required;
    control.placeholder = field.placeholder || '';
    control.autocomplete = field.field_type === 'phone' ? 'tel'
      : field.field_type === 'email' ? 'email'
      : field.field_key === 'name' ? 'name' : 'off';

    wrap.append(label, control);
    return wrap;
  }

  function attribution() {
    const keys = ['ttclid', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term'];
    const out = {};
    keys.forEach(key => {
      const value = params.get(key);
      if (value) out[key] = value.slice(0, 500);
    });
    return out;
  }

  async function loadForm() {
    if (!UUID_RE.test(formId)) {
      fail('لینکی فۆڕمەکە دروست نییە.');
      return;
    }
    if (adId && !UUID_RE.test(adId)) {
      fail('لینکی ڕیکلامەکە دروست نییە.');
      return;
    }

    try {
      const res = await fetch('/api/forms?form_id=' + encodeURIComponent(formId), {
        headers: { Accept: 'application/json' },
        cache: 'no-store'
      });
      const payload = await res.json().catch(() => null);
      if (!res.ok || !payload?.ok) {
        fail(payload?.message || 'فۆڕمەکە نەدۆزرایەوە.');
        return;
      }

      const { form, fields } = payload.data;
      document.title = (form.title || 'Form') + ' · Proxo';
      formTitle.textContent = form.title || '';

      if (form.description) {
        formDescription.textContent = form.description;
        formDescription.classList.remove('hidden');
      }

      if (form.product_image_url) {
        productImage.src = form.product_image_url;
        productImage.alt = form.title || 'Product';
        hero.style.display = 'block';
      }

      submitButton.textContent = form.button_text || 'داواکاری بنێرە';
      fieldsRoot.replaceChildren(...(fields || []).map(buildField));
      show(formCard);
    } catch (_) {
      fail('پەیوەندی بە سێرڤەرەوە سەرکەوتوو نەبوو.');
    }
  }

  leadForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!leadForm.reportValidity()) return;

    const answers = {};
    leadForm.querySelectorAll('[data-field-key]').forEach(control => {
      answers[control.dataset.fieldKey] = String(control.value || '').trim();
    });

    submitButton.disabled = true;
    const oldText = submitButton.textContent;
    submitButton.textContent = 'دەنێردرێت…';

    try {
      const res = await fetch('/api/forms', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          form_id: formId,
          ad_id: adId || null,
          answers,
          attribution: attribution()
        })
      });
      const payload = await res.json().catch(() => null);
      if (!res.ok || !payload?.ok) {
        if (payload?.field) {
          const control = leadForm.querySelector('[data-field-key="' + CSS.escape(payload.field) + '"]');
          if (control) {
            control.focus();
            control.setCustomValidity(payload.message || 'تکایە ئەم خانەیە پڕ بکەرەوە.');
            control.reportValidity();
            setTimeout(() => control.setCustomValidity(''), 100);
          }
        } else {
          alert(payload?.message || 'ناردنی داواکاری سەرکەوتوو نەبوو.');
        }
        return;
      }
      show(successState);
    } catch (_) {
      alert('پەیوەندی بە سێرڤەرەوە سەرکەوتوو نەبوو.');
    } finally {
      submitButton.disabled = false;
      submitButton.textContent = oldText;
    }
  });

  loadForm();
})();
