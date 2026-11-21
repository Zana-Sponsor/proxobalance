import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

// «پوختەی نرخ» is checked by the database (v83): ex_order_quote_preview, then the screen.
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const app=read('assets/js/app.js');
const sql=read('supabase/migrations/20261121163000_order_quote_preview.sql');
const css=read('assets/css/exchange-form.css');

test('the database prices a preview exactly as a new order, splits it as an approval, and changes nothing', () => {
  assert.match(sql, /create or replace function public\.ex_order_quote_preview\(p_from_method text, p_to_method text, p_amount numeric\)\nreturns jsonb\nlanguage plpgsql\nstable\nsecurity definer\nset search_path to ''/);
  // signed-in customers only
  assert.match(sql, /if auth\.uid\(\) is null then\n    raise exception 'AUTH_REQUIRED'/);
  assert.match(sql, /revoke all on function public\.ex_order_quote_preview\(text, text, numeric\) from public, anon;\ngrant execute on function public\.ex_order_quote_preview\(text, text, numeric\) to authenticated;/);
  // the order trigger's row, effective value and quote
  assert.match(sql, /select \* into v_rate from public\.ex_rates\n   where from_method = p_from_method and to_method = p_to_method and is_active\n   limit 1;/);
  assert.match(sql, /v_effective := public\.ex_effective_rate_value_b\(v_rate\.rate_type, v_rate\.rate_value, v_rate\.fee_tier_enabled,\n    v_rate\.fee_tier_limit_iqd, v_rate\.fee_tier_low_percent, v_rate\.fee_tier_high_percent, v_rate\.fee_brackets, p_amount\);/);
  assert.match(sql, /v_quote := public\.ex_order_quote\(p_amount, v_rate\.rate_type, v_effective\);/);
  // the approval's split: whole thousands to the recipient; the balance is not split
  assert.match(sql, /v_split := p_to_method <> 'AccountBalance';\n  v_payout := case when v_split then trunc\(v_total \/ 1000\) \* 1000 else v_total end;/);
  assert.match(sql, /'EXCHANGE_RATE_NOT_AVAILABLE'/);
  // read only
  assert.doesNotMatch(sql.replace(/--[^\n]*/g, ''), /\b(insert|update|delete)\b/i);
  // then with the caller's own rights: customers may already read ex_rates (ex_rates_select_auth)
  assert.match(read('supabase/migrations/20261121164500_order_quote_preview_invoker.sql'),
    /alter function public\.ex_order_quote_preview\(text, text, numeric\) security invoker;/);
});

function harness(rpc){
  const rows=new Map();
  const element=id=>{
    if(!rows.has(id)){
      const classes=new Set();
      rows.set(id,{value:'',textContent:'',innerText:'',hidden:false,disabled:false,attributes:{},
        classList:{add:c=>classes.add(c),remove:c=>classes.delete(c),toggle:(c,on)=>{ (on===undefined?!classes.has(c):on)?classes.add(c):classes.delete(c); },contains:c=>classes.has(c)},
        setAttribute(k,v){ this.attributes[k]=v; }});
    }
    return rows.get(id);
  };
  element('from').value='FastPay'; element('receiveVia').value='FIB';
  const calls=[], errors=[];
  const c=vm.createContext({document:{getElementById:element},amount:'60000',
    RATES:{'FastPay>FIB':{type:'fee_percent',value:2}},MIN_AMOUNT:10000,formatNum:v=>Number(v).toLocaleString('en-US'),fmtPct:String,
    refreshFormHints(){},updateSubmitState(){ element('submitBtn').disabled=false; },updateHeaderRate(){},
    routeAllowed:()=>true,METHOD_META:{},getWalletInfo:()=>({locked:false}),
    reportAppError:(e,d)=>{ errors.push([String(e?.message||e),d.stage]); return Promise.resolve(); },
    sb:{rpc:(name,args)=>{ calls.push([name,args]); return rpc(args,calls.length); }},
    setTimeout,clearTimeout,Promise,Date,JSON});
  vm.runInContext(read('assets/js/exchange-pricing.js')+'\n'+read('assets/js/exchange-payout-rounding.js'),c);
  vm.runInContext('function getAmtRaw(){return amount;}',c);
  vm.runInContext(app.slice(app.indexOf('function calc(){'),app.indexOf('function _validateOrderFields()')),c);
  // no waiting in tests
  const q=c.xcQ(); q.WAIT_MS=0; q.MIN_SHIMMER_MS=0;
  return {c,element,calls,errors};
}
const settle=()=>new Promise(r=>setTimeout(r,30));
const answer=(total,fee)=>({ok:true,fee,total,split:true,payout_iqd:Math.trunc(total/1000)*1000,remainder_iqd:total-Math.trunc(total/1000)*1000});

test('the figures shimmer while the database answers, then show its answer', async () => {
  const {c,element,calls}=harness(()=>Promise.resolve({data:answer(58800,1200),error:null}));
  c.calc();
  // the local layout at once, shimmering
  assert.equal(element('xcBreakdown').classList.contains('is-quoting'),true);
  assert.equal(element('xcBreakdown').attributes['aria-busy'],'true');
  assert.equal(element('bdSent').textContent,'60,000 د.ع');
  await settle();
  // (the arguments come from the page's own realm: compare their content)
  assert.equal(JSON.stringify(calls),JSON.stringify([['ex_order_quote_preview',{p_from_method:'FastPay',p_to_method:'FIB',p_amount:60000}]]));
  assert.equal(element('xcBreakdown').classList.contains('is-quoting'),false);
  assert.equal(element('xcBreakdown').attributes['aria-busy'],'false');
  assert.equal(element('bdFee').textContent,'1,200 د.ع');
  assert.equal(element('payoutDisplay').textContent,'58,000 د.ع');
  assert.equal(element('roundingDisplay').textContent,'800 د.ع');
  // asking again for the same figures does not call the database again
  c.calc(); await settle();
  assert.equal(calls.length,1);
});

test('the database wins over the local figures, and a difference is reported', async () => {
  const {c,element,errors}=harness(()=>Promise.resolve({data:answer(58700,1300),error:null}));
  c.calc(); await settle();
  assert.equal(element('bdFee').textContent,'1,300 د.ع');
  assert.equal(element('payoutDisplay').textContent,'58,000 د.ع');
  assert.equal(element('roundingDisplay').textContent,'700 د.ع');
  assert.deepEqual(errors,[['QUOTE_MISMATCH','FastPay>FIB']]);
  // the confirmation uses the same answer
  assert.equal(c.calc().remainder_iqd,700);
});

test('only the answer for the latest amount is shown', async () => {
  const later=[];
  const {c,element,calls}=harness((args)=>new Promise(r=>later.push(()=>r({data:answer(args.p_amount*0.98,args.p_amount*0.02),error:null}))));
  c.calc(); await settle();             // asks for 60,000
  c.amount='100000'; c.calc(); await settle();   // asks for 100,000 before the first answer
  assert.equal(calls.length,2);
  later[1](); await settle();            // the newer answer first
  later[0](); await settle();            // the older one arrives late and is ignored
  assert.equal(element('payoutDisplay').textContent,'98,000 د.ع');
  assert.equal(element('bdFee').textContent,'2,000 د.ع');
});

test('a route without an active price in the database is closed and cannot be confirmed', async () => {
  const {c,element}=harness(()=>Promise.resolve({data:{ok:false,code:'EXCHANGE_RATE_NOT_AVAILABLE'},error:null}));
  c.calc(); await settle();
  assert.equal(element('totalDisplay').innerText,'ئەم گۆڕینەوەیە داخراوە');
  assert.equal(element('submitBtn').disabled,true);
  assert.equal(await c.xcQuoteReady(),'closed');
});

test('when the database cannot answer, the local figures stay and the confirmation asks again', async () => {
  let fail=true;
  const {c,element,calls,errors}=harness(()=>fail?Promise.resolve({data:null,error:{message:'network'}}):Promise.resolve({data:answer(58800,1200),error:null}));
  c.xcQ().TIMEOUT_MS=50;
  c.calc(); await new Promise(r=>setTimeout(r,900));   // one retry after 700ms
  assert.equal(calls.length,2);
  assert.equal(c.xcQ().state,'error');
  assert.equal(element('xcBreakdown').classList.contains('is-quoting'),false);
  assert.equal(element('payoutDisplay').textContent,'58,000 د.ع');
  // a fixed code, never the raw error text
  assert.deepEqual(errors,[['QUOTE_RPC_FAILED','rpc']]);
  fail=false;
  assert.equal(await c.xcQuoteReady(),'ok');
  assert.equal(calls.length,3);
});

test('nothing is asked without an amount or for an amount the screen already refuses', async () => {
  const {c,element,calls}=harness(()=>Promise.resolve({data:answer(1,0),error:null}));
  for(const amount of ['', '5000', '60000.5']){ c.amount=amount; c.calc(); }
  await settle();
  assert.equal(calls.length,0);
  assert.equal(element('xcBreakdown').classList.contains('is-quoting'),false);
});

test('the confirmation waits for the database and stops without its answer', () => {
  const confirm=app.slice(app.indexOf('async function openOrderConfirm(){'),app.indexOf('function roundingExplainHTML('));
  assert.match(confirm, /if\(!_validateOrderFields\(\)\) return;\n  \/\/ [^\n]*\n  const quoteState=await xcQuoteReady\(\);/);
  assert.match(confirm, /if\(quoteState==='closed'\)\{ showToast\(/);
  assert.match(confirm, /if\(quoteState==='error'\)\{ showToast\('نرخەکە پشتڕاست نەکرایەوە؛/);
});

test('the shimmer: fee, returned amount and total in their own width, right to left, still for reduced motion', () => {
  assert.match(css, /--xf-skel: #e8ecf3; --xf-skel-hi: #f6f7f9;/);
  assert.match(css, /--xf-skel: #1b2740; --xf-skel-hi: #25324a;/);
  assert.match(css, /#xcBreakdown\.is-quoting :is\(#bdFee, #roundingDisplay, #payoutDisplay, #totalDisplay\) \{\n  position: relative; color: transparent !important;\n\}/);
  assert.doesNotMatch(css, /is-quoting[^{]*#bdSent/);
  assert.match(css, /@keyframes xf-quote-sweep \{ from \{ background-position: 0 0; \} to \{ background-position: 100% 0; \} \}/);
  assert.match(css, /@media \(prefers-reduced-motion: reduce\) \{\n  html body [^{]*#xcBreakdown\.is-quoting [^{]*::after \{ animation: none; \}/);
});
