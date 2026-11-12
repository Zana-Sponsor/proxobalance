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
  // Amount-tiered fees: each max_iqd is inclusive; the final bracket is open-ended.
  // Legacy {limit,low,high} settings are normalized into the same bracket list.
  function tierOf(rate){
    const dbBrackets=rate&&(Array.isArray(rate.fee_brackets)&&rate.fee_brackets.length?rate.fee_brackets:rate.fee_tiers);
    const t=rate&&(Array.isArray(dbBrackets)&&dbBrackets.length?dbBrackets:rate.tier?.tiers);
    if(Array.isArray(t)&&t.length>=2&&t.length<=12){
      let previous=0;
      const tiers=[];
      for(let i=0;i<t.length;i++){
        const max=t[i]?.max_iqd,fee=Number(t[i]?.fee_percent);
        if(!Number.isFinite(fee)||fee<0||fee>100||(i===t.length-1?max!==null:!Number.isSafeInteger(Number(max))||Number(max)<1||Number(max)>1000000000||Number(max)<=previous))return null;
        if(i<t.length-1)previous=Number(max);
        tiers.push({max_iqd:max===null?null:Number(max),fee_percent:fee});
      }
      return {tiers};
    }
    const legacy=rate&&rate.tier?rate.tier:(rate?.fee_tier_enabled?{limit:rate.fee_tier_limit_iqd,low:rate.fee_tier_low_percent,high:rate.fee_tier_high_percent}:null);
    if(!legacy||!(Number(legacy.limit)>0)||!Number.isFinite(Number(legacy.low))||!Number.isFinite(Number(legacy.high)))return null;
    return {tiers:[{max_iqd:Number(legacy.limit),fee_percent:Number(legacy.low)},{max_iqd:null,fee_percent:Number(legacy.high)}]};
  }
  function tierPercent(rate,amount){
    const t=tierOf(rate);
    if(!t||!Number.isFinite(Number(amount)))return null;
    const match=t.tiers.find(bracket=>bracket.max_iqd===null||Number(amount)<=bracket.max_iqd);
    return match?match.fee_percent:null;
  }
  function effectiveRate(rate,amount){
    const pct=tierPercent(rate,amount);
    if(pct===null||(rate.type!=='fee_percent'&&rate.type!=='multiplier'))return {type:rate.type,value:rate.value};
    // string arithmetic via toFixed keeps 1 - 2.2/100 exactly 0.978 (same as the database's numeric)
    return {type:rate.type,value:rate.type==='fee_percent'?pct:Number((1-pct/100).toFixed(10))};
  }
  root.ProxoRewardPricing=Object.freeze({quote,routeScope,scopeLabel,effectiveRate,tierOf,tierPercent});
})(globalThis);
