#!/usr/bin/env python3
"""Build and validate this checkout using real installed SDKs and a fresh native service."""
import hashlib,json,os,socket,subprocess,sys,time,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'scripts'));import dev
OUT=ROOT/'build/checkout-validation'/time.strftime('%Y%m%d-%H%M%S');OUT.mkdir(parents=True)
copy=ROOT
source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
source_files={}
for area in ['src','workbench_native','web','scripts','tests','examples','integrations']:
 for path in sorted((ROOT/area).rglob('*')):
  if path.is_file() and '__pycache__' not in path.parts and '.docguard' not in path.parts:
   source_files[path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
env=os.environ.copy()
for sdk in ['1.1.3','1.2.0']:env['CJ_DOCGUARD_SDK_'+sdk.replace('.','_')]=str(dev.sdk_home(sdk))
r=subprocess.run(['bash','scripts/build_workbench.sh'],cwd=copy,env=env,capture_output=True,text=True,timeout=180)
(OUT/'clean-build.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
base=f'http://127.0.0.1:{port}';token=None;steps=[]
log=(OUT/'clean-server.log').open('w');server=subprocess.Popen(['bash','scripts/workbench.sh','--port',str(port)],cwd=copy,env=env,stdout=log,stderr=subprocess.STDOUT)
def req(path,body=None):
 h={'Origin':base}
 if token:h['X-DocGuard-Token']=token
 if body is not None:h['Content-Type']='application/json'
 with urllib.request.urlopen(urllib.request.Request(base+path,headers=h,data=None if body is None else json.dumps(body).encode()),timeout=30) as r:return json.load(r)
def job(action,**args):
 j=req(prefix+'/jobs',{'action':action,**args});deadline=time.monotonic()+240
 while time.monotonic()<deadline:
  r=req('/api/jobs/'+j['id'])
  if r['status'] not in ('running','queued'):break
  time.sleep(.2)
 else:raise RuntimeError('job timeout '+action)
 (OUT/('clean-'+action+('-'+args.get('sdk',''))+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
 assert r['exit_code']==0,(action,r)
 steps.append({'action':action,'status':r['status'],'exit_code':r['exit_code']});print(steps[-1],flush=True);return r
try:
 for _ in range(100):
  if server.poll() is not None:raise RuntimeError('server exited')
  try:b=req('/api/bootstrap');break
  except OSError:time.sleep(.1)
 else:raise RuntimeError('startup timeout')
 token=b['token'];assert b['implementation']=='Cangjie' and len(b['projects'])==1
 prefix='/api/projects/'+b['projects'][0]['id']
 for path in ['/','/app.js','/views.js','/interaction.js','/styles.css']:
  with urllib.request.urlopen(base+path) as r:assert r.status==200 and len(r.read())>0
 job('doctor');job('build');job('verify');job('check')
 report=req(prefix+'/report')['report'];assert report['summary']['VERIFIED_CURRENT']==26 and report['summary']['COMPILE_ONLY']==2 and report['summary']['CURRENT']==28
 assert report['link_summary']['TOTAL']==len(report['links'])
 assert report['link_summary']['FAIL']==0 and report['link_summary']['UNVERIFIED']==0
 assert any(x.get('scope')=='index' and x.get('syntax')=='html-href' for x in report['links'])
 for sdk in ['1.1.3','1.2.0']:
  q=job('query',tool='get_verified_examples',sdk=sdk,platform=b['platform'])['result'];assert len(q['items'])==13
  exported=job('export',example='arithmetic',sdk=sdk,platform=b['platform'])
  archive=OUT/('clean-export-'+sdk+'.zip')
  with urllib.request.urlopen(base+exported['artifact_url']) as r:archive.write_bytes(r.read())
  with zipfile.ZipFile(archive) as z:z.extractall(OUT/('clean-export-rebuild-'+sdk))
  runtime=dev.sdk_env(sdk)|{'CJ_SDK_HOME':str(dev.sdk_home(sdk))}
  rebuilt=subprocess.run(['bash','build.sh'],cwd=OUT/('clean-export-rebuild-'+sdk),env=runtime,capture_output=True,text=True,timeout=120)
  (OUT/('clean-export-rebuild-'+sdk+'.stdout')).write_text(rebuilt.stdout);(OUT/('clean-export-rebuild-'+sdk+'.stderr')).write_text(rebuilt.stderr)
  assert rebuilt.returncode==0 and rebuilt.stdout=='42\n'
 result={'source_commit':source_commit,'source_files_sha256':source_files,'implementation':b['implementation'],'platform':b['platform'],'summary':report['summary'],'link_summary':report['link_summary'],'api_symbols':len(report['api']['symbols']),'steps':steps,'export_rebuild_stdout':rebuilt.stdout,'cli_sha256':hashlib.sha256((copy/'build/cj-docguard').read_bytes()).hexdigest(),'service_sha256':hashlib.sha256((copy/'build/cj-docguard-workbench').read_bytes()).hexdigest()}
 (OUT/'clean-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('PASS checkout native build/start/verify/check/query/export/rebuild',flush=True);print('Evidence: '+str(OUT),flush=True)
finally:
 server.terminate();server.wait(timeout=20);log.close()
 assert server.returncode==0
