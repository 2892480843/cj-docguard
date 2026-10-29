"""Focused controls for the pinned upstream case registry."""
import copy
import hashlib
import importlib.util
import json
import os
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('real_projects', ROOT / 'scripts/real_projects.py')
REAL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REAL)


class RealProjectCasesTest(unittest.TestCase):
    def setUp(self):
        self.item = next(p for p in REAL.LOCK['projects'] if p['name'] == 'leven4cj')

    def test_registry_has_60_distinct_hashed_cases(self):
        cases = [case for item in REAL.LOCK['projects'] for case in REAL.examples_for(item)]
        self.assertGreaterEqual(len(cases), 60)
        self.assertEqual(len(cases), len({(item['name'], case['id']) for item in REAL.LOCK['projects'] for case in REAL.examples_for(item)}))
        for item in REAL.LOCK['projects']:
            for case in REAL.examples_for(item):
                path = ROOT / 'integrations' / item['name'] / case['file']
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), case['sha256'])
                self.assertIn(case['symbol'], path.read_text(encoding='utf-8'))
                self.assertIsInstance(case['stdout'], str)
                self.assertEqual(case['expected_exit'], 0)

    def test_harness_copies_exact_case_bytes_and_assertions(self):
        REAL.validate_examples([self.item])
        with tempfile.TemporaryDirectory() as temp:
            # Synthetic upstream bytes exercise copying without a developer's external cache.
            repo = Path(temp) / 'synthetic-upstream'
            upstream = {
                'src/leven.cj': b'package synthetic\npublic func distance(): Int64 { return 0 }\n',
                'src/test/leven_test.cj': b'package synthetic\n// excluded fixture\n',
                'LICENSE': b'MIT License\nSynthetic test fixture only.\n',
                'NOTICE': b'Synthetic notice for copy control.\n',
                'README.md': b'# Synthetic upstream\n',
                'cjpm.toml': b'[package]\nname = "synthetic"\n',
            }
            for relative, content in upstream.items():
                path = repo / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
            item = copy.deepcopy(self.item)
            item['files_sha256'] = {name: hashlib.sha256(content).hexdigest()
                                    for name, content in upstream.items()}
            item['production_sources'] = ['src/leven.cj']
            item['excluded_sources'] = ['src/test/leven_test.cj']
            dest = Path(temp) / 'project'
            REAL.harness(item, repo, dest, ['1.1.3', '1.2.0'])
            config = (dest / 'docguard.toml').read_text()
            for relative, content in upstream.items():
                self.assertEqual((dest / 'upstream' / relative).read_bytes(), content)
            self.assertEqual({str(path.relative_to(dest / 'upstream'))
                              for path in (dest / 'upstream').rglob('*') if path.is_file()}, set(upstream))
            for case in REAL.examples_for(item):
                source = ROOT / 'integrations' / item['name'] / case['file']
                self.assertEqual((dest / case['file']).read_bytes(), source.read_bytes())
                self.assertIn('id = "' + case['id'] + '"', config)
                self.assertIn('stdout = ' + json.dumps(case['stdout'], ensure_ascii=False), config)
                self.assertIn('expected_exit = ' + str(case['expected_exit']), config)
            self.assertEqual(config.count('[[examples]]'), len(REAL.examples_for(item)))
            self.assertEqual(config.count('timeout_ms = 10000'), len(REAL.examples_for(item)))
            self.assertIn('upstream/src/test/leven_test.cj', config)
            self.assertIn('sources = ["upstream/src"]', config)
            self.assertEqual(json.loads((dest / 'provenance.json').read_text())['files_sha256'],
                             item['files_sha256'])

    def test_reviewed_fix_is_explicit_and_hash_checked(self):
        repo = ROOT / 'build/workbench/projects/leven4cj/upstream'
        if not repo.is_dir():
            self.skipTest('pinned local baseline unavailable')
        with tempfile.TemporaryDirectory() as temp:
            dest = Path(temp) / 'fixed'
            REAL.harness(self.item, repo, dest, ['1.1.3', '1.2.0'], apply_reviewed_fixes=True)
            original = (repo / 'src/leven.cj').read_bytes()
            self.assertEqual(hashlib.sha256(original).hexdigest(), self.item['files_sha256']['src/leven.cj'])
            source = (dest / 'upstream/src/leven.cj').read_text()
            self.assertIn('return secondString.toRuneArray().size', source)
            self.assertIn('return firstString.toRuneArray().size', source)
            provenance = json.loads((dest / 'provenance.json').read_text())
            self.assertTrue(provenance['source_modified'])
            self.assertEqual(provenance['reviewed_fixes'][0]['after_sha256'], hashlib.sha256(source.encode()).hexdigest())
            self.assertIn('local fixed', (dest / 'docguard.toml').read_text())
            for case in REAL.examples_for(self.item):
                self.assertEqual((dest / case['file']).read_bytes(), (ROOT / 'integrations/leven4cj' / case['file']).read_bytes())
            (dest / 'upstream/src/leven.cj').write_text(source + '// drift\n')
            with self.assertRaisesRegex(RuntimeError, 'before hash mismatch'):
                REAL.apply_reviewed_source_fixes(self.item, dest)

    @unittest.skipUnless(os.environ.get('CJ_DOCGUARD_TEST_REAL_UNICODE') == '1',
                         'set CJ_DOCGUARD_TEST_REAL_UNICODE=1 for two installed SDKs')
    def test_native_original_and_fixed_unicode_against_codepoint_reference(self):
        def reference(a, b):
            row = list(range(len(b) + 1))
            for i, x in enumerate(a, 1):
                following = [i]
                for j, y in enumerate(b, 1):
                    following.append(min(following[-1] + 1, row[j] + 1, row[j - 1] + (x != y)))
                row = following
            return row[-1]
        pairs = [('', ''), ('', '你'), ('你', ''), ('', '😀'), ('😀', ''),
                 ('', '你😀a'), ('你😀a', ''), ('你好', '你们'), ('😀a', '😀b'),
                 ('你😀', '😀你'), ('kitten', 'sitting'), ('e\u0301', 'é')]
        repo = ROOT / 'build/workbench/projects/leven4cj/upstream'
        original = (repo / 'src/leven.cj').read_bytes()
        self.assertEqual(hashlib.sha256(original).hexdigest(), self.item['files_sha256']['src/leven.cj'])
        expected = [reference(a, b) for a, b in pairs]
        baseline = [len((a or b).encode('utf-8')) if bool(a) != bool(b) else reference(a, b) for a, b in pairs]
        with tempfile.TemporaryDirectory() as temp:
            work = Path(temp)
            REAL.harness(self.item, repo, work / 'fixed', ['1.1.3', '1.2.0'], apply_reviewed_fixes=True)
            calls = '\n'.join('    println(leven(' + json.dumps(a, ensure_ascii=False) + ', ' +
                              json.dumps(b, ensure_ascii=False) + '))' for a, b in pairs)
            main = work / 'main.cj'
            main.write_text('package leven4cj\nmain(): Int64 {\n' + calls + '\n    return 0\n}\n', encoding='utf-8')
            for version in ('1.1.3', '1.2.0'):
                env = REAL.DEV.sdk_env(version)
                for label, source, wanted in [('original', repo / 'src/leven.cj', baseline),
                                               ('fixed', work / 'fixed/upstream/src/leven.cj', expected)]:
                    with self.subTest(sdk=version, variant=label):
                        binary = work / ('probe-' + version + '-' + label)
                        compiled = subprocess.run([str(REAL.DEV.sdk_home(version) / 'bin/cjc'), str(source),
                                                   str(main), '-o', str(binary)], env=env, capture_output=True,
                                                  text=True, timeout=120)
                        self.assertEqual(compiled.returncode, 0, compiled.stderr)
                        executed = subprocess.run([str(binary)], env=env, capture_output=True, text=True, timeout=20)
                        self.assertEqual(executed.returncode, 0, executed.stderr)
                        self.assertEqual([int(line) for line in executed.stdout.splitlines()], wanted)
                        print('Unicode probe', version, label, executed.stdout.splitlines(), flush=True)
        self.assertNotEqual(baseline, expected)

    def test_main_preserves_explicit_system_sdk_for_native_audit(self):
        # Inspect the real launch boundary, then stop before native execution.
        class LaunchObserved(Exception):
            pass
        captured = {}
        environment = {'PATH': '/usr/bin', 'SDKROOT': '/registered/apple-sdk',
                       'CJ_DOCGUARD_SYSTEM_SDKROOT': '/registered/apple-sdk',
                       'PRIVATE_UNRELATED_TOKEN': 'must-not-forward'}
        def stop_launch(command, **options):
            captured.update(options['env'])
            raise LaunchObserved()
        with tempfile.TemporaryDirectory() as temporary:
            work = Path(temporary)
            argv = ['real_projects.py', '--project', 'leven4cj', '--cache', str(work / 'cache'),
                    '--output', str(work / 'output')]
            with patch.object(REAL.sys, 'argv', argv), \
                 patch.object(REAL.DEV, 'sdk_env', return_value=environment), \
                 patch.object(REAL, 'checked_checkout', return_value=work), \
                 patch.object(REAL, 'harness', return_value=work / 'docguard.toml'), \
                 patch.object(REAL.subprocess, 'run', side_effect=stop_launch):
                with self.assertRaises(LaunchObserved):
                    REAL.main()
        self.assertEqual(captured.get('CJ_DOCGUARD_SYSTEM_SDKROOT'), '/registered/apple-sdk')
        self.assertEqual(captured.get('SDKROOT'), '/registered/apple-sdk')
        self.assertNotIn('PRIVATE_UNRELATED_TOKEN', captured)

    def test_invalid_registry_rejected_before_copy(self):
        valid = REAL.examples_for(self.item)[0]
        for replacement in (
            {**valid, 'id': '../escape'},
            {**valid, 'file': '../sample.cj'},
            {**valid, 'sha256': '0' * 64},
            {**valid, 'stdout': 1},
            {**valid, 'expected_exit': 999},
            {**valid, 'stdout': 'x' * 65537},
        ):
            item = copy.deepcopy(self.item)
            item['examples'] = [replacement]
            with self.subTest(replacement=replacement):
                with self.assertRaises(ValueError):
                    REAL.validate_examples([item])
        item = copy.deepcopy(self.item)
        item['examples'] = [valid, valid]
        with self.assertRaises(ValueError):
            REAL.validate_examples([item])
        item['examples'] = [valid, {**valid, 'id': 'different-id'}]
        with self.assertRaises(ValueError):
            REAL.validate_examples([item])

    def test_legacy_single_sample_supported(self):
        item = {key: value for key, value in self.item.items() if key != 'examples'}
        case = REAL.examples_for(item)[0]
        self.assertEqual(case['id'], 'upstream-api')
        REAL.validate_examples([item])


if __name__ == '__main__':
    unittest.main()
