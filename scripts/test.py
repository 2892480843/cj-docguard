#!/usr/bin/env python3
"""Run native tests on both real SDKs and Python integration tests."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import dev

ROOT = dev.ROOT
CASES = {
    'primitives': ['primitives'],
    'extractor': ['primitives', 'extractor'],
    'evidence': ['primitives', 'evidence'],
    'report': ['primitives', 'report'],
    'platform': ['primitives', 'util', 'platform'],
    'export': ['primitives', 'util', 'extractor', 'evidence', 'platform', 'engine', 'report', 'export'],
}

def run(argv, env, log, timeout=600):
    started = time.monotonic()
    r = subprocess.run(argv, env=env, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    log.write_text(r.stdout + r.stderr, encoding='utf-8')
    print(f'{log.name}: exit {r.returncode}, {time.monotonic()-started:.2f}s', flush=True)
    if r.returncode: print(r.stdout + r.stderr, file=sys.stderr)
    return r.returncode

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--sdk', action='append', choices=['1.1.3','1.2.0'])
    p.add_argument('--native-only', action='store_true')
    a=p.parse_args()
    logs=ROOT/'build/test-results';logs.mkdir(parents=True,exist_ok=True)
    outcomes=[]
    for sdk in a.sdk or ['1.1.3','1.2.0']:
        env=dev.sdk_env(sdk)
        env['CJ_DOCGUARD_TEST_SDK']=sdk
        cli=logs/f'native-cli-{sdk}'
        cli_sources=[str(p.relative_to(ROOT)) for p in sorted((ROOT/'src').glob('*.cj'))]
        cli_code=run([str(dev.sdk_home(sdk)/'bin/cjc'),*cli_sources,'-O2','-Woff','unused','-o',str(cli)],
                     env,logs/f'export-cli-{sdk}-compile.log')
        outcomes.append({'case':'export-cli-build','sdk':sdk,'exit_code':cli_code})
        if cli_code: continue
        env['CJ_DOCGUARD_TEST_CLI']=str(cli)
        for name, sources in CASES.items():
            binary=logs/f'native-{name}-{sdk}'
            cmd=[str(dev.sdk_home(sdk)/'bin/cjc'),*[f'src/{s}.cj' for s in sources], f'tests/native_{name}.cj','-O2','-Woff','unused','-o',str(binary)]
            code=run(cmd,env,logs/f'{name}-{sdk}-compile.log')
            if not code: code=run([str(binary)],env,logs/f'{name}-{sdk}-run.log')
            outcomes.append({'case':name,'sdk':sdk,'exit_code':code})
    if not a.native_only:
        code=run([sys.executable,'-m','unittest','discover','-s','tests','-p','test_*.py','-v'],dev.sdk_env('1.1.3'),logs/'python-integration.log')
        outcomes.append({'case':'python-integration','exit_code':code})
    (logs/'summary.json').write_text(json.dumps(outcomes,ensure_ascii=False,indent=2)+'\n')
    return int(any(o['exit_code'] for o in outcomes))

if __name__ == '__main__': raise SystemExit(main())
