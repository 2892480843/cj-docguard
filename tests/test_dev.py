"""Host/SDK runtime mapping regressions; pure unit tests need no SDK."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('dev', ROOT / 'scripts/dev.py')
dev = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dev)


class RuntimeDirectoryTests(unittest.TestCase):
    def test_linux_arm_sdk_env_uses_arm_runtime(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            (home / 'runtime/lib/linux_aarch64_cjnative').mkdir(parents=True)
            with patch.object(dev, 'sdk_home', return_value=home), \
                 patch.object(dev, 'host_identity', return_value=('Linux', 'aarch64')):
                env = dev.sdk_env('1.1.3')
            self.assertEqual(env['LD_LIBRARY_PATH'], str(home / 'runtime/lib/linux_aarch64_cjnative'))

    def test_native_runtime_matches_os_and_machine(self):
        cases = {
            ('Darwin', 'arm64'): 'darwin_aarch64_cjnative',
            ('Darwin', 'aarch64'): 'darwin_aarch64_cjnative',
            ('Linux', 'aarch64'): 'linux_aarch64_cjnative',
            ('Linux', 'arm64'): 'linux_aarch64_cjnative',
            ('Linux', 'x86_64'): 'linux_x86_64_cjnative',
        }
        for identity, expected in cases.items():
            with self.subTest(identity=identity):
                self.assertEqual(dev.native_runtime_directory(*identity), expected)

    def test_unsupported_host_is_explicitly_rejected(self):
        for identity in [('Darwin', 'x86_64'), ('Linux', 'riscv64'), ('Windows', 'AMD64')]:
            with self.subTest(identity=identity):
                with self.assertRaisesRegex(RuntimeError, 'unsupported native host'):
                    dev.native_runtime_directory(*identity)


if __name__ == '__main__':
    unittest.main()
