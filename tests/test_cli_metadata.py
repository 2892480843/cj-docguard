"""Native diff/archive/doctor checks; report mutations are labelled test fixtures."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('dev',ROOT/'scripts/dev.py')
dev=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(dev)

class MetadataTests(unittest.TestCase):
    def invoke(self,*args):
        r=subprocess.run([str(ROOT/'build/cj-docguard'),*map(str,args)],env=dev.sdk_env('1.1.3'),capture_output=True,text=True,timeout=90)
        self.assertEqual(r.returncode,0,r.stdout+r.stderr)
        return json.loads(r.stdout)

    def test_diff_and_frozen_history_are_explicit(self):
        # Synthetic minimal report fixture, never used as execution evidence.
        old={'manifest':{'fingerprint':'old'},'summary':{'TOTAL':1},'api':{'symbols':[{'id':'old-symbol'}]},'results':[{'example_id':'x','sdk_version':'1.1.3','status':'RUN_FAILED','freshness':'CURRENT'}], 'history':[{'example_id':'x','sdk_version':'1.1.3','status':'RUN_VERIFIED'}]}
        new={'manifest':{'fingerprint':'new'},'summary':{'TOTAL':0},'api':{'symbols':[{'id':'new-symbol'}]},'results':[],'history':[]}
        with tempfile.TemporaryDirectory() as t:
            a=Path(t)/'old.json';b=Path(t)/'new.json'
            a.write_text(json.dumps(old));b.write_text(json.dumps(new))
            diff=self.invoke('diff','--old',a,'--new',b)
            self.assertEqual(diff['symbols_added'],[{'id':'new-symbol'}])
            self.assertEqual(diff['symbols_removed'],[{'id':'old-symbol'}])
            self.assertIsNone(diff['changes'][0]['after'])
            archive=self.invoke('history','--report',a,'--example','x')
            self.assertEqual(archive['scope'],'FROZEN_ARCHIVE_NOT_CURRENT')
            self.assertEqual(archive['items'][0]['freshness'],'FROZEN')
            self.assertFalse(archive['items'][0]['eligible'])

    def test_real_doctor_probes_both_package_managers(self):
        config=ROOT/'examples/healthy/docguard.toml'
        report=self.invoke('doctor','--config',config)
        self.assertEqual(len(report['package_managers']),2)
        for e in report['environments']:
            self.assertTrue(e['available'])
            self.assertEqual(e['version'],e['declared_version'])
        for manager in report['package_managers']:
            self.assertTrue(manager['available'])
            self.assertEqual(manager['exit_code'],0)
            self.assertTrue(manager['stdout'].strip())
