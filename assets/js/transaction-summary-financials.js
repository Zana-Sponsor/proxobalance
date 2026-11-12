/* Read-only display math for the standalone customer transaction summary. */
(function(root){
  'use strict';
  function numberOrNull(value){
    if(!['number','string'].includes(typeof value)||value==='')return null;
    if(typeof value==='string'&&!/^\d+(?:\.\d+)?$/.test(value))return null;
    const valueAsNumber=Number(value);
    return Number.isFinite(valueAsNumber)&&valueAsNumber>=0?valueAsNumber:null;
  }
  function breakdown(order,payout){
    const o=order||{};
    const sourceAmount=numberOrNull(o.amount);
    const total=numberOrNull(o.total);
    const discount=numberOrNull(o.reward_discount_iqd)??0;
    const netFee=numberOrNull(o.fee);
    const feeBeforeDiscount=numberOrNull(o.reward_original_fee_iqd)??(netFee===null?null:netFee+discount);
    const sameIqd=o.from_method!=='USDT'&&o.to_method!=='USDT';
    const formulaTotal=sameIqd&&sourceAmount!==null&&feeBeforeDiscount!==null
      ? sourceAmount-feeBeforeDiscount+discount : null;
    const formulaMatchesTotal=formulaTotal!==null&&total!==null&&Math.abs(formulaTotal-total)<0.01;
    const isFullRefund=!!(o.balance_refunded_at||o.balance_refund_case_id);
    const settled=!!(payout&&payout.settled&&payout.has_settlement);
    let recipientAmount=0;
    if(settled) recipientAmount=numberOrNull(payout.payout_iqd)??0;
    else if(!isFullRefund&&o.status==='پەسەندکرا') recipientAmount=total??0;
    let returnedAmount=0;
    if(settled) returnedAmount=numberOrNull(payout.remainder_iqd)??numberOrNull(o.payout_rounding_iqd)??0;
    else if(o.refund_case_amount_iqd!==null&&o.refund_case_amount_iqd!==undefined)
      returnedAmount=numberOrNull(o.refund_case_amount_iqd)??0;
    else if(o.shortfall_refunded_iqd!==null&&o.shortfall_refunded_iqd!==undefined)
      returnedAmount=numberOrNull(o.shortfall_refunded_iqd)??0;
    else if(o.payout_rounding_iqd!==null&&o.payout_rounding_iqd!==undefined)
      returnedAmount=numberOrNull(o.payout_rounding_iqd)??0;
    else if(isFullRefund&&o.from_method==='AccountBalance') returnedAmount=sourceAmount??0;
    return Object.freeze({
      sourceAmount,total,feeBeforeDiscount,netFee,discount,formulaTotal,formulaMatchesTotal,
      recipientAmount,returnedAmount,sameIqd
    });
  }
  root.ProxoTransactionSummaryFinancials=Object.freeze({breakdown,numberOrNull});
})(globalThis);
