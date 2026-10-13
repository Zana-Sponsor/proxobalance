import { json, readJson, rpc, serviceFetch, withSecurity } from './_lib/security.js';

const clean = (value, max = 1000) => String(value || '').replace(/[\r\n\t]+/g, ' ').trim().slice(0, max);
const active = row => row.is_active === true && (!row.expires_at || new Date(row.expires_at) > new Date());

async function activeBans() {
  const rows = await serviceFetch('/rest/v1/banned_ips?select=*&order=banned_at.desc&limit=500');
  return (rows || []).map(row => ({ ...row, effective_active: active(row) }));
}

async function alertRows(limit = 100) {
  const [alerts, bans] = await Promise.all([
    serviceFetch(`/rest/v1/security_alerts?status=eq.pending&select=*&order=created_at.desc&limit=${limit}`),
    activeBans()
  ]);
  const banned = new Set(bans.filter(active).map(row => row.ip_address));
  return (alerts || []).map(a => ({
    ...a,
    event_type: a.alert_type,
    account_name: a.username,
    account_email: a.user_email,
    detail: a.message,
    meta: { ...(a.payload_summary || {}), orders: a.request_count, seconds: a.window_seconds },
    ip_is_banned: banned.has(a.ip_address)
  }));
}

async function logRows(limit = 300) {
  const [logs, bans] = await Promise.all([
    serviceFetch(`/rest/v1/suspicious_activity_logs?select=*&order=occurred_at.desc&limit=${limit}`),
    activeBans()
  ]);
  const banned = new Set(bans.filter(active).map(row => row.ip_address));
  return (logs || []).map(row => ({
    ...row,
    event_type: row.action_type,
    created_at: row.occurred_at,
    account_name: row.username,
    account_email: row.user_email,
    meta: row.payload_summary,
    ip_is_banned: banned.has(row.ip_address)
  }));
}

function accountIpSummary(logs, bans) {
  const byUser = new Map();
  for (const row of logs) {
    if (!row.user_id || !row.ip_address) continue;
    let item = byUser.get(row.user_id);
    if (!item) {
      item = { user_id: row.user_id, last_ip: row.ip_address, last_seen: row.occurred_at,
        browser: row.browser, os: row.os, device: row.device, ips: new Set() };
      byUser.set(row.user_id, item);
    }
    item.ips.add(row.ip_address);
    if (new Date(row.occurred_at) > new Date(item.last_seen)) Object.assign(item, {
      last_ip: row.ip_address, last_seen: row.occurred_at,
      browser: row.browser, os: row.os, device: row.device
    });
  }
  const banned = new Set(bans.filter(active).map(row => row.ip_address));
  return [...byUser.values()].map(item => ({
    ...item, ip_count: item.ips.size, last_ip_banned: banned.has(item.last_ip), ips: undefined
  }));
}

async function handleGet(req, res, user) {
  const url = new URL(req.url, 'http://localhost');
  const view = url.searchParams.get('view') || 'alerts';
  const limit = Math.max(1, Math.min(500, Number(url.searchParams.get('limit') || 200)));

  if (view === 'alerts') return json(res, 200, { alerts: await alertRows(limit) });
  if (view === 'bans') return json(res, 200, { bans: await activeBans() });
  if (view === 'logs') return json(res, 200, { logs: await logRows(limit) });

  if (view === 'dashboard') {
    const [alerts, bans, logs] = await Promise.all([alertRows(100), activeBans(), logRows(limit)]);
    const recent = logs.filter(row => new Date(row.occurred_at) >= new Date(Date.now() - 86_400_000));
    const counts = recent.reduce((map, row) => map.set(row.action_type, (map.get(row.action_type) || 0) + 1), new Map());
    const top = [...counts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] || null;
    return json(res, 200, {
      alerts,
      bans,
      logs,
      stats: {
        active_bans: bans.filter(active).length,
        events_24h: recent.length,
        blocked_hits: bans.reduce((sum, row) => sum + Number(row.hit_count || 0), 0),
        top_type: top
      }
    });
  }

  if (view === 'account-ip-summary') {
    const [logs, bans] = await Promise.all([
      serviceFetch('/rest/v1/suspicious_activity_logs?user_id=not.is.null&select=user_id,ip_address,browser,os,device,occurred_at&order=occurred_at.desc&limit=5000'),
      activeBans()
    ]);
    return json(res, 200, { accounts: accountIpSummary(logs || [], bans) });
  }

  if (view === 'user-ips') {
    const userId = clean(url.searchParams.get('user_id'), 50);
    const [logs, bans] = await Promise.all([
      serviceFetch(`/rest/v1/suspicious_activity_logs?user_id=eq.${encodeURIComponent(userId)}&ip_address=not.is.null&select=ip_address,browser,os,device,occurred_at&order=occurred_at.desc&limit=1000`),
      activeBans()
    ]);
    const byIp = new Map();
    for (const row of logs || []) {
      const item = byIp.get(row.ip_address) || { ...row, events: 0, last_seen: row.occurred_at };
      item.events++;
      byIp.set(row.ip_address, item);
    }
    const banned = new Set(bans.filter(active).map(row => row.ip_address));
    return json(res, 200, { ips: [...byIp.values()].map(row => ({ ...row, is_banned: banned.has(row.ip_address) })) });
  }

  if (view === 'ip-accounts') {
    const ip = clean(url.searchParams.get('ip'), 80);
    const logs = await serviceFetch(`/rest/v1/suspicious_activity_logs?ip_address=eq.${encodeURIComponent(ip)}&user_id=not.is.null&select=user_id,username,user_email,occurred_at&order=occurred_at.desc&limit=1000`);
    const byUser = new Map();
    for (const row of logs || []) {
      const item = byUser.get(row.user_id) || { user_id: row.user_id, account_name: row.username, account_email: row.user_email, events: 0 };
      item.events++;
      byUser.set(row.user_id, item);
    }
    return json(res, 200, { accounts: [...byUser.values()] });
  }

  return json(res, 404, { error: 'Unknown view' });
}

async function handlePost(req, res, user) {
  const body = await readJson(req, 32 * 1024);
  const action = clean(body.action, 40);

  if (action === 'ban' || action === 'ban_from_alert') {
    let source = {};
    if (action === 'ban_from_alert') {
      const rows = await serviceFetch(`/rest/v1/security_alerts?id=eq.${encodeURIComponent(body.alert_id)}&select=*&limit=1`);
      source = rows?.[0] || {};
      if (!source.ip_address) return json(res, 404, { error: 'Alert not found' });
    }
    const ip = clean(body.ip || source.ip_address, 80);
    const result = await rpc('security_admin_ban_ip', {
      p_admin_user: user.id,
      p_ip: ip,
      p_reason: clean(body.reason || source.message || 'Manual admin ban', 1000),
      p_hours: body.hours === null || body.hours === '' ? null : Number(body.hours || 24),
      p_user_id: body.user_id || source.user_id || null,
      p_browser_agent: source.user_agent || null,
      p_browser: source.browser || null,
      p_os: source.os || null,
      p_device: source.device || null,
      p_risk_score: Number(source.risk_score || body.risk_score || 75)
    });
    if (source.id) await rpc('security_admin_resolve_alert', { p_admin_user: user.id, p_id: source.id, p_status: 'resolved' });
    return json(res, 200, { ok: true, ban_id: result });
  }

  if (action === 'unban') {
    const ok = await rpc('security_admin_unban_ip', { p_admin_user: user.id, p_id: body.id });
    return json(res, 200, { ok: Boolean(ok) });
  }

  if (action === 'extend') {
    const rows = await serviceFetch(`/rest/v1/banned_ips?id=eq.${encodeURIComponent(body.id)}&select=*&limit=1`);
    const source = rows?.[0];
    if (!source) return json(res, 404, { error: 'Ban not found' });
    const result = await rpc('security_admin_ban_ip', {
      p_admin_user: user.id, p_ip: source.ip_address, p_reason: source.reason,
      p_hours: body.hours === null || body.hours === '' ? null : Number(body.hours || 24),
      p_user_id: source.user_id, p_browser_agent: source.browser_agent,
      p_browser: source.browser, p_os: source.os, p_device: source.device,
      p_risk_score: Number(source.risk_score || 75)
    });
    return json(res, 200, { ok: true, ban_id: result });
  }

  if (action === 'resolve') {
    const ok = await rpc('security_admin_resolve_alert', {
      p_admin_user: user.id, p_id: body.id,
      p_status: body.status === 'dismissed' ? 'dismissed' : 'resolved'
    });
    return json(res, 200, { ok: Boolean(ok) });
  }

  return json(res, 422, { error: 'Unsupported action' });
}

export default withSecurity(async (req, res, { user }) => {
  if (req.method === 'GET') return handleGet(req, res, user);
  return handlePost(req, res, user);
}, { auth: 'admin', methods: ['GET', 'POST'] });
