import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const html=fs.readFileSync(path.join(root,'exchange-admin.html'),'utf8');
const admin=fs.readFileSync(path.join(root,'assets/js/admin.js'),'utf8');
const staff=fs.readFileSync(path.join(root,'assets/js/exchange-staff.js'),'utf8');
function idsOf(source){return [...source.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);}
function occurrences(source,id){return idsOf(source).filter(value=>value===id).length;}

test('all balance destinations have unique page containers and sidebar links',()=>{
 const routes=['balance','balanceRefunds','balancePayouts','balanceManual','balanceRisk'];
 for(const route of routes){
  assert.equal(occurrences(html,'pg'+route[0].toUpperCase()+route.slice(1)),1,route+' page container');
  assert.match(html,new RegExp(`goPage\\('${route}'\\)`),route+' sidebar route');
  assert.match(admin,new RegExp(`\\b${route}:\\s*\\{[^}]*load:\\(\\)=>loadBalanceAdmin\\(\\)\\}`),route+' pageConfig');
 }
});

test('balance loader and all existing workflows retain exactly one mounted target',()=>{
 const preserved=[
  'balanceAdminStats','balanceAccountList','balanceRefundReportFrom','balanceRefundReportTo','balanceRefundReportBtn',
  'balanceRefundReportStatus','balanceRefundReportError','balanceOrderSearch','balanceOrderLookupBtn','balanceFoundOrder',
  'balanceShortfallPanel','balanceShortfallForm','balanceShortfallFields','balanceShortfallAmount','balanceShortfallReason',
  'balanceShortfallPreview','balanceShortfallConfirmed','balanceShortfallBtn','balanceShortfallError','balanceShortfallSuccess',
  'balanceShortfallOrderDetails','balanceShortfallOrderHistory','balanceBankReference','balanceRefundReason',
  'balanceFundsVerified','balanceRefundError','balanceCreditBtn','balanceRefundList','balanceShortfallList',
  'balancePayoutsList','balancePayReview','balanceReviewId','balanceTransferReference','balanceDestVerification',
  'balancePayoutReceipt','balancePayoutNote','balancePayConfirmed','balancePayError','balanceRiskList',
  'bmPanel','bmTotals','bmSearch','bmSearchBtn','bmResults','bmAccount','bmAccName','bmAccSub','bmAccBal',
  'bmForm','bmAmount','bmChips','bmOrder','bmNote','bmError','bmSubmit','bmReview','bmReviewList',
  'bmReviewNote','bmConfirm','bmBack','bmSuccess','bmLog','bmLogRefresh'
 ];
 for(const id of preserved)assert.equal(occurrences(html,id),1,id);
 assert.match(admin,/balance:\s*\{[^}]*load:\(\)=>loadBalanceAdmin\(\)\}/);
});

test('staff page permissions preserve read-only overview, refund/manual access and super-admin risk gate',()=>{
 assert.match(staff,/balance:'view'/);
 assert.match(staff,/balanceRefunds:'refunds'/);
 assert.match(staff,/balancePayouts:'view'/);
 assert.match(staff,/balanceManual:'refunds'/);
 assert.match(staff,/if\(page==='balanceRisk'\)return isSuperAdmin\(\)/);
 assert.match(staff,/startBalancePayout:'approve_orders'/);
 assert.match(staff,/completeBalancePayout:'approve_orders'/);
 assert.match(staff,/creditVerifiedRefund:'refunds'/);
 assert.match(staff,/resolveBalanceRisk:'full'/);
});
