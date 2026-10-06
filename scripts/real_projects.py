#!/usr/bin/env python3
"""Pinned external-source integrations; production sources stay byte-identical upstream."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / 'integrations/upstream-lock.json').read_text(encoding='utf-8'))
SPEC = importlib.util.spec_from_file_location('docguard_dev', ROOT / 'scripts/dev.py')
DEV = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DEV)


def git(repo: Path, *arguments: str) -> str:
    return subprocess.check_output(['git', '-c', 'core.hooksPath=/dev/null', '-C', str(repo), *arguments],
                                   text=True, timeout=120).strip()


def checked_checkout(item: dict, cache: Path, fetch: bool) -> Path:
    repo = cache / item['name']
    if not repo.exists():
        if not fetch:
            raise RuntimeError(f'{repo} missing; use --fetch or point --cache at a reviewed checkout')
        cache.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', 'clone', '--no-checkout',
                        item['repository'], str(repo)], check=True, timeout=180)
        git(repo, 'checkout', '--detach', item['commit'])
    if git(repo, 'rev-parse', 'HEAD') != item['commit']:
        raise RuntimeError(f'{item["name"]}: HEAD differs from reviewed fixed commit')
    if git(repo, 'status', '--porcelain', '--untracked-files=all'):
        raise RuntimeError(f'{item["name"]}: upstream working tree is modified')
    paths = git(repo, 'ls-files').splitlines()
    if set(paths) != set(item['files_sha256']):
        raise RuntimeError(f'{item["name"]}: tracked input inventory mismatch')
    for relative, expected in item['files_sha256'].items():
        path = repo / relative
        if path.is_symlink() or not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f'{item["name"]}: reviewed content hash mismatch: {relative}')
    production = [p for p in paths if p.startswith('src/') and p.endswith('.cj')
                  and not p.endswith('_test.cj') and not p.startswith('src/test/')]
    if set(production) != set(item['production_sources']):
        raise RuntimeError('production source coverage mismatch')
    license = (repo / 'LICENSE').read_text(encoding='utf-8')
    if item['license'] == 'Apache-2.0' and 'Apache License' not in license:
        raise RuntimeError('Apache license mismatch')
    if item['license'] == 'MIT' and not license.startswith('MIT License'):
        raise RuntimeError('MIT license mismatch')
    return repo


def harness(item: dict, repo: Path, destination: Path, sdks: list[str]) -> Path:
    destination.mkdir(parents=True)
    # Copy all src files, keeping tests in the hash-bound snapshot but excluding them
    # explicitly from production analysis/build. Preserve bytes and license notices.
    for relative in [p for p in item['files_sha256'] if p.startswith('src/') and p.endswith('.cj')]:
        target = destination / 'upstream' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo / relative, target)
    for relative in ('LICENSE', 'README.md', 'cjpm.toml'):
        target = destination / 'upstream' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo / relative, target)
    for extra in ('NOTICE', 'NOTICE.txt'):
        if extra in item['files_sha256']:
            shutil.copyfile(repo / extra, destination / 'upstream' / extra)
    shutil.copyfile(ROOT / 'integrations' / item['name'] / 'sample.cj', destination / 'sample.cj')
    provenance = {key: value for key, value in item.items() if key != 'stdout'}
    provenance.update(scope='full unchanged production src; upstream test files excluded',
                      source_modified=False, third_party_adoption=False)
    (destination / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    exclusions = [f'upstream/{path}' for path in item['excluded_sources']]
    lines = ['[project]', f'name = {json.dumps("upstream integration: " + item["name"])}',
             'sources = ["upstream/src"]', 'documents = ["README.md"]',
             'output = ".docguard"', 'trusted = true', 'closed_inputs = true',
             'exclude = ' + json.dumps(exclusions), '']
    for version in sdks:
        lines += ['[[sdks]]', f'version = {json.dumps(version)}', '']
    lines += ['[[examples]]', 'id = "upstream-api"', 'file = "sample.cj"',
              f'symbol = {json.dumps(item["symbol"])}', 'kind = "program"', 'mode = "run"',
              'sdks = ' + json.dumps(sdks), 'stdout = ' + json.dumps(item['stdout'], ensure_ascii=False),
              'expected_exit = 0', 'timeout_ms = 1000', 'required = true', '']
    config = destination / 'docguard.toml'
    config.write_text('\n'.join(lines), encoding='utf-8')
    readme = (f'# {item["name"]} 固定提交集成\n\n'
              f'上游：{item["repository"]}；提交 `{item["commit"]}`；许可 {item["license"]}。\n\n'
              '这是本工具作者的独立复验，不是上游采用声明。上游生产源码按字节完整复制，未作兼容性改写。'
              '样例与上游库使用相同包，检查公共算法调用；不宣称已支持跨包构建或上游全部测试。\n\n'
              f'明确排除的上游测试：`{", ".join(item["excluded_sources"])}`。'
              '这些测试先经人工审计，不执行测试宏或旧测试依赖；配置显式记录排除，因此封闭输入判定以原生引擎实际报告为准。\n\n'
              '[许可](upstream/LICENSE)、[来源和字节摘要](provenance.json)、[运行样例](sample.cj)。\n')
    (destination / 'README.md').write_text(readme, encoding='utf-8')
    return config


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=ROOT / 'build/external-cache')
    parser.add_argument('--fetch', action='store_true', help='fetch only the pre-reviewed pinned commits')
    parser.add_argument('--sdk', action='append', choices=['1.1.3', '1.2.0'])
    parser.add_argument('--project', action='append', choices=[p['name'] for p in LOCK['projects']])
    parser.add_argument('--output', type=Path, default=ROOT / 'build/real-projects')
    args = parser.parse_args()
    sdk_versions = args.sdk or ['1.1.3', '1.2.0']
    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    run_root = args.output.resolve() / timestamp
    run_root.mkdir(parents=True)
    binary = ROOT / 'build/cj-docguard'
    if not binary.is_file():
        raise RuntimeError('build/cj-docguard unavailable; run scripts/dev.py build first')
    binary_digest = hashlib.sha256(binary.read_bytes()).hexdigest()
    base_env = DEV.sdk_env('1.1.3')
    allowed = {'PATH', 'CANGJIE_HOME', 'DYLD_LIBRARY_PATH', 'LD_LIBRARY_PATH', 'SDKROOT',
               'CJ_DOCGUARD_SDK_1_1_3', 'CJ_DOCGUARD_SDK_1_2_0', 'CJ_DOCGUARD_RUNNER'}
    environment = {key: value for key, value in base_env.items() if key in allowed}
    environment.update(LANG='C', LC_ALL='C')
    results = []
    # Audit/check all selected cache inputs before executing even the first project.
    selected = [p for p in LOCK['projects'] if not args.project or p['name'] in args.project]
    checkouts = {p['name']: checked_checkout(p, args.cache.resolve(), args.fetch) for p in selected}
    for item in selected:
        config = harness(item, checkouts[item['name']], run_root / item['name'], sdk_versions)
        started = datetime.now(timezone.utc).isoformat()
        command = [str(binary), 'verify', '--matrix', '--config', str(config)]
        completed = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True,
                                   text=True, timeout=300)
        finished = datetime.now(timezone.utc).isoformat()
        # Do not write audit logs inside the input tree after verification: that would
        # invalidate the just-recorded fingerprint. Keep orchestration logs outside it.
        outside = run_root / ('orchestration-' + item['name'])
        outside.mkdir()
        (outside / 'stdout.txt').write_text(completed.stdout, encoding='utf-8')
        (outside / 'stderr.txt').write_text(completed.stderr, encoding='utf-8')
        report_path = config.parent / '.docguard/report.json'
        report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}
        result = dict(name=item['name'], commit=item['commit'], repository=item['repository'],
                      license=item['license'], production_sources=item['production_sources'],
                      excluded_sources=item['excluded_sources'], command=command, started_at=started,
                      finished_at=finished, exit_code=completed.returncode, stdout=completed.stdout,
                      stderr=completed.stderr, report_path=str(report_path), summary=report.get('summary', {}),
                      closure_complete=report.get('manifest', {}).get('closure_complete'),
                      extraction_files=report.get('api', {}).get('files', []),
                      diagnostics=report.get('diagnostics', []),
                      results=[{k: r.get(k) for k in ('sdk_version','status','freshness','eligible','reason')}
                               for r in report.get('results', [])], third_party_adoption=False)
        results.append(result)
        print(json.dumps({k: result[k] for k in ('name','exit_code','summary','results')}, ensure_ascii=False), flush=True)
    binary_digest_after = hashlib.sha256(binary.read_bytes()).hexdigest()
    record = dict(schema_version=1, audited_at=datetime.now(timezone.utc).isoformat(),
                  binary_sha256=binary_digest, binary_sha256_after=binary_digest_after,
                  binary_unchanged=binary_digest == binary_digest_after,
                  run_root=str(run_root), projects=results, claim='independent pinned-source audit, not third-party adoption')
    (run_root / 'audit.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Audit record: ' + str(run_root / 'audit.json'))
    if binary_digest != binary_digest_after:
        raise RuntimeError('native binary changed during this audit; preserve evidence but rerun against a fixed binary')
    # Nonzero project outcomes remain audit data; this script fails only setup/audit errors.
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (RuntimeError, subprocess.SubprocessError, OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(2)
