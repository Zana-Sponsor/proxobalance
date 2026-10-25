// Payout previews are separate from pricing. Saved settlements remain authoritative.
(function(root){
  'use strict';
  const MAX_IQD=1000000000,UNIT_IQD=1000;
  const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const PENDING=new Set(['چاوەڕوانە','ڕاستکراوەتەوە','پێویستی بە ڕاستکردنەوەیە']);
  function amount(value,whole=true){
    if(!['number','string'].includes(typeof value)||value==='')return null;
    if(typeof value==='string'&&!/^\d+(?:\.\d+)?$/.test(value))return null;
    const n=Number(value);
    return Number.isFinite(n)&&n>=0&&n<=MAX_IQD&&(!whole||Number.isSafeInteger(n))?n:null;
  }
  function appliesTo(toMethod){
    // Wallet keys are managed in the database, not a fixed built-in enum.
    return typeof toMethod==='string'&&toMethod!==''&&toMethod.trim()===toMethod&&
      !/[\u0000-\u001f\u007f]/.test(toMethod)&&!['USDT','AccountBalance'].includes(toMethod);
  }
  function plan(total,toMethod){
    const applies=appliesTo(toMethod),expected=applies?amount(total):null;
    const payout=expected===null?null:Math.floor(expected/UNIT_IQD)*UNIT_IQD;
    return Object.freeze({applies,valid:applies&&expected!==null,expected_iqd:expected,
      payout_iqd:payout,remainder_iqd:expected===null?null:expected-payout,
      requires_payout:payout!==null&&payout>0});
  }
  function forOrder(order){
    const o=order||{},p=plan(o.total,o.to_method);
    const hasSnapshot=[o.payout_settlement_id,o.payout_iqd,o.payout_rounding_iqd].some(v=>v!==null&&v!==undefined);
    if(hasSnapshot){
      const payout=amount(o.payout_iqd),remainder=amount(o.payout_rounding_iqd);
      const valid=p.valid&&UUID.test(String(o.payout_settlement_id||''))&&o.status==='پەسەندکرا'&&
        !o.balance_refunded_at&&!o.balance_refund_case_id&&payout===p.payout_iqd&&remainder===p.remainder_iqd;
      return Object.freeze({...p,valid,settled:valid,planned:false,legacy:false,has_settlement:true,
        payout_iqd:valid?payout:null,remainder_iqd:valid?remainder:null,
        requires_payout:valid&&payout>0,display_amount:valid?payout:null});
    }
    if(p.applies&&!o.balance_refunded_at&&!o.balance_refund_case_id&&PENDING.has(o.status)){
      return Object.freeze({...p,settled:false,planned:true,legacy:false,has_settlement:false,display_amount:p.payout_iqd});
    }
    // Never apply a new transfer rule retrospectively to completed or rejected orders.
    const original=amount(o.total,false);
    return Object.freeze({...p,valid:original!==null,settled:false,planned:false,legacy:true,has_settlement:false,
      payout_iqd:null,remainder_iqd:null,requires_payout:false,display_amount:original});
  }
  function canAttachReceipt(order){
    const o=order||{},p=forOrder(o);
    if(o.status!=='پەسەندکرا'||o.balance_refunded_at||o.balance_refund_case_id||!p.valid)return false;
    if(p.has_settlement){
      return p.settled&&p.requires_payout&&!o.payout_receipt_url&&amount(o.shortfall_refunded_iqd)===p.remainder_iqd;
    }
    return o.shortfall_refunded_iqd==null||amount(o.shortfall_refunded_iqd)===0;
  }
  const api=Object.freeze({plan,forOrder,canAttachReceipt,appliesTo,amount,UNIT_IQD});
  root.ProxoPayoutRounding=api;
  if(typeof module==='object'&&module.exports)module.exports=api;
})(globalThis);
