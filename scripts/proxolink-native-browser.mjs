export const BROWSER_CASE_IDS=['tools-browser-1','tools-browser-2','tools-browser-3'];
const packages=['com.android.chrome','org.mozilla.firefox','com.android.browser'];
// Observe only the foreground component. Never retain the native dump, URL,
// account/session fields or arbitrary package strings.
export function foregroundBrowser(dump){
 const lines=String(dump||'').split('\n');
 const line=lines.find(l=>/topResumedActivity/.test(l))||lines.find(l=>/mResumedActivity/.test(l));
 return packages.find(p=>line?.includes(p+'/'))||null;
}
export function safeBrowserResults(data){
 const flags=['passed','pause_observed','resume_observed','same_row_element','same_scroll_offset','same_row_position',
  'public_content_verified','fictional_repository'];
 const errors=['browser_journey_ack','browser_journey_element','browser_journey_state','browser_journey_unclassified'];
 return Object.fromEntries(BROWSER_CASE_IDS.filter(id=>data?.[id]).map(id=>{
  const item=data[id],out=Object.fromEntries(flags.filter(k=>typeof item[k]==='boolean').map(k=>[k,item[k]]));
  for(const key of ['collection_reads','pause_count_before','pause_count_after','resume_count_before','resume_count_after'])
   if(Number.isInteger(item[key])&&item[key]>=0&&item[key]<=100000)out[key]=item[key];
  for(const key of ['scroll_offset_after','row_x_before','row_y_before','row_x_after','row_y_after'])
   if(Number.isFinite(item[key])&&Math.abs(item[key])<100000)out[key]=item[key];
  if(Number.isFinite(item.scroll_offset)&&item.scroll_offset>0&&item.scroll_offset<100000)out.scroll_offset=item.scroll_offset;
  if(errors.includes(item.failed_check))out.failed_check=item.failed_check;
  return[id,out];
 }));
}
export function validateBrowserResults(data,receipts,captures){
 if(Object.keys(data).length!==3||receipts.size!==3||captures.size!==3||!BROWSER_CASE_IDS.every(id=>{
  const item=data[id],receipt=receipts.get(id);
  return ['passed','pause_observed','resume_observed','same_row_element','same_scroll_offset','same_row_position','fictional_repository'].every(k=>item?.[k]===true)
   &&item.public_content_verified===false&&item.collection_reads===1&&item.scroll_offset>0&&captures.has(id)
   &&packages.includes(receipt?.browser_package)&&receipt?.existing_activity_resumed===true;
 }))throw Error('native_browser_journey_failed');
 return data;
}
