"""Real independent PostgreSQL connections race wallet locks and retry receipts."""
import concurrent.futures,json,subprocess
U="11111111-1111-4111-8111-111111111111"
S="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
def sql(q):
 p=subprocess.run(["psql","-XAt","-v","ON_ERROR_STOP=1","-c",q],capture_output=True,text=True)
 if p.returncode: raise AssertionError(p.stderr)
 return p.stdout.strip().splitlines()
def buy(key):
 return json.loads(sql(f"select fixture_login('{U}','{S}'); set role authenticated; select fixture_buy('{key}');")[-1])
sql(f"update pa_wallets set balance=10 where user_id='{U}'; delete from app_finance.request_limits;")
keys=["70000000-0000-4000-8000-000000000001","70000000-0000-4000-8000-000000000002"]
with concurrent.futures.ThreadPoolExecutor(2) as ex: results=list(ex.map(buy,keys))
assert sum(r.get('ok') is True for r in results)==1,results
assert sum(r.get('code')=='INSUFFICIENT_FUNDS' for r in results)==1,results
assert sql(f"select balance=0 from pa_wallets where user_id='{U}'")[-1]=='t'
sql(f"update pa_wallets set balance=10 where user_id='{U}'")
with concurrent.futures.ThreadPoolExecutor(8) as ex: results=list(ex.map(buy,["80000000-0000-4000-8000-000000000001"]*8))
assert all(r==results[0] and r['ok'] for r in results),results
assert sql(f"select balance=0 from pa_wallets where user_id='{U}'")[-1]=='t'
assert sql("select count(*)=1 from proxo_private.ad_submissions where submission_id='80000000-0000-4000-8000-000000000001'")[-1]=='t'
print('PASS: two distinct deductions cannot overspend; eight concurrent retries charge once')
