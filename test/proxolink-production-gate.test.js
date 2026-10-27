import test from 'node:test';
import assert from 'node:assert/strict';
import { assertIsolatedWrites } from '../api/_lib/proxolink-pages.js';

const keys=['PROXO_SUPABASE_URL','PROXO_V6_WRITE_MODE','PROXO_V6_PRODUCTION_ENABLED'];
const original=Object.fromEntries(keys.map(k=>[k,process.env[k]]));
test.afterEach(()=>{for(const k of keys) original[k]===undefined?delete process.env[k]:process.env[k]=original[k];});
function configure(url,mode,enabled) { process.env.PROXO_SUPABASE_URL=url; process.env.PROXO_V6_WRITE_MODE=mode; process.env.PROXO_V6_PRODUCTION_ENABLED=enabled; }
const intended='https://cojchkwssmasiejcgvbk.supabase.co';
test('page authoring production mode requires explicit release flag and exact intended project',()=>{
  configure(intended,'production','true');assert.doesNotThrow(assertIsolatedWrites);
  for(const flag of ['false','','TRUE','1']) {configure(intended,'production',flag);assert.throws(assertIsolatedWrites,{code:'isolated_staging_required'});}
  for(const url of ['https://other.supabase.co',intended+'.evil.example',intended+'.',intended+':444','http://cojchkwssmasiejcgvbk.supabase.co',intended+'/path',intended+'?key=x',intended+'#x','https://user:pass@cojchkwssmasiejcgvbk.supabase.co']) {
    configure(url,'production','true');assert.throws(assertIsolatedWrites,{code:'isolated_staging_required'});
  }
});
test('isolated mode remains excluded from production even when release flag is set',()=>{
  for(const url of [intended,intended+'.',intended+':444']) { configure(url,'isolated','true');assert.throws(assertIsolatedWrites,{code:'isolated_staging_required'}); }
  configure('https://isolated.supabase.co','isolated','false');assert.doesNotThrow(assertIsolatedWrites);
  configure('http://127.0.0.1:54321','isolated','false');assert.doesNotThrow(assertIsolatedWrites);
  configure(intended,'','true');assert.throws(assertIsolatedWrites,{code:'isolated_staging_required'});
  configure('invalid','production','true');assert.throws(assertIsolatedWrites,{code:'isolated_staging_required'});
});
