"""Real native binary integration. No simulated compiler evidence."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import dev
ROOT = dev.ROOT
ENV = dev.sdk_env('1.1.3')
BINARY = ROOT / 'build/cj-docguard'

class NativeCLI(unittest.TestCase):
    def call(self, *args, code=0):
        r = subprocess.run([str(BINARY), *map(str, args)], env=ENV, capture_output=True, text=True, timeout=300)
        self.assertEqual(r.returncode, code, r.stdout + r.stderr)
        return r

    def test_help_and_init(self):
        self.assertIn('verify', self.call('--help').stdout)
        with tempfile.TemporaryDirectory() as t:
            config = Path(t) / 'docguard.toml'
            self.call('init', '--config', config)
            self.assertIn('trusted = false', config.read_text())
            self.call('init', '--config', config, code=2)
            self.call('verify', '--config', config, code=2)


class EvidenceIntegration(NativeCLI):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.config = self.root / 'docguard.toml'
        (self.root/'lib.cj').write_text('package demo\n/// Add inputs.\npublic func add(a: Int64,b: Int64): Int64 { a+b }\n')
        (self.root/'example.cj').write_text('package demo\nmain(): Int64 { println(add(1,2)); return 0 }\n')
        (self.root/'README.md').write_text('# Demo\n[Library](lib.cj)\n')
        (self.root/'binary.dat').write_bytes(bytes(range(256)))
        self.base = '[project]\nname="Integration"\nsources=["lib.cj"]\ndocuments=["README.md"]\noutput=".docguard"\ntrusted=true\nclosed_inputs=true\n[[sdks]]\nversion="1.1.3"\n[[examples]]\nid="add"\nfile="example.cj"\nsymbol="add"\n'
        self.config.write_text(self.base + 'stdout="3\\n"\nexpected_exit=0\n')

    def tearDown(self):
        self.temp.cleanup()

    def command(self, name, *args, code=0):
        return self.call(name, '--config', self.config, *args, code=code)

    def report(self):
        return json.loads((self.root/'.docguard/report.json').read_text())

    def query(self, **kwargs):
        args = ['--tool','get_verified_examples','--sdk','1.1.3','--platform','Darwin-arm64']
        for key,value in kwargs.items(): args += ['--'+key,str(value)]
        return json.loads(self.command('query', *args).stdout)

    def test_state_history_fingerprint_and_links(self):
        self.command('verify')
        r=self.report()
        self.assertEqual(r['summary']['VERIFIED_CURRENT'],1)
        self.assertEqual(len(self.query()['items']),1)
        old_fp=r['manifest']['fingerprint']
        source=self.root/'lib.cj'; original=source.read_text()
        source.write_text(original.replace('a+b','a-b'))
        self.assertEqual(self.query()['items'],[])
        self.command('check',code=1)
        self.assertEqual(self.report()['results'][0]['freshness'],'STALE')
        self.command('verify',code=1)
        self.assertEqual(self.report()['results'][0]['status'],'ASSERTION_FAILED')
        self.assertEqual(len(self.report()['history']),2)
        source.write_text(original)
        self.assertEqual(self.query()['items'],[], 'newer failed attempt blocks earlier matching success')
        self.command('verify')
        self.assertEqual(self.report()['manifest']['fingerprint'],old_fp)
        self.assertEqual(len(self.query()['items']),1)
        self.assertEqual(len(self.report()['history']),3)
        record=self.report()['results'][0]
        evidence=self.root/'.docguard'/record['run']['stdout_file']
        evidence.write_text('altered\n')
        self.assertEqual(self.query()['items'],[])
        self.command('check',code=1)
        self.assertEqual(self.report()['results'][0]['freshness'],'UNKNOWN_CURRENT')
        self.command('verify')
        site=self.root/'.docguard/site/index.html'
        site.write_text(site.read_text().replace('id="s-','id="broken-'))
        self.command('check',code=1)
        self.assertTrue(any(l['status']=='FAIL' for l in self.report()['links']))
        self.assertEqual((self.root/'.docguard/snapshots'/old_fp/'project/binary.dat').read_bytes(),bytes(range(256)))

    def test_mutation_during_verification(self):
        import time
        original=(self.root/'lib.cj').read_text()
        process=subprocess.Popen([str(BINARY),'verify','--config',str(self.config)],env=ENV,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        attempt=self.root/'.docguard/attempts/1.json'
        deadline=time.monotonic()+60
        while not attempt.exists() and time.monotonic()<deadline: time.sleep(.005)
        self.assertTrue(attempt.exists())
        (self.root/'lib.cj').write_text(original.replace('a+b','a-b'))
        out,err=process.communicate(timeout=120)
        self.assertEqual(process.returncode,1,out+err)
        r=self.report()['results'][0]
        self.assertEqual(r['status'],'RUN_VERIFIED')
        self.assertEqual(r['freshness'],'STALE')
        frozen=self.root/'.docguard/snapshots'/r['project_fingerprint']/'project/lib.cj'
        self.assertEqual(frozen.read_text(),original)
        self.assertEqual(self.query()['items'],[])

    def test_interrupted_latest_attempt_blocks_success(self):
        import time
        self.command('verify')
        process=subprocess.Popen([str(BINARY),'verify','--config',str(self.config)],env=ENV,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        attempt=self.root/'.docguard/attempts/2.json'
        deadline=time.monotonic()+60
        while not attempt.exists() and time.monotonic()<deadline: time.sleep(.005)
        self.assertTrue(attempt.exists())
        process.terminate();process.communicate(timeout=30)
        time.sleep(.3)
        self.command('query','--tool','list_symbols',code=2)
        # Test fixture owner explicitly resolves orphan reservation, never auto-removal.
        shutil.rmtree(self.root/'.docguard/writer.lock')
        self.assertEqual(self.query()['items'],[])
        self.assertEqual(json.loads(attempt.read_text())['execution_state'],'RUNNING')

    def test_invalid_configuration_and_lock(self):
        self.command('query','--tool','get_verified_examples',code=2)
        self.command('verify','--sdk','9.9.9',code=2)
        (self.root/'.docguard/writer.lock').mkdir(parents=True,exist_ok=True)
        self.command('query','--tool','list_symbols',code=2)
        shutil.rmtree(self.root/'.docguard/writer.lock')
        self.config.write_text(self.config.read_text().replace('output=".docguard"','output="."'))
        self.command('build',code=2)

    def test_failure_modes_and_no_assertions(self):
        program=self.root/'example.cj'
        cases=[
            ('compile', 'package demo\nmain(): Int64 { doesNotExist(); return 0 }\n', 'stdout="3\\n"\nexpected_exit=0\n', 'COMPILE_FAILED'),
            ('runtime', 'package demo\nmain(): Int64 { return 7 }\n', 'expected_exit=0\n','RUN_FAILED'),
            ('assertion', 'package demo\nmain(): Int64 { println("bad"); return 0 }\n','stdout="3\\n"\nexpected_exit=0\n','ASSERTION_FAILED'),
            ('no_assertion','package demo\nmain(): Int64 { return 0 }\n','','COMPILE_ONLY'),
            ('timeout','package demo\nmain(): Int64 { while (true) {}; return 0 }\n','expected_exit=0\ntimeout_ms=100\n','RUN_FAILED'),
            ('skip','package demo\nmain(): Int64 { return 0 }\n','skip_reason="review pending"\n','SKIPPED'),
        ]
        for name,body,assertions,status in cases:
            with self.subTest(name=name):
                program.write_text(body); self.config.write_text(self.base+assertions)
                self.command('verify',code=1)
                self.assertEqual(self.report()['results'][0]['status'],status)
                self.assertEqual(self.query()['items'],[])
        self.config.write_text(self.base+'mode="compile"\n')
        self.command('verify')
        self.assertEqual(self.query()['items'],[])
        r=self.report()['results'][0]
        (self.root/'.docguard'/r['compile']['stdout_file']).unlink()
        self.command('check',code=1)

    def test_missing_sdk_and_unknown_inputs(self):
        self.config.write_text(self.config.read_text().replace('version="1.1.3"','version="9.9.9"'))
        self.command('verify',code=2)
        self.assertEqual(self.report()['results'][0]['status'],'ENV_UNAVAILABLE')
        self.config.write_text(self.base+'stdout="3\\n"\nexpected_exit=0\n')
        (self.root/'example.cj').write_text('package demo\nimport std.env.*\nmain(): Int64 { println(add(1,2)); return 0 }\n')
        self.command('verify',code=1)
        self.assertEqual(self.report()['results'][0]['freshness'],'UNKNOWN_CURRENT')
        self.assertEqual(self.query()['items'],[])

if __name__ == '__main__':
    unittest.main()
