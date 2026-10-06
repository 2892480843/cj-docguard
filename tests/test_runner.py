import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class RunnerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (ROOT / 'build').mkdir(exist_ok=True)
        subprocess.run(['/usr/bin/cc', '-std=c11', '-O2', '-Wall', '-Wextra', str(ROOT / 'scripts/runner.c'), '-o', str(ROOT / 'build/cjdg-runner')], check=True)

    def call(self, command, timeout=2000, limit=4096):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            argv = [str(ROOT / 'build/cjdg-runner'), str(timeout), str(limit), str(d), str(d / 'stdout'), str(d / 'stderr'), str(d / 'result.json'), '--', *command]
            p = subprocess.run(argv, capture_output=True, text=True, timeout=8)
            self.assertEqual(p.returncode, 0, p.stderr)
            return json.loads((d / 'result.json').read_text()), (d / 'stdout').read_text(), (d / 'stderr').read_text()

    def test_normal_and_nonzero_exit_are_preserved(self):
        r, out, err = self.call(['/bin/sh', '-c', 'printf hello; printf err >&2; exit 7'])
        self.assertEqual((r['exit_code'], out, err), (7, 'hello', 'err'))
        self.assertFalse(r['timed_out'])

    def test_timeout_cleans_process_group(self):
        r, out, _ = self.call(['/bin/sh', '-c', 'sleep 30 & echo $!; wait'], timeout=150)
        self.assertTrue(r['timed_out'])
        pid = int(out.strip())
        time.sleep(.15)
        p = subprocess.run(['/bin/ps', '-p', str(pid), '-o', 'stat='], capture_output=True, text=True)
        self.assertTrue(p.returncode != 0 or p.stdout.strip().startswith('Z'), p.stdout)

    def test_log_overflow_never_success(self):
        r, out, _ = self.call(['/usr/bin/yes', 'oversize'], limit=1024)
        self.assertTrue(r['truncated'])
        self.assertLessEqual(len(out.encode()), 1024)
        self.assertNotEqual(r['exit_code'], 0)

    def test_interrupt_cleans_process_group(self):
        with tempfile.TemporaryDirectory() as tmp:
            d=Path(tmp)
            argv=[str(ROOT/'build/cjdg-runner'),'5000','4096',str(d),str(d/'stdout'),str(d/'stderr'),str(d/'result.json'),'--','/bin/sh','-c','sleep 30 & echo $!; wait']
            process=subprocess.Popen(argv,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
            deadline=time.monotonic()+5
            while time.monotonic()<deadline and (not (d/'stdout').exists() or not (d/'stdout').read_text().strip()): time.sleep(.01)
            self.assertTrue((d/'stdout').read_text().strip())
            child=int((d/'stdout').read_text().strip())
            process.send_signal(signal.SIGTERM)
            out,err=process.communicate(timeout=5)
            self.assertEqual(process.returncode,0,out+err)
            result=json.loads((d/'result.json').read_text())
            self.assertTrue(result['interrupted'])
            time.sleep(.15)
            status=subprocess.run(['/bin/ps','-p',str(child),'-o','stat='],capture_output=True,text=True)
            self.assertTrue(status.returncode!=0 or status.stdout.strip().startswith('Z'),status.stdout)

    def test_parent_death_cleans_process_group(self):
        with tempfile.TemporaryDirectory() as tmp:
            d=Path(tmp)
            argv=[str(ROOT/'build/cjdg-runner'),'5000','4096',str(d),str(d/'stdout'),str(d/'stderr'),str(d/'result.json'),'--','/bin/sh','-c','sleep 30 & echo $!; wait']
            # Controlled parent fixture: killing it must make supervisor stop descendants.
            parent_code='import subprocess,sys,time; subprocess.Popen(sys.argv[1:]); time.sleep(30)'
            parent=subprocess.Popen([sys.executable,'-c',parent_code,*argv],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            deadline=time.monotonic()+5
            while time.monotonic()<deadline and (not (d/'stdout').exists() or not (d/'stdout').read_text().strip()): time.sleep(.01)
            self.assertTrue((d/'stdout').read_text().strip())
            child=int((d/'stdout').read_text().strip())
            parent.kill();parent.wait(timeout=5)
            deadline=time.monotonic()+5
            while not (d/'result.json').exists() and time.monotonic()<deadline: time.sleep(.01)
            self.assertTrue(json.loads((d/'result.json').read_text())['interrupted'])
            time.sleep(.15)
            status=subprocess.run(['/bin/ps','-p',str(child),'-o','stat='],capture_output=True,text=True)
            self.assertTrue(status.returncode!=0 or status.stdout.strip().startswith('Z'),status.stdout)

    def test_exec_failure_is_not_program_success(self):
        r, _, err = self.call(['/nonexistent-cj-docguard-program'])
        self.assertEqual(r['exit_code'], 127)
        self.assertIn('exec', err)


if __name__ == '__main__':
    unittest.main()
