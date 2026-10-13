import {appendFileSync,mkdirSync,writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import {validateStagingConfiguration} from './proxolink-staging-verification.mjs';

export const NATIVE_SETTING_NAMES=['PROXO_NATIVE_ANON_KEY','PROXO_NATIVE_TEST_EMAIL',
  'PROXO_NATIVE_TEST_PASSWORD','PROXO_NATIVE_VERCEL_BYPASS'];
export const STAGING_SETTING_NAMES=['PROXO_STAGING_PROJECT_REF','PROXO_STAGING_SUPABASE_URL',
  'PROXO_STAGING_BASE_URL','PROXO_STAGING_ANON_KEY','PROXO_STAGING_TEST_EMAIL',
  'PROXO_STAGING_TEST_PASSWORD','PROXO_STAGING_OTHER_EMAIL','PROXO_STAGING_OTHER_PASSWORD'];
const SAFE_CODES=new Set(['isolated_staging_project_required','isolated_staging_origin_required',
  'staging_setting_required','publishable_key_required']);

// Never enumerate arbitrary environment entries or serialize their values.
export function protectedConfigurationEvidence(env){
  const names=[...NATIVE_SETTING_NAMES,...STAGING_SETTING_NAMES,'PROXO_STAGING_VERCEL_BYPASS'];
  const presence=Object.fromEntries(names.map(name=>[name,typeof env[name]==='string'&&env[name].trim().length>0]));
  const missing=STAGING_SETTING_NAMES.filter(name=>!presence[name]);
  let valid=false,code=missing.length?'staging_setting_required':null;
  if(!missing.length){
    try{validateStagingConfiguration(env);valid=true;}
    catch(error){code=SAFE_CODES.has(error?.message)?error.message:'staging_configuration_invalid';}
  }
  return {environment:'proxolink-preview-verification',credential_values_retained:false,presence,
    native_primary_settings_present:NATIVE_SETTING_NAMES.every(name=>presence[name]),
    staging:{configured:valid,missing_setting_names:missing,validation_code:code,
      second_account_settings_present:presence.PROXO_STAGING_OTHER_EMAIL&&presence.PROXO_STAGING_OTHER_PASSWORD,
      account_existence_or_authentication_verified:false,isolated_hosted_execution_verified:false}};
}

if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){
  const evidence=protectedConfigurationEvidence(process.env);
  mkdirSync('build/proxolink-staging-verification',{recursive:true});
  writeFileSync('build/proxolink-staging-verification/protected-configuration.json',JSON.stringify(evidence,null,2)+'\n');
  if(process.env.GITHUB_OUTPUT)appendFileSync(process.env.GITHUB_OUTPUT,'staging_ready='+evidence.staging.configured+'\n');
  console.log('Protected configuration presence audit recorded; no credential values were retained.');
  if(!evidence.staging.configured)console.log('Hosted verification BLOCKED: '+
    (evidence.staging.missing_setting_names.join(', ')||evidence.staging.validation_code));
}
