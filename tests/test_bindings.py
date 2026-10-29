"""Real SDK regression for unambiguous API/example evidence identity."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import dev

ROOT = dev.ROOT


class BindingIntegration(unittest.TestCase):
    def test_owner_overload_and_historical_binding_on_both_sdks(self):
        # No compilation or SDK probing at import time. The suite builds this CLI.
        binary = Path(os.environ.get('CJ_DOCGUARD_TEST_CLI', ROOT / 'build/cj-docguard'))
        for sdk in ('1.1.3', '1.2.0'):
            with self.subTest(sdk=sdk), tempfile.TemporaryDirectory(prefix='cjdg-bindings-') as tmp, tempfile.TemporaryDirectory(prefix='cjdg-binding-exports-') as exports:
                root = Path(tmp)
                env = dev.sdk_env(sdk)
                config = root / 'docguard.toml'
                first_source = ('package binding_regression\npublic class First { public init() {}\n'
                                ' public func read(): Int64 { return 1 }\n')
                (root / 'first.cj').write_text(first_source + '}\n', encoding='utf-8')
                (root / 'second.cj').write_text(
                    'package binding_regression\npublic class Second { public init() {}\n'
                    ' public func read(): Int64 { return 2 } }\n', encoding='utf-8')
                (root / 'example.cj').write_text(
                    'package binding_regression\nmain(): Unit { println(First().read()) }\n', encoding='utf-8')

                def configure(reference):
                    config.write_text(
                        '[project]\nname="Binding regression"\nsources=["first.cj","second.cj"]\n'
                        'documents=[]\noutput=".docguard"\ntrusted=true\nclosed_inputs=true\n'
                        f'[[sdks]]\nversion="{sdk}"\n[[examples]]\nid="first-only"\n'
                        f'file="example.cj"\nsymbol="{reference}"\nstdout="1\\n"\nexpected_exit=0\n',
                        encoding='utf-8')

                def call(command, *args, code=0):
                    result = subprocess.run([str(binary), command, '--config', str(config), *map(str, args)],
                                            env=env, capture_output=True, text=True, timeout=120)
                    self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                    return json.loads(result.stdout)

                def report():
                    return json.loads((root / '.docguard/report.json').read_text(encoding='utf-8'))

                configure('read')
                call('verify', code=1)
                data = report()
                self.assertEqual(data['results'][0]['status'], 'RUN_VERIFIED')
                self.assertFalse(data['results'][0]['eligible'])
                reads = [s for s in data['api']['symbols'] if s['name'] == 'read']
                self.assertEqual(len(reads), 2)
                self.assertTrue(all(not s['examples'] for s in reads))
                self.assertIn('EXAMPLE_SYMBOL_AMBIGUOUS', [d.get('code') for d in data['diagnostics']])
                first = next(s['id'] for s in reads if s['owner'] == 'First')
                second = next(s['id'] for s in reads if s['owner'] == 'Second')

                configure('First.read')
                call('verify')
                data = report()
                self.assertTrue(data['results'][0]['eligible'])
                self.assertEqual(data['results'][0]['symbol_id'], first)
                self.assertEqual({s['owner']: len(s['examples']) for s in data['api']['symbols']
                                  if s['name'] == 'read'}, {'First': 1, 'Second': 0})
                html = (root / '.docguard/site/index.html').read_text(encoding='utf-8')
                first_card = html.split(f'<article class="api-card" id="{first}"', 1)[1].split('</article>', 1)[0]
                second_card = html.split(f'<article class="api-card" id="{second}"', 1)[1].split('</article>', 1)[0]
                self.assertIn('href="#result-0"', first_card)
                self.assertNotIn('href="#result-0"', second_card)
                platform = data['results'][0]['platform']
                for tool in ('get_verified_examples', 'get_evidence'):
                    for reference, count in ((first, 1), ('binding_regression.Second.read', 0)):
                        query = call('query', '--tool', tool, '--sdk', sdk, '--platform', platform,
                                     '--symbol', reference)
                        self.assertEqual(len(query['items']), count)
                call('query', '--tool', 'get_evidence', '--sdk', sdk, '--platform', platform,
                     '--symbol', 'read', code=2)

                # A second signature makes even an owner-qualified reference ambiguous.
                (root / 'first.cj').write_text(first_source +
                    ' public func read(value: Int64): Int64 { return value }\n}\n', encoding='utf-8')
                call('verify', code=1)
                self.assertFalse(report()['results'][0]['eligible'])
                configure(first)
                call('verify')
                data = report()
                self.assertTrue(data['results'][0]['eligible'])
                self.assertEqual(sum(len(s['examples']) for s in data['api']['symbols']), 1)
                call('export', '--example', 'first-only', '--sdk', sdk, '--platform', platform,
                     '--out', Path(exports) / 'good')

                # Simulate a pre-binding record; preserve actual execution/log evidence.
                attempt = root / '.docguard/attempts' / f"{data['results'][0]['sequence']}.json"
                legacy = json.loads(attempt.read_text(encoding='utf-8'))
                legacy.pop('symbol_id')
                legacy.pop('binding_status')
                attempt.write_text(json.dumps(legacy), encoding='utf-8')
                self.assertFalse(call('query', '--tool', 'get_evidence', '--sdk', sdk,
                                      '--platform', platform)['items'])
                call('check', '--strict', code=1)
                self.assertIsNone(report()['results'][0]['symbol_id'])
                self.assertEqual(report()['results'][0]['freshness'], 'CURRENT')
                call('export', '--example', 'first-only', '--sdk', sdk, '--platform', platform,
                     '--out', Path(exports) / 'legacy', code=1)


if __name__ == '__main__':
    unittest.main()
