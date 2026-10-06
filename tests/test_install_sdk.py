"""Installer guard tests. Synthetic archives are not official SDK installations."""
import contextlib
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('docguard_install_sdk', ROOT / 'scripts/install_sdk.py')
INSTALLER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INSTALLER)


def synthetic_archive(member=None):
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode='w:gz') as archive:
        compiler = tarfile.TarInfo('cangjie/bin/cjc')
        compiler.size = len(b'synthetic compiler fixture')
        archive.addfile(compiler, io.BytesIO(b'synthetic compiler fixture'))
        if member is not None:
            archive.addfile(member)
    return output.getvalue()


class InstallerGuards(unittest.TestCase):
    def invoke(self, root, payload, expected=None):
        sdk = {'1.1.3': ('synthetic-key', expected or hashlib.sha256(payload).hexdigest())}
        with patch.object(INSTALLER, 'ROOT', root), patch.object(INSTALLER, 'SDK', sdk), \
             patch.object(INSTALLER.platform, 'system', return_value='Darwin'), \
             patch.object(INSTALLER.platform, 'machine', return_value='arm64'), \
             patch.object(INSTALLER, 'urlopen', return_value=io.BytesIO(payload)), \
             patch.object(sys, 'argv', ['install_sdk.py', '--sdk', '1.1.3']), \
             contextlib.redirect_stdout(io.StringIO()):
            INSTALLER.main()

    def test_fixed_official_metadata(self):
        self.assertEqual(INSTALLER.SDK, {
            '1.1.3': ('6a19312721f5a8178d6fd225', '7eff8d3b9119535cf3d05cb81526c5df391137dce908d744449f4edb99da3199'),
            '1.2.0': ('6ab1e6451320215435b23d52', 'de88d6ba2185c94979e0ab2fe8ac1d81535dfdff3fcb51fbba71e4b99d851f97'),
        })

    def test_checksum_mismatch_installs_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                self.invoke(root, synthetic_archive(), '0' * 64)
            self.assertFalse((root / '.local/sdks/1.1.3').exists())

    def test_regular_synthetic_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.invoke(root, synthetic_archive())
            self.assertEqual((root / '.local/sdks/1.1.3/cangjie/bin/cjc').read_bytes(),
                             b'synthetic compiler fixture')

    def test_existing_sdk_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / '.local/sdks/1.1.3'
            target.mkdir(parents=True)
            sentinel = target / 'sentinel'
            sentinel.write_text('preserve')
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                self.invoke(root, synthetic_archive())
            self.assertEqual(sentinel.read_text(), 'preserve')

    def test_parent_traversal_is_rejected(self):
        member = tarfile.TarInfo('../../outside')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(tarfile.OutsideDestinationError):
                self.invoke(root, synthetic_archive(member))
            self.assertFalse((root / '.local/sdks/1.1.3').exists())
            self.assertFalse((root / '.local/sdks/outside').exists())

    def test_absolute_symlink_is_rejected(self):
        member = tarfile.TarInfo('cangjie/escape')
        member.type = tarfile.SYMTYPE
        member.linkname = '/tmp/docguard-synthetic-outside'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(tarfile.AbsoluteLinkError):
                self.invoke(root, synthetic_archive(member))
            self.assertFalse((root / '.local/sdks/1.1.3').exists())

    def test_relative_symlink_escape_is_rejected(self):
        member = tarfile.TarInfo('cangjie/escape')
        member.type = tarfile.SYMTYPE
        member.linkname = '../../../outside'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(tarfile.LinkOutsideDestinationError):
                self.invoke(root, synthetic_archive(member))
            self.assertFalse((root / '.local/sdks/1.1.3').exists())

    def test_special_fifo_is_rejected(self):
        member = tarfile.TarInfo('cangjie/fifo')
        member.type = tarfile.FIFOTYPE
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaises(tarfile.SpecialFileError):
                self.invoke(root, synthetic_archive(member))
            self.assertFalse((root / '.local/sdks/1.1.3').exists())

    def test_cached_official_archives_hash_and_data_filter(self):
        cache = Path(os.environ.get('CJ_DOCGUARD_ARCHIVE_CACHE', str(ROOT.parent / '.toolchains')))
        archives = [(version, cache / version / f'cangjie-sdk-mac-aarch64-{version}.tar.gz')
                    for version in INSTALLER.SDK]
        if not all(path.is_file() for _, path in archives):
            self.skipTest('cached official archives unavailable; no download or official install claimed')
        with tempfile.TemporaryDirectory() as directory:
            for version, path in archives:
                with self.subTest(sdk=version):
                    digest = hashlib.sha256()
                    with path.open('rb') as stream:
                        while chunk := stream.read(1024 * 1024):
                            digest.update(chunk)
                    self.assertEqual(digest.hexdigest(), INSTALLER.SDK[version][1])
                    count = 0
                    with tarfile.open(path, 'r:gz') as archive:
                        for member in archive:
                            filtered = tarfile.data_filter(member, directory)
                            self.assertIsNotNone(filtered)
                            count += 1
                    self.assertGreater(count, 0)


if __name__ == '__main__':
    unittest.main()
