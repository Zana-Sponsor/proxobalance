import assert from 'node:assert/strict';
import test from 'node:test';
import {readFileSync} from 'node:fs';

const admin=readFileSync(new URL('../assets/js/admin.js',import.meta.url),'utf8');
const staff=readFileSync(new URL('../assets/js/exchange-staff.js',import.meta.url),'utf8');
const html=readFileSync(new URL('../exchange-admin.html',import.meta.url),'utf8');
const passwordFn=readFileSync(new URL('../supabase/functions/admin-set-password/index.ts',import.meta.url),'utf8');
const createFn=readFileSync(new URL('../supabase/functions/admin-create-user/index.ts',import.meta.url),'utf8');

test('ordinary admins get read-only account controls',()=>{
  assert.match(admin,/function accountAdminActionsHTML\(a\)\{\s*if\(!isSuperAdmin\(\)\) return '';/);
  assert.match(admin,/function openSetPasswordModal\(userId, email\)\{\s*if\(!isSuperAdmin\(\)\)/);
  assert.match(admin,/async function submitSetPassword\(\)\{[\s\S]*?if\(!isSuperAdmin\(\)\)/);
  assert.match(admin,/function openCreateUserModal\(\)\{\s*if\(!isSuperAdmin\(\)\)/);
  assert.match(admin,/async function submitCreateUser\(\)\{[\s\S]*?if\(!isSuperAdmin\(\)\)/);
  assert.match(staff,/openSetPasswordModal:'super',openCreateUserModal:'super'/);
  assert.match(staff,/function staffPasswordAllowed\(_id\)\{\s*return !!adminUser&&isSuperAdmin\(\);/);
  assert.match(html,/data-super-admin-only hidden onclick="openCreateUserModal\(\)"/);
});

test('account mutation edge functions require super admin',()=>{
  assert.match(passwordFn,/callerProfile\.role !== "super_admin"/);
  assert.match(createFn,/callerProfile\.role !== "super_admin"/);
});
