// receipt-read — reads one order's receipt image with Gemini and saves what it found.
//
// Called only by the database (ex_receipt_read_queue, from the trigger on ex_orders when an
// order gets a receipt, and from the panel's «دووبارە خوێندنەوە»). The caller sends the
// reader key in x-receipt-key; only its sha256 is in ex_receipt_read_keys, and the same key
// lets ex_receipt_read_save store the result. The function answers at once and reads in the
// background. Gemini's key is the Edge Function secret GEMINI_API_KEY (Supabase Dashboard →
// Edge Functions → Secrets); without it a reading is saved as an error and nothing else
// happens. A reading only helps the admin: it never approves, rejects or blocks an order.
// The fast model reads first. The stronger model is asked once when Gemini answers that the
// fast one is busy (429/5xx) or it does not answer in time, and when the fast one finds no
// receipt or no amount. The model whose answer is saved is saved with it.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { encodeBase64 } from 'jsr:@std/encoding@1/base64';

const SUPABASE_URL = (Deno.env.get('SUPABASE_URL') || '').replace(/\/$/, '');
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const MODEL = Deno.env.get('RECEIPT_READ_MODEL') || 'gemini-3.5-flash-lite';
const FALLBACK = Deno.env.get('RECEIPT_READ_FALLBACK_MODEL') || 'gemini-3.5-flash';
const BUSY = new Set([429, 500, 502, 503, 504]);
const RECEIPTS = `${SUPABASE_URL}/storage/v1/object/public/receipts/`;
const MAX_BYTES = 15 * 1024 * 1024;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const db = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { persistSession: false } });

const PROMPT = [
  'You are reading a screenshot or photo of a money-transfer receipt from an Iraqi wallet or bank app (for example FIB, FastPay, Qi Card / Qi Services, Zain Cash, AsiaHawala, Korek, NassWallet) or a crypto transfer (USDT).',
  'The receipt may be written in Central Kurdish (Sorani), Arabic or English. Read every line, including small grey text.',
  'Read only what is printed on it. Never guess or invent a value; use null when a value is not printed.',
  'Convert Arabic-Indic and Persian digits to Western digits.',
  'wallet: the app, wallet or bank name, from its printed name or its logo.',
  'amount: the transferred amount as a plain number, without thousands separators or currency. If a fee is shown separately, the amount does not include it.',
  'currency: IQD for Iraqi dinar (IQD, د.ع, دينار, دینار), USD or USDT when printed.',
  'reference: the transaction / reference / operation number exactly as printed, letters and digits kept. Its label may be Transaction ID, Reference, Ref, ژمارەی مامەڵە, ژمارەی گواستنەوە, کۆدی مامەڵە, ناسنامەی مامەڵە, رقم العملية, رقم المعاملة, رقم المرجع.',
  'paid_at: the date and time as printed, as ISO 8601 when it is clear. Its label may be Date, Time, بەروار, کات, ڕێکەوت, التاريخ, الوقت.',
  'sender_* and receiver_*: the names and the account or phone numbers of the two sides as printed (labels such as From, To, نێرەر, وەرگر, لە, بۆ, المرسل, المستلم).',
  'status_text: the status words as printed (for example Successful, ناجحة).',
  'success: true when the receipt shows the transfer succeeded, false when it shows failed, pending or cancelled, null when it does not say.',
  'is_receipt: false when the image is not a payment receipt at all.',
  'notes: one short sentence in Central Kurdish (Sorani, Arabic script) only when something looks wrong: numbers that look edited, pasted or misaligned, mixed fonts or sizes, blurred or smudged areas around the amount or number, cut-off parts, a layout unlike the app it claims to be, a date in the future, a pending or failed status. Otherwise an empty string.'
].join('\n');
const S = { type: 'STRING', nullable: true };
const N = { type: 'NUMBER', nullable: true };
const SCHEMA = {
  type: 'OBJECT', required: ['is_receipt'], properties: {
    is_receipt: { type: 'BOOLEAN' }, wallet: S, success: { type: 'BOOLEAN', nullable: true }, status_text: S,
    amount: N, currency: S, fee: N, reference: S, paid_at: S,
    sender_name: S, sender_account: S, receiver_name: S, receiver_account: S, notes: S
  }
};

async function sha256Hex(text: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
}
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

// one question to Gemini; a timeout or a network failure counts as busy (504)
async function ask(model: string, gemini: string, mime: string, data: string, ms: number) {
  try {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': gemini },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: `${PROMPT}\nToday is ${new Date().toISOString().slice(0, 10)} (UTC); only a later date is in the future.` }, { inlineData: { mimeType: mime, data } }] }],
        // full resolution: transaction numbers and dates are small text
        generationConfig: { temperature: 0, mediaResolution: 'MEDIA_RESOLUTION_HIGH', responseMimeType: 'application/json', responseSchema: SCHEMA }
      }),
      signal: AbortSignal.timeout(ms)
    });
    return { status: res.status, out: await res.json().catch(() => ({})) };
  } catch (error) {
    return { status: 504, out: { error: { status: 'TIMEOUT', message: String((error as Error)?.message || error) } } };
  }
}

async function readReceipt(key: string, orderId: string) {
  let sourceReceiptUrl: string | null = null;
  const save = async (result: Record<string, unknown>, model = MODEL) => {
    const { error } = await db.rpc('ex_receipt_read_save', { p_key: key, p_order_id: orderId, p_result: { ...result, model, receipt_url: sourceReceiptUrl } });
    if (error) console.error('receipt-read save failed', error.message);
  };
  try {
    const { data: order } = await db.from('ex_orders').select('id,user_id,receipt_url').eq('id', orderId).maybeSingle();
    if (!order?.receipt_url || !String(order.receipt_url).startsWith(RECEIPTS)) return;
    sourceReceiptUrl = String(order.receipt_url);
    const gemini = Deno.env.get('GEMINI_API_KEY') || '';
    if (!gemini) { await save({ error: 'gemini_key_missing' }); return; }

    // the receipts bucket is private: the file is taken with the service key, by its path
    const path = decodeURIComponent(sourceReceiptUrl.slice(RECEIPTS.length).split('?')[0]);
    const segments = path.split('/');
    if (segments[0] !== order.user_id || segments.length < 2 || segments.some(part => !part || part === '.' || part === '..')) {
      await save({ error: 'invalid_receipt_path' }); return;
    }
    const { data: file, error: fileError } = await db.storage.from('receipts').download(path);
    if (fileError || !file) { await save({ error: 'download_failed ' + String(fileError?.message || '').slice(0, 80) }); return; }
    if (file.size > MAX_BYTES) { await save({ error: 'file_too_large' }); return; }
    const byName = /\.png$/i.test(path) ? 'image/png' : /\.webp$/i.test(path) ? 'image/webp' : /\.pdf$/i.test(path) ? 'application/pdf' : /\.hei[cf]$/i.test(path) ? 'image/heic' : 'image/jpeg';
    const mime = (String(file.type || '').split(';')[0].trim() || byName).replace('application/octet-stream', byName);
    if (!/^(image\/(jpeg|png|webp|heic|heif)|application\/pdf)$/.test(mime)) { await save({ error: 'unsupported_file ' + mime }); return; }
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length > MAX_BYTES) { await save({ error: 'file_too_large' }); return; }
    const data = encodeBase64(bytes);

    // the whole reading stays inside the Edge Function's time: 40 s, a pause, then 90 s
    let model = MODEL;
    let { status, out } = await ask(MODEL, gemini, mime, data, 40000);
    if (BUSY.has(status) && FALLBACK && FALLBACK !== MODEL) {
      await new Promise(r => setTimeout(r, 2000));
      model = FALLBACK;
      ({ status, out } = await ask(FALLBACK, gemini, mime, data, 90000));
    }
    if (status >= 400 || out.error) {
      await save({ error: `gemini_${status} ${String(out?.error?.status || '')} ${String(out?.error?.message || '').slice(0, 200)}`.trim() }, model);
      return;
    }
    const text = (out.candidates?.[0]?.content?.parts || []).map((p: { text?: string }) => p.text || '').join('').trim();
    if (!text) { await save({ error: 'empty_answer ' + String(out.promptFeedback?.blockReason || '') }, model); return; }
    let result: Record<string, unknown>;
    try { result = JSON.parse(text); } catch { await save({ error: 'unreadable_answer' }, model); return; }

    // when the fast model found no receipt or no amount, the stronger model looks once more;
    // its answer is used only when it gives one
    if (model === MODEL && FALLBACK && FALLBACK !== MODEL && (result.is_receipt === false || result.amount == null)) {
      const second = await ask(FALLBACK, gemini, mime, data, 90000);
      const secondText = (second.out?.candidates?.[0]?.content?.parts || []).map((p: { text?: string }) => p.text || '').join('').trim();
      if (second.status < 400 && !second.out?.error && secondText) {
        try { result = JSON.parse(secondText); model = FALLBACK; } catch { /* keep the first answer */ }
      }
    }
    await save(result, model);
  } catch (error) {
    await save({ error: String((error as Error)?.message || error).slice(0, 300) }).catch(() => {});
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return reply(405, { error: 'method_not_allowed' });
  const key = req.headers.get('x-receipt-key') || '';
  if (!/^rk_[0-9a-f]{48}$/.test(key)) return reply(401, { error: 'not_allowed' });
  const { data: known } = await db.from('ex_receipt_read_keys').select('id').eq('key_hash', await sha256Hex(key)).eq('active', true).limit(1);
  if (!known?.length) return reply(401, { error: 'not_allowed' });
  const body = await req.json().catch(() => ({}));
  const orderId = String(body?.order_id || '');
  if (!UUID.test(orderId)) return reply(422, { error: 'bad_order' });
  // answer now; the reading takes a few seconds and is saved by itself
  // deno-lint-ignore no-explicit-any
  const runtime = (globalThis as any).EdgeRuntime;
  if (runtime?.waitUntil) runtime.waitUntil(readReceipt(key, orderId));
  else await readReceipt(key, orderId);
  return reply(202, { queued: true });
});
