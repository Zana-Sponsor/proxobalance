// Shared by the customer KYC screen and the admin review panel.
(function (root) {
  'use strict';
  function normalize(value) {
    return String(value ?? '').normalize('NFC')
      .replace(/[\u200B-\u200F\u202A-\u202E\u2066-\u2069\u0640\uFEFF]/g, '')
      .replace(/[\u00A0\u2000-\u200A\u202F\u205F\u3000]/g, ' ')
      .replace(/[\u064A\u0649]/g, '\u06CC').replace(/\u0643/g, '\u06A9').replace(/\u06BE/g, '\u0647')
      .replace(/\s+/g, ' ').trim().toLowerCase();
  }
  const AR2LAT = {
    'ا':'a','آ':'a','أ':'a','إ':'a','ء':'','ئ':'','ؤ':'w','ة':'h','ب':'b','پ':'p','ت':'t','ث':'s','ج':'j','چ':'C','ح':'h','خ':'x','د':'d','ذ':'z','ر':'r','ڕ':'r','ز':'z','ژ':'j','س':'s','ش':'S','ص':'s','ض':'z','ط':'t','ظ':'z','ع':'','غ':'g','ف':'f','ڤ':'v','ق':'q','ك':'k','ک':'k','گ':'g','ل':'l','ڵ':'l','م':'m','ن':'n','ه':'h','ھ':'h','ە':'e','و':'w','ۆ':'o','ی':'i','ي':'i','ى':'i','ێ':'e'
  };
  function scriptOf(value) {
    const text = String(value || ''), arabic = /[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]/.test(text), latin = /[A-Za-z]/.test(text);
    return arabic && latin ? 'mixed' : arabic ? 'arabic' : latin ? 'latin' : 'other';
  }
  function skeleton(token) {
    let text = String(token || '').normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
    text = text.replace(/[\u0600-\u06FF]/g, ch => AR2LAT[ch] !== undefined ? AR2LAT[ch] : ' ');
    text = text.replace(/tch|ch/g,'C').replace(/sh/g,'S').replace(/kh/g,'x').replace(/zh/g,'j').replace(/gh/g,'g').replace(/th/g,'s').replace(/ph/g,'f').replace(/ck/g,'k');
    return text.replace(/[^bptsjChxdrzSgfvqklmn]/g, '').replace(/(.)\1+/g, '$1');
  }
  function partCount(value) { const text = normalize(value); return text ? text.split(' ').filter(Boolean).length : 0; }
  function validThreePartName(value) {
    const text = normalize(value);
    return !!text && text.length >= 5 && text.length <= 120 && partCount(text) === 3 && !/[0-9٠-٩۰-۹<>{}\[\]\\/@#$%^*=+_|~]/.test(text);
  }
  function relation(accountName, identityName) {
    const a = normalize(accountName), b = normalize(identityName);
    if (!a || !b) return 'unknown';
    const at = a.split(' ').filter(Boolean), bt = b.split(' ').filter(Boolean);
    if (at.length !== 3 || bt.length !== 3) return 'different';
    if (a === b) return 'same';
    const sa = scriptOf(a), sb = scriptOf(b), ta = at.map(skeleton), tb = bt.map(skeleton);
    const enough = ta.join('').length >= 4 && tb.join('').length >= 4;
    const equal = ta.every((token, index) => token && token === tb[index]);
    if (equal && enough) return 'same_translit';
    return sa !== sb && sa !== 'other' && sb !== 'other' ? 'different_script' : 'different';
  }
  root.KycName = Object.freeze({ normalize, partCount, validThreePartName, relation });
})(window);
