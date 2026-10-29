"""Loopback-only workbench. Native CLI remains the authority for evidence."""
from __future__ import annotations
import copy
import codecs
import hmac
import json
import mimetypes
import os
from pathlib import Path
import platform
import secrets
import shutil
import signal
import subprocess
import threading
import time
import tomllib
import uuid
import zipfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, unquote
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import dev

ROOT = Path(__file__).resolve().parents[1]
ACTIONS = {'doctor','build','verify','check','query','export','demo_break','demo_restore'}
LIMIT = 256 * 1024
RESULT_LIMIT = 16 * 1024 * 1024

class APIError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message); self.status=status

def atomic(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary=path.with_name(path.name+'.'+uuid.uuid4().hex+'.tmp')
    try:
        with temporary.open('w',encoding='utf-8') as out:
            out.write(content); out.flush(); os.fsync(out.fileno())
        os.replace(temporary,path)
    finally:
        temporary.unlink(missing_ok=True)

class Workbench:
    def __init__(self, state_dir=None, setup_demo=True, timeout=600):
        self.state=Path(state_dir or ROOT/'build/workbench').resolve(); self.state.mkdir(parents=True,exist_ok=True)
        self.token=secrets.token_urlsafe(32); self.lock=threading.RLock(); self.jobs={}; self.processes={}; self.timeout=timeout
        self.registry=self.state/'projects.json'; self.projects={}; self.active=None; self.threads={}; self.closing=False
        if self.registry.exists():
            for p in json.loads(self.registry.read_text(encoding='utf-8')):
                self.projects[p['id']]=p
        if setup_demo:
            demo=self.state/'projects/demo'
            if not demo.exists(): shutil.copytree(ROOT/'examples/healthy',demo,ignore=shutil.ignore_patterns('.docguard'))
            self.register(str(demo/'docguard.toml'),demo=True)
    def parse(self,p):
        try: return tomllib.loads(Path(p['config']).read_text(encoding='utf-8'))
        except (OSError,ValueError) as e: raise APIError(str(e))
    def record(self,p):
        result=dict(p)
        try:
            c=self.parse(p); result.update(name=c.get('project',{}).get('name',Path(p['root']).name),sdk_versions=[s['version'] for s in c.get('sdks',[]) if 'version' in s],trusted=c.get('project',{}).get('trusted',False))
        except APIError as e: result.update(error=str(e),trusted=False,sdk_versions=[])
        return result
    def persist(self): atomic(self.registry,json.dumps(list(self.projects.values()),ensure_ascii=False,indent=2))
    def register(self,config,demo=False):
        if not isinstance(config,str) or not Path(config).is_absolute(): raise APIError('config must be an absolute TOML path')
        path=Path(config).resolve()
        if not path.is_file() or path.suffix.lower()!='.toml': raise APIError('existing TOML file required')
        p={'id':uuid.uuid5(uuid.NAMESPACE_URL,str(path)).hex,'config':str(path),'root':str(path.parent),'demo':demo}
        self.parse(p)
        with self.lock:
            if p['id'] in self.projects: p=self.projects[p['id']]
            self.projects[p['id']]=p; self.persist()
        return self.record(p)
    def project(self,id):
        if id not in self.projects: raise APIError('project not found',404)
        return self.projects[id]
    def report(self,id):
        p=self.project(id); c=self.parse(p)
        output=c.get('project',{}).get('output','.docguard')
        if not isinstance(output,str): raise APIError('invalid output path')
        target=(Path(p['root'])/output/'report.json').resolve()
        # Reports outside the registered project are never exposed through HTTP.
        if not target.is_relative_to(Path(p['root'])): raise APIError('report output must remain inside project')
        result={'report':None,'snapshot':True,'config':c}
        try:
            report=json.loads(target.read_text(encoding='utf-8'))
            if not isinstance(report,dict): raise ValueError('report must be a JSON object')
            result['report']=report
        except FileNotFoundError: pass
        except (OSError,ValueError) as e: result['error']=str(e)
        return result
    def save_config(self,id,content):
        if not isinstance(content,str): raise APIError('content must be text')
        try: tomllib.loads(content)
        except ValueError as e: raise APIError(str(e))
        with self.lock:
            self.idle(); atomic(Path(self.project(id)['config']),content)
        return self.record(self.project(id))
    def idle(self):
        if self.closing: raise APIError('service is shutting down',409)
        if self.active: raise APIError('native operation already running',409)
    def command(self,p,action,b):
        argv=[str(ROOT/'build/cj-docguard'),action,'--config',p['config']]
        if action=='verify': argv+=['--sdk',b['sdk']] if b.get('sdk') else ['--matrix']
        if action=='query':
            tool=b.get('tool','list_symbols')
            if tool not in ('list_symbols','get_verified_examples','get_evidence'): raise APIError('unsupported query tool')
            argv+=['--tool',tool]
            if tool!='list_symbols' and not all(b.get(k) for k in ('sdk','platform')): raise APIError('exact sdk and platform required')
            keys=('symbol',) if tool=='list_symbols' else ('symbol','example','sdk','platform')
            for key in keys:
                if b.get(key): argv+=['--'+key,b[key]]
        if action=='export':
            if not all(b.get(k) for k in ('sdk','platform','example')): raise APIError('export requires example, sdk, platform')
            for key in ('sdk','platform','example'): argv+=['--'+key,b[key]]
        return argv,None
    def start_job(self,id,b):
        p=self.project(id); action=b.get('action')
        if action not in ACTIONS: raise APIError('unsupported action')
        for key in ('sdk','tool','symbol','example','platform'):
            if key in b and (not isinstance(b[key],str) or len(b[key])>1024 or '\x00' in b[key]): raise APIError('invalid '+key)
        if action.startswith('demo_') and not p.get('demo'): raise APIError('fault injection is restricted to owned demo')
        if not action.startswith('demo_'): self.command(p,action,b)
        with self.lock:
            self.idle(); jid=uuid.uuid4().hex
            job=dict(id=jid,project_id=id,action=action,status='queued',started_at=None,finished_at=None,exit_code=None,stdout='',stderr='',result=None)
            self.jobs[jid]=job; self.active=jid
            thread=threading.Thread(target=self.run,args=(job,p,dict(b)),daemon=True)
            self.threads[jid]=thread; thread.start()
            return copy.deepcopy(job)
    def get_job(self,id):
        with self.lock:
            if id not in self.jobs: raise APIError('job not found',404)
            return copy.deepcopy(self.jobs[id])
    def cancel(self,id):
        with self.lock:
            j=self.jobs.get(id)
            if not j: raise APIError('job not found',404)
            if j['status'] in ('queued','running'):
                j['_cancel']=True
                proc=self.processes.get(id)
                if proc: self.interrupt(proc)
            return self.get_job(id)
    def shutdown(self):
        """Stop accepting work and reap native processes before the launcher exits."""
        with self.lock:
            self.closing=True
            ids=[id for id,j in self.jobs.items() if j['status'] in ('queued','running')]
            for id in ids: self.cancel(id)
            threads=list(self.threads.values())
        deadline=time.monotonic()+6
        for thread in threads: thread.join(max(0,deadline-time.monotonic()))
        with self.lock:
            for proc in self.processes.values(): self.interrupt(proc,signal.SIGKILL)
        for thread in threads: thread.join(max(0,deadline+1-time.monotonic()))
    @staticmethod
    def interrupt(proc, sig=signal.SIGINT):
        try: os.killpg(proc.pid,sig)
        except ProcessLookupError: pass
    def run(self,j,p,b):
        proc=None
        try:
            with self.lock: j.update(status='running',started_at=time.time())
            action=j['action']
            if action.startswith('demo_'):
                self.demo(p,action); j['result']={'snapshot_invalidated':True}; j['exit_code']=0
            else:
                argv,_=self.command(p,action,b)
                artifact=self.state/'artifacts'/j['id']; native_out=artifact/'native'
                if action=='export':
                    native_out.mkdir(parents=True); argv+=['--out',str(native_out)]
                env=dev.sdk_env('1.1.3')
                proc=subprocess.Popen(argv,cwd=p['root'],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
                with self.lock:
                    self.processes[j['id']]=proc
                    if j.get('_cancel'): self.interrupt(proc)
                raw_stdout=bytearray()
                result_overflow=False
                def consume(pipe,key):
                    nonlocal result_overflow
                    decoder=codecs.getincrementaldecoder('utf-8')(errors='replace')
                    while chunk:=pipe.read1(4096):
                        if key=='stdout':
                            if len(raw_stdout)+len(chunk)<=RESULT_LIMIT: raw_stdout.extend(chunk)
                            else: result_overflow=True
                        with self.lock:
                            j[key]=(j[key]+decoder.decode(chunk))[-LIMIT:]
                    with self.lock:
                        j[key]=(j[key]+decoder.decode(b'',final=True))[-LIMIT:]
                    pipe.close()
                readers=[threading.Thread(target=consume,args=(pipe,key),daemon=True) for pipe,key in ((proc.stdout,'stdout'),(proc.stderr,'stderr'))]
                for t in readers:t.start()
                deadline=time.monotonic()+self.timeout; stop_at=None
                while proc.poll() is None:
                    if time.monotonic()>deadline and not j.get('_cancel') and not j.get('_timeout'):
                        j['error']='native operation timed out'; j['_timeout']=True; self.interrupt(proc); stop_at=time.monotonic()+5
                    if j.get('_cancel') and stop_at is None: stop_at=time.monotonic()+5
                    if stop_at and time.monotonic()>stop_at: self.interrupt(proc,signal.SIGKILL)
                    time.sleep(.05)
                for t in readers:t.join(2)
                if any(t.is_alive() for t in readers):
                    self.interrupt(proc,signal.SIGKILL)
                    for t in readers:t.join(2)
                j['exit_code']=proc.returncode
                if result_overflow: raise APIError('native structured output exceeded 16 MiB limit')
                try: j['result']=json.loads(raw_stdout)
                except ValueError:
                    if action=='query' and proc.returncode==0 and not j.get('_cancel'): raise APIError('native query returned invalid JSON')
                if action=='export' and proc.returncode==0 and not j.get('_cancel') and not j.get('_timeout'):
                    archive=artifact/'export.zip'
                    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
                        for file in native_out.rglob('*'):
                            if file.is_symlink(): raise APIError('export contains unsafe symlink')
                            if file.is_file(): z.write(file,file.relative_to(native_out))
                    j['artifact_url']='/api/artifacts/'+j['id']
            j['status']='cancelled' if j.get('_cancel') else ('succeeded' if j['exit_code']==0 and not j.get('_timeout') else 'failed')
        except Exception as e:
            j.update(status='cancelled' if j.get('_cancel') else 'failed',error=str(e))
        finally:
            with self.lock:
                j['finished_at']=time.time(); j.pop('_cancel',None); j.pop('_timeout',None); self.processes.pop(j['id'],None); self.threads.pop(j['id'],None); self.active=None
    def demo(self,p,action):
        root=Path(p['root']).resolve(); expected=(self.state/'projects/demo').resolve()
        if root!=expected: raise APIError('not owned demo directory')
        source=ROOT/'examples/healthy'; target=root/'programs/arithmetic.cj'
        if not target.resolve().is_relative_to(root): raise APIError('unsafe demo path')
        if action=='demo_break': target.write_text((source/'programs/arithmetic.cj').read_text(encoding='utf-8').replace('add(20, 22)','subtract(20, 22)'),encoding='utf-8')
        else:
            for file in source.rglob('*'):
                if file.is_file() and '.docguard' not in file.relative_to(source).parts:
                    dest=root/file.relative_to(source)
                    if not dest.resolve().is_relative_to(root): raise APIError('unsafe demo path')
                    dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(file,dest)

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    @property
    def app(self): return self.server.app
    def reply(self,status,data):
        raw=json.dumps(data,ensure_ascii=False).encode(); self.send_response(status); self.send_header('Content-Type','application/json; charset=utf-8'); self.send_header('Content-Length',str(len(raw))); self.send_header('Cache-Control','no-store'); self.send_header('X-Content-Type-Options','nosniff'); self.end_headers(); self.wfile.write(raw)
    def do_GET(self): self.dispatch(False)
    def do_POST(self): self.dispatch(True)
    def dispatch(self,post):
        try:
            port=self.server.server_port
            allowed={f'127.0.0.1:{port}',f'localhost:{port}'}
            if self.headers.get('Host') not in allowed: raise APIError('invalid loopback Host',403)
            if post:
                if self.headers.get('Origin') != 'http://'+self.headers.get('Host',''): raise APIError('same-origin request required',403)
                if not hmac.compare_digest(self.headers.get('X-DocGuard-Token',''),self.app.token): raise APIError('invalid session token',403)
                try: length=int(self.headers.get('Content-Length','0'))
                except ValueError: raise APIError('invalid content length')
                if length<0 or length>2*1024*1024: raise APIError('request too large')
                try: b=json.loads(self.rfile.read(length))
                except (ValueError,UnicodeError): raise APIError('invalid JSON')
                if not isinstance(b,dict): raise APIError('JSON object required')
            else: b={}
            path=unquote(urlsplit(self.path).path); parts=path.strip('/').split('/'); a=self.app
            if path=='/api/bootstrap' and not post:
                return self.reply(200,dict(token=a.token,projects=[a.record(p) for p in a.projects.values()],platform=platform.system()+'-'+platform.machine(),active_job=a.get_job(a.active) if a.active in a.jobs else None,capabilities={'actions':sorted(ACTIONS),'native_available':(ROOT/'build/cj-docguard').is_file(),'snapshot':True}))
            if path=='/api/projects' and post: return self.reply(200,a.register(b.get('config')))
            if path=='/api/projects/init' and post: return self.initialize(b)
            if parts[:2]==['api','projects'] and len(parts)==4:
                id,operation=parts[2:]; p=a.project(id)
                if operation=='report' and not post: return self.reply(200,a.report(id))
                if operation=='history' and not post:
                    report=a.report(id)['report'] or {}; items=copy.deepcopy(report.get('history',[]))
                    for item in items:item.update(freshness='FROZEN',eligible=False)
                    return self.reply(200,{'items':items,'scope':'FROZEN_ARCHIVE_NOT_CURRENT'})
                if operation=='config':
                    return self.reply(200,a.save_config(id,b.get('content')) if post else {'content':Path(p['config']).read_text(encoding='utf-8')})
                if operation=='jobs' and post: return self.reply(200,a.start_job(id,b))
                if operation=='compare' and post:
                    old,new=b.get('old'),b.get('new')
                    if not isinstance(old,dict) or not isinstance(new,dict): raise APIError('old and new report objects required')
                    for report in (old,new):
                        if not isinstance(report.get('results',[]),list) or any(not isinstance(item,dict) for item in report.get('results',[])): raise APIError('report results must be objects')
                    def keyed(r): return {(x.get('example_id'),x.get('sdk_version'),x.get('platform')):x for x in r.get('results',[])}
                    left,right=keyed(old),keyed(new)
                    changes=[{'example_id':k[0],'sdk_version':k[1],'platform':k[2],'before':left.get(k),'after':right.get(k)} for k in left.keys()|right.keys() if left.get(k)!=right.get(k)]
                    def symbols(report):
                        api=report.get('api',{})
                        values=api.get('symbols',[]) if isinstance(api,dict) else []
                        if not isinstance(values,list) or any(not isinstance(x,dict) for x in values): raise APIError('symbols must be objects')
                        return {x.get('id'):x for x in values}
                    ls,rs=symbols(old),symbols(new)
                    old_manifest,new_manifest=old.get('manifest',{}),new.get('manifest',{})
                    if not isinstance(old_manifest,dict) or not isinstance(new_manifest,dict): raise APIError('manifest must be object')
                    return self.reply(200,{'scope':'SUPPLIED_SNAPSHOTS_ONLY','changes':changes,'old_summary':old.get('summary'),'new_summary':new.get('summary'),'symbols_added':[rs[k] for k in rs.keys()-ls.keys()],'symbols_removed':[ls[k] for k in ls.keys()-rs.keys()],'old_fingerprint':old_manifest.get('fingerprint'),'new_fingerprint':new_manifest.get('fingerprint'),'inputs_changed':old_manifest.get('fingerprint')!=new_manifest.get('fingerprint')})
            if path=='/api/jobs' and not post: return self.reply(200,{'items':[a.get_job(id) for id in list(a.jobs)]})
            if parts[:2]==['api','jobs']:
                if len(parts)==3 and not post: return self.reply(200,a.get_job(parts[2]))
                if len(parts)==4 and parts[3]=='cancel' and post: return self.reply(200,a.cancel(parts[2]))
            if parts[:2]==['api','artifacts'] and len(parts)==3 and not post:
                id=parts[2]
                if len(id)!=32 or any(c not in '0123456789abcdef' for c in id): raise APIError('artifact not found',404)
                j=a.get_job(id)
                if j['status']!='succeeded' or not j.get('artifact_url'): raise APIError('artifact not available',404)
                return self.file(a.state/'artifacts'/id/'export.zip', 'application/zip',download=True)
            if not post and not path.startswith('/api/'):
                web=ROOT/'web'; target=(web/('index.html' if path=='/' else path.lstrip('/'))).resolve()
                if not target.is_relative_to(web.resolve()): raise APIError('not found',404)
                return self.file(target,mimetypes.guess_type(str(target))[0] or 'application/octet-stream')
            raise APIError('not found',404)
        except APIError as e: self.reply(e.status,{'error':str(e)})
        except (OSError,ValueError,TypeError,KeyError,RuntimeError,subprocess.TimeoutExpired) as e: self.reply(400,{'error':str(e)})
    def file(self,path,kind,download=False):
        if not path.is_file(): raise APIError('not found',404)
        raw=path.read_bytes(); self.send_response(200); self.send_header('Content-Type',kind); self.send_header('Content-Length',str(len(raw))); self.send_header('X-Content-Type-Options','nosniff')
        if download:self.send_header('Content-Disposition','attachment; filename="docguard-export.zip"')
        self.end_headers(); self.wfile.write(raw)
    def initialize(self,b):
        a=self.app; directory=b.get('directory'); name=b.get('name')
        if not isinstance(directory,str) or not Path(directory).is_absolute() or not isinstance(name,str) or not name.strip(): raise APIError('absolute nonexistent directory and name required')
        target=Path(directory)
        if target.exists(): raise APIError('initialization directory already exists')
        with a.lock:
            a.idle(); a.active='initializing'
        try:
            target.mkdir(parents=True)
            result=subprocess.run([str(ROOT/'build/cj-docguard'),'init','--project',str(target)],env=dev.sdk_env('1.1.3'),cwd=ROOT,capture_output=True,text=True,timeout=30)
            if result.returncode: raise APIError(result.stdout+result.stderr)
            config=target/'docguard.toml'; content=config.read_text(encoding='utf-8'); content=content.replace('name = "my-cangjie-project"','name = '+json.dumps(name,ensure_ascii=False),1); atomic(config,content)
            return self.reply(200,a.register(str(config)))
        finally:
            with a.lock:a.active=None

def make_server(app,host='127.0.0.1',port=8765):
    if host not in ('127.0.0.1','localhost'): raise ValueError('loopback binding required')
    server=ThreadingHTTPServer((host,port),Handler); server.app=app; server.daemon_threads=True; return server
