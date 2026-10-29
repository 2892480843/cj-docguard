"""Local evidence client: no HTTP server or fake compiler results."""
import argparse,hashlib,json,sys,time,urllib.request,subprocess,zipfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import dev
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--url',default='http://127.0.0.1:8765')
parser.add_argument('--original-config',type=Path,required=True)
parser.add_argument('--fixed-config',type=Path,required=True)
args=parser.parse_args()
BASE=args.url.rstrip('/')
from urllib.parse import urlsplit
if urlsplit(BASE).hostname not in ('127.0.0.1','localhost'):parser.error('local loopback service required')
out=dev.ROOT/'build/link-repair-validation'/time.strftime('%Y%m%d-%H%M%S');out.mkdir(parents=True)
token=None
steps=[]
def save(name,value):
 (out/(name+'.json')).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def request(path,body=None):
 headers={'Origin':BASE}
 if token:headers['X-DocGuard-Token']=token
 if body is not None:headers['Content-Type']='application/json'
 with urllib.request.urlopen(urllib.request.Request(BASE+path,headers=headers,data=None if body is None else json.dumps(body).encode()),timeout=30) as r:return json.load(r)
b=request('/api/bootstrap');assert b['implementation']=='Cangjie';token=b['token'];platform=b['platform']
lock=json.loads((dev.ROOT/'integrations/upstream-lock.json').read_text())['projects'][0]
fix=json.loads((dev.ROOT/'integrations/leven4cj/patches/manifest.json').read_text())
base=args.original_config.resolve().parent;fixed=args.fixed_config.resolve().parent
assert hashlib.sha256((base/'upstream/src/leven.cj').read_bytes()).hexdigest()==fix['before_sha256']
assert hashlib.sha256((fixed/'upstream/src/leven.cj').read_bytes()).hexdigest()==fix['after_sha256']
assert json.loads((fixed/'provenance.json').read_text())['source_modified'] is True
for c in lock['examples']:
 for project_root in (base,fixed):
  assert hashlib.sha256((project_root/c['file']).read_bytes()).hexdigest()==c['sha256']
def register(config):return request('/api/projects',{'config':str(config)})['id']
projects={'original':register(args.original_config.resolve()),'fixed':register(args.fixed_config.resolve()),'links':register(dev.ROOT/'examples/link-checks/docguard.toml')}
save('projects',projects)
def job(project,label,action,expected=0,**params):
 start=request('/api/projects/'+projects[project]+'/jobs',{'action':action,**params});deadline=time.monotonic()+240
 while time.monotonic()<deadline:
  result=request('/api/jobs/'+start['id'])
  if result['status'] not in ('queued','running'):break
  time.sleep(.2)
 else:raise AssertionError('timeout '+label)
 save(label,result);assert result['exit_code']==expected,(label,result)
 steps.append({'step':label,'id':result['id'],'status':result['status'],'exit_code':result['exit_code']});print(json.dumps(steps[-1]),flush=True)
 return result
try:
 for project,expected in [('original',1),('fixed',0)]:
  job(project,project+'-doctor','doctor')
  job(project,project+'-build','build')
  job(project,project+'-verify','verify',expected)
  job(project,project+'-check','check',expected)
  report=request('/api/projects/'+projects[project]+'/report')['report'];save(project+'-report',report)
  assert report['summary']['TOTAL']==40
  assert report['summary'].get('ASSERTION_FAILED',0)==(4 if project=='original' else 0)
  assert report['summary']['VERIFIED_CURRENT']==(36 if project=='original' else 40)
 for sdk in ['1.1.3','1.2.0']:
  for example in ['unicode-empty','emoji-empty']:
   q=job('fixed','fixed-query-'+sdk+'-'+example,'query',tool='get_verified_examples',sdk=sdk,platform=platform,example=example)['result']
   assert len(q['items'])==1 and q['items'][0]['run']['stdout']=='1\n' and q['items'][0]['eligible']
  exported=job('fixed','fixed-export-'+sdk,'export',example='unicode-empty',sdk=sdk,platform=platform)
  archive=out/('fixed-'+sdk+'.zip')
  with urllib.request.urlopen(BASE+exported['artifact_url']) as r:archive.write_bytes(r.read())
  dest=out/('rebuild-'+sdk)
  with zipfile.ZipFile(archive) as z:z.extractall(dest)
  r=subprocess.run(['bash','build.sh'],cwd=dest,env=dev.sdk_env(sdk)|{'CJ_SDK_HOME':str(dev.sdk_home(sdk))},capture_output=True,text=True,timeout=120)
  (out/('rebuild-'+sdk+'.stdout')).write_text(r.stdout);(out/('rebuild-'+sdk+'.stderr')).write_text(r.stderr)
  assert r.returncode==0 and r.stdout=='1\n',(sdk,r.stdout,r.stderr)
 job('links','links-verify','verify',1)
 job('links','links-check','check',1)
 r=request('/api/projects/'+projects['links']+'/report')['report'];save('links-report',r)
 assert r['summary']['VERIFIED_CURRENT']==2,r['summary']
 assert r['link_summary']['TOTAL']==len(r['links']),r['link_summary']
 assert r['link_summary']['FAIL']==2 and r['link_summary']['UNVERIFIED']==1,r['link_summary']
 assert any(x.get('scope')=='index' and x.get('syntax')=='html-href' for x in r['links'])
 assert any(x.get('syntax')=='index' for x in r['links'])
 assert not any('missing-inline-code' in x['target'] or 'missing-fenced-code' in x['target'] for x in r['links'])
 print('PASS original 36/40 + fixed 40/40 + unchanged 4 assertions + both SDK queries/export/rebuild + native link outcomes',flush=True)
finally:
 save('summary',steps);print('Evidence: '+str(out),flush=True)
