#!/usr/bin/env python3
"""Build/probe native code; no third-party Python dependencies."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def sdk_home(version: str) -> Path:
    explicit = os.environ.get('CJ_DOCGUARD_SDK_' + version.replace('.', '_'))
    candidates = [Path(explicit)] if explicit else []
    candidates += [ROOT.parent / '.toolchains' / version / 'cangjie', ROOT / '.local' / 'sdks' / version / 'cangjie']
    if version == '1.0.5':
        candidates.append(Path.home() / 'Downloads' / 'cangjie')
    for home in candidates:
        if (home / 'bin' / 'cjc').is_file():
            return home.resolve()
    raise RuntimeError(f'SDK {version} unavailable; set CJ_DOCGUARD_SDK_{version.replace(".", "_")} to its directory')


def sdk_env(version: str) -> dict[str, str]:
    home = sdk_home(version)
    env = os.environ.copy()
    env['CANGJIE_HOME'] = str(home)
    env['PATH'] = os.pathsep.join([str(home / 'bin'), str(home / 'tools' / 'bin'), '/usr/bin', '/bin', '/usr/sbin', '/sbin'])
    runtime = home / 'runtime' / 'lib' / ('darwin_aarch64_cjnative' if sys.platform == 'darwin' else 'linux_x86_64_cjnative')
    env['DYLD_LIBRARY_PATH' if sys.platform == 'darwin' else 'LD_LIBRARY_PATH'] = str(runtime)
    if sys.platform == 'darwin':
        env['SDKROOT'] = subprocess.check_output(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
    for v in ('1.1.3', '1.2.0'):
        try:
            env['CJ_DOCGUARD_SDK_' + v.replace('.', '_')] = str(sdk_home(v))
        except RuntimeError:
            pass
    env['CJ_DOCGUARD_RUNNER'] = str(ROOT / 'build' / 'cjdg-runner')
    return env


def invoke(argv: list[str], env: dict[str, str], timeout: int = 180) -> int:
    return subprocess.run(argv, env=env, cwd=ROOT, timeout=timeout).returncode


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['build', 'compile', 'run', 'probe'])
    parser.add_argument('--sdk', default='1.1.3')
    parser.add_argument('--output', default='build/cj-docguard')
    parser.add_argument('files', nargs='*')
    args, tail = parser.parse_known_args()
    env = sdk_env(args.sdk)
    home = sdk_home(args.sdk)
    (ROOT / 'build').mkdir(exist_ok=True)
    if args.action == 'probe':
        probe_home = ROOT / 'build' / 'probe-home'
        probe_home.mkdir(exist_ok=True)
        env['HOME'] = str(probe_home)
        for name, path in [('cjc', home / 'bin/cjc'), ('cjpm', home / 'tools/bin/cjpm')]:
            r = subprocess.run([str(path), '--version'], env=env, capture_output=True, text=True, timeout=30)
            print(json.dumps({'tool': name, 'sdk': args.sdk, 'exit_code': r.returncode, 'stdout': r.stdout, 'stderr': r.stderr}, ensure_ascii=False))
            if r.returncode:
                return r.returncode
        return 0
    if args.action == 'run':
        argv = args.files + tail
        if argv and argv[0] == '--':
            argv = argv[1:]
        return invoke([str(ROOT / 'build/cj-docguard'), *argv], env, 600)
    if args.action == 'build':
        r = invoke(['/usr/bin/cc', '-std=c11', '-O2', '-Wall', '-Wextra', 'scripts/runner.c', '-o', 'build/cjdg-runner'], env)
        if r:
            return r
        files = [str(p.relative_to(ROOT)) for p in sorted((ROOT / 'src').glob('*.cj'))]
    else:
        files = args.files + tail
    if not files:
        parser.error('compile requires source files')
    out = ROOT / args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    return invoke([str(home / 'bin/cjc'), *files, '-O2', '-Woff', 'unused', '-o', str(out)], env)


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(2)
