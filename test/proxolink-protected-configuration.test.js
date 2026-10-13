import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {protectedConfigurationEvidence,STAGING_SETTING_NAMES,NATIVE_SETTING_NAMES} from '../scripts/proxolink-protected-configuration.mjs';

const settings={PROXO_STAGING_PROJECT_REF:'abcdefghijklmnopqrst',
 PROXO_STAGING_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',
 PROXO_STAGING_BASE_URL:'https://proxolink-staging-fixtures.vercel.app',
 PROXO_STAGING_ANON_KEY:'sb_publishable_fixture',PROXO_STAGING_TEST_EMAIL:'first@example.invalid',
 PROXO_STAGING_TEST_PASSWORD:'fictional-password-1',PROXO_STAGING_OTHER_EMAIL:'second@example.invalid',
 PROXO_STAGING_OTHER_PASSWORD:'fictional-password-2'};

test('protected configuration distinguishes uninspected account existence from missing bindings and never retains values',()=>{
 const native=Object.fromEntries(NATIVE_SETTING_NAMES.map(name=>[name,'fictional-private-value']));
 const result=protectedConfigurationEvidence({...native,UNKNOWN_SECRET:'must-not-retain'});
 assert.equal(result.native_primary_settings_present,true);
 assert.deepEqual(result.staging.missing_setting_names,STAGING_SETTING_NAMES);
 assert.equal(result.staging.account_existence_or_authentication_verified,false);
 assert.equal(result.staging.configured,false);
 const text=JSON.stringify(result);
 for(const value of ['fictional-private-value','must-not-retain','UNKNOWN_SECRET'])assert.ok(!text.includes(value));
});

test('protected audit validates isolation before hosted execution without logging project/account URLs or service keys',()=>{
 const result=protectedConfigurationEvidence(settings);
 assert.equal(result.staging.configured,true);
 assert.equal(result.staging.second_account_settings_present,true);
 assert.equal(result.staging.isolated_hosted_execution_verified,false);
 for(const value of Object.values(settings))assert.ok(!JSON.stringify(result).includes(value));
 for(const patch of [{PROXO_STAGING_PROJECT_REF:'cojchkwssmasiejcgvbk'},
   {PROXO_STAGING_BASE_URL:'https://www.proxobalance.app'},
   {PROXO_STAGING_ANON_KEY:'sb_secret_fixture'}]){
  const result=protectedConfigurationEvidence({...settings,...patch});
  assert.equal(result.staging.configured,false);assert.ok(result.staging.validation_code);
 }
});

test('hosted workflow uses the original protected environment and exact supported setting names with no production fallback',()=>{
 const source=readFileSync('.github/workflows/proxolink-native-build.yml','utf8');
 const job=source.split('  isolated-hosted-verification:')[1];assert.ok(job);
 assert.match(job,/environment: proxolink-preview-verification/);
 assert.match(job,/\[proxolink-hosted-verification\]/);
 for(const name of [...NATIVE_SETTING_NAMES,...STAGING_SETTING_NAMES])assert.ok(job.includes('secrets.'+name),name);
 assert.match(job,/if: steps\.configuration\.outputs\.staging_ready == 'true'/);
 assert.ok(!job.includes('PROXO_STAGING_TEST_PASSWORD: ${{ secrets.PROXO_NATIVE_TEST_PASSWORD'));
 assert.ok(!job.includes('toJSON(secrets)'));
});
