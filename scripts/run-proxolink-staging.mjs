import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {validateStagingConfiguration,verifyStagingLifecycle} from './proxolink-staging-verification.mjs';
import {verifyStagingTools,verifyStagingToolsTransitions} from './proxolink-staging-tools.mjs';
try {
  const config=validateStagingConfiguration(process.env);
  if(process.argv.includes('--tools-transitions')){
    const previous=JSON.parse(await readFile('build/proxolink-staging-verification/tools-results.json','utf8'));
    const transitions=await verifyStagingToolsTransitions(config,previous);
    await writeFile('build/proxolink-staging-verification/tools-transitions.json',JSON.stringify(transitions,null,2)+'\n');
    console.log('Trusted fixture transitions and advertisement dependency verified through ordinary-account HTTP. App/browser/device coverage remains separate.');
  }else{
  const avatar=await readFile('assets/proxolink-demo-avatar.png');
  const result=await verifyStagingLifecycle(config,avatar);
  await mkdir('build/proxolink-staging-verification',{recursive:true});
  await writeFile('build/proxolink-staging-verification/results.json',JSON.stringify(result,null,2)+'\n');
  console.log(result.cases.length+'/12 isolated staging lifecycle cases passed. Fictional fixtures retained for review.');
  const tools=await verifyStagingTools(config,avatar);
  await writeFile('build/proxolink-staging-verification/tools-results.json',JSON.stringify(tools,null,2)+'\n');
  console.log(tools.cases.length+'/12 current Tools API cases verified; trusted transitions, dependency fixture and app/browser/device execution remain pending.');
  }
}catch {
  // URLs, request bodies, Auth values and server errors never enter logs.
  console.error('Staging verification did not complete. Check the documented isolated provider configuration; no production fallback was used.');
  process.exitCode=1;
}
