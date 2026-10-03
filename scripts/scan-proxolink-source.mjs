import { readFileSync, readdirSync, statSync } from 'node:fs';
const forbidden=['buildCardHtml(', 'loadHtmlString(', 'sendHtmlDocument(', 'api.telegram.org/bot', '{{HANDLERS}}', 'function askConfirm('];
function scan(folder) {
  for(const name of readdirSync(folder)) {
    const path=folder+'/'+name;
    if(statSync(path).isDirectory()) {scan(path); continue;}
    if(!path.endsWith('.dart'))continue;
    const source=readFileSync(path,'utf8');
    for(const token of forbidden)if(source.includes(token))throw Error('Legacy ProxoLink source in '+path);
  }
}
scan('proxo_app/lib');
for(const folder of ['public','assets']) {
  const walk=(directory)=>{for(const name of readdirSync(directory)) {
    const path=directory+'/'+name;
    if(statSync(path).isDirectory())walk(path);
    else if(/\.(html|js|json|map)$/.test(path)&&readFileSync(path,'utf8').includes('{{HANDLERS}}'))
      throw Error('Private template leaked to '+path);
  }};
  walk(folder);
}
console.log('Flutter and public output contain no reusable template source or HTML delivery.');
