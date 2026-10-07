#!/usr/bin/env python3
"""Measure native CLI memory on an isolated, unchanged project history."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import dev


COMMANDS = ('check', 'query', 'verify')


def native_platform() -> str:
    os_name = 'Darwin' if sys.platform == 'darwin' else 'Linux'
    return f'{os_name}-{os.uname().machine}'


def attempt_count(project: Path) -> int:
    return sum(1 for _ in (project / '.docguard' / 'attempts').glob('*.json'))


def attempts_sha256(project: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted((project / '.docguard' / 'attempts').glob('*.json')):
        digest.update(path.name.encode('utf-8'))
        with path.open('rb') as handle:
            for block in iter(lambda: handle.read(65536), b''):
                digest.update(block)
    return digest.hexdigest()


def clone_project(source: Path, target: Path) -> None:
    if target.exists() or source.resolve() == target.resolve():
        raise ValueError('diagnostic target must be new and separate from source')
    target.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == 'darwin':
        # APFS clone-on-write preserves source bytes without duplicating large logs.
        subprocess.run(['/bin/cp', '-c', '-R', str(source), str(target)], check=True)
    else:
        shutil.copytree(source, target, symlinks=True)


def rss_kib(pid: int) -> int | None:
    result = subprocess.run(['/bin/ps', '-o', 'rss=', '-p', str(pid)],
                            capture_output=True, text=True, check=False)
    try:
        return int(result.stdout.strip())
    except ValueError:
        return None


def run_case(command: list[str], env: dict[str, str], project: Path, output: Path,
             name: str, timeout: float, interval: float) -> dict:
    stdout_path = output / f'{name}.stdout'
    stderr_path = output / f'{name}.stderr'
    start = time.monotonic()
    before_attempts = attempt_count(project)
    report = project / '.docguard' / 'report.json'
    before_report_mtime = report.stat().st_mtime_ns if report.exists() else None
    samples: list[list[float | int]] = []
    events: list[dict] = []
    previous_attempts = before_attempts
    previous_report_mtime = before_report_mtime
    timed_out = False
    with stdout_path.open('wb') as stdout, stderr_path.open('wb') as stderr:
        proc = subprocess.Popen(command, cwd=dev.ROOT, env=env, stdout=stdout, stderr=stderr)
        while proc.poll() is None:
            elapsed = time.monotonic() - start
            rss = rss_kib(proc.pid)
            if rss is not None:
                samples.append([round(elapsed, 3), rss])
            current_attempts = attempt_count(project)
            if current_attempts != previous_attempts:
                events.append({'seconds': round(elapsed, 3), 'kind': 'attempt_count',
                               'value': current_attempts})
                previous_attempts = current_attempts
            current_report_mtime = report.stat().st_mtime_ns if report.exists() else None
            if current_report_mtime != previous_report_mtime:
                events.append({'seconds': round(elapsed, 3), 'kind': 'report_updated'})
                previous_report_mtime = current_report_mtime
            if elapsed >= timeout:
                timed_out = True
                proc.kill()
                break
            time.sleep(interval)
        exit_code = proc.wait()
    elapsed = round(time.monotonic() - start, 3)
    final_attempts = attempt_count(project)
    if final_attempts != previous_attempts:
        events.append({'seconds': elapsed, 'kind': 'attempt_count', 'value': final_attempts})
    final_report_mtime = report.stat().st_mtime_ns if report.exists() else None
    if final_report_mtime != previous_report_mtime:
        events.append({'seconds': elapsed, 'kind': 'report_updated'})
    return {
        'name': name, 'command': command, 'exit_code': exit_code,
        'timed_out': timed_out, 'seconds': round(time.monotonic() - start, 3),
        'maximum_observed_rss_kib': max((sample[1] for sample in samples), default=None),
        'sampling_interval_seconds': interval, 'samples': samples,
        'events': events, 'attempts_before': before_attempts,
        'attempts_after': final_attempts,
        'stdout_file': stdout_path.name, 'stderr_file': stderr_path.name,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='existing complete project history')
    parser.add_argument('--binary', type=Path, default=dev.ROOT / 'build/cj-docguard')
    parser.add_argument('--output', type=Path, required=True, help='new diagnostic directory')
    parser.add_argument('--sdk', choices=('1.1.3', '1.2.0'), default='1.1.3')
    parser.add_argument('--heap', help='optional cjHeapSize, for example 128MB')
    parser.add_argument('--commands', nargs='+', choices=COMMANDS, default=list(COMMANDS))
    parser.add_argument('--max-attempts', type=int, default=400)
    parser.add_argument('--timeout', type=float, default=300)
    parser.add_argument('--interval', type=float, default=0.1)
    args = parser.parse_args(argv)
    source = args.source.resolve()
    binary = args.binary.resolve()
    output = args.output.resolve()
    if not (source / 'docguard.toml').is_file() or not binary.is_file():
        parser.error('source docguard.toml and binary must exist')
    if args.max_attempts < 1 or args.timeout <= 0 or args.interval <= 0:
        parser.error('limits must be positive')
    if output == source or source in output.parents or output in source.parents:
        parser.error('output and source must be separate')
    count = attempt_count(source)
    source_digest = attempts_sha256(source)
    if count > args.max_attempts:
        parser.error(f'{count} attempts exceeds --max-attempts {args.max_attempts}')
    if output.exists():
        parser.error('output directory already exists')
    project = output / 'project'
    clone_project(source, project)
    env = dev.sdk_env(args.sdk)
    if args.heap:
        env['cjHeapSize'] = args.heap
    else:
        env.pop('cjHeapSize', None)
    summary = {
        'created_at_utc': datetime.now(timezone.utc).isoformat(),
        'platform': native_platform(), 'source': str(source), 'project_copy': str(project),
        'binary': str(binary), 'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
        'sdk': args.sdk, 'heap_override': args.heap, 'source_attempt_count': count,
        'source_attempts_sha256_before': source_digest,
        'copied_attempts_sha256_before': attempts_sha256(project),
        'cases': [],
    }
    for index, name in enumerate(args.commands):
        command = [str(binary), name, '--config', str(project / 'docguard.toml')]
        if name == 'check':
            command.append('--strict')
        elif name == 'query':
            command.extend(['--tool', 'get_verified_examples', '--sdk', args.sdk,
                            '--platform', native_platform()])
        else:
            command.append('--matrix')
        case_name = f'{index + 1:02d}-{name}'
        summary['cases'].append(run_case(command, env, project, output, case_name,
                                         args.timeout, args.interval))
        summary['source_attempts_sha256_after'] = attempts_sha256(source)
        (output / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n',
                                             encoding='utf-8')
        print(json.dumps({key: value for key, value in summary['cases'][-1].items()
                          if key not in ('samples', 'command')}, ensure_ascii=False), flush=True)
    return int(any(case['exit_code'] != 0 or case['timed_out'] for case in summary['cases']))


if __name__ == '__main__':
    raise SystemExit(main())
