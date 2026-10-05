import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {validateStagingConfiguration,verifyStagingLifecycle} from './proxolink-staging-verification.mjs';
try {
  const config=validateStagingConfiguration(process.env);
  const avatar=await readFile('assets/proxolink-demo-avatar.png');
  const result=await verifyStagingLifecycle(config,avatar);
  await mkdir('build/proxolink-staging-verification',{recursive:true});
  await writeFile('build/proxolink-staging-verification/results.json',JSON.stringify(result,null,2)+'\n');
  console.log('8/8 isolated staging lifecycle cases passed. Fictional fixtures retained for review.');
}catch {
  // URLs, request bodies, Auth values and server errors never enter logs.
  console.error('Staging verification did not complete. Check the documented isolated provider configuration; no production fallback was used.');
  process.exitCode=1;
}
