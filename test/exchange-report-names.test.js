import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
const script=readFileSync(new URL('../assets/js/exchange-profit.js',import.meta.url),'utf8');
function fixture(){
  const elements=new Map(),downloads=[],sheets=[],pdfSources=[],toasts=[];
  const get=id=>{if(!elements.has(id))elements.set(id,{value:'',innerHTML:'',textContent:'',hidden:false});return elements.get(id);};
  const rows=[
    {id:'internal-one',order_code:'P7K9M2Q4R6T8',handled_by:'staff-one',handling_admin_name:'ئادمینی یەکەم',deduction_iqd:2000},
    {id:'internal-two',order_code:'P8A3B5C7D9E2',handled_by:'staff-two',handling_admin_name:'=دووەم, "ئادمین"',deduction_iqd:0},
    {id:'internal-three',order_code:'P3K5J7H9G2F4',handled_by:null,handling_admin_name:null,deduction_iqd:null}
  ].map(o=>({...o,from_method:'FastPay',to_method:'FIB',amount:100000,total:100000-(o.deduction_iqd||0),accounted_at:'2026-10-06T18:00:00Z'}));
  const data={scope:'all',approved_orders:3,recorded_orders:2,unrecorded_orders:1,total_deduction_iqd:2000,today_deduction_iqd:2000,month_deduction_iqd:2000,avg_deduction_iqd:1000,
    orders:rows,by_method:[{method:'FIB',approved_orders:3,recorded_orders:2,deduction_iqd:2000}],
    by_admin:rows.map(o=>({...o,approved_orders:1,recorded_orders:o.deduction_iqd==null?0:1}))};
  const XLSX={utils:{book_new:()=>({}),aoa_to_sheet:t=>{sheets.push(t);return {};},book_append_sheet(){}},writeFile(){}};
  const html2canvas=async source=>{pdfSources.push(source.innerHTML);return {width:850,height:900,toDataURL:()=> 'data:image/jpeg;base64,fixture'};};
  const context=vm.createContext({document:{getElementById:get,body:{appendChild(){}},createElement:()=>({innerHTML:'',remove(){}})},pageConfig:{dashboard:{}},
    console,XLSX,html2canvas,window:{XLSX,html2canvas,jspdf:{jsPDF:class{addImage(){}addPage(){}save(){}}}},
    sb:{rpc:async()=>({data,error:null})},showToast:msg=>toasts.push(msg),exDownload:(text,name)=>downloads.push({text,name})});
  vm.runInContext(script,context);
  return {context,get,data,downloads,sheets,pdfSources,toasts};
}
test('profit reports identify the handler in CSV, Excel and PDF including zero fees and unattributed orders',async()=>{
  const f=fixture(),{context:c}=f;await c.loadProfitStats();
  assert.match(f.get('profitScope').textContent,/هەموو ئادمینەکان/);
  assert.equal(f.get('profitAdminSummary').hidden,false);
  assert.match(f.get('profitOrders').innerHTML,/ئادمینی یەکەم/);
  assert.match(f.get('profitOrders').innerHTML,/=دووەم, &quot;ئادمین&quot;/);
  assert.match(f.get('profitOrders').innerHTML,/نەدیاریکراو/);
  c.profitExport('csv');c.profitExport('xlsx');await c.profitExportPdf('fixture');
  assert.match(f.downloads[0].text,/ناوی ئادمین/);
  assert.match(f.downloads[0].text,/ئادمینی یەکەم/);
  assert.ok(f.downloads[0].text.includes('"\'=دووەم, ""ئادمین"""'));
  assert.ok(f.downloads[0].text.includes('"نەدیاریکراو"'));
  assert.equal(f.sheets[0][0].at(-1),'ناوی ئادمین');
  assert.deepEqual(Array.from(f.sheets[0].slice(1),r=>r.at(-1)),['ئادمینی یەکەم','\'=دووەم, "ئادمین"','نەدیاریکراو']);
  assert.equal(f.sheets[0][2][5],'0');
  assert.match(f.pdfSources[0],/<th>ناوی ئادمین<\/th>/);
  assert.match(f.pdfSources[0],/ئادمینی یەکەم/);
  assert.match(f.pdfSources[0],/=دووەم, &quot;ئادمین&quot;/);
  assert.match(f.pdfSources[0],/نەدیاریکراو/);
  for(const row of f.data.orders){assert.ok(f.pdfSources[0].includes(row.order_code));assert.ok(!f.pdfSources[0].includes(row.id));}
});
test('regular staff retain their own report and a failed reload cannot export stale data',async()=>{
  const f=fixture(),{context:c}=f;
  f.data.scope='own';f.data.orders=f.data.orders.slice(0,1);f.data.by_admin=f.data.by_admin.slice(0,1);
  await c.loadProfitStats();
  assert.equal(f.get('profitAdminSummary').hidden,true);
  assert.equal(f.get('profitAdminSummary').innerHTML,'');
  assert.match(f.get('profitScope').textContent,/خۆت/);
  c.profitExport('csv');assert.doesNotMatch(f.downloads[0].text,/دووەم/);
  c.sb.rpc=async()=>({error:{message:'Report unavailable'}});
  await c.loadProfitStats();c.profitExport('csv');assert.equal(f.downloads.length,1);
  assert.match(f.get('profitOrders').innerHTML,/Report unavailable/);
});
