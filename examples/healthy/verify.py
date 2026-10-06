#!/usr/bin/env python3
"""Independent fixture audit: real compilers and exact registered output checks."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
SPEC = importlib.util.spec_from_file_location('docguard_dev', PROJECT / 'scripts/dev.py')
DEV = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DEV)


def main() -> int:
    config = tomllib.loads((HERE / 'docguard.toml').read_text(encoding='utf-8'))
    builds = runs = compile_only = 0
    with tempfile.TemporaryDirectory(prefix='docguard-healthy-audit-') as work:
        work = Path(work)
        for sdk in config['sdks']:
            version = sdk['version']
            inherited = DEV.sdk_env(version)
            allowed = {'PATH', 'CANGJIE_HOME', 'DYLD_LIBRARY_PATH', 'LD_LIBRARY_PATH', 'SDKROOT',
                       'CJ_DOCGUARD_SDK_1_1_3', 'CJ_DOCGUARD_SDK_1_2_0', 'CJ_DOCGUARD_RUNNER'}
            environment = {key: value for key, value in inherited.items() if key in allowed}
            environment.update(LANG='C', LC_ALL='C')
            for example in config['examples']:
                if version not in example['sdks']:
                    continue
                source = HERE / example['file']
                if example['kind'] == 'snippet':
                    source = work / f'{version}-{example["id"]}.cj'
                    wrapper = (HERE / example['wrapper']).read_text(encoding='utf-8')
                    if wrapper.count('{{code}}') != 1:
                        raise RuntimeError('wrapper must have exactly one code placeholder')
                    source.write_text(wrapper.replace('{{code}}', (HERE / example['file']).read_text(encoding='utf-8')), encoding='utf-8')
                output = work / f'{version}-{example["id"]}'
                command = [sys.executable, str(PROJECT / 'scripts/dev.py'), 'compile', '--sdk', version,
                           '--output', str(output), str(HERE / 'src/demo.cj'), str(source), '-Woff', 'unused']
                compiled = subprocess.run(command, cwd=PROJECT, env=environment, capture_output=True,
                                          text=True, timeout=60)
                if compiled.returncode:
                    raise RuntimeError(f'{version}/{example["id"]} compile failed:\n{compiled.stderr}')
                builds += 1
                if example['mode'] == 'compile':
                    compile_only += 1
                    print(f'PASS {version}/{example["id"]}: compile only')
                    continue
                executed = subprocess.run([str(output)], cwd=HERE, env=environment, capture_output=True,
                                          text=True, timeout=example['timeout_ms'] / 1000)
                if executed.returncode != example['expected_exit'] or executed.stdout != example['stdout']:
                    raise RuntimeError(f'{version}/{example["id"]}: exit={executed.returncode}, stdout={executed.stdout!r}, stderr={executed.stderr!r}')
                runs += 1
                print(f'PASS {version}/{example["id"]}: exact stdout and exit {executed.returncode}')
    print(f'PASS healthy audit: {builds} real builds, {runs} exact-output runs, {compile_only} compile-only cases')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
