import { json, serviceFetch, withSecurity } from './_lib/security.js';

export default withSecurity(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const limit = Math.max(1, Math.min(20, Number(url.searchParams.get('limit') || 8)));
  let list = [];

  try {
    const rows = await serviceFetch(
      '/rest/v1/ex_orders?status=eq.%D9%BE%DB%95%D8%B3%DB%95%D9%86%D8%AF%DA%A9%D8%B1%D8%A7&select=from_method,to_method,amount,total,created_at,user_id&order=created_at.desc&limit=5000'
    );
    if (Array.isArray(rows) && rows.length > 0) {
      list = rows;
    }
  } catch (err) {
    // The feed shows only real approved exchanges from Supabase; when the
    // database is unreachable it is simply empty.
  }

  const since = Date.now() - 86_400_000;
  // Route, amount and time only: no order code, phone or account details.
  const feed = list.slice(0, limit).map(row => ({
    from: row.from_method,
    to: row.to_method,
    amount: row.amount,
    total: row.total,
    at: row.created_at
  }));
  return json(res, 200, {
    ok: true,
    data: {
      stats: {
        approved_count: list.length,
        approved_24h: list.filter(row => new Date(row.created_at).getTime() >= since).length,
        users_count: new Set(list.map(row => row.user_id).filter(Boolean)).size,
        total_volume: list.reduce((sum, row) => sum + Number(row.total || 0), 0)
      },
      feed
    }
  });
}, { auth: 'none', methods: ['GET'] });
