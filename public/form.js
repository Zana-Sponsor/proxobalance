(() => {
  'use strict';

  const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const $ = (id) => document.getElementById(id);

  const loadingState = $('loadingState');
  const errorState = $('errorState');
  const errorMessage = $('errorMessage');
  const formExperience = $('formExperience');
  const successState = $('successState');
  const formTitle = $('formTitle');
  const formDescription = $('formDescription');
  const hero = $('hero');
  const productImage = $('productImage');
  const offerCard = $('offerCard');
  const offerText = $('offerText');
  const fieldsRoot = $('fields');
  const leadForm = $('leadForm');
  const submitButton = $('submitButton');
  const submitButtonText = $('submitButtonText');
  const submitButtonIcon = $('submitButtonIcon');
  const starsRoot = $('stars');
  const feedbackThanks = $('feedbackThanks');
  const countdownValue = $('countdownValue');
  const successAction = $('successAction');

  const pathParts = location.pathname.split('/').filter(Boolean);
  const isDemo = pathParts[0] === 'form-demo';
  const formId = isDemo ? 'demo' : (pathParts[0] === 'form' ? pathParts[1] : '');
  const params = new URLSearchParams(location.search);
  const adId = params.get('ad') || '';

  let successTimer = null;
  let lastSubmissionId = null;

  const icons = {
    person: '<svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="8" r="3.2" stroke="currentColor" stroke-width="1.8"/><path d="M5.8 19c.8-4 3-6 6.2-6s5.4 2 6.2 6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    phone: '<svg viewBox="0 0 24 24" fill="none"><path d="M7 4 9.2 8.1 7.7 9.6c1.2 2.7 3.1 4.6 5.8 5.8l1.5-1.5L19 16c.4.2.6.7.4 1.1-.7 1.6-2.2 2.7-4 2.6C9.3 19.2 4.8 14.7 4.3 8.6c-.1-1.8 1-3.3 2.6-4 .4-.2.9 0 1.1.4Z" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    location: '<svg viewBox="0 0 24 24" fill="none"><path d="M12 21s6-5.1 6-11a6 6 0 1 0-12 0c0 5.9 6 11 6 11Z" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="10" r="2.1" stroke="currentColor" stroke-width="1.8"/></svg>',
    home: '<svg viewBox="0 0 24 24" fill="none"><path d="m4 10 8-6 8 6v9H4v-9Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M9.5 19v-5h5v5" stroke="currentColor" stroke-width="1.8"/></svg>',
    box: '<svg viewBox="0 0 24 24" fill="none"><path d="m4 7 8-4 8 4-8 4-8-4Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M4 7v9l8 5 8-5V7M12 11v10" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>',
    note: '<svg viewBox="0 0 24 24" fill="none"><path d="M5 4h10l4 4v12H5V4Z" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/><path d="M15 4v5h5M8.5 13h7M8.5 16h5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>',
    email: '<svg viewBox="0 0 24 24" fill="none"><rect x="4" y="6" width="16" height="12" rx="2.5" stroke="currentColor" stroke-width="1.8"/><path d="m5.5 8 6.5 5 6.5-5" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>',
    text: '<svg viewBox="0 0 24 24" fill="none"><path d="M6 6h12M12 6v12M9 18h6" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>'
  };

  const chevron = '<svg class="select-arrow" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m8 10 4 4 4-4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  const starSvg = '<svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m12 3 2.75 5.58 6.16.9-4.46 4.34 1.05 6.13L12 17.06l-5.5 2.89 1.05-6.13L3.1 9.48l6.15-.9L12 3Z" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"/></svg>';

  function hidePrimaryStates() {
    loadingState.classList.add('hidden');
    errorState.classList.add('hidden');
    formExperience.classList.add('hidden');
  }

  function showForm() {
    hidePrimaryStates();
    formExperience.classList.remove('hidden');
  }

  function fail(message) {
    hidePrimaryStates();
    errorMessage.textContent = message || 'تکایە دواتر هەوڵ بدەرەوە.';
    errorState.classList.remove('hidden');
  }

  function inputType(fieldType) {
    if (fieldType === 'phone') return 'tel';
    if (fieldType === 'email') return 'email';
    if (fieldType === 'number') return 'number';
    return 'text';
  }

  function iconFor(field) {
    const key = String(field.field_key || '').toLowerCase();
    const type = String(field.field_type || '').toLowerCase();

    if (type === 'phone' || key.includes('phone') || key.includes('mobile')) return icons.phone;
    if (type === 'email' || key.includes('email')) return icons.email;
    if (key.includes('name') || key.includes('fullname')) return icons.person;
    if (key.includes('province') || key.includes('city') || key.includes('area') || key.includes('location')) return icons.location;
    if (key.includes('address')) return icons.home;
    if (key.includes('quantity') || key.includes('qty') || key.includes('amount') || key.includes('count')) return icons.box;
    if (type === 'textarea' || key.includes('note') || key.includes('comment')) return icons.note;
    return icons.text;
  }

  function buildField(field) {
    const wrap = document.createElement('div');
    wrap.className = 'field';

    const label = document.createElement('label');
    label.className = 'field-label';
    label.htmlFor = 'f_' + field.id;
    label.textContent = field.label || '';

    if (field.required) {
      const mark = document.createElement('span');
      mark.className = 'required';
      mark.textContent = '*';
      label.appendChild(mark);
    }

    const shell = document.createElement('div');
    shell.className = 'field-shell';

    const icon = document.createElement('span');
    icon.className = 'field-icon';
    icon.setAttribute('aria-hidden', 'true');
    icon.innerHTML = iconFor(field);

    let control;

    if (field.field_type === 'textarea') {
      control = document.createElement('textarea');
      control.rows = 4;
    } else if (field.field_type === 'select') {
      control = document.createElement('select');

      const empty = document.createElement('option');
      empty.value = '';
      empty.textContent = field.placeholder || 'هەڵبژێرە';
      control.appendChild(empty);

      const options = Array.isArray(field.options) ? field.options : [];
      options.forEach((value) => {
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
    control.autocomplete = field.field_type === 'phone'
      ? 'tel'
      : field.field_type === 'email'
        ? 'email'
        : String(field.field_key).toLowerCase().includes('name')
          ? 'name'
          : 'off';

    shell.append(icon, control);

    if (field.field_type === 'select') {
      shell.insertAdjacentHTML('beforeend', chevron);
    }

    wrap.append(label, shell);
    return wrap;
  }

  function attribution() {
    const keys = ['ttclid', 'utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term'];
    const output = {};

    keys.forEach((key) => {
      const value = params.get(key);
      if (value) output[key] = value.slice(0, 500);
    });

    return output;
  }

  function setSubmitting(isSubmitting, normalText) {
    submitButton.disabled = isSubmitting;
    submitButtonIcon.classList.toggle('hidden', isSubmitting);

    const oldSpinner = submitButton.querySelector('.submit-spinner');
    if (oldSpinner) oldSpinner.remove();

    if (isSubmitting) {
      submitButtonText.textContent = 'دەنێردرێت…';
      const spinner = document.createElement('span');
      spinner.className = 'submit-spinner';
      spinner.setAttribute('aria-hidden', 'true');
      submitButton.prepend(spinner);
    } else {
      submitButtonText.textContent = normalText || 'داواکاری بنێرە';
    }
  }

  async function loadForm() {
    if (isDemo) {
      const form = {
        title: 'سەماعاتی وایەرلێس Proxo',
        description: 'دەنگێکی پاک، دیزاینێکی مۆدێرن و باترییەکی بەردەوام.',
        product_image_url: '/assets/demo-product.svg',
        button_text: 'داواکاری بنێرە',
        offer_text: 'کاتێک 2 دانە داوا بکەیت، گەیاندن خۆڕاییە.'
      };

      const fields = [
        { id: 'demo-name', field_key: 'name', label: 'ناوی تەواو', placeholder: 'ناوی تەواوت بنووسە', field_type: 'text', required: true, options: [] },
        { id: 'demo-phone', field_key: 'phone', label: 'ژمارەی مۆبایل', placeholder: '07XX XXX XXXX', field_type: 'phone', required: true, options: [] },
        { id: 'demo-province', field_key: 'province', label: 'پارێزگا', placeholder: 'پارێزگا هەڵبژێرە', field_type: 'select', required: true, options: ['هەولێر','سلێمانی','دهۆک','کەرکووک','بەغدا'] },
        { id: 'demo-area', field_key: 'area', label: 'شار / ناوچە', placeholder: 'شار یان ناوچە بنووسە', field_type: 'text', required: true, options: [] },
        { id: 'demo-address', field_key: 'address', label: 'ناونیشان', placeholder: 'ناونیشانی تەواوت بنووسە', field_type: 'text', required: true, options: [] },
        { id: 'demo-quantity', field_key: 'quantity', label: 'بڕی داواکراو', placeholder: 'ژمارەی دانەکان هەڵبژێرە', field_type: 'select', required: true, options: ['1','2','3','4','5'] },
        { id: 'demo-note', field_key: 'note', label: 'تێبینی', placeholder: 'هەر تێبینییەکت هەیە بنووسە', field_type: 'textarea', required: false, options: [] }
      ];

      document.title = 'نمونەی فۆڕمی داواکاری · Proxo';
      formTitle.textContent = form.title;
      formDescription.textContent = form.description;
      formDescription.classList.remove('hidden');
      productImage.src = form.product_image_url;
      productImage.alt = form.title;
      hero.style.display = 'block';
      offerText.textContent = form.offer_text;
      offerCard.classList.remove('hidden');
      submitButtonText.textContent = form.button_text;
      fieldsRoot.replaceChildren(...fields.map(buildField));
      showForm();
      return;
    }

    if (!UUID_RE.test(formId)) {
      fail('لینکی فۆڕمەکە دروست نییە.');
      return;
    }

    if (adId && !UUID_RE.test(adId)) {
      fail('لینکی ڕیکلامەکە دروست نییە.');
      return;
    }

    try {
      const response = await fetch('/api/forms?form_id=' + encodeURIComponent(formId), {
        headers: { Accept: 'application/json' },
        cache: 'no-store'
      });

      const payload = await response.json().catch(() => null);

      if (!response.ok || !payload?.ok) {
        fail(payload?.message || 'فۆڕمەکە نەدۆزرایەوە.');
        return;
      }

      const { form, fields } = payload.data;

      document.title = (form.title || 'Form') + ' · Proxo';
      formTitle.textContent = form.title || 'داواکاری بەرهەم';

      if (form.description) {
        formDescription.textContent = form.description;
        formDescription.classList.remove('hidden');
      } else {
        formDescription.classList.add('hidden');
      }

      if (form.product_image_url) {
        productImage.src = form.product_image_url;
        productImage.alt = form.title || 'وێنەی بەرهەم';
        hero.style.display = 'block';
      } else {
        hero.style.display = 'none';
      }

      const currentOffer = String(
        form.offer_text ||
        form.offer ||
        form.special_offer ||
        ''
      ).trim();

      if (currentOffer) {
        offerText.textContent = currentOffer;
        offerCard.classList.remove('hidden');
      } else {
        offerCard.classList.add('hidden');
      }

      const buttonLabel = form.button_text || 'داواکاری بنێرە';
      submitButtonText.textContent = buttonLabel;

      fieldsRoot.replaceChildren(...(fields || []).map(buildField));
      showForm();
    } catch (_) {
      fail('پەیوەندی بە سێرڤەرەوە سەرکەوتوو نەبوو.');
    }
  }

  function selectRating(rating) {
    const buttons = [...starsRoot.querySelectorAll('.star')];

    buttons.forEach((button) => {
      const value = Number(button.dataset.rating);
      button.classList.toggle('active', value <= rating);
      button.setAttribute('aria-pressed', value === rating ? 'true' : 'false');
    });

    feedbackThanks.classList.remove('hidden');

    try {
      sessionStorage.setItem(
        'proxo-form-rating:' + (lastSubmissionId || formId),
        String(rating)
      );
    } catch (_) {
      // Rating UI should keep working even when storage is unavailable.
    }
  }

  function startSuccessCountdown() {
    if (successTimer) clearInterval(successTimer);

    let seconds = 6;
    countdownValue.textContent = String(seconds);

    successTimer = setInterval(() => {
      seconds -= 1;
      countdownValue.textContent = String(Math.max(seconds, 0));

      if (seconds <= 0) {
        clearInterval(successTimer);
        successTimer = null;
        location.reload();
      }
    }, 1000);
  }

  function showSuccess(submissionId) {
    lastSubmissionId = submissionId || null;

    [...starsRoot.querySelectorAll('.star')].forEach((button) => {
      button.classList.remove('active');
      button.setAttribute('aria-pressed', 'false');
    });

    feedbackThanks.classList.add('hidden');
    successState.classList.remove('hidden');
    document.body.style.overflow = 'hidden';
    startSuccessCountdown();
  }

  starsRoot.querySelectorAll('.star').forEach((button) => {
    button.innerHTML = starSvg;
    button.setAttribute('aria-pressed', 'false');

    button.addEventListener('click', () => {
      selectRating(Number(button.dataset.rating));
    });
  });

  successAction.addEventListener('click', () => {
    if (successTimer) {
      clearInterval(successTimer);
      successTimer = null;
    }
    location.reload();
  });

  leadForm.addEventListener('submit', async (event) => {
    event.preventDefault();

    if (!leadForm.reportValidity()) return;

    const answers = {};

    leadForm.querySelectorAll('[data-field-key]').forEach((control) => {
      answers[control.dataset.fieldKey] = String(control.value || '').trim();
    });

    const normalButtonText = submitButtonText.textContent;
    setSubmitting(true, normalButtonText);

    if (isDemo) {
      await new Promise((resolve) => setTimeout(resolve, 650));
      setSubmitting(false, normalButtonText);
      showSuccess('demo-submission');
      return;
    }

    try {
      const response = await fetch('/api/forms', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json'
        },
        body: JSON.stringify({
          form_id: formId,
          ad_id: adId || null,
          answers,
          attribution: attribution()
        })
      });

      const payload = await response.json().catch(() => null);

      if (!response.ok || !payload?.ok) {
        if (payload?.field) {
          const control = leadForm.querySelector(
            '[data-field-key="' + CSS.escape(payload.field) + '"]'
          );

          if (control) {
            control.focus();
            control.setCustomValidity(
              payload.message || 'تکایە ئەم خانەیە بە دروستی پڕ بکەرەوە.'
            );
            control.reportValidity();

            setTimeout(() => {
              control.setCustomValidity('');
            }, 150);
          }
        } else {
          alert(payload?.message || 'ناردنی داواکاری سەرکەوتوو نەبوو.');
        }

        return;
      }

      showSuccess(payload?.data?.submission_id || null);
    } catch (_) {
      alert('پەیوەندی بە سێرڤەرەوە سەرکەوتوو نەبوو.');
    } finally {
      setSubmitting(false, normalButtonText);
    }
  });

  loadForm();
})();
