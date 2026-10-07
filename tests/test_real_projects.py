"""Focused controls for the pinned upstream case registry."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

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
