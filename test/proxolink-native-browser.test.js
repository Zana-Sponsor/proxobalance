import test from 'node:test';
import assert from 'node:assert/strict';
import {BROWSER_CASE_IDS,foregroundBrowser,safeBrowserResults,validateBrowserResults} from '../scripts/proxolink-native-browser.mjs';
test('browser evidence requires actual foreground handoff, three resume cycles and unchanged owner-list geometry',()=>{
 assert.equal(foregroundBrowser('topResumedActivity=ActivityRecord{x com.android.chrome/BrowserActivity secret}'),'com.android.chrome');
 assert.equal(foregroundBrowser('mResumedActivity: ActivityRecord{x org.mozilla.firefox/App}'),'org.mozilla.firefox');
 assert.equal(foregroundBrowser('topResumedActivity=ActivityRecord{x com.android.intentresolver/ResolverActivity}'),null);
 assert.equal(foregroundBrowser('nonforeground com.android.chrome/BrowserActivity'),null);
 const data=Object.fromEntries(BROWSER_CASE_IDS.map(id=>[id,{passed:true,pause_observed:true,resume_observed:true,same_row_element:true,
  same_scroll_offset:true,same_row_position:true,collection_reads:1,scroll_offset:800,fictional_repository:true,public_content_verified:false,token:'secret'}]));
 const safe=safeBrowserResults(data),receipts=new Map(BROWSER_CASE_IDS.map(id=>[id,{browser_package:'com.android.chrome',existing_activity_resumed:true}])),captures=new Set(BROWSER_CASE_IDS);
 assert.doesNotMatch(JSON.stringify(safe),/secret|token/);validateBrowserResults(safe,receipts,captures);
 for(const flag of ['passed','pause_observed','resume_observed','same_row_element','same_scroll_offset','same_row_position']){
  safe[BROWSER_CASE_IDS[0]][flag]=false;assert.throws(()=>validateBrowserResults(safe,receipts,captures),/native_browser_journey_failed/);safe[BROWSER_CASE_IDS[0]][flag]=true;
 }
 assert.throws(()=>validateBrowserResults(safe,new Map(),captures),/native_browser_journey_failed/);
 assert.throws(()=>validateBrowserResults(safe,receipts,new Set()),/native_browser_journey_failed/);
 safe[BROWSER_CASE_IDS[0]].public_content_verified=true;assert.throws(()=>validateBrowserResults(safe,receipts,captures),/native_browser_journey_failed/);
});
test('failed browser state retains individual predicates and bounded counts without weakening the gate',()=>{
 const safe=safeBrowserResults({'tools-browser-1':{passed:false,failed_check:'browser_journey_state',pause_observed:false,
  resume_observed:true,same_row_element:true,same_scroll_offset:false,same_row_position:false,collection_reads:2,
  pause_count_before:0,pause_count_after:0,resume_count_before:0,resume_count_after:1,
  scroll_offset:356,scroll_offset_after:400,row_y_before:-24,row_y_after:-68,token:'secret',email:'secret'}});
 assert.equal(safe['tools-browser-1'].pause_observed,false);assert.equal(safe['tools-browser-1'].collection_reads,2);
 assert.equal(safe['tools-browser-1'].scroll_offset_after,400);assert.equal(safe['tools-browser-1'].row_y_before,-24);
 assert.doesNotMatch(JSON.stringify(safe),/secret|token|email/);
 assert.throws(()=>validateBrowserResults(safe,new Map(),new Set()),/native_browser_journey_failed/);
});
