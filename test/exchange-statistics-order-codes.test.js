import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

const insights=readFileSync(new URL('../assets/js/exchange-insights.js',import.meta.url),'utf8');
const admin=readFileSync(new URL('../assets/js/admin.js',import.meta.url),'utf8');

test('statistics, code search and every report use the persisted public transaction ID',async()=>{
  const orders=[
    {id:'11111111-1111-4111-8111-111111111111',order_code:'P7K9M2Q4R6T8',order_number:123,
      user_id:'customer-one',handled_by:'staff-one',from_method:'FastPay',to_method:'FIB',amount:60000,total:58800,
      status:'approved',created_at:'2026-10-05T09:00:00Z'},
    {id:'22222222-2222-4222-8222-222222222222',order_code:'P8A3B5C7D9E2',order_number:124,
      user_id:'customer-two',handled_by:'staff-two',from_method:'QiCard',to_method:'FastPay',amount:40000,total:39200,
      status:'pending',created_at:'2026-10-05T08:00:00Z'}
  ];
  const profiles=[{id:'staff-one',full_name:'ئادمینی یەکەم'},{id:'staff-two',full_name:'=دووەم, "ئادمین"'}];
  const elements=new Map(),downloads=[],spreadsheets=[],pdfSources=[],opened=[];
  const element=id=>{
    if(!elements.has(id))elements.set(id,{value:'',innerHTML:'',textContent:'',addEventListener(){}});
    return elements.get(id);
  };
  const html2canvas=async source=>{
    pdfSources.push(source.innerHTML);
    return {width:850,height:900,toDataURL:()=> 'data:image/jpeg;base64,fixture'};
  };
  const context=vm.createContext({
    document:{getElementById:element,addEventListener(){},body:{appendChild(){}},
      createElement:()=>({innerHTML:'',remove(){}})},
    STATUS_APPROVED:'approved',STATUS_REJECTED:'rejected',STATUS_PENDING:'pending',
    STATUS_CORRECTED:'corrected',STATUS_NEEDS_CORRECTION:'needs-correction',
    METHOD_META:{},pageConfig:{},allOrders:[],showToast(){},console,
    loadProfilesFor:async()=>({}),showOrderDetail:id=>opened.push(id),
    html2canvas,window:{html2canvas,jspdf:{jsPDF:class {addImage(){}addPage(){}save(){}}}},
    XLSX:{utils:{book_new:()=>({}),aoa_to_sheet:table=>{spreadsheets.push(table);return {};},
      book_append_sheet(){}},writeFile(){}},
    sb:{from(table){
      let columns='*',id;
      const query={
        select(value){columns=value;return query;},order(){return query;},
        async in(key,ids){assert.equal(table,'ex_profiles');assert.equal(columns,'id,full_name');assert.equal(key,'id');return {data:profiles.filter(p=>ids.includes(p.id)),error:null};},
        eq(key,value){assert.equal(key,'id');id=value;return query;},
        async range(from,to){
          assert.equal(table,'ex_orders');
          const data=orders.slice(from,to+1).map(row=>Object.fromEntries(
            columns.split(',').map(key=>[key,row[key]])));
          return {data,error:null};
        },
        async maybeSingle(){return {data:orders.find(row=>row.id===id),error:null};},
        then(resolve,reject){assert.equal(table,'ex_rates');
          return Promise.resolve({data:[{id:'route-one',is_active:true}],error:null}).then(resolve,reject);}
      };
      return query;
    }}
  });
  // Use the same public-code formatter as the Transactions page.
  vm.runInContext(admin.match(/^function orderCodeOf\(o\).*$/m)[0],context);
  vm.runInContext(insights,context);
  context.exDownload=(text,name,mime)=>downloads.push({text,name,mime});

  await context.exLoadStatistics();
  for(const order of orders){
    assert.equal(context.exCode(order),context.orderCodeOf(order));
    assert.ok(element('exOrderList').innerHTML.includes('dir="ltr">'+order.order_code+'</div>'));
  }
  assert.doesNotMatch(element('exOrderList').innerHTML,/P00000000123|P00000000124/);

  // Searching with the visible transaction code must find the exact same row.
  element('exSearch').value='#'+orders[0].order_code;
  context.exStatsRender();
  assert.equal(context.exFiltered().length,1);
  assert.equal(context.exFiltered()[0].id,orders[0].id);
  assert.doesNotMatch(element('exOrderList').innerHTML,new RegExp(orders[1].order_code));
  element('exSearch').value='';

  context.exExport('csv');
  assert.match(downloads[0].text,/^\uFEFF"ئایدی مامەڵە",/);
  for(const order of orders){
    assert.ok(downloads[0].text.includes('"'+order.order_code+'",'));
    assert.ok(!downloads[0].text.includes(order.id));
  }
  assert.ok(downloads[0].text.includes('ناوی ئادمین'));
  assert.ok(downloads[0].text.includes('ئادمینی یەکەم'));
  assert.ok(downloads[0].text.includes("'=دووەم, "));
  element('exSearch').value='ئادمینی یەکەم';
  assert.equal(context.exFiltered().length,1);element('exSearch').value='';
  context.exExport('xlsx');
  assert.equal(spreadsheets[0][0][0],'ئایدی مامەڵە');
  assert.deepEqual(Array.from(spreadsheets[0].slice(1),row=>row[0]),orders.map(row=>row.order_code));
  assert.equal(spreadsheets[0][0].at(-1),'ناوی ئادمین');
  assert.equal(spreadsheets[0][1].at(-1),profiles[0].full_name);
  assert.equal(spreadsheets[0][2].at(-1),"'"+profiles[1].full_name);
  assert.equal(context.exAdminName({handled_by:'no-profile'}),'نەدیاریکراو');
  await context.exExportPdf(context.exFiltered(),'fixture-report');
  for(const order of orders){
    assert.ok(pdfSources[0].includes('<td dir="ltr">'+order.order_code+'</td>'));
    assert.ok(!pdfSources[0].includes(order.id));
  }

  assert.ok(pdfSources[0].includes('<th>ناوی ئادمین</th>'));
  assert.ok(pdfSources[0].includes('ئادمینی یەکەم'));
  assert.ok(pdfSources[0].includes('=دووەم, &quot;ئادمین&quot;'));

  // UUIDs remain the internal lookup keys when opening transaction details.
  await context.exOpenOrder(orders[0].id);
  assert.deepEqual(opened,[orders[0].id]);
  assert.equal(context.allOrders[0].order_code,orders[0].order_code);
  assert.equal(context.exCode({id:orders[0].id,order_number:123}),'—');
});

