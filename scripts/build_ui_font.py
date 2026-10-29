#!/usr/bin/env python3
"""Build the bundled UI font from a pinned OFL font; requires fonttools[woff]."""
from pathlib import Path
import hashlib
import json
import urllib.request
from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
COMMIT = '9862abc066c9b83bf84c3e8ed1fc2d8d48f9bbf0'
EXPECTED_SOURCE_SHA256 = 'a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da'
BASE = f'https://raw.githubusercontent.com/google/fonts/{COMMIT}/ofl/notosanssc/'
cache = ROOT / 'build/ui-font-source'
output = ROOT / 'web/assets/fonts'
cache.mkdir(parents=True, exist_ok=True)
output.mkdir(parents=True, exist_ok=True)
font_path = cache / 'NotoSansSC-VF.ttf'
if not font_path.exists():
    with urllib.request.urlopen(BASE + 'NotoSansSC%5Bwght%5D.ttf', timeout=90) as response:
        font_path.write_bytes(response.read())
if hashlib.sha256(font_path.read_bytes()).hexdigest() != EXPECTED_SOURCE_SHA256:
    raise SystemExit('Font source checksum mismatch; remove the cached file and retry.')
with urllib.request.urlopen(BASE + 'OFL.txt', timeout=30) as response:
    license_text = response.read().decode('utf-8')
    (output / 'OFL.txt').write_text('\n'.join(line.rstrip() for line in license_text.splitlines()) + '\n', encoding='utf8')
characters = set(range(0x20, 0x250))
for lead in range(0xA1, 0xF8):
    for trail in range(0xA1, 0xFF):
        try:
            characters.update(map(ord, bytes([lead, trail]).decode('gb2312')))
        except UnicodeDecodeError:
            pass
for lo, hi in [(0x2000, 0x2070), (0x2300, 0x2800), (0x3000, 0x3040), (0xFF00, 0xFFF0)]:
    characters.update(range(lo, hi))
font = TTFont(font_path)
options = subset.Options()
options.flavor = 'woff2'
options.layout_features = ['*']
options.name_IDs = ['*']
options.name_languages = ['*']
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=characters)
subsetter.subset(font)
# Give the derived UI font its own primary family while retaining the OFL notice.
values = {1: 'DocGuard Sans SC', 2: 'Regular', 3: 'DocGuardSansSC-UI-1',
          4: 'DocGuard Sans SC UI', 6: 'DocGuardSansSC-UI',
          16: 'DocGuard Sans SC', 17: 'Regular'}
for record in list(font['name'].names):
    if record.nameID in values:
        font['name'].setName(values[record.nameID], record.nameID,
                             record.platformID, record.platEncID, record.langID)
font.flavor = 'woff2'
destination = output / 'docguard-sans-sc.woff2'
font.save(destination)
record = {'source': 'Google Fonts / Noto Sans SC', 'commit': COMMIT,
          'source_url': BASE + 'NotoSansSC%5Bwght%5D.ttf',
          'license_url': BASE + 'OFL.txt', 'license': 'SIL OFL 1.1',
          'source_sha256': hashlib.sha256(font_path.read_bytes()).hexdigest(),
          'output_sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
          'bytes': destination.stat().st_size,
          'modifications': 'GB2312, Latin and punctuation subset; renamed primary family DocGuard Sans SC; variable weights retained',
          'glyphs': len(font.getGlyphOrder()),
          'fonttools': __import__('fontTools').version}
(output / 'provenance.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf8')
print(json.dumps(record, indent=2))
