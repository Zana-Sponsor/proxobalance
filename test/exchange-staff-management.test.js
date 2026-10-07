import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const source=readFileSync(new URL('../assets/js/exchange-staff.js',import.meta.url),'utf8');
function fixture(){
 const elements=new Map(),calls=[],queries=[];
 const rows=[{id:'super',role:'super_admin',is_admin:true,is_banned:false,full_name:'Super Admin',email:'super@example.invalid',staff_permissions:null},
  {id:'staff',role:'admin',is_admin:true,is_banned:false,full_name:'Fresh Staff',email:'staff@example.invalid',staff_permissions:['view']},
  {id:'blocked',role:'admin',is_admin:true,is_banned:true,full_name:'Blocked Staff',email:'blocked@example.invalid',staff_permissions:null}];
 const c=vm.createContext({adminUser:{id:'super'},allAccounts:[{id:'customer',role:'user',is_admin:false}],superMode:true,
  document:{getElementById(id){if(!elements.has(id))elements.set(id,{innerHTML:''});return elements.get(id);},addEventListener(){}},
  esc:v=>String(v),adminDbMessage:e=>e.message,
  openMo:id=>calls.push(['open',id]),closeMo:id=>calls.push(['close',id]),
  toggleBan:(...a)=>calls.push(['ban',...a]),toggleAdmin:(...a)=>calls.push(['demote',...a]),openSetPasswordModal:(...a)=>calls.push(['password',...a]),
  sb:{from(table){queries.push(table);return {select(){return this;},eq(key,value){assert.equal(key,'is_admin');assert.equal(value,true);return this;},order(){return this;},
   async range(start){if(c.failure)throw new Error('Read failed');if(c.pending)return c.pending;return {data:start===0?rows:[],error:null};}};}}});
 vm.runInContext('function isSuperAdmin(){return superMode;}\n'+source,c);
 return {c,elements,calls,queries};
}
test('super admin management reads fresh staff and routes controls through existing privileged actions',async()=>{
 const {c,elements,calls,queries}=fixture();await c.openStaffDirectory();
 assert.deepEqual(queries,['ex_profiles','ex_profiles']);
 const html=elements.get('staffDirectoryList').innerHTML;
 assert.match(html,/Super Admin/);assert.match(html,/Fresh Staff/);assert.match(html,/Blocked Staff/);assert.doesNotMatch(html,/customer/);
 for(const action of ['ban','demote','password'])assert.ok(html.includes("'"+action+"'"));
 assert.match(html,/openStaffPermissions/);
 assert.match(html,/سوپەر ئادمین/);
 c.staffDirectoryAction('staff','ban');c.staffDirectoryAction('blocked','ban');
 c.staffDirectoryAction('staff','demote');c.staffDirectoryAction('staff','password');
 assert.deepEqual(calls.filter(x=>['ban','demote','password'].includes(x[0])),[
  ['ban','staff',false],['ban','blocked',true],['demote','staff',true],['password','staff','staff@example.invalid']]);
});
test('ordinary admins cannot open staff management or reset staff passwords',async()=>{
 const {c,calls,queries}=fixture();await c.openStaffDirectory();queries.length=0;calls.length=0;c.superMode=false;
 await c.openStaffDirectory();c.staffDirectoryAction('staff','demote');
 assert.deepEqual(queries,[]);assert.deepEqual(calls,[]);
 assert.equal(c.staffPasswordAllowed('staff'),false);assert.equal(c.staffPasswordAllowed('customer'),true);
 vm.runInContext("adminStaffPermissions=['view'];",c);
 assert.equal(c.staffPasswordAllowed('customer'),false);
});
test('a failed or stale staff read cannot enable actions from an earlier directory',async()=>{
 const {c,elements,calls}=fixture();await c.openStaffDirectory();c.failure=true;calls.length=0;
 await c.openStaffDirectory();assert.match(elements.get('staffDirectoryList').innerHTML,/Read failed/);
 c.staffDirectoryAction('staff','ban');assert.equal(calls.some(x=>x[0]==='ban'),false);
 c.failure=false;let resolve;c.pending=new Promise(r=>resolve=r);
 const loading=c.openStaffDirectory();c.adminUser={id:'other'};c.superMode=false;resolve({data:[{id:'foreign',role:'admin',is_admin:true}],error:null});
 await loading;assert.doesNotMatch(elements.get('staffDirectoryList').innerHTML,/foreign/);
});
