import assert from 'node:assert/strict';
import {readFileSync,mkdirSync} from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url),{chromium}=require(process.env.PROXO_PLAYWRIGHT_MODULE||'playwright');
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const libDir=process.env.PROXO_REPORT_LIB_DIR;
if(!libDir)throw Error('Set PROXO_REPORT_LIB_DIR to the XLSX 0.18.5, html2canvas 1.4.1 and jsPDF 2.5.1 bundles (xlsx.js, html2canvas.js, jspdf.js).');
const output=process.env.PROXO_REPORT_OUTPUT_DIR||'/tmp/proxo-report-check';mkdirSync(output,{recursive:true});
const html=read('exchange-admin.html').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi,'').replace(/<link\b[^>]*>/gi,t=>{const m=t.match(/href="\/?(assets\/css\/[^"?]+)/);return m?'<style>'+read(m[1])+'</style>':'';});
const browser=await chromium.launch({headless:true,executablePath:process.env.PROXO_BROWSER_EXECUTABLE,args:['--no-sandbox']});
try{
 for(const width of [390,1280]){
  const page=await browser.newPage({viewport:{width,height:900},acceptDownloads:true});await page.route('**/*',r=>r.abort());await page.setContent(html);
  for(const lib of ['xlsx','html2canvas','jspdf'])await page.addScriptTag({path:libDir+'/'+lib+'.js'});
  await page.evaluate(()=>{
   document.getElementById('authWrap').style.display='none';
   document.getElementById('main').style.display='block';
   document.querySelectorAll('.pg').forEach(el=>el.classList.remove('on'));
   document.getElementById('pgProfit').classList.add('on');
   window.pageConfig={dashboard:{}};window.METHOD_META={};window.allOrders=[];window.showToast=()=>{};
   window.STATUS_APPROVED='پەسەندکرا';window.STATUS_REJECTED='ڕەتکرا';window.STATUS_PENDING='چاوەڕوان';window.STATUS_CORRECTED='ڕاستکراوەتەوە';window.STATUS_NEEDS_CORRECTION='پێویستی بە ڕاستکردنەوە';
   window.reportRows=[{id:'internal-one',order_code:'P7K9M2Q4R6T8',handled_by:'staff-one',handling_admin_name:'ئادمینی یەکەم',amount:100000,total:98000,deduction_iqd:2000},
    {id:'internal-two',order_code:'P8A3B5C7D9E2',handled_by:'staff-two',handling_admin_name:'ئادمینی دووەم',amount:50000,total:49000,deduction_iqd:1000}].map(o=>({...o,from_method:'FastPay',to_method:'FIB',status:STATUS_APPROVED,created_at:'2026-10-06T18:00:00Z',accounted_at:'2026-10-06T18:00:00Z'}));
   window.reportData={scope:'all',approved_orders:2,recorded_orders:2,unrecorded_orders:0,total_deduction_iqd:3000,today_deduction_iqd:3000,month_deduction_iqd:3000,avg_deduction_iqd:1500,orders:reportRows,
    by_method:[{method:'FIB',approved_orders:2,recorded_orders:2,deduction_iqd:3000}],by_admin:reportRows.map(o=>({...o,approved_orders:1,recorded_orders:1}))};
   window.sb={rpc:async(name,args)=>{
    if(name!=='ex_admin_deduction_stats_filtered')return {data:reportData,error:null};
    const rows=reportData.orders.filter(o=>args.p_unassigned?!o.handled_by:o.handled_by===args.p_admin_id),sum=rows.reduce((n,o)=>n+o.deduction_iqd,0);
    return {data:{...reportData,report_admin_id:args.p_admin_id,report_admin_name:rows[0]?.handling_admin_name,report_unassigned:args.p_unassigned,
      orders:rows,approved_orders:rows.length,total_deduction_iqd:sum,by_admin:reportData.by_admin.filter(o=>o.handled_by===args.p_admin_id),
      by_method:[{method:'FIB',approved_orders:rows.length,recorded_orders:rows.length,deduction_iqd:sum}]},error:null};
   },from:table=>({select(){return this;},order(){return this;},
    async range(){return {data:reportRows,error:null};},async in(){return {data:reportRows.map(o=>({id:o.handled_by,full_name:o.handling_admin_name})),error:null};},
    then(resolve,reject){return Promise.resolve({data:[{id:'route',is_active:true}],error:null}).then(resolve,reject);}})};
   const capture=window.html2canvas;
   window.pdfTables=[];
   window.html2canvas=async(source,options)=>{
    pdfTables.push([...source.querySelectorAll('table:last-of-type tbody tr')].map(tr=>[...tr.cells].map(td=>td.textContent)));
    if(source.scrollWidth>source.clientWidth)throw Error('PDF table overflow');
    return capture(source,options);
   };
  });
  await page.addScriptTag({content:read('assets/js/exchange-insights.js')});await page.addScriptTag({content:read('assets/js/exchange-profit.js')});
  await page.evaluate(()=>loadProfitStats());
  assert.equal(await page.locator('#profitAdminSummary').isVisible(),true);
  assert.equal(await page.locator('#profitOrders bdi').count(),2);
  for(const card of await page.locator('#profitOrders .profit-order').all()){
   const b=await card.boundingBox();assert.ok(b.x>=0&&b.x+b.width<=width+1,'Profit cards fit the viewport');
  }
  if(width===390)await page.locator('#pgProfit').screenshot({path:output+'/profit-mobile.png'});
  for(const module of ['profit','statistics']){
   if(module==='statistics')await page.evaluate(()=>{document.getElementById('pgProfit').classList.remove('on');document.getElementById('pgStatistics').classList.add('on');return exLoadStatistics();});
   for(const kind of ['csv','xlsx','pdf']){
    // Chromium throttles bursts of automatic downloads; use normal user click cadence.
    await page.waitForTimeout(1200);
    const pending=page.waitForEvent('download');
    await page.evaluate(({module,kind})=>module==='profit'?profitExport(kind):exExport(kind),{module,kind});
    const download=await pending,path=output+'/'+module+'-'+width+'.'+kind;await download.saveAs(path);assert.equal(await download.failure(),null);
    const file=readFileSync(path);assert.ok(file.length>100);
    if(kind==='csv'){const csv=file.toString();assert.ok(csv.includes('ناوی ئادمین'));assert.ok(csv.includes('ئادمینی یەکەم'));assert.ok(csv.includes('ئادمینی دووەم'));}
    if(kind==='xlsx'){
     const rows=await page.evaluate(b64=>{const wb=XLSX.read(b64,{type:'base64'});return XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]],{header:1});},file.toString('base64'));
     assert.equal(rows[0].at(-1),'ناوی ئادمین');assert.deepEqual(rows.slice(1).map(r=>r.at(-1)),['ئادمینی یەکەم','ئادمینی دووەم']);
    }
    if(kind==='pdf'){assert.equal(file.subarray(0,5).toString(),'%PDF-');const table=await page.evaluate(()=>pdfTables.at(-1));assert.deepEqual(table.map(r=>r.at(-1)),['ئادمینی یەکەم','ئادمینی دووەم']);assert.deepEqual(table.map(r=>r[0]),['P7K9M2Q4R6T8','P8A3B5C7D9E2']);}
   }
   const selector=module==='profit'?'#profitAdmin':'#exAdmin';
   await page.locator(selector).selectOption('staff-two');
   if(module==='profit')await page.waitForFunction(()=>document.querySelectorAll('#profitOrders .profit-order').length===1&&document.getElementById('profitOrders').textContent.includes('P8A3B5C7D9E2'));
   for(const kind of ['csv','xlsx','pdf']){
    // Chromium throttles bursts of automatic downloads; use normal user click cadence.
    await page.waitForTimeout(1200);
    const pending=page.waitForEvent('download');
    await page.evaluate(({module,kind})=>module==='profit'?profitExport(kind):exExport(kind),{module,kind});
    const download=await pending,path=output+'/'+module+'-selected-'+width+'.'+kind;await download.saveAs(path);
    assert.ok(download.suggestedFilename().includes('ئادمینی دووەم'),'Filename identifies the selected admin');
    const file=readFileSync(path);
    if(kind==='csv'){const text=file.toString();assert.ok(text.includes('P8A3B5C7D9E2'));assert.ok(!text.includes('P7K9M2Q4R6T8'));assert.ok(!text.includes('ئادمینی یەکەم'));}
    if(kind==='xlsx'){
     const rows=await page.evaluate(b64=>{const wb=XLSX.read(b64,{type:'base64'});return XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]],{header:1});},file.toString('base64'));
     assert.equal(rows.length,2);assert.equal(rows[1][0],'P8A3B5C7D9E2');assert.equal(rows[1].at(-1),'ئادمینی دووەم');
    }
    if(kind==='pdf'){const table=await page.evaluate(()=>pdfTables.at(-1));assert.equal(table.length,1);assert.equal(table[0][0],'P8A3B5C7D9E2');assert.equal(table[0].at(-1),'ئادمینی دووەم');}
   }
   await page.locator(selector).selectOption('');
   if(module==='profit')await page.waitForFunction(()=>document.querySelectorAll('#profitOrders .profit-order').length===2);
  }
  await page.evaluate(()=>{reportData.scope='own';reportData.orders=reportRows.slice(0,1);return loadProfitStats();});
  assert.equal(await page.locator('#profitAdminSummary').isVisible(),false);
  assert.equal(await page.locator('#profitAdminFilter').isVisible(),false);
  assert.ok((await page.locator('#profitScope').textContent()).includes('خۆت'));
  await page.close();console.log('PASS: '+width+'px real all/selected-admin CSV/Excel/PDF downloads, isolated rows, names, P codes and report layout');
 }
}finally{await browser.close();}
