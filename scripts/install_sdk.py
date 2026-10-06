#!/usr/bin/env python3
"""Install fixed official macOS arm64 SDK archives after SHA256 verification."""
import argparse
import hashlib
import platform
from pathlib import Path
import shutil
import tarfile
import tempfile
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
SDK = {
    '1.1.3': ('6a19312721f5a8178d6fd225', '7eff8d3b9119535cf3d05cb81526c5df391137dce908d744449f4edb99da3199'),
    '1.2.0': ('6ab1e6451320215435b23d52', 'de88d6ba2185c94979e0ab2fe8ac1d81535dfdff3fcb51fbba71e4b99d851f97'),
}

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--sdk', choices=SDK, required=True)
    a = p.parse_args()
    if (platform.system(), platform.machine()) != ('Darwin', 'arm64'):
        p.error('automatic installer is verified only on macOS arm64; register an official SDK manually')
    target = ROOT / '.local/sdks' / a.sdk
    if target.exists():
        p.error(f'{target} already exists; refusing to replace an SDK')
    target.parent.mkdir(parents=True, exist_ok=True)
    key, expected = SDK[a.sdk]
    url = f'https://cangjie-lang.cn/v1/files/auth/downLoad?nsId=142267&fileName=cangjie-sdk-mac-aarch64-{a.sdk}.tar.gz&objectKey={key}'
    with tempfile.TemporaryDirectory(dir=target.parent) as temp:
        archive = Path(temp) / 'sdk.tar.gz'
        h = hashlib.sha256()
        with urlopen(Request(url, headers={'User-Agent':'CJ-DocGuard SDK installer'}), timeout=60) as response, archive.open('wb') as f:
            while chunk := response.read(1024 * 1024):
                h.update(chunk); f.write(chunk)
        if h.hexdigest() != expected:
            raise RuntimeError('official archive checksum mismatch; nothing installed')
        stage = Path(temp) / 'unpacked'; stage.mkdir()
        with tarfile.open(archive, 'r:gz') as tar:
            tar.extractall(stage, filter='data')
        if not (stage / 'cangjie/bin/cjc').is_file():
            raise RuntimeError('archive lacks expected compiler')
        stage.rename(target)
    print(f'Installed {a.sdk}: {target / "cangjie"}')
    print(f'Archive SHA256: {expected}. Run scripts/dev.py probe --sdk {a.sdk} to confirm execution.')

if __name__ == '__main__':
    main()
