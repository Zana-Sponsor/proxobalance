// Retirement replacement for the legacy ProxoLink HTML delivery endpoint.
// Keep verify_jwt=true if separately approved for deployment. This change
// does not authorize a production deployment or alteration of customer data.
const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
};

Deno.serve((request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers });
  }
  // Do not parse or forward legacy HTML, account details or credentials.
  return new Response(request.method === 'HEAD' ? null : JSON.stringify({
    ok: false,
    error: 'proxolink_html_delivery_retired',
  }), { status: 410, headers });
});
