"""Focused checks for isolated memory measurements."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
spec = importlib.util.spec_from_file_location('diagnose_memory', ROOT / 'scripts/diagnose_memory.py')
diagnose = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnose)


class MemoryDiagnosticsTests(unittest.TestCase):
    def test_clone_is_independent_and_existing_target_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / 'source'
            source.mkdir()
            (source / 'docguard.toml').write_text('original', encoding='utf-8')
            target = root / 'target'
            diagnose.clone_project(source, target)
            (target / 'docguard.toml').write_text('changed', encoding='utf-8')
            self.assertEqual((source / 'docguard.toml').read_text(encoding='utf-8'), 'original')
            with self.assertRaises(ValueError):
                diagnose.clone_project(source, target)

    def test_measurement_preserves_full_streams_and_exit_code(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            project = root / 'project'
            project.mkdir()
            case = diagnose.run_case(
                [sys.executable, '-c', "import sys,time; print('out'); print('err',file=sys.stderr); time.sleep(.08); sys.exit(3)"],
                {}, project, root, 'probe', 2, .01)
            self.assertEqual(case['exit_code'], 3)
            self.assertFalse(case['timed_out'])
            self.assertEqual((root / 'probe.stdout').read_text(encoding='utf-8'), 'out\n')
            self.assertEqual((root / 'probe.stderr').read_text(encoding='utf-8'), 'err\n')
            self.assertGreater(len(case['samples']), 0)

    def test_timeout_is_reported_as_failure(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            project = root / 'project'
            project.mkdir()
            case = diagnose.run_case([sys.executable, '-c', 'import time; time.sleep(5)'],
                                     {}, project, root, 'timeout', .05, .01)
            self.assertTrue(case['timed_out'])
            self.assertNotEqual(case['exit_code'], 0)

    def test_final_report_update_is_captured(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            project = root / 'project'
            (project / '.docguard').mkdir(parents=True)
            command = [sys.executable, '-c',
                       "from pathlib import Path; import sys; Path(sys.argv[1]).write_text('{}')",
                       str(project / '.docguard' / 'report.json')]
            case = diagnose.run_case(command, {}, project, root, 'report', 2, .1)
            self.assertEqual(case['exit_code'], 0)
            self.assertIn('report_updated', [event['kind'] for event in case['events']])


if __name__ == '__main__':
    unittest.main()
