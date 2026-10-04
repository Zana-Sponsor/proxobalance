import test from 'node:test';
import assert from 'node:assert/strict';
import {TEMPLATE_ORDER,refineTemplate} from '../scripts/proxolink-refinements.mjs';

const source='<html><head><style>.original{background:#123;animation:shine 2s infinite;}#tg i{font-size:22px;}.modal-ok.ok-te{background:#abc;}</style></head><body><div class="original"><h1>{{NAME}}</h1><p>{{BIO}}</p>{{BUTTONS}}</div><script>function askConfirm(n){var cls="ok";if(n===\'telegram\')cls=\'ok-te\';return cls;}</script></body></html>';
test('private v2 generation retains original structure and removes only retired code plus approved deltas',()=>{
 for(const key of TEMPLATE_ORDER) {
  const refined=refineTemplate(source,key);
  assert.match(refined,/<div class="original"><h1>\{\{NAME\}\}<\/h1><p>\{\{BIO\}\}<\/p>\{\{BUTTONS\}\}<\/div>/);
  assert.match(refined,/\.original\{background:#123;animation:shine 2s infinite;\}/);
  assert.match(refined,/text-wrap:balance/);assert.match(refined,/prefers-reduced-motion/);
  assert.match(refined,/scale\(\.985\)/);assert.match(refined,/font-weight:400/);
  assert.doesNotMatch(refined,/telegram|#tg|ok-te/);
  assert.equal((refined.match(/data-proxo-refinement=/g)||[]).length,1);
  assert.throws(()=>refineTemplate(refined,key));
 }
 assert.doesNotMatch(source,/data-proxo-refinement/);
 assert.throws(()=>refineTemplate(source,'unknown'));
 assert.throws(()=>refineTemplate('<html>no contract</html>','dark'));
});
