// Decimal-safe IQD previews; the database authorizes and consumes rewards.
(function(root){
  'use strict';
  const positive=value=>value>0n?value:0n;
  function fraction(value){
    if(!Number.isFinite(Number(value))||Number(value)<0)throw new RangeError('Invalid decimal');
    const m=String(value).toLowerCase().match(/^(\d+)(?:\.(\d+))?(?:e([+-]?\d+))?$/);
    if(!m)throw new RangeError('Invalid decimal');
    const digits=m[2]||'',exponent=Number(m[3]||0);
    let n=BigInt(m[1]+digits),d=10n**BigInt(digits.length);
    if(exponent>=0)n*=10n**BigInt(exponent);
    else d*=10n**BigInt(-exponent);
    return {n,d};
  }
  function payout(n,d,type,rate){
    if(type==='fee_percent'){
      if(rate.n>100n*rate.d)throw new RangeError('Invalid fee percent');
      return positive(n*(100n*rate.d-rate.n))/(d*100n*rate.d);
    }
    if(type==='fee_fixed')return positive(n*rate.d-rate.n*d)/(d*rate.d);
    if(type==='multiplier')return n*rate.n/(d*rate.d);
    throw new RangeError('Invalid rate type');
  }
  function quote(amount,rate,reward){
    if(!Number.isFinite(Number(amount))||Number(amount)<0||Number(amount)>1000000000)throw new RangeError('Invalid IQD amount');
    const {n,d}=fraction(amount),r=fraction(rate.value);
    const base=payout(n,d,rate.type,r),baseFee=positive(n-base*d);
    let covered=0n,discount=0n;
    if(reward&&baseFee>0n){
      const cap=reward.max_amount_iqd==null?null:Number(reward.max_amount_iqd);
      if(cap!==null&&(!Number.isSafeInteger(cap)||cap<1||cap>1000000000))throw new RangeError('Invalid reward cap');
      const discountCap=reward.max_discount_iqd==null?null:Number(reward.max_discount_iqd);
      if(discountCap!==null&&(!Number.isSafeInteger(discountCap)||discountCap<1||discountCap>1000000000))throw new RangeError('Invalid maximum discount');
      covered=cap==null?n:(n<BigInt(cap)*d?n:BigInt(cap)*d);
      const excess=n-covered;
      const eligibleFee=positive(baseFee-positive(excess-payout(excess,d,rate.type,r)*d));
      if(reward.kind==='free_transactions')discount=eligibleFee;
      else if(reward.kind==='fee_discount'){
        const percent=Number(reward.discount_percent);
        if(!(percent>0&&percent<=100))throw new RangeError('Invalid discount');
        const p=fraction(reward.discount_percent);
        discount=(eligibleFee*p.n/(d*100n*p.d))*d;
      }else throw new RangeError('Invalid reward kind');
      if(discountCap!==null){const maximum=BigInt(discountCap)*d;if(discount>maximum)discount=maximum;}
    }
    discount=discount>baseFee?baseFee:positive(discount);
    const value=x=>Number(x)/Number(d);
    return {base_total:Number(base),base_fee:value(baseFee),covered_amount_iqd:value(covered),
      excess_amount_iqd:value(n-covered),discount_iqd:value(discount),
      total:value(base*d+discount),fee:value(positive(n-base*d-discount))};
  }
  function routeScope(from,to){
    if(from==='USDT'||to==='USDT')return null;
    if(from==='Korek')return 'korek';
    if(from==='Asiacell')return 'asiacell';
    if(to==='Korek')return 'korek';
    if(to==='Asiacell')return 'asiacell';
    return 'wallets';
  }
  function scopeLabel(scope){
    return scope==='korek'?'کۆڕەک':scope==='asiacell'?'ئاسیاسێڵ':'جزدانەکان';
  }
  // Amount-tiered fees: up to the limit (inclusive) the low percent applies, above it the high percent.
  // Returns a plain {type,value} so quote() stays unchanged; a route without an enabled tier is returned as is.
  function tierOf(rate){
    const t=rate&&rate.tier;
    if(!t||!(Number(t.limit)>0)||!Number.isFinite(Number(t.low))||!Number.isFinite(Number(t.high)))return null;
    return {limit:Number(t.limit),low:Number(t.low),high:Number(t.high)};
  }
  function tierPercent(rate,amount){
    const t=tierOf(rate);
    return t?(Number(amount)<=t.limit?t.low:t.high):null;
  }
  function effectiveRate(rate,amount){
    const t=tierOf(rate);
    if(!t||(rate.type!=='fee_percent'&&rate.type!=='multiplier'))return {type:rate.type,value:rate.value};
    const pct=tierPercent(rate,amount);
    // string arithmetic via toFixed keeps 1 - 2.2/100 exactly 0.978 (same as the database's numeric)
    return {type:rate.type,value:rate.type==='fee_percent'?pct:Number((1-pct/100).toFixed(10))};
  }
  root.ProxoRewardPricing=Object.freeze({quote,routeScope,scopeLabel,effectiveRate,tierOf,tierPercent});
})(globalThis);
