#!/usr/bin/env python3
"""Exercise the actual workbench HTTP/native pipeline on its owned demo only."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.request
import zipfile
import dev


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url', default='http://127.0.0.1:8765')
    args = parser.parse_args()
    base = args.url.rstrip('/')
    from urllib.parse import urlsplit
    if urlsplit(base).hostname not in ('127.0.0.1', 'localhost'):
        parser.error('local loopback service required')
    output = dev.ROOT / 'build/workbench-validation' / time.strftime('%Y%m%d-%H%M%S')
    output.mkdir(parents=True)
    token = None
    outcomes = []

    def request(path, body=None):
        headers = {'Origin': base}
        if token:
            headers['X-DocGuard-Token'] = token
        if body is not None:
            headers['Content-Type'] = 'application/json'
        req = urllib.request.Request(base + path, headers=headers,
            data=None if body is None else json.dumps(body).encode())
        with urllib.request.urlopen(req, timeout=30) as response:
            return json.load(response)

    bootstrap = request('/api/bootstrap')
    token = bootstrap['token']
    project = next(p for p in bootstrap['projects'] if p['demo'])
    prefix = '/api/projects/' + project['id']
    platform = bootstrap['platform']

    def job(label, action, expected=0, **params):
        started = request(prefix + '/jobs', {'action': action, **params})
        deadline = time.monotonic() + 600
        while time.monotonic() < deadline:
            result = request('/api/jobs/' + started['id'])
            if result['finished_at']:
                break
            time.sleep(.25)
        else:
            raise AssertionError('job did not finish: ' + label)
        (output / (label + '.json')).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
        assert result['exit_code'] == expected, (label, result)
        assert result['status'] == ('succeeded' if expected == 0 else 'failed'), (label, result)
        outcomes.append({'step':label,'exit_code':result['exit_code'],'status':result['status']})
        print(json.dumps(outcomes[-1]), flush=True)
        return result

    def query(label):
        return job(label, 'query', tool='get_verified_examples', sdk='1.1.3',
                   platform=platform, example='arithmetic')['result']

    try:
        job('01-restore', 'demo_restore')
        job('02-doctor', 'doctor')
        job('03-build', 'build')
        job('04-verify-matrix', 'verify')
        job('05-check', 'check')
        before = request(prefix + '/report')['report']
        assert before['summary']['TOTAL'] == 28, before['summary']
        assert before['summary']['VERIFIED_CURRENT'] == 26, before['summary']
        assert len(query('06-current')['items']) == 1
        job('07-break', 'demo_break')
        assert query('08-stale')['items'] == []
        job('09-stale-check', 'check', expected=1)
        job('10-failed-verify', 'verify', expected=1)
        failed = request(prefix + '/report')['report']
        assert any(r['example_id'] == 'arithmetic' and r['status'] == 'ASSERTION_FAILED' for r in failed['results'])
        assert query('11-latest-failure')['items'] == []
        job('12-refused-export','export',expected=1,example='arithmetic',sdk='1.1.3',platform=platform)
        job('13-restore','demo_restore')
        job('14-reverify','verify')
        assert len(query('15-restored')['items']) == 1
        exported = job('16-export','export',example='arithmetic',sdk='1.1.3',platform=platform)
        with urllib.request.urlopen(base + exported['artifact_url']) as response:
            archive = output / 'export.zip'
            archive.write_bytes(response.read())
        with zipfile.ZipFile(archive) as z:
            assert 'build.sh' in z.namelist()
            z.extractall(output / 'rebuild')
        env = dev.sdk_env('1.1.3') | {'CJ_SDK_HOME':str(dev.sdk_home('1.1.3'))}
        rebuild = subprocess.run(['bash','build.sh'],cwd=output/'rebuild',env=env,capture_output=True,text=True,timeout=120)
        (output/'rebuild.stdout').write_text(rebuild.stdout,encoding='utf-8')
        (output/'rebuild.stderr').write_text(rebuild.stderr,encoding='utf-8')
        assert rebuild.returncode == 0 and rebuild.stdout == '42\n', rebuild.stdout + rebuild.stderr
        history = request(prefix+'/history')['items']
        assert history and all(r['freshness']=='FROZEN' and r['eligible'] is False for r in history)
        assert any(r['status']=='ASSERTION_FAILED' for r in history)
        compact = lambda r: {k:r[k] for k in ('summary','results','manifest','api')}
        # Keep comparison request focused; stage logs remain in the full saved reports.
        def comparison(r):
            c=compact(r)
            c['results']=[{k:v for k,v in x.items() if k in ('example_id','sdk_version','platform','status','freshness','eligible')} for x in r['results']]
            c['api']={'symbols':[{'id':x['id']} for x in r['api']['symbols']]}
            return c
        compared = request(prefix+'/compare',{'old':comparison(before),'new':comparison(failed)})
        assert compared['changes']
        (output/'compare.json').write_text(json.dumps(compared,ensure_ascii=False,indent=2),encoding='utf-8')
        print('PASS: dual SDK, current/stale/failure/restore, export/rebuild, frozen history, compare', flush=True)
    finally:
        (output/'summary.json').write_text(json.dumps(outcomes,indent=2),encoding='utf-8')
        print('Evidence: '+str(output), flush=True)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
