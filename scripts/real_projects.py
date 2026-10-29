#!/usr/bin/env python3
"""Pinned external-source integrations with explicit reviewed local repair opt-in."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / 'integrations/upstream-lock.json').read_text(encoding='utf-8'))
SPEC = importlib.util.spec_from_file_location('docguard_dev', ROOT / 'scripts/dev.py')
DEV = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DEV)

CASE_ID = re.compile(r'[a-z][a-z0-9-]{0,63}\Z')
CASE_FILE = re.compile(r'(?:sample\.cj|cases/[a-z][a-z0-9-]{0,63}\.cj)\Z')
SHA256 = re.compile(r'[0-9a-f]{64}\Z')


def examples_for(item: dict) -> list[dict]:
    """Keep the original one-sample lock usable by older integrations."""
    if 'examples' in item:
        return item['examples']
    sample = ROOT / 'integrations' / item['name'] / 'sample.cj'
    return [dict(id='upstream-api', file='sample.cj', symbol=item['symbol'],
                 stdout=item['stdout'], expected_exit=0,
                 sha256=hashlib.sha256(sample.read_bytes()).hexdigest())]


def validate_examples(items: list[dict]) -> None:
    """Validate the entire registry before any project inputs are copied."""
    for item in items:
        cases = examples_for(item)
        if not isinstance(cases, list) or not cases:
            raise ValueError(f'{item["name"]}: examples must be a nonempty list')
        seen = set()
        seen_files = set()
        for case in cases:
            if not isinstance(case, dict) or not {'id', 'file', 'symbol', 'stdout', 'expected_exit', 'sha256'} <= case.keys():
                raise ValueError(f'{item["name"]}: incomplete case')
            case_id, relative = case['id'], case['file']
            if not isinstance(case_id, str) or not CASE_ID.fullmatch(case_id) or case_id in seen:
                raise ValueError(f'{item["name"]}: invalid or duplicate case id: {case_id}')
            seen.add(case_id)
            if not isinstance(relative, str) or not CASE_FILE.fullmatch(relative) or relative in seen_files:
                raise ValueError(f'{item["name"]}: invalid case path: {relative}')
            seen_files.add(relative)
            source = ROOT / 'integrations' / item['name'] / relative
            digest = case['sha256']
            case_root = (ROOT / 'integrations' / item['name']).resolve()
            if (not source.resolve().is_relative_to(case_root) or not isinstance(digest, str)
                    or not SHA256.fullmatch(digest) or source.is_symlink() or not source.is_file()
                    or source.stat().st_size > 65536 or hashlib.sha256(source.read_bytes()).hexdigest() != digest):
                raise ValueError(f'{item["name"]}: case content mismatch: {relative}')
            if not isinstance(case['symbol'], str) or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', case['symbol']):
                raise ValueError(f'{item["name"]}: invalid symbol')
            if not isinstance(case['stdout'], str) or len(case['stdout'].encode('utf-8')) > 65536:
                raise ValueError(f'{item["name"]}: invalid stdout assertion')
            if type(case['expected_exit']) is not int or not 0 <= case['expected_exit'] <= 255:
                raise ValueError(f'{item["name"]}: invalid exit assertion')
            if not re.search(r'\b' + re.escape(case['symbol']) + r'\s*\(', source.read_text(encoding='utf-8')):
                raise ValueError(f'{item["name"]}: case does not call declared symbol')


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


def apply_reviewed_source_fixes(item: dict, destination: Path) -> list[dict]:
    """Apply only reviewed, hash-bound local repairs to the copied snapshot."""
    if item['name'] != 'leven4cj':
        return []
    folder = ROOT / 'integrations/leven4cj/patches'
    fix = json.loads((folder / 'manifest.json').read_text(encoding='utf-8'))
    patch = folder / fix['patch']
    if hashlib.sha256(patch.read_bytes()).hexdigest() != fix['patch_sha256']:
        raise RuntimeError('reviewed patch hash mismatch')
    if item['files_sha256'].get(fix['path']) != fix['before_sha256']:
        raise RuntimeError('reviewed fix does not match pinned source')
    target = destination / 'upstream' / fix['path']
    before = target.read_bytes()
    if hashlib.sha256(before).hexdigest() != fix['before_sha256']:
        raise RuntimeError('reviewed fix before hash mismatch')
    after = before
    for old, new in fix['replacements']:
        if after.count(old.encode('utf-8')) != 1:
            raise RuntimeError('reviewed fix replacement count mismatch')
        after = after.replace(old.encode('utf-8'), new.encode('utf-8'))
    if hashlib.sha256(after).hexdigest() != fix['after_sha256']:
        raise RuntimeError('reviewed fix after hash mismatch')
    # Bind the human-reviewable patch to the exact transformation actually applied.
    import difflib
    expected = ''.join(difflib.unified_diff(before.decode().splitlines(True), after.decode().splitlines(True),
                                         fromfile='a/' + fix['path'], tofile='b/' + fix['path']))
    if patch.read_bytes() != expected.encode('utf-8'):
        raise RuntimeError('reviewed patch differs from applied transformation')
    target.write_bytes(after)
    return [{key: value for key, value in fix.items() if key != 'replacements'}]


def harness(item: dict, repo: Path, destination: Path, sdks: list[str], apply_reviewed_fixes: bool = False) -> Path:
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
    fixes = apply_reviewed_source_fixes(item, destination) if apply_reviewed_fixes else []
    cases = examples_for(item)
    for case in cases:
        target = destination / case['file']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / 'integrations' / item['name'] / case['file'], target)
    provenance = {key: value for key, value in item.items() if key != 'stdout'}
    provenance.update(scope='full unchanged production src; upstream test files excluded',
                      source_modified=False, third_party_adoption=False)
    if fixes:
        provenance.update(scope='full production src with reviewed local Unicode repair; upstream tests excluded',
                          source_modified=True, reviewed_fixes=fixes,
                          modified_files_sha256={fix['path']: fix['after_sha256'] for fix in fixes})
    (destination / 'provenance.json').write_text(json.dumps(provenance, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    exclusions = [f'upstream/{path}' for path in item['excluded_sources']]
    lines = ['[project]', f'name = {json.dumps(("local fixed integration: " if fixes else "upstream integration: ") + item["name"])}',
             'sources = ["upstream/src"]', 'documents = ["README.md"]',
             'output = ".docguard"', 'trusted = true', 'closed_inputs = true',
             'exclude = ' + json.dumps(exclusions), '']
    for version in sdks:
        lines += ['[[sdks]]', f'version = {json.dumps(version)}', '']
    for case in cases:
        lines += ['[[examples]]', 'id = ' + json.dumps(case['id']),
                  'file = ' + json.dumps(case['file']),
                  'symbol = ' + json.dumps(case['symbol']), 'kind = "program"', 'mode = "run"',
                  'sdks = ' + json.dumps(sdks), 'stdout = ' + json.dumps(case['stdout'], ensure_ascii=False),
                  'expected_exit = ' + str(case['expected_exit']), 'timeout_ms = 10000',
                  'required = true', '']
    config = destination / 'docguard.toml'
    config.write_text('\n'.join(lines), encoding='utf-8')
    readme = (f'# {item["name"]} 固定提交集成\n\n'
              f'上游：{item["repository"]}；提交 `{item["commit"]}`；许可 {item["license"]}。\n\n'
              '这是本工具作者的独立复验，不是上游采用声明。上游生产源码按字节完整复制，未作兼容性改写。'
              '样例与上游库使用相同包，检查公共算法调用；不宣称已支持跨包构建或上游全部测试。\n\n'
              f'明确排除的上游测试：`{", ".join(item["excluded_sources"])}`。'
              '这些测试先经人工审计，不执行测试宏或旧测试依赖；配置显式记录排除，因此封闭输入判定以原生引擎实际报告为准。\n\n'
              '[许可](upstream/LICENSE)、[来源和字节摘要](provenance.json)、[运行样例](sample.cj)。\n')
    if fixes:
        readme = readme.replace('上游生产源码按字节完整复制，未作兼容性改写。',
                                '这是明确标记的本地修复版本；空字符串分支改用 Unicode 码点计数，详情与前后摘要见 provenance.json。')
    (destination / 'README.md').write_text(readme, encoding='utf-8')
    return config


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=ROOT / 'build/external-cache')
    parser.add_argument('--apply-reviewed-fixes', action='store_true', help='opt in to hash-checked reviewed local source repairs')
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
    validate_examples(selected)
    checkouts = {p['name']: checked_checkout(p, args.cache.resolve(), args.fetch) for p in selected}
    for item in selected:
        config = harness(item, checkouts[item['name']], run_root / item['name'], sdk_versions, args.apply_reviewed_fixes)
        started = datetime.now(timezone.utc).isoformat()
        command = [str(binary), 'verify', '--matrix', '--config', str(config)]
        matrix_cells = len(examples_for(item)) * len(sdk_versions)
        completed = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True,
                                   text=True, timeout=120 + matrix_cells * 20)
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
                      example_count=len(examples_for(item)), expected_matrix_cells=matrix_cells,
                      observed_matrix_cells=len(report.get('results', [])),
                      results=[{k: r.get(k) for k in ('example_id','sdk_version','status','freshness','eligible','reason')}
                               for r in report.get('results', [])], third_party_adoption=False)
        result['source_provenance'] = json.loads((config.parent / 'provenance.json').read_text(encoding='utf-8'))
        results.append(result)
        print(json.dumps({k: result[k] for k in ('name','exit_code','summary','results')}, ensure_ascii=False), flush=True)
    binary_digest_after = hashlib.sha256(binary.read_bytes()).hexdigest()
    record = dict(schema_version=1, audited_at=datetime.now(timezone.utc).isoformat(),
                  binary_sha256=binary_digest, binary_sha256_after=binary_digest_after,
                  binary_unchanged=binary_digest == binary_digest_after,
                  run_root=str(run_root), example_count=sum(r['example_count'] for r in results),
                  expected_matrix_cells=sum(r['expected_matrix_cells'] for r in results),
                  observed_matrix_cells=sum(r['observed_matrix_cells'] for r in results),
                  projects=results, claim='independent pinned-source audit, not third-party adoption')
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
