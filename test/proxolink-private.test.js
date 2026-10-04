import test from 'node:test';
import assert from 'node:assert/strict';
import {
  safeHtml, validUuid, contactDestination, validateCardData, renderTemplate
} from '../api/_lib/proxolink.js';

const owner='11111111-1111-4111-8111-111111111111';
const id='22222222-2222-4222-8222-222222222222';
const card={
  id,user_id:owner,name:'Zana <Store>',bio:'Contact & order',
  tt:'zana_store',template_key:'classic',template_version:1,
  color_theme:'purple',card_language:'ku',avatar_path:null,
  platforms:{wa:'9647501234567',ig:'zana.store'}
};
const template='<html><title>{{NAME}}</title><p>{{BIO}}</p>{{AVATAR}}'
  +'{{GRAD}}{{BUTTONS}}{{TT_BADGE}}{{TT_INLINE}}{{THEME_FROM}}{{THEME_TO}}'
  +'<script>{{HANDLERS}}</script></html>';

test('safe rendering escapes customer HTML without changing layout placeholders',()=>{
  const html=renderTemplate(template,card);
  assert.match(html,/Zana &lt;Store&gt;/);
  assert.match(html,/Contact &amp; order/);
  assert.match(html,/class="btn-classic shine-active"/);
  assert.match(html,/https:\/\/www.tiktok.com\/@zana_store/);
  assert.doesNotMatch(html,/\{\{[A-Z_]+\}\}/);
});
test('two advertisements using one card retain distinct tracked actions',()=>{
  const a=renderTemplate(template,card,{adToken:'link-A'});
  const b=renderTemplate(template,card,{adToken:'link-B'});
  assert.match(a,/\/a\/link-A\/action\/wa/);
  assert.match(b,/\/a\/link-B\/action\/wa/);
  assert.doesNotMatch(a,/\/a\/link-B\/action\//);
  assert.doesNotMatch(b,/\/a\/link-A\/action\//);
});
test('dangerous customer content and URLs are rejected or escaped',()=>{
  assert.equal(safeHtml('<script>"'), '&lt;script&gt;&quot;');
  assert.throws(()=>contactDestination('ig','javascript:alert(1)'));
  assert.throws(()=>contactDestination('wa','123'));
  assert.throws(()=>validateCardData({...card,platforms:{evil:'http://site'}}));
  const html=renderTemplate(template,{...card,name:'<script>alert(1)</script>'});
  assert.doesNotMatch(html,/<title><script>/);
});
test('only valid stable identifiers are accepted',()=>{
  assert.equal(validUuid(id),true);
  assert.equal(validUuid('../../../secrets'),false);
});
