#!/usr/bin/env python3
"""Check generated HTML structure and optionally run its search script in Node VM.

This is a structural/script check, not a browser or visual-layout check.
"""
import argparse
from html.parser import HTMLParser
import json
from pathlib import Path
import subprocess


class Site(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
        self.ids = []
        self.hrefs = []
        self.cards = []
        self.scripts = []
        self.in_script = False

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if attrs.get('id'):
            self.ids.append(attrs['id'])
        if attrs.get('href'):
            self.hrefs.append(attrs['href'])
        if 'api-card' in attrs.get('class', '').split():
            self.cards.append({'in_api': any(a.get('id') == 'api-list' for _, a in self.stack),
                               'dataset': {k[5:]: v for k, v in attrs.items() if k.startswith('data-')},
                               'hidden': 'hidden' in attrs})
        if tag == 'script':
            if attrs.get('src'):
                raise ValueError('external script in offline report')
            self.in_script = True
            self.scripts.append('')
        if tag in {'link', 'img', 'iframe'} and (attrs.get('src') or attrs.get('href')):
            raise ValueError('unexpected external resource element')
        if tag not in {'meta', 'input', 'br', 'hr', 'img', 'link', 'source', 'wbr'}:
            self.stack.append((tag, attrs))

    def handle_endtag(self, tag):
        if tag == 'script':
            self.in_script = False
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break

    def handle_data(self, text):
        if self.in_script:
            self.scripts[-1] += text


NODE_CHECK = r"""
const fs=require('fs'),vm=require('vm');
const data=JSON.parse(fs.readFileSync(0,'utf8'));
const cards=data.cards, api=cards.filter(c=>c.in_api), source=cards.filter(c=>!c.in_api);
let callback;const input={value:'',addEventListener:(e,fn)=>{callback=fn}};
const count={textContent:''},empty={hidden:true};
const nodes={'api-search':input,'search-count':count,'search-empty':empty};
const document={getElementById:id=>nodes[id],querySelectorAll:selector=>{
  if(selector==='.api-card')return cards;
  if(selector==='#api-list .api-card')return api;
  throw Error('unexpected selector');
}};
function check(ok,msg){if(!ok)throw Error(msg)}
vm.runInNewContext(data.script,{document},{timeout:1000});
check(count.textContent===api.length+' / '+api.length+' 个接口','source cards counted as APIs');
for(const q of [api[0].dataset.name,api[0].dataset.package.toUpperCase(),'  '+api[0].dataset.name+'  ']){
  input.value=q;callback();check(!api[0].hidden,'name/package/case/trim match failed');
}
input.value='__docguard_no_match_9e072__';callback();
check(api.every(c=>c.hidden)&&!empty.hidden,'no-match state failed');
check(source.every(c=>!c.hidden),'API search hid source anchors');
input.value='';callback();
check(api.every(c=>!c.hidden)&&source.every(c=>!c.hidden),'clear did not restore interface cards');
check(count.textContent===api.length+' / '+api.length+' 个接口','incorrect restored count');
console.log(JSON.stringify({api_cards:api.length,source_cards:source.length,search_script_passed:true}));
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path)
    parser.add_argument('--node', type=Path, help='explicit Node executable for isolated script checks')
    args = parser.parse_args()
    site = Site()
    site.feed(args.file.read_text(encoding='utf-8'))
    if len(site.ids) != len(set(site.ids)):
        raise ValueError('duplicate report IDs')
    if len(site.scripts) != 1:
        raise ValueError('expected exactly one embedded search script')
    for target in site.hrefs:
        if target.startswith('#'):
            if target[1:] not in site.ids:
                raise ValueError('missing anchor: ' + target)
        elif ':' in target:
            raise ValueError('unexpected URL in offline generated site: ' + target)
        elif not (args.file.parent / target).is_file():
            raise ValueError('missing artifact link: ' + target)
    api = [card for card in site.cards if card['in_api']]
    if not api:
        raise ValueError('no API cards; use a generated source fixture')
    outcome = {'ids': len(site.ids), 'links': len(site.hrefs), 'api_cards': len(api),
               'source_cards': len(site.cards) - len(api), 'search_script_passed': False,
               'browser_visual_check': 'NOT_PERFORMED'}
    if args.node:
        result = subprocess.run([str(args.node.resolve()), '-e', NODE_CHECK],
                                input=json.dumps({'cards': site.cards, 'script': site.scripts[0]}),
                                capture_output=True, text=True, timeout=10)
        if result.returncode:
            raise ValueError(result.stderr)
        outcome.update(json.loads(result.stdout))
    print(json.dumps(outcome, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
