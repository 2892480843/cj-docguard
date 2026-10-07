"""Regression checks for the resumable Linux evidence recorder."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/linux_verify.py'
SPEC = importlib.util.spec_from_file_location('linux_verify', SCRIPT)
verify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify)


class LinuxVerifyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.input = self.root / 'input'
        self.work = self.root / 'work'
        for root in (self.input, self.work):
            for name in ('src', 'scripts', 'tests', 'examples/healthy'):
                folder = root / name
                folder.mkdir(parents=True)
                (folder / 'sample.txt').write_text(name, encoding='utf-8')
        self.sdk = self.root / 'sdk'
        (self.sdk / 'bin').mkdir(parents=True)
        (self.sdk / 'bin/cjc').write_bytes(b'compiler')
        self.output = self.root / 'out'
        (self.output / 'commands').mkdir(parents=True)
        (self.output / 'commands/stdout').write_bytes(b'42\n')
        (self.output / 'commands/stderr').write_bytes(b'warning: example\n')
        self.command = ['/usr/bin/bash', 'build.sh']
        self.env = {'PATH': '/sdk/bin', 'CANGJIE_HOME': '/sdk'}
        self.entry = {'name': 'replay', 'argv': self.command, 'cwd': str(self.work),
                      'exit_code': 0, 'expected_exit_code': 0, 'timed_out': False,
                      'environment_sha256': verify.environment_digest(self.env),
                      'stdout': 'commands/stdout', 'stderr': 'commands/stderr',
                      'stdout_sha256': verify.sha256(self.output / 'commands/stdout'),
                      'stderr_sha256': verify.sha256(self.output / 'commands/stderr')}
        self.summary = {'schema_version': verify.SCHEMA_VERSION,
                        'verifier_sha256': verify.sha256(SCRIPT),
                        'input_inventory': verify.input_inventory(self.input),
                        'sdk_tree_sha256': {'1.1.3': verify.tree_digest(self.sdk)}}

    def assert_identity(self):
        verify.validate_resume_identity(self.summary, self.input, self.work,
                                        {'1.1.3': self.sdk}, SCRIPT)

    def test_resume_rejects_changed_selected_inputs_on_both_sides(self):
        self.assert_identity()
        for side in (self.input, self.work):
            for name in ('src', 'scripts', 'tests', 'examples/healthy'):
                path = side / name / 'sample.txt'
                original = path.read_bytes()
                path.write_bytes(b'changed')
                with self.subTest(side=side, name=name), self.assertRaises(RuntimeError):
                    self.assert_identity()
                path.write_bytes(original)

    def test_resume_rejects_missing_legacy_identity_and_changed_sdk(self):
        for missing in ('schema_version', 'verifier_sha256', 'input_inventory', 'sdk_tree_sha256'):
            broken = dict(self.summary)
            del broken[missing]
            with self.subTest(missing=missing), self.assertRaises(RuntimeError):
                verify.validate_resume_identity(broken, self.input, self.work,
                                                {'1.1.3': self.sdk}, SCRIPT)
        (self.sdk / 'bin/cjc').write_bytes(b'changed compiler')
        with self.assertRaises(RuntimeError):
            self.assert_identity()

    def test_resume_rejects_command_mismatch_or_altered_logs(self):
        verify.reuse_command(self.entry, self.command, self.work, 0, self.env, self.output)
        for field in ('argv', 'cwd', 'exit_code', 'expected_exit_code',
                      'environment_sha256', 'stdout_sha256', 'stderr_sha256'):
            broken = dict(self.entry)
            del broken[field]
            with self.subTest(missing=field), self.assertRaises(RuntimeError):
                verify.reuse_command(broken, self.command, self.work, 0, self.env, self.output)
        for change in ({'argv': ['wrong']}, {'cwd': '/wrong'}, {'exit_code': 1},
                       {'expected_exit_code': 1}, {'timed_out': True},
                       {'environment_sha256': 'wrong'}):
            with self.subTest(change=change), self.assertRaises(RuntimeError):
                verify.reuse_command(self.entry | change, self.command, self.work, 0,
                                     self.env, self.output)
        for stream in ('stdout', 'stderr'):
            path = self.output / 'commands' / stream
            original = path.read_bytes()
            path.write_bytes(b'altered')
            with self.subTest(stream=stream), self.assertRaises(RuntimeError):
                verify.reuse_command(self.entry, self.command, self.work, 0, self.env, self.output)
            path.unlink()
            with self.subTest(missing=stream), self.assertRaises(RuntimeError):
                verify.reuse_command(self.entry, self.command, self.work, 0, self.env, self.output)
            path.write_bytes(original)

    def test_replay_requires_expected_stdout_and_classifies_warnings(self):
        self.assertEqual(verify.check_replay_output(b'42\n', b'warning: example\n'),
                         {'stderr': 'compiler_warnings', 'stderr_bytes': 17})
        for stdout in (b'', b'41\n', b'42\nextra'):
            with self.subTest(stdout=stdout), self.assertRaises(RuntimeError):
                verify.check_replay_output(stdout, b'')
        with self.assertRaises(RuntimeError):
            verify.check_replay_output(b'42\n', b'error: compiler failed\n')

    def test_atomic_summary_write_keeps_previous_json_on_interruption(self):
        path = self.output / 'summary.json'
        verify.write_json(path, {'complete': False})
        with patch.object(verify.os, 'replace', side_effect=OSError('interrupted')):
            with self.assertRaises(OSError):
                verify.write_json(path, {'complete': True})
        self.assertEqual(json.loads(path.read_text(encoding='utf-8')), {'complete': False})


if __name__ == '__main__':
    unittest.main()
