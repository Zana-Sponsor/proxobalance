const NAMES = "alt-arrow-down-linear,alt-arrow-left-linear,alt-arrow-right-linear,arrow-left-down-linear,arrow-left-linear,arrow-right-linear,arrow-right-up-linear,banknote-2-linear,banknote-linear,bell-linear,bell-off-linear,bill-list-linear,bolt-linear,buildings-2-linear,calendar-linear,card-linear,chat-round-dots-linear,check-circle-linear,check-read-linear,clock-circle-linear,close-circle-linear,copy-linear,danger-triangle-linear,diskette-linear,dollar-linear,dollar-minimalistic-linear,download-minimalistic-linear,eye-closed-linear,eye-linear,gallery-linear,graph-down-linear,graph-up-linear,headphones-round-linear,history-2-linear,history-linear,info-circle-linear,key-linear,letter-linear,lock-linear,lock-unlocked-linear,magic-stick-3-linear,magnifer-linear,moon-linear,pen-linear,phone-linear,plain-2-linear,power-linear,refresh-linear,sale-linear,shield-check-linear,shield-linear,smartphone-linear,sun-linear,transfer-horizontal-linear,transfer-vertical-linear,tuning-2-linear,upload-linear,upload-minimalistic-linear,user-check-rounded-linear,user-linear,user-plus-rounded-linear,user-rounded-linear,verified-check-linear,wallet-linear,wi-fi-router-linear,wi-fi-router-minimalistic-linear,wi-fi-router-round-linear".split(',');
const grid = document.getElementById('grid');
for (const n of NAMES) {
  const c = document.createElement('div');
  c.className = 'cell';
  c.innerHTML = '<span class="icon--solar icon--solar--' + n + '"></span><code>' + n + '</code>';
  grid.appendChild(c);
}
setTimeout(() => {
  const missing = [];
  document.querySelectorAll('.cell').forEach(cell => {
    const v = getComputedStyle(cell.firstElementChild).getPropertyValue('--svg').trim();
    if (!v) { cell.classList.add('miss'); missing.push(cell.querySelector('code').textContent); }
  });
  const box = document.getElementById('status');
  if (missing.length === NAMES.length) {
    box.classList.add('bad');
    box.textContent = 'هیچ ئایکۆنێک بار نەبوو — واتە api.iconify.design ناگاتێ لای تۆ.';
  } else if (missing.length) {
    box.classList.add('bad');
    box.innerHTML = '<b>' + missing.length + ' ناو هەڵەن</b> لە کۆی ' + NAMES.length +
      '. ئەم لیستەم بۆ بنێرە:<br><code style="direction:ltr;display:block;margin-top:6px;font-size:11px">' +
      missing.join(', ') + '</code>';
  } else {
    box.textContent = 'هەموو ' + NAMES.length + ' ئایکۆنەکە دروستن. ✓';
  }
}, 1500);
