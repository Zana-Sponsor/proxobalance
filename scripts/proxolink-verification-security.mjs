// Read-only checks for the one approved Preview. Never accept a caller-selected
// origin or service credential, and never follow redirects carrying headers.
export const PREVIEW_ORIGIN='https://proxobalance-git-feat-proxolink-private-re-00a2aa-proxoapp-1758.vercel.app';
export const SUPABASE_ORIGIN='https://cojchkwssmasiejcgvbk.supabase.co';
export const STYLES=['pill','pill-mint','pill-dark','pill-white'];
export const PAGE_TYPES=['contact','order','download'];
export const LANGUAGES=['ku','en'];
export const WIDTHS=[320,375,393,430,768];
export const ORIENTATIONS=['portrait','landscape'];
export const NATIVE_CASE_IDS=STYLES.flatMap(style=>PAGE_TYPES.flatMap(type=>LANGUAGES.flatMap(language=>ORIENTATIONS.flatMap(orientation=>WIDTHS.map(width=>`${style}-${type}-${language}-${orientation}-${width}`)))));

export function validateRuntime(env) {
  if(env.GITHUB_REPOSITORY!=='Zana-Sponsor/proxobalance'
    ||env.GITHUB_REF!=='refs/heads/feat/proxolink-private-renderer-migration'
    ||env.GITHUB_WORKFLOW_REF!=='Zana-Sponsor/proxobalance/.github/workflows/proxolink-native-build.yml@refs/heads/feat/proxolink-private-renderer-migration'
    ||env.PROXO_NATIVE_BASE_URL!==PREVIEW_ORIGIN
    ||env.PROXO_NATIVE_SUPABASE_URL!==SUPABASE_ORIGIN)
    throw Error('approved_preview_workflow_required');
  for(const name of ['PROXO_NATIVE_ANON_KEY','PROXO_NATIVE_TEST_EMAIL',
    'PROXO_NATIVE_TEST_PASSWORD','PROXO_NATIVE_VERCEL_BYPASS'])
    if(typeof env[name]!=='string'||!env[name].length)throw Error('runtime_setting_required');
  const key=env.PROXO_NATIVE_ANON_KEY;
  if(!key.startsWith('sb_publishable_')) {
    let role;
    try {role=JSON.parse(Buffer.from(key.split('.')[1],'base64url')).role;}catch {}
    if(role!=='anon')throw Error('publishable_key_required');
  }
}

export async function safeRequest(url,options={},fetcher=fetch) {
  const parsed=new URL(url);
  if(![PREVIEW_ORIGIN,SUPABASE_ORIGIN].includes(parsed.origin)
    ||parsed.username||parsed.password||parsed.searchParams.has('x-vercel-protection-bypass'))
    throw Error('approved_origin_required');
  if(parsed.origin===SUPABASE_ORIGIN&&Object.keys(options.headers||{})
    .some(name=>name.toLowerCase().startsWith('x-vercel-')))
    throw Error('protection_header_scope');
  if(!['GET','POST'].includes(options.method||'GET')
    ||(options.method==='POST'&&(parsed.origin!==SUPABASE_ORIGIN
      ||parsed.pathname!=='/auth/v1/token')))
    throw Error('read_only_verification_required');
  return fetcher(parsed.href,{...options,redirect:'error',signal:AbortSignal.timeout(30000)});
}

// Preview capabilities are renewed during long native runs. Their app-auth
// session must also stay valid; keep only its bearer and the same account ID
// in runner memory, never the full sign-in response or a refresh token.
export function createNativeVerificationSession(signIn,now=Date.now) {
  let current=null,expiresAt=0;
  return async()=>{
    if(current&&now()<expiresAt-300000)return current;
    const startedAt=now(),session=await signIn();
    const ttl=Number(session?.expires_in),absolute=Number(session?.expires_at);
    const deadline=Number.isFinite(absolute)&&absolute>0
      ?Math.min(absolute*1000,startedAt+ttl*1000):startedAt+ttl*1000;
    if(typeof session?.access_token!=='string'||!session.access_token
      ||!Number.isFinite(ttl)||ttl<=0||!Number.isFinite(deadline)||deadline<=now()
      ||!/^([0-9a-f]{8}-)([0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(session?.user?.id||''))
      throw Error('verification_sign_in_failed');
    if(current&&session.user.id!==current.userId)throw Error('verification_user_required');
    current={authorization:'Bearer '+session.access_token,userId:session.user.id};
    expiresAt=deadline;
    return current;
  };
}

export async function verifyReadOnlySecurity({authorization,key,userId,protection},fetcher=fetch) {
  const checks={};
  const request=async (url,headers,check)=>{
    try {return await safeRequest(url,{headers},fetcher);}
    catch(error) {
      // Fixed check identifiers only; never attach URLs, headers or credentials.
      error.verificationCheck=check;
      throw error;
    }
  };
  for(const [name,auth] of [['bypass_without_app_auth',null],['forged_app_auth','Bearer invalid']]) {
    const response=await request(PREVIEW_ORIGIN+'/api/contact-templates',
      {...protection,...(auth?{Authorization:auth}:{})},name);
    if(response.status!==401)throw Error('application_auth_boundary_failed');
    checks[name]=true;
  }
  for(const path of ['/contact-preview?token=invalid','/a/invalid','/contact/invalid/avatar']) {
    const response=await request(PREVIEW_ORIGIN+path,protection,
      path.startsWith('/contact-preview')?'invalid_preview_capability':
        path.startsWith('/a/')?'invalid_ad_token':'invalid_avatar_card');
    if(response.status!==404)throw Error('invalid_capability_boundary_failed');
  }
  checks.invalid_capabilities=true;
  for(const auth of [null,authorization]) {
    const headers={apikey:key,...(auth?{Authorization:auth}:{})};
    for(const table of ['proxolink_templates','pa_ad_contact_links','pa_contact_events','proxolink_publish_attempts']) {
      const response=await request(SUPABASE_ORIGIN+'/rest/v1/'+table+'?select=id&limit=1',headers,
        (auth?'authenticated_':'anonymous_')+table);
      if(![401,403].includes(response.status))throw Error('internal_table_access_failed');
    }
  }
  checks.internal_client_access_denied=true;
  if(!/^[0-9a-f-]{36}$/i.test(userId||''))throw Error('verification_user_required');
  const otherCards=await request(SUPABASE_ORIGIN+'/rest/v1/proxolink_cards?select=id&user_id=neq.'+userId+'&limit=1',
    {apikey:key,Authorization:authorization},'ordinary_account_other_cards_rls');
  if(otherCards.status!==200||JSON.stringify(await otherCards.json())!=='[]')
    throw Error('ordinary_account_rls_required');
  checks.other_owner_cards_hidden=true;
  for(const style of STYLES) {
    const response=await request(SUPABASE_ORIGIN+'/storage/v1/object/public/proxolink-templates/'+style+'/v6/template.html',{},
      'private_template_'+style);
    if(![400,401,403,404].includes(response.status))throw Error('private_template_access_failed');
  }
  checks.private_templates_denied=true;
  return checks;
}

export function validateNativeResults(data,captured,pixels) {
  const cases=NATIVE_CASE_IDS;
  if(Object.keys(data||{}).length!==cases.length||captured.size!==cases.length
    ||!cases.every(id=>captured.has(id)&&data[id]?.passed===true
      &&data[id].font_loaded===true&&data[id].font_applied===true&&data[id].images_loaded===true
      &&data[id].icons_loaded===true&&data[id].width===Number(id.split('-').at(-1))
      &&Number.isInteger(data[id].animation_count)&&data[id].animation_count>=0
      &&data[id].animation_checked===true&&data[id].provider_types===true
      &&data[id].preview_inert===true&&data[id].public_actions_checked===true&&data[id].navigation_blocked===true
      &&data[id].fresh_native_views===true&&data[id].native_paint_barriers===true)
    ||Object.keys(pixels||{}).length!==cases.length
    ||!cases.every(id=>pixels[id]?.width===Number(id.split('-').at(-1))))
    throw Error('native_evidence_incomplete');
  if(!cases.every(id=>pixels[id].capture_stable===true&&pixels[id].capture_samples===3))
    throw Error('native_capture_unstable');
  if(!cases.every(id=>pixels[id].exact_pixels_equal===true&&pixels[id].changed_pixels===0))
    throw Error('native_pixel_parity_failed');
  // Explicit allowlist prevents runtime credentials/URLs or arbitrary page
  // data from accidentally entering a public CI artifact.
  return Object.fromEntries(cases.map(id=>[id,Object.fromEntries(
    ['passed','width','font_loaded','font_applied','images_loaded','icons_loaded','animation_checked',
      'animation_count','provider_types','preview_inert','public_actions_checked','navigation_blocked','fresh_native_views','native_paint_barriers']
      .map(key=>[key,data[id][key]])
  )]));
}
