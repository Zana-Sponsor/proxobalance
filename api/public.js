import { json, serviceFetch, withSecurity } from './_lib/security.js';

function maskPhone(phone) {
  const value = String(phone || '');
  return value.length >= 7 ? `${value.slice(0, 3)}••••${value.slice(-3)}` : '••••';
}

export default withSecurity(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const limit = Math.max(1, Math.min(20, Number(url.searchParams.get('limit') || 8)));
  const rows = await serviceFetch(
    '/rest/v1/ex_orders?status=eq.%D9%BE%DB%95%D8%B3%DB%95%D9%86%D8%AF%DA%A9%D8%B1%D8%A7&select=order_code,from_method,to_method,amount,total,phone,created_at,user_id&order=created_at.desc&limit=5000'
  );
  const list = rows || [];
  const since = Date.now() - 86_400_000;
  const feed = list.slice(0, limit).map(row => ({
    id: row.order_code,
    from: row.from_method,
    to: row.to_method,
    amount: row.amount,
    total: row.total,
    phone: maskPhone(row.phone),
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
