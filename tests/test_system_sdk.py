"""Explicit macOS system SDK selection; never silently choose a different SDK."""
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import dev

class SystemSdkSelection(unittest.TestCase):
    def test_explicit_system_sdk_is_validated_and_used(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory) / 'cangjie'
            (home / 'runtime/lib/darwin_aarch64_cjnative').mkdir(parents=True)
            sdk = Path(directory) / 'MacOSX.sdk'
            (sdk / 'usr/lib').mkdir(parents=True)
            (sdk / 'usr/lib/libSystem.tbd').write_text('test fixture')
            with patch.object(dev, 'sdk_home', return_value=home), patch.object(dev, 'host_identity', return_value=('Darwin','arm64')), patch.dict(os.environ, {'CJ_DOCGUARD_SYSTEM_SDKROOT': str(sdk)}):
                self.assertEqual(dev.sdk_env('1.1.3')['SDKROOT'], str(sdk.resolve()))

    def test_invalid_override_is_not_silently_ignored(self):
        with patch.dict(os.environ, {'CJ_DOCGUARD_SYSTEM_SDKROOT':'relative-sdk'}):
            with self.assertRaisesRegex(RuntimeError, 'absolute'):
                dev.system_sdk_root()
