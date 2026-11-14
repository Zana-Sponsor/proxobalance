// Decimal-safe IQD fee previews (tiered fees included). The database prices every order itself (ex_orders_apply_pricing).
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
  // Fee and payout for an amount, exactly like the database (ex_order_quote): payout is floored, fee = amount - payout.
  function quote(amount,rate){
    if(!Number.isFinite(Number(amount))||Number(amount)<0||Number(amount)>1000000000)throw new RangeError('Invalid IQD amount');
    const {n,d}=fraction(amount),r=fraction(rate.value);
    const base=payout(n,d,rate.type,r),fee=positive(n-base*d);
    return {total:Number(base),fee:Number(fee)/Number(d)};
  }
  // Amount-tiered fees: the first bracket whose upper limit is >= the amount (inclusive) applies; the last
  // bracket has no limit. A route with two brackets and the old {limit,low,high} shape are the same thing.
  // Returns a plain {type,value} for quote(); a route without a tier is returned as is.
  function tierOf(rate){
    const t=rate&&rate.tier;
    if(!t)return null;
    let list=null;
    if(Array.isArray(t.brackets)&&t.brackets.length>=2){
      list=t.brackets.map(function(x){return {upTo:x.upTo==null?null:Number(x.upTo),percent:Number(x.percent)};});
    }else if(Number(t.limit)>0&&Number.isFinite(Number(t.low))&&Number.isFinite(Number(t.high))){
      list=[{upTo:Number(t.limit),percent:Number(t.low)},{upTo:null,percent:Number(t.high)}];
    }
    if(!list)return null;
    for(let i=0;i<list.length;i++){
      const x=list[i],last=i===list.length-1;
      if(!Number.isFinite(x.percent)||(last?x.upTo!==null:!(x.upTo>0)))return null;
    }
    const out={brackets:list};
    if(list.length===2){out.limit=list[0].upTo;out.low=list[0].percent;out.high=list[1].percent;}
    return out;
  }
  function tierPercent(rate,amount){
    const t=tierOf(rate);
    if(!t)return null;
    const n=Number(amount);
    for(const x of t.brackets)if(x.upTo===null||n<=x.upTo)return x.percent;
    return null;
  }
  function effectiveRate(rate,amount){
    const t=tierOf(rate);
    if(!t||(rate.type!=='fee_percent'&&rate.type!=='multiplier'))return {type:rate.type,value:rate.value};
    const pct=tierPercent(rate,amount);
    // string arithmetic via toFixed keeps 1 - 2.2/100 exactly 0.978 (same as the database's numeric)
    return {type:rate.type,value:rate.type==='fee_percent'?pct:Number((1-pct/100).toFixed(10))};
  }
  root.ProxoPricing=Object.freeze({quote,effectiveRate,tierOf,tierPercent});
})(globalThis);
