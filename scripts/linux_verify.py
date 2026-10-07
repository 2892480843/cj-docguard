#!/usr/bin/env python3
"""Run an isolated, logged Linux aarch64 verification in the prepared container.

Invoke inside cjdg-gap-linux-20261007:
    python3 /input/scripts/linux_verify.py --output /out/verification-NAME
The input and SDK mounts are read-only. No downloads or existing evidence are edited.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import time


INPUT = Path('/input')
SDKS = Path('/sdks')
WORK = Path('/work/cj-docguard')
VERSIONS = ('1.1.3', '1.2.0')


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def clone_inputs() -> None:
    if WORK.exists():
        raise RuntimeError(f'working copy already exists: {WORK}')
    WORK.mkdir(parents=True)
    for name in ('src', 'scripts', 'tests'):
        shutil.copytree(INPUT / name, WORK / name,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '.DS_Store'))
    shutil.copytree(INPUT / 'examples' / 'healthy', WORK / 'examples' / 'healthy',
                    ignore=shutil.ignore_patterns('.docguard', '.DS_Store', '__pycache__'))


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main(argv: list[str] | None = None) -> int:
    global WORK
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True, help='new directory under /out')
    parser.add_argument('--resume', action='store_true', help='continue this script after a recorded failure')
    args = parser.parse_args(argv)
    output = args.output
    if not output.is_absolute() or output.parent != Path('/out') or output.exists() == (not args.resume):
        parser.error('--output must be a new direct child of /out, or existing with --resume')
    WORK = Path('/work') / output.name
    if os.uname().sysname != 'Linux' or os.uname().machine != 'aarch64':
        parser.error('actual Linux aarch64 host required')
    if not INPUT.is_dir() or not SDKS.is_dir():
        parser.error('/input and /sdks mounts required')
    for version in VERSIONS:
        if not (SDKS / f'linux-{version}/cangjie/bin/cjc').is_file():
            parser.error(f'SDK {version} missing')

    if not args.resume:
        output.mkdir()
    summary: dict = json.loads((output / 'summary.json').read_text(encoding='utf-8')) if args.resume else {
        'created_at_utc': datetime.now(timezone.utc).isoformat(),
        'platform': {'sysname': os.uname().sysname, 'machine': os.uname().machine,
                     'release': os.uname().release},
        'image_digest': 'sha256:050dd71fd48cf03db1924609facd0f51dc148e9055276e45aade78f2abafdc10',
        'input': str(INPUT), 'work': str(WORK), 'sdks': {}, 'source_sha256': {}, 'commands': [],
    }
    log_dir = output / 'commands'
    log_dir.mkdir(exist_ok=True)

    def save() -> None:
        write_json(output / 'summary.json', summary)

    def execute(name: str, command: list[str], env: dict[str, str] | None = None,
                cwd: Path = WORK, expected: int = 0, timeout: int = 600) -> subprocess.CompletedProcess[bytes]:
        if args.resume:
            previous = next((item for item in summary['commands'] if item['name'] == name), None)
            if previous is not None:
                if previous['argv'] != command or previous['cwd'] != str(cwd) or previous['exit_code'] != expected:
                    raise RuntimeError(f'prior command differs or failed: {name}')
                return subprocess.CompletedProcess(command, previous['exit_code'],
                    (output / previous['stdout']).read_bytes(), (output / previous['stderr']).read_bytes())
        index = len(summary['commands']) + 1
        key = f'{index:02d}-{name}'
        started = time.monotonic()
        timed_out = False
        try:
            result = subprocess.run(command, cwd=cwd, env=env, capture_output=True, timeout=timeout)
        except subprocess.TimeoutExpired as error:
            timed_out = True
            result = subprocess.CompletedProcess(command, 124, error.stdout or b'', error.stderr or b'')
        stdout = log_dir / f'{key}.stdout'
        stderr = log_dir / f'{key}.stderr'
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        entry = {'name': name, 'argv': command, 'cwd': str(cwd), 'exit_code': result.returncode,
                 'expected_exit_code': expected, 'timed_out': timed_out,
                 'elapsed_seconds': round(time.monotonic() - started, 3),
                 'stdout': str(stdout.relative_to(output)), 'stderr': str(stderr.relative_to(output))}
        summary['commands'].append(entry)
        save()
        print(f'{key}: exit {result.returncode}, expected {expected}', flush=True)
        if timed_out or result.returncode != expected:
            raise RuntimeError(f'{name} failed: exit {result.returncode}; see {stdout} and {stderr}')
        return result

    try:
        if not args.resume:
            clone_inputs()
        for path in sorted((WORK / 'src').glob('*.cj')) + [WORK / 'scripts/runner.c']:
            relative = str(path.relative_to(WORK))
            actual = sha256(path)
            if args.resume and summary['source_sha256'].get(relative) != actual:
                raise RuntimeError(f'working source changed since prior run: {relative}')
            summary['source_sha256'][relative] = actual
        sdk_envs = {}
        for version in VERSIONS:
            metadata = json.loads((SDKS / f'linux-{version}.json').read_text(encoding='utf-8'))
            archive = SDKS / metadata['name']
            actual = sha256(archive)
            if actual != metadata['sha256']:
                raise RuntimeError(f'SDK {version} archive digest mismatch: {actual}')
            prior_sdk = summary['sdks'].get(version)
            if args.resume and (prior_sdk is None or prior_sdk['archive_sha256'] != actual):
                raise RuntimeError(f'SDK {version} archive changed since prior run')
            summary['sdks'][version] = {'archive': str(archive), 'archive_sha256': actual,
                                        'source_page': metadata['source_page'],
                                        'home': str(SDKS / f'linux-{version}/cangjie')}
            if prior_sdk is not None:
                for key in ('cli_sha256', 'native_test_count'):
                    if key in prior_sdk:
                        summary['sdks'][version][key] = prior_sdk[key]
        save()
        execute('uname', ['/usr/bin/uname', '-a'])
        execute('os-release', ['/usr/bin/cat', '/etc/os-release'])
        execute('python-version', ['/usr/bin/python3', '--version'])
        execute('cc-version', ['/usr/bin/cc', '--version'])

        env = os.environ.copy()
        for version in VERSIONS:
            env['CJ_DOCGUARD_SDK_' + version.replace('.', '_')] = summary['sdks'][version]['home']
        execute('runtime-unit-tests', ['/usr/bin/python3', '-m', 'unittest', 'discover',
                                       '-s', 'tests', '-p', 'test_dev.py', '-v'], env)
        for version in VERSIONS:
            execute(f'probe-{version}', ['/usr/bin/python3', 'scripts/dev.py', 'probe', '--sdk', version], env)

        (WORK / 'build').mkdir(exist_ok=True)
        execute('build-runner', ['/usr/bin/cc', '-std=c11', '-O2', '-Wall', '-Wextra',
                                 'scripts/runner.c', '-o', 'build/cjdg-runner'], env)
        runner_sha = sha256(WORK / 'build/cjdg-runner')
        if args.resume and 'runner_sha256' in summary and summary['runner_sha256'] != runner_sha:
            raise RuntimeError('runner changed since prior run')
        summary['runner_sha256'] = runner_sha
        cases = runpy.run_path(str(WORK / 'scripts/test.py'))['CASES']
        source_files = [str(p.relative_to(WORK)) for p in sorted((WORK / 'src').glob('*.cj'))]
        for version in VERSIONS:
            home = Path(summary['sdks'][version]['home'])
            sdk_env = env.copy()
            sdk_env.update({'CANGJIE_HOME': str(home),
                            'PATH': f'{home}/bin:{home}/tools/bin:/usr/bin:/bin:/usr/sbin:/sbin',
                            'LD_LIBRARY_PATH': f'{home}/runtime/lib/linux_aarch64_cjnative',
                            'CJ_DOCGUARD_RUNNER': str(WORK / 'build/cjdg-runner'),
                            'CJ_DOCGUARD_TEST_SDK': version})
            sdk_envs[version] = sdk_env
            cli = WORK / f'build/native-cli-{version}'
            execute(f'cli-build-{version}', [str(home / 'bin/cjc'), *source_files, '-O2',
                                            '-Woff', 'unused', '-o', str(cli)], sdk_env)
            cli_sha = sha256(cli)
            if args.resume and 'cli_sha256' in summary['sdks'][version] and summary['sdks'][version]['cli_sha256'] != cli_sha:
                raise RuntimeError(f'CLI {version} changed since prior run')
            summary['sdks'][version]['cli_sha256'] = cli_sha
            sdk_env['CJ_DOCGUARD_TEST_CLI'] = str(cli)
            for name, sources in cases.items():
                binary = WORK / f'build/native-{name}-{version}'
                command = [str(home / 'bin/cjc'), *[f'src/{part}.cj' for part in sources],
                           f'tests/native_{name}.cj', '-O2', '-Woff', 'unused', '-o', str(binary)]
                execute(f'native-{name}-{version}-compile', command, sdk_env)
                execute(f'native-{name}-{version}-run', [str(binary)], sdk_env)
            summary['sdks'][version]['native_test_count'] = len(cases)
            save()

        config = WORK / 'examples/healthy/docguard.toml'
        cli = WORK / 'build/native-cli-1.1.3'
        cli_env = sdk_envs['1.1.3']
        execute('doctor', [str(cli), 'doctor', '--config', str(config)], cli_env)
        execute('verify-matrix', [str(cli), 'verify', '--config', str(config), '--matrix'], cli_env, timeout=900)
        report = json.loads((config.parent / '.docguard/report.json').read_text(encoding='utf-8'))
        results = report['results']
        counts = {'RUN_VERIFIED': 0, 'COMPILE_ONLY': 0}
        for result in results:
            expected_eligible = 'compile_eligible' if result['status'] == 'COMPILE_ONLY' else 'eligible'
            if result['platform'] != 'Linux-aarch64' or result['freshness'] != 'CURRENT' or not result[expected_eligible]:
                raise RuntimeError('matrix has unexpected platform, freshness or eligibility')
            counts[result['status']] += 1
        if len(results) != 28 or counts != {'RUN_VERIFIED': 26, 'COMPILE_ONLY': 2}:
            raise RuntimeError(f'unexpected healthy matrix: {len(results)}, {counts}')
        summary['healthy_matrix'] = {'results': len(results), 'statuses': counts,
                                     'report_sha256': sha256(config.parent / '.docguard/report.json')}
        save()
        execute('strict', [str(cli), 'check', '--config', str(config), '--strict'], cli_env)
        for version in VERSIONS:
            query = [str(cli), 'query', '--config', str(config), '--tool', 'get_verified_examples',
                     '--sdk', version, '--platform', 'Linux-aarch64']
            response = execute(f'query-{version}', query, cli_env)
            payload = json.loads(response.stdout)
            if len(payload['items']) != 13 or len(payload['rejected']) != 1 or payload['rejected'][0]['status'] != 'COMPILE_ONLY':
                raise RuntimeError(f'unexpected query items for {version}')
            bundle = output / f'export-arithmetic-{version}'
            execute(f'export-{version}', [str(cli), 'export', '--config', str(config),
                    '--example', 'arithmetic', '--sdk', version, '--platform', 'Linux-aarch64',
                    '--out', str(bundle)], cli_env)
            replay_env = sdk_envs[version].copy()
            replay_env['CJ_SDK_HOME'] = summary['sdks'][version]['home']
            execute(f'replay-{version}', ['/usr/bin/bash', 'build.sh'], replay_env, cwd=bundle)
            refusal = output / f'refused-compile-only-{version}'
            response = execute(f'compile-only-refusal-{version}', [str(cli), 'export',
                    '--config', str(config), '--example', 'compile-only', '--sdk', version,
                    '--platform', 'Linux-aarch64', '--out', str(refusal)], cli_env, expected=1)
            if refusal.exists() or json.loads(response.stdout)['status'] != 'COMPILE_ONLY':
                raise RuntimeError(f'compile-only export was not cleanly refused for {version}')
        if 'error' in summary:
            summary['recovered_error'] = summary.pop('error')
        summary['complete'] = True
        save()
        return 0
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        summary['complete'] = False
        summary['error'] = str(error)
        save()
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
