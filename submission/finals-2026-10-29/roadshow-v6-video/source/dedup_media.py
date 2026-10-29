"""Merge byte-identical image parts; preserve every image's original bytes."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib, posixpath, sys
import xml.etree.ElementTree as ET
source, output=map(Path,sys.argv[1:])
assert source!=output and not output.exists()
with ZipFile(source) as z:
 contents={name:z.read(name) for name in z.namelist()}
 seen={}; duplicates={}
 for name,data in contents.items():
  if name.startswith('ppt/media/'):
   key=(hashlib.sha256(data).hexdigest(),Path(name).suffix)
   if key in seen:duplicates[name]=seen[key]
   else:seen[key]=name
 for name,data in list(contents.items()):
  if not name.endswith('.rels'):continue
  doc=ET.fromstring(data);changed=False;base=posixpath.dirname(posixpath.dirname(name))
  for rel in doc:
   if rel.get('TargetMode')=='External':continue
   target=rel.get('Target',''); full=posixpath.normpath(posixpath.join(base,target)) if not target.startswith('/') else target[1:]
   if full in duplicates:
    rel.set('Target',posixpath.relpath(duplicates[full],base or '.'));changed=True
  if changed:contents[name]=ET.tostring(doc,encoding='utf-8',xml_declaration=True)
 doc=ET.fromstring(contents['[Content_Types].xml']);changed=False
 for child in list(doc):
  if child.get('PartName','').lstrip('/') in duplicates:doc.remove(child);changed=True
 if changed:contents['[Content_Types].xml']=ET.tostring(doc,encoding='utf-8',xml_declaration=True)
 for name in duplicates:del contents[name]
 with ZipFile(output,'w',ZIP_DEFLATED,compresslevel=6) as result:
  for name,data in contents.items():result.writestr(name,data)
print(f'Merged {len(duplicates)} byte-identical image parts: {source.stat().st_size} -> {output.stat().st_size} bytes')
