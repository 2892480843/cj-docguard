import sys, unittest, tempfile, json, threading, urllib.request, urllib.error, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from reference_workbench import Workbench, make_server

class WorkbenchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.app = Workbench(state_dir=self.root / 'state', setup_demo=False)
        self.config = self.root / 'docguard.toml'
        self.config.write_text('[project]\nname="test"\noutput=".docguard"\ntrusted=false\n', encoding='utf-8')
        self.project = self.app.register(str(self.config))
        self.server = make_server(self.app, port=0)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.url = 'http://127.0.0.1:' + str(self.server.server_port)
    def tearDown(self):
        self.server.shutdown(); self.server.server_close(); self.tmp.cleanup()
    def request(self, path, body=None, headers=None):
        h = {'Host': '127.0.0.1:' + str(self.server.server_port)}
        if body is not None:
            h.update({'X-DocGuard-Token': self.app.token, 'Origin': self.url, 'Content-Type':'application/json'})
        h.update(headers or {})
        req = urllib.request.Request(self.url + path, data=None if body is None else json.dumps(body).encode(), headers=h)
        try:
            with urllib.request.urlopen(req) as r: return r.status, json.load(r)
        except urllib.error.HTTPError as e:
            with e: return e.code, json.load(e)
    def test_absent_report_and_frozen_history(self):
        p = '/api/projects/' + self.project['id']
        self.assertIsNone(self.request(p + '/report')[1]['report'])
        out = self.root / '.docguard'; out.mkdir()
        (out/'report.json').write_text(json.dumps({'history':[{'eligible':True,'freshness':'CURRENT'}]}))
        self.assertEqual(self.request(p+'/history')[1]['items'], [{'eligible':False,'freshness':'FROZEN'}])
    def test_auth_host_and_origin(self):
        self.assertEqual(self.request('/api/projects', {}, {'X-DocGuard-Token':'bad'})[0],403)
        self.assertEqual(self.request('/api/projects', {}, {'Origin':'https://evil.test'})[0],403)
        self.assertEqual(self.request('/api/bootstrap', headers={'Host':'evil.test'})[0],403)
    def test_config_atomic_validation_and_registry(self):
        p = '/api/projects/' + self.project['id'] + '/config'
        before=self.config.read_text()
        self.assertEqual(self.request(p, {'content':'[bad'})[0],400)
        self.assertEqual(self.config.read_text(),before)
        self.assertEqual(len(Workbench(state_dir=self.root/'state', setup_demo=False).projects),1)
        self.assertEqual(self.request('/api/projects', {'config':'relative.toml'})[0],400)
    def test_job_live_logs_busy_cancel(self):
        self.app.command = lambda p,a,b: ([sys.executable,'-u','-c','import time; print("live",flush=True); time.sleep(30)'], None)
        job=self.app.start_job(self.project['id'], {'action':'build'})
        for _ in range(100):
            if 'live' in self.app.get_job(job['id'])['stdout']: break
            time.sleep(.02)
        self.assertIn('live',self.app.get_job(job['id'])['stdout'])
        self.assertEqual(self.request('/api/projects/'+self.project['id']+'/jobs',{'action':'doctor'})[0],409)
        self.app.cancel(job['id'])
        for _ in range(100):
            if self.app.get_job(job['id'])['status']=='cancelled': break
            time.sleep(.02)
        self.assertEqual(self.app.get_job(job['id'])['status'],'cancelled')
    def test_timeout_and_bounded_logs_quality_failure(self):
        self.app.timeout=.15
        self.app.command=lambda p,a,b: ([sys.executable,'-u','-c','import time; print("x"*400000,flush=True); time.sleep(30)'],None)
        job=self.app.start_job(self.project['id'],{'action':'build'})
        for _ in range(150):
            current=self.app.get_job(job['id'])
            if current['finished_at']: break
            time.sleep(.02)
        self.assertEqual(current['status'],'failed'); self.assertIn('timed out',current['error'])
        self.assertLessEqual(len(current['stdout']),256*1024)
        self.app.command=lambda p,a,b: ([sys.executable,'-c','raise SystemExit(1)'],None)
        job=self.app.start_job(self.project['id'],{'action':'check'})
        for _ in range(100):
            current=self.app.get_job(job['id'])
            if current['finished_at']: break
            time.sleep(.02)
        self.assertEqual(current['exit_code'],1); self.assertEqual(current['status'],'failed')
    def test_export_artifact_and_demo_boundary(self):
        self.app.command=lambda p,a,b: ([sys.executable,'-c','import pathlib,sys; p=pathlib.Path(sys.argv[-1]); (p/"example.cj").write_text("example"); print("{}")'],None)
        job=self.app.start_job(self.project['id'],{'action':'export','sdk':'1.1.3','platform':'darwin-arm64','example':'x'})
        for _ in range(100):
            current=self.app.get_job(job['id'])
            if current['finished_at']: break
            time.sleep(.02)
        self.assertEqual(current['status'],'succeeded',current)
        self.assertTrue((self.app.state/'artifacts'/job['id']/'export.zip').is_file())
        self.assertEqual(self.request('/api/projects/'+self.project['id']+'/jobs',{'action':'demo_break'})[0],400)
        self.config.write_text('[project]\noutput="../outside"\n')
        self.assertEqual(self.request('/api/projects/'+self.project['id']+'/report')[0],400)
    def test_large_query_result_survives_log_truncation(self):
        self.app.command=lambda p,a,b: ([sys.executable,'-c','import json; print(json.dumps({"items":["x"*400000]}))'],None)
        job=self.app.start_job(self.project['id'],{'action':'query'})
        for _ in range(200):
            current=self.app.get_job(job['id'])
            if current['finished_at']: break
            time.sleep(.02)
        self.assertEqual(current['status'],'succeeded',current)
        self.assertEqual(len(current['result']['items'][0]),400000)
        self.assertLessEqual(len(current['stdout']),256*1024)
    def test_live_logs_preserve_utf8_across_read_boundaries(self):
        self.app.command=lambda p,a,b: ([sys.executable,'-c','import sys; sys.stdout.buffer.write(("仓颉"*3000).encode())'],None)
        job=self.app.start_job(self.project['id'],{'action':'build'})
        for _ in range(200):
            current=self.app.get_job(job['id'])
            if current['finished_at']: break
            time.sleep(.02)
        self.assertEqual(current['status'],'succeeded',current)
        self.assertNotIn('\ufffd',current['stdout'])
        self.assertEqual(current['stdout'],'仓颉'*3000)
    def test_query_overflow_fails_explicitly(self):
        from unittest.mock import patch
        self.app.command=lambda p,a,b: ([sys.executable,'-c','print("x"*10000)'],None)
        with patch('reference_workbench.RESULT_LIMIT',1024):
            job=self.app.start_job(self.project['id'],{'action':'query'})
            for _ in range(200):
                current=self.app.get_job(job['id'])
                if current['finished_at']: break
                time.sleep(.02)
        self.assertEqual(current['status'],'failed'); self.assertIn('output exceeded',current['error'])
    def test_shutdown_waits_and_kills_sigint_ignoring_native(self):
        self.app.command=lambda p,a,b: ([sys.executable,'-u','-c','import signal,time; signal.signal(signal.SIGINT,signal.SIG_IGN); print("ready",flush=True); time.sleep(30)'],None)
        job=self.app.start_job(self.project['id'],{'action':'build'})
        for _ in range(100):
            if 'ready' in self.app.get_job(job['id'])['stdout']: break
            time.sleep(.02)
        self.app.shutdown()
        current=self.app.get_job(job['id'])
        self.assertEqual(current['status'],'cancelled'); self.assertIsNotNone(current['finished_at'])
        self.assertFalse(self.app.processes)
    def test_demo_break_idempotent_and_restore(self):
        import dev
        original=(dev.ROOT/'examples/healthy/programs/arithmetic.cj').read_text()
        app=Workbench(state_dir=self.root/'demo-state')
        p=next(iter(app.projects.values())); target=Path(p['root'])/'programs/arithmetic.cj'
        app.demo(p,'demo_break'); broken=target.read_text()
        app.demo(p,'demo_break'); self.assertEqual(target.read_text(),broken)
        self.assertIn('subtract(20, 22)',broken)
        self.assertEqual((dev.ROOT/'examples/healthy/programs/arithmetic.cj').read_text(),original)
        app.demo(p,'demo_restore'); self.assertEqual(target.read_text(),original)
    def test_compare_symbols_and_manifest(self):
        p='/api/projects/'+self.project['id']+'/compare'
        status,result=self.request(p,{'old':{'manifest':{'fingerprint':'a'},'api':{'symbols':[{'id':'a'}]}},'new':{'manifest':{'fingerprint':'b'},'api':{'symbols':[{'id':'b'}]}}})
        self.assertEqual(status,200); self.assertEqual(result['symbols_added'],[{'id':'b'}]); self.assertTrue(result['inputs_changed'])
        self.assertEqual(result['symbols_removed'],[{'id':'a'}])
    def test_actual_native_query(self):
        import dev
        if not (dev.ROOT/'build/cj-docguard').is_file(): self.skipTest('native CLI unavailable')
        try: dev.sdk_env('1.1.3')
        except RuntimeError as e: self.skipTest(str(e))
        app=Workbench(state_dir=self.root/'native-state')
        project=next(iter(app.projects.values()))
        job=app.start_job(project['id'],{'action':'query','tool':'list_symbols'})
        for _ in range(1500):
            current=app.get_job(job['id'])
            if current['finished_at']: break
            time.sleep(.02)
        self.assertEqual(current['status'],'succeeded',current)
        self.assertEqual(current['result']['tool'],'list_symbols')
        self.assertTrue(current['result']['items'])
        import platform
        bootstrap=self.request('/api/bootstrap')[1]
        self.assertEqual(bootstrap['platform'],platform.system()+'-'+platform.machine())
        job=app.start_job(project['id'],{'action':'query','tool':'get_verified_examples','sdk':'1.1.3','platform':bootstrap['platform']})
        for _ in range(1500):
            current=app.get_job(job['id'])
            if current['finished_at']: break
            time.sleep(.02)
        self.assertEqual(current['status'],'succeeded',current)
        self.assertEqual(current['result']['platform'],bootstrap['platform'])
    def test_query_argv_and_export_validation(self):
        argv,_=self.app.command(self.project,'query',{'tool':'list_symbols','symbol':'add'})
        self.assertIn('query',argv); self.assertIn('list_symbols',argv)
        self.assertEqual(self.request('/api/projects/'+self.project['id']+'/jobs',{'action':'export'})[0],400)
        self.assertEqual(self.request('/api/artifacts/../../docguard.toml')[0],404)

if __name__=='__main__': unittest.main()
