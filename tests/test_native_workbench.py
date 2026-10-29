"""Real native HTTP regression tests; build via scripts/build_workbench.sh first.

No Python serving process, mocked compiler, or manufactured evidence is used.
"""
import concurrent.futures
import http.client
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import dev


class NativeWorkbenchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix='cjdg-native-http-')
        cls.directory = Path(cls.tmp.name)
        cls.environment = dev.sdk_env('1.1.3')
        cls.server, cls.port, cls.log = cls.launch(cls.directory / 'state')
        cls.origin = f'http://127.0.0.1:{cls.port}'
        cls.token = cls.request('/api/bootstrap')[1]['token']

    @classmethod
    def launch(cls, state, environment=None):
        binary = Path(os.environ.get('CJ_DOCGUARD_TEST_WORKBENCH', ROOT / 'build/cj-docguard-workbench'))
        if not binary.is_file():
            raise RuntimeError('build/cj-docguard-workbench missing; run scripts/build_workbench.sh')
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        log = tempfile.TemporaryFile()
        process = subprocess.Popen([str(binary), '--root', str(ROOT), '--state-dir', str(state), '--port', str(port)],
                                   cwd=ROOT, env=environment or cls.environment, stdout=log, stderr=subprocess.STDOUT)
        for _ in range(100):
            if process.poll() is not None:
                log.seek(0)
                raise RuntimeError(log.read().decode('utf-8', 'replace'))
            try:
                with socket.create_connection(('127.0.0.1', port), timeout=.1):
                    return process, port, log
            except OSError:
                time.sleep(.05)
        process.kill(); process.wait(); log.close()
        raise RuntimeError('native server did not become ready')

    @classmethod
    def tearDownClass(cls):
        try:
            cls.server.send_signal(signal.SIGTERM)
            cls.server.wait(timeout=15)
            if cls.server.returncode != 0:
                cls.log.seek(0)
                raise AssertionError(cls.log.read().decode('utf-8', 'replace'))
        finally:
            if cls.server.poll() is None:
                cls.server.kill(); cls.server.wait()
            cls.log.close(); cls.tmp.cleanup()

    @classmethod
    def request(cls, path, body=None, headers=None, port=None, token=None):
        port = port or cls.port
        h = {'Host': f'127.0.0.1:{port}'}
        if body is not None:
            h.update({'Origin': f'http://127.0.0.1:{port}', 'X-DocGuard-Token': token or getattr(cls, 'token', ''),
                      'Content-Type': 'application/json'})
        h.update(headers or {})
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=10)
        try:
            connection.request('GET' if body is None else 'POST', path,
                               None if body is None else json.dumps(body).encode(), h)
            response = connection.getresponse()
            payload = response.read()
            return response.status, json.loads(payload)
        finally:
            connection.close()

    def test_large_history_concurrent_reads_preserve_all_records(self):
        # Exercise transport pressure, not fabricated verification evidence. The
        # synthetic archive is only an HTTP payload and is never executed/qualified.
        directory, prefix = self.fixture()
        history = [{'sequence': i, 'eligible': False, 'freshness': 'FROZEN',
                    'stdout': 'archive-only-' + ('x' * 24000),
                    'metadata': {f'field-{k}': 'record-' + ('y' * 100) for k in range(64)}}
                   for i in range(640)]
        payload = {'history': history, 'results': [], 'summary': {'TOTAL': 0}}
        target = directory / '.docguard/report.json'
        target.parent.mkdir(exist_ok=True)
        original = json.dumps(payload).encode()
        target.write_bytes(original)

        def fetch(index):
            endpoint = 'history' if index % 3 == 0 else 'report'
            status, body = self.request(prefix + '/' + endpoint)
            self.assertEqual(status, 200)
            records = body['items'] if endpoint == 'history' else body['report']['history']
            self.assertEqual(len(records), 640)
            self.assertEqual([r['sequence'] for r in records], list(range(640)))
            self.assertTrue(all(r['stdout'] == history[0]['stdout'] for r in records))
            self.assertTrue(all(not r['eligible'] for r in records))
            self.assertTrue(all(r['metadata'] == history[0]['metadata'] for r in records))

        for _ in range(2):
            with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
                list(pool.map(fetch, range(12)))
        self.assertEqual(target.read_bytes(), original)
        self.assertEqual(self.request('/api/bootstrap')[0], 200)
        # A reader can leave while a large response is being sent. Disk-backed
        # response resources must be released on disconnect as well as success.
        for _ in range(2):
            with socket.create_connection(('127.0.0.1', self.port), timeout=10) as sock:
                sock.sendall((f'GET {prefix}/report HTTP/1.1\r\n'
                              f'Host: 127.0.0.1:{self.port}\r\n\r\n').encode())
                self.assertTrue(sock.recv(4096).startswith(b'HTTP/1.1 200'))
            self.assertEqual(self.request('/api/bootstrap')[0], 200)
        responses = self.directory / 'state/responses'
        self.assertFalse(list(responses.iterdir()) if responses.exists() else [])
        self.assertEqual(target.read_bytes(), original)

    def raw(self, data):
        with socket.create_connection(('127.0.0.1', self.port), timeout=10) as sock:
            sock.sendall(data); sock.shutdown(socket.SHUT_WR)
            result = b''
            try:
                while chunk := sock.recv(8192):
                    result += chunk
            except ConnectionResetError:
                pass  # Oversized requests may leave rejected input unread.
        self.assertTrue(result.startswith(b'HTTP/1.1 '), result)
        return int(result.split(b' ', 2)[1]), result

    def fixture(self, long=False):
        directory = Path(tempfile.mkdtemp(dir=self.directory))
        (directory / 'src').mkdir()
        (directory / 'src/lib.cj').write_text('package sample\npublic func add(a: Int64, b: Int64): Int64 { a+b }\n', encoding='utf-8')
        (directory / 'README.md').write_text('# Sample\n`add`\n', encoding='utf-8')
        config = '[project]\nname="HTTP regression"\nsources=["src"]\ndocuments=["README.md"]\noutput=".docguard"\ntrusted=true\nclosed_inputs=true\n\n[[sdks]]\nversion="1.1.3"\n'
        if not long:
            (directory / 'example.cj').write_text('main(): Int64 { println(42); return 0 }\n', encoding='utf-8')
            config += '\n[[examples]]\nid="sample"\nfile="example.cj"\nsymbol="add"\nkind="program"\nmode="run"\nsdks=["1.1.3"]\nstdout="42\\n"\nexpected_exit=0\ntimeout_ms=1000\nrequired=true\n'
        if long:
            (directory / 'long.cj').write_text('package sample\nmain(): Int64 { while (true) {} ; return 0 }\n', encoding='utf-8')
            config += '\n[[examples]]\nid="long"\nfile="long.cj"\nsymbol="add"\nkind="program"\nmode="run"\nsdks=["1.1.3"]\nstdout=""\nexpected_exit=0\ntimeout_ms=20000\nrequired=true\n'
        (directory / 'docguard.toml').write_text(config, encoding='utf-8')
        status, project = self.request('/api/projects', {'config': str(directory / 'docguard.toml')})
        self.assertEqual(status, 200, project)
        return directory, '/api/projects/' + project['id']

    def wait_job(self, job, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            status, current = self.request('/api/jobs/' + job['id'])
            self.assertEqual(status, 200)
            if current['status'] not in ('queued', 'running'):
                return current
            time.sleep(.05)
        self.fail(f'job did not finish: {current}')

    @staticmethod
    def descendants(pid):
        rows = subprocess.check_output(['/bin/ps', '-axo', 'pid=,ppid='], text=True)
        pairs = [tuple(map(int, row.split())) for row in rows.splitlines() if row.strip()]
        found = {pid}
        while True:
            expanded = found | {child for child, parent in pairs if parent in found}
            if expanded == found:
                return found - {pid}
            found = expanded

    def assert_processes_gone(self, pids):
        deadline = time.monotonic() + 5
        alive = set(pids)
        while alive and time.monotonic() < deadline:
            for pid in list(alive):
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    alive.remove(pid)
            if alive:
                time.sleep(.05)
        self.assertFalse(alive, f'unreaped native processes: {alive}')

    def test_invalid_worker_heap_rejected_before_launch(self):
        process, port, log = self.launch(self.directory / 'bad-heap',
            {**self.environment, 'CJ_DOCGUARD_HEAP_SIZE': 'unbounded'})
        try:
            bootstrap = self.request('/api/bootstrap', port=port)[1]
            project = next(p for p in bootstrap['projects'] if p.get('demo'))
            status, job = self.request('/api/projects/' + project['id'] + '/jobs',
                {'action': 'doctor'}, port=port, token=bootstrap['token'])
            self.assertEqual(status, 200)
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                job = self.request('/api/jobs/' + job['id'], port=port)[1]
                if job['status'] not in ('queued', 'running'):
                    break
                time.sleep(.05)
            self.assertEqual(job['status'], 'failed')
            self.assertIn('CJ_DOCGUARD_HEAP_SIZE', job.get('error') or '')
            self.assertEqual(job['stdout'], '')
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
            log.close()

    def test_bootstrap_native_identity(self):
        status, data = self.request('/api/bootstrap')
        self.assertEqual(status, 200)
        self.assertEqual(data['implementation'], 'Cangjie')
        self.assertTrue(data['capabilities']['native_server'])
        self.assertTrue((ROOT / 'build/cj-docguard').is_file())
        self.assertEqual(len(data['token']), 64)

    def test_auth_host_origin_token(self):
        for headers in ({'Host': 'evil.invalid'}, {'Host': f'127.0.0.1:{self.port+1}'}, {'Origin': 'https://evil.invalid'}):
            self.assertEqual(self.request('/api/bootstrap', headers=headers)[0], 403)
        for headers in ({'X-DocGuard-Token': 'wrong'}, {'Origin': ''}, {'Origin': 'https://evil.invalid'}):
            self.assertEqual(self.request('/api/projects', {}, headers)[0], 403)

    def test_duplicate_and_ambiguous_framing(self):
        prefix = f'POST /api/projects HTTP/1.1\r\nHost: 127.0.0.1:{self.port}\r\n'.encode()
        for header in (b'Content-Length: 0\r\nContent-Length: 0\r\n', b'Transfer-Encoding: chunked\r\n',
                       b'Content-Length: -1\r\n', b'Content-Length: 1,1\r\n', b'Host: localhost\r\n'):
            self.assertEqual(self.raw(prefix + header + b'\r\n')[0], 400)

    def test_body_and_header_limits(self):
        prefix = f'POST /api/projects HTTP/1.1\r\nHost: 127.0.0.1:{self.port}\r\n'.encode()
        self.assertEqual(self.raw(prefix + b'Content-Length: 2097153\r\n\r\n')[0], 413)
        self.assertEqual(self.raw(prefix + b'X-Large: ' + b'x'*17000 + b'\r\n\r\n')[0], 431)

    def test_invalid_request_targets(self):
        for target in ('//evil', 'http://evil/', '/#fragment', '/api/%zz', '/api/%00'):
            status, _ = self.raw(f'GET {target} HTTP/1.1\r\nHost: 127.0.0.1:{self.port}\r\n\r\n'.encode())
            self.assertEqual(status, 400, target)

    def test_invalid_json_and_utf8(self):
        prefix = f'POST /api/projects HTTP/1.1\r\nHost: 127.0.0.1:{self.port}\r\nOrigin: {self.origin}\r\nX-DocGuard-Token: {self.token}\r\nContent-Length: '.encode()
        for body in (b'[]', b'{', b'\xff', b'{"x":1,"x":2}', b'{"x":' + b'['*300 + b'0' + b']'*300 + b'}'):
            self.assertEqual(self.raw(prefix + str(len(body)).encode() + b'\r\n\r\n' + body)[0], 400)

    def test_connection_close_and_response_headers(self):
        status, raw = self.raw(f'GET /api/bootstrap HTTP/1.1\r\nHost: localhost:{self.port}\r\n\r\n'.encode())
        self.assertEqual(status, 200)
        for header in (b'Connection: close', b'Cache-Control: no-store', b'X-Content-Type-Options: nosniff'):
            self.assertIn(header, raw.split(b'\r\n\r\n')[0])

    def test_stalled_header_timeout_and_concurrency_bound(self):
        clients = []
        try:
            for _ in range(16):
                sock = socket.create_connection(('127.0.0.1', self.port), timeout=8)
                sock.sendall(b'GET / HTTP/1.1\r\n'); clients.append(sock)
            time.sleep(.1)
            self.assertEqual(self.raw(f'GET /api/bootstrap HTTP/1.1\r\nHost: localhost:{self.port}\r\n\r\n'.encode())[0], 503)
            clients[0].settimeout(8)
            self.assertTrue(clients[0].recv(8192).startswith(b'HTTP/1.1 408 '))
        finally:
            for sock in clients:
                sock.close()
        time.sleep(.1)

    def test_registry_and_config_atomic_validation(self):
        directory, path = self.fixture()
        original = (directory / 'docguard.toml').read_text()
        self.assertEqual(self.request(path + '/config')[1]['content'], original)
        self.assertEqual(self.request(path + '/config', {'content': '[bad'})[0], 400)
        self.assertEqual((directory / 'docguard.toml').read_text(), original)
        changed = original.replace('HTTP regression', 'Saved name')
        self.assertEqual(self.request(path + '/config', {'content': changed})[0], 200)
        self.assertEqual((directory / 'docguard.toml').read_text(), changed)
        registry = json.loads((self.directory / 'state/projects.json').read_text())
        self.assertIn(path.split('/')[-1], [p['id'] for p in registry])
        self.assertEqual(self.request('/api/projects', {'config': 'relative.toml'})[0], 400)

    def test_registry_survives_server_restart(self):
        directory, _ = self.fixture()
        state = self.directory / 'restart-state'
        process, port, log = self.launch(state)
        try:
            token = self.request('/api/bootstrap', port=port)[1]['token']
            status, project = self.request('/api/projects', {'config': str(directory / 'docguard.toml')}, port=port, token=token)
            self.assertEqual(status, 200)
            process.send_signal(signal.SIGTERM)
            self.assertEqual(process.wait(timeout=15), 0)
            log.close()
            process, port, log = self.launch(state)
            bootstrap = self.request('/api/bootstrap', port=port)[1]
            reopened = [p for p in bootstrap['projects'] if p['id'] == project['id']]
            self.assertEqual(len(reopened), 1)
            self.assertEqual(reopened[0]['config'], str((directory / 'docguard.toml').resolve()))
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()
            log.close()

    def test_source_optimistic_concurrency(self):
        directory, path = self.fixture()
        endpoint = path + '/source'
        before = self.request(endpoint + '?path=src%2Flib.cj')[1]
        content = before['content'] + '// saved\n'
        self.assertEqual(self.request(endpoint, {'path': 'src/lib.cj', 'content': content})[0], 400)
        self.assertEqual(self.request(endpoint, {'path': 'src/lib.cj', 'content': content, 'expected_sha256': 'bad'})[0], 409)
        status, after = self.request(endpoint, {'path': 'src/lib.cj', 'content': content, 'expected_sha256': before['sha256']})
        self.assertEqual(status, 200)
        self.assertNotEqual(before['sha256'], after['sha256'])
        self.assertEqual((directory / 'src/lib.cj').read_text(), content)

    def test_source_path_escape_and_symlink(self):
        directory, path = self.fixture()
        (directory / 'src/escape.cj').symlink_to(ROOT / 'src/main.cj')
        for relative in ('../outside', '/etc/passwd', 'src/escape.cj'):
            self.assertIn(self.request(path + '/source?path=' + quote(relative, safe=''))[0], (400, 403, 404))
        self.assertIn(self.request('/../../etc/passwd')[0], (400, 403, 404))

    def test_real_native_build_and_query(self):
        _, path = self.fixture()
        for action in ('build', 'query'):
            status, job = self.request(path + '/jobs', {'action': action})
            self.assertEqual(status, 200, job)
            result = self.wait_job(job)
            self.assertEqual(result['status'], 'succeeded', result)
            if action == 'query':
                self.assertIsInstance(result['result'], dict)
        self.assertIsInstance(self.request(path + '/report')[1]['report'], dict)

    def test_global_busy_cancel_and_other_project_recovery(self):
        _, path = self.fixture(long=True)
        _, other = self.fixture()
        status, job = self.request(path + '/jobs', {'action': 'verify', 'sdk': '1.1.3'})
        self.assertEqual(status, 200)
        children = set()
        for _ in range(60):
            children = self.descendants(self.server.pid)
            if len(children) >= 2:
                break
            time.sleep(.05)
        self.assertGreaterEqual(len(children), 2, 'actual native supervisor and CLI must launch before cancellation')
        self.assertEqual(self.request(other + '/jobs', {'action': 'build'})[0], 409)
        for _ in range(60):
            lock_info = self.request(path + '/lock')[1]
            if lock_info.get('owner'):
                break
            time.sleep(.05)
        self.assertTrue(lock_info.get('exists'), lock_info)
        self.assertFalse(lock_info.get('recoverable'), lock_info)
        self.assertEqual(self.request('/api/jobs/' + job['id'] + '/cancel', {})[0], 200)
        self.assertEqual(self.wait_job(job)['status'], 'cancelled')
        self.assert_processes_gone(children)
        status, recovery = self.request(other + '/jobs', {'action': 'build'})
        self.assertEqual(status, 200)
        self.assertEqual(self.wait_job(recovery)['status'], 'succeeded')
        lock_info = self.request(path + '/lock')[1]
        if lock_info['exists']:
            self.assertTrue(lock_info['recoverable'], lock_info)
            self.assertEqual(self.request(path + '/recover-lock', {'acknowledge': True})[0], 200)
            self.assertFalse(self.request(path + '/lock')[1]['exists'])
            status, retry = self.request(path + '/jobs', {'action': 'build'})
            self.assertEqual(status, 200)
            self.assertEqual(self.wait_job(retry)['status'], 'succeeded')
        # Recovery is explicit through the service; no test-side lock removal.

    def test_initialized_project_real_verify_and_broken_link(self):
        directory = Path(tempfile.mkdtemp(dir=self.directory)) / 'initialized'
        status, project = self.request('/api/projects/init', {'directory': str(directory), 'name': 'HTTP initialized'})
        self.assertEqual(status, 200, project)
        self.assertFalse(project['trusted'])
        path = '/api/projects/' + project['id']
        original = self.request(path + '/config')[1]['content']
        self.assertIn('trusted = false', original)
        self.assertIn('package docguard_demo', (directory / 'docguard-demo/src/identity.cj').read_text())
        self.assertIn('package docguard_demo', (directory / 'docguard-demo/examples/identity.cj').read_text())
        trusted = original.replace('trusted = false', 'trusted = true').replace('closed_inputs = false', 'closed_inputs = true')
        self.assertEqual(self.request(path + '/config', {'content': trusted})[0], 200)
        status, job = self.request(path + '/jobs', {'action': 'verify', 'sdk': '1.1.3'})
        self.assertEqual(status, 200, job)
        verified = self.wait_job(job, timeout=25)
        self.assertEqual(verified['exit_code'], 0, verified)
        self.assertEqual(verified['status'], 'succeeded', verified)
        report = self.request(path + '/report')[1]['report']
        self.assertEqual(report['results'][0]['status'], 'RUN_VERIFIED')
        self.assertTrue(report['results'][0]['eligible'])
        broken = trusted + '\n[[links]]\nfrom="docguard.toml"\ntarget="missing.cj"\n'
        self.assertEqual(self.request(path + '/config', {'content': broken})[0], 200)
        status, job = self.request(path + '/jobs', {'action': 'check'})
        self.assertEqual(status, 200)
        checked = self.wait_job(job)
        self.assertEqual(checked['exit_code'], 1, checked)
        self.assertEqual(checked['status'], 'failed')
        links = self.request(path + '/report')[1]['report']['links']
        self.assertTrue(any(item['target'] == 'missing.cj' and item['status'] == 'FAIL' for item in links), links)

    def test_rich_markdown_link_results_exposed_by_native_report(self):
        directory, path = self.fixture()
        (directory / 'target file.md').write_text('# Repeat\n# Repeat\n', encoding='utf-8')
        (directory / 'README.md').write_text(
            '[full][doc]\n[doc]: target%20file.md#repeat-1 "title"\n'
            '[broken](missing.md)\n[external](https://example.com)\n'
            '`[ignored](missing-code.md)`\n', encoding='utf-8')
        status, job = self.request(path + '/jobs', {'action': 'build'})
        self.assertEqual(status, 200, job)
        self.assertEqual(self.wait_job(job)['status'], 'succeeded')
        report = self.request(path + '/report')[1]['report']
        documents = [row for row in report['links'] if row.get('scope') == 'document']
        self.assertEqual([row['status'] for row in documents], ['PASS', 'FAIL', 'UNVERIFIED'])
        self.assertEqual(report['link_summary']['TOTAL'], len(report['links']))
        self.assertEqual(report['link_summary']['FAIL'], 1)
        self.assertEqual(report['link_summary']['UNVERIFIED'], 1)
        self.assertTrue(any(row.get('syntax') == 'index' for row in report['links']))
        self.assertTrue(any(row.get('scope') == 'index' and row['syntax'] == 'html-href' for row in report['links']))
        self.assertEqual(report['links'][0]['line'], 1)
        self.assertEqual(report['links'][0]['syntax'], 'reference')
        self.assertEqual(report['links'][0]['target'], 'target%20file.md#repeat-1')
        self.assertFalse(report['links'][2]['required'])
        status, job = self.request(path + '/jobs', {'action': 'check'})
        self.assertEqual(status, 200)
        self.assertEqual(self.wait_job(job)['exit_code'], 1)
        self.assertEqual(self.request(path + '/report')[1]['report']['link_summary']['FAIL'], 1)

    def test_actual_index_hrefs_and_multiline_heading_results(self):
        directory, path = self.fixture()
        (directory / 'guide.md').write_text('Title\nwith continuation\n---\n', encoding='utf-8')
        (directory / 'README.md').write_text('[valid](guide.md#title-with-continuation)\n', encoding='utf-8')
        status, job = self.request(path + '/jobs', {'action': 'verify'})
        self.assertEqual(status, 200)
        self.assertEqual(self.wait_job(job, timeout=30)['exit_code'], 0)
        index = directory / '.docguard/site/index.html'
        index.write_text(index.read_text() + '<a href="#missing-api">bad</a><img src="missing.png">', encoding='utf-8')
        status, job = self.request(path + '/jobs', {'action': 'check'})
        self.assertEqual(status, 200)
        self.assertEqual(self.wait_job(job)['exit_code'], 1)
        report = self.request(path + '/report')[1]['report']
        for target in ('#missing-api', 'missing.png'):
            actual = [row for row in report['links'] if row['target'] == target]
            self.assertEqual(len(actual), 1)
            self.assertEqual(actual[0]['status'], 'FAIL')
            self.assertEqual(actual[0]['from'], '.docguard/site/index.html')
            self.assertEqual(actual[0]['scope'], 'index')
        self.assertEqual(next(row for row in report['links'] if row['target'] == 'guide.md#title-with-continuation')['status'], 'PASS')
        # Report regeneration repairs the injected output; a subsequent check can pass.
        status, job = self.request(path + '/jobs', {'action': 'check'})
        self.assertEqual(status, 200)
        self.assertEqual(self.wait_job(job)['exit_code'], 0)

    def test_doctor_missing_sdk_and_real_version_mismatch(self):
        for kind in ('missing', 'mismatch'):
            with self.subTest(kind=kind):
                _, path = self.fixture()
                content = self.request(path + '/config')[1]['content']
                if kind == 'missing':
                    content = content.replace('1.1.3', '9.9.9')
                else:
                    content = content.replace('1.1.3', '1.2.0')
                    content = content.replace('version="1.2.0"', 'version="1.2.0"\nhome=' + json.dumps(str(dev.sdk_home('1.1.3'))))
                self.assertEqual(self.request(path + '/config', {'content': content})[0], 200)
                status, job = self.request(path + '/jobs', {'action': 'doctor'})
                self.assertEqual(status, 200)
                doctor = self.wait_job(job)
                self.assertEqual(doctor['exit_code'], 2, doctor)
                environments = doctor['result']['environments']
                self.assertEqual(len(environments), 1)
                self.assertFalse(environments[0]['available'])
                if kind == 'missing':
                    self.assertIn('home not registered', environments[0]['reason'])
                else:
                    self.assertEqual(environments[0]['version'], '1.1.3')
                    self.assertIn('SDK version mismatch: declared 1.2.0, actual 1.1.3', environments[0]['reason'])

    def test_lock_recovery_validation(self):
        dead = subprocess.Popen(['/usr/bin/true'])
        dead.wait()
        for kind in ('live', 'missing_metadata', 'wrong_config', 'extra_file', 'dead'):
            with self.subTest(kind=kind):
                directory, path = self.fixture()
                status, info = self.request(path + '/lock')
                self.assertEqual(status, 200)
                self.assertFalse(info['exists'])
                lock = directory / '.docguard/writer.lock'
                lock.mkdir(parents=True)
                owner = {'pid': os.getpid() if kind == 'live' else dead.pid,
                         'config': str((directory / 'docguard.toml').resolve()),
                         'started_at': '2026-10-29T00:00:00Z'}
                if kind == 'wrong_config':
                    owner['config'] = str(directory / 'another.toml')
                if kind != 'missing_metadata':
                    (lock / 'owner.json').write_text(json.dumps(owner), encoding='utf-8')
                if kind == 'extra_file':
                    (lock / 'unexpected').write_text('preserve me', encoding='utf-8')
                status, info = self.request(path + '/lock')
                self.assertEqual(status, 200, info)
                self.assertTrue(info['exists'])
                self.assertEqual(info['recoverable'], kind == 'dead')
                self.assertTrue(info['reason'])
                self.assertEqual(self.request(path + '/recover-lock', {})[0], 400)
                if kind == 'dead':
                    status, recovered = self.request(path + '/recover-lock', {'acknowledge': True})
                    self.assertEqual(status, 200, recovered)
                    self.assertTrue(recovered['recovered'])
                    self.assertFalse(recovered['exists'])
                    self.assertFalse(lock.exists())
                else:
                    self.assertEqual(self.request(path + '/recover-lock', {'acknowledge': True})[0], 409)
                    self.assertTrue(lock.is_dir())

    def test_lock_recovery_rejects_symlink_output(self):
        directory, path = self.fixture()
        output = directory / 'actual-output'
        lock = output / 'writer.lock'
        lock.mkdir(parents=True)
        dead = subprocess.Popen(['/usr/bin/true'])
        dead.wait()
        (lock / 'owner.json').write_text(json.dumps({'pid': dead.pid,
            'config': str((directory / 'docguard.toml').resolve()), 'started_at': '2026-10-29T00:00:00Z'}), encoding='utf-8')
        (directory / '.docguard').symlink_to(output, target_is_directory=True)
        self.assertEqual(self.request(path + '/lock')[0], 409)
        self.assertEqual(self.request(path + '/recover-lock', {'acknowledge': True})[0], 409)
        self.assertTrue((lock / 'owner.json').exists())

    def test_shutdown_reaps_native_processes(self):
        process, port, log = self.launch(self.directory / 'shutdown-state')
        try:
            token = self.request('/api/bootstrap', port=port)[1]['token']
            directory, _ = self.fixture(long=True)
            project = self.request('/api/projects', {'config': str(directory / 'docguard.toml')}, port=port, token=token)[1]
            self.request('/api/projects/' + project['id'] + '/jobs', {'action': 'verify', 'sdk': '1.1.3'}, port=port, token=token)
            children = set()
            for _ in range(60):
                children = self.descendants(process.pid)
                if len(children) >= 2:
                    break
                time.sleep(.05)
            self.assertGreaterEqual(len(children), 2)
            process.send_signal(signal.SIGTERM)
            self.assertEqual(process.wait(timeout=15), 0)
            self.assert_processes_gone(children)
        finally:
            if process.poll() is None:
                process.kill(); process.wait()
            log.close()


if __name__ == '__main__':
    unittest.main()
