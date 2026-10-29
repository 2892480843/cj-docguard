"""Attach a native embedded MP4 to the authored slide-4 poster.

Package shape and media relationships follow Microsoft Learn's PresentationML
video example. No external media URL is required for playback.
"""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib,sys
from lxml import etree as E
source,video,output=map(Path,sys.argv[1:]);assert source!=output and not output.exists()
P='http://schemas.openxmlformats.org/presentationml/2006/main';A='http://schemas.openxmlformats.org/drawingml/2006/main';R='http://schemas.openxmlformats.org/officeDocument/2006/relationships';P14='http://schemas.microsoft.com/office/powerpoint/2010/main';REL='http://schemas.openxmlformats.org/package/2006/relationships';CT='http://schemas.openxmlformats.org/package/2006/content-types'
ns={'p':P,'a':A,'r':R};q=lambda n,t:f'{{{n}}}{t}'
with ZipFile(source) as z:parts={x:z.read(x) for x in z.namelist()}
slide=E.fromstring(parts['ppt/slides/slide4.xml'])
posters=slide.xpath('//p:pic[p:nvPicPr/p:cNvPr[@descr="video-poster.png" or @name="CJ-DocGuard-System-Video"]]',namespaces=ns)
# Image names are not exported by every runtime revision; the 1024x576 frame is unique.
if not posters:
 posters=[pic for pic in slide.findall('.//'+q(P,'pic')) if pic.find('.//'+q(A,'ext')) is not None and pic.find('.//'+q(A,'ext')).get('cx')=='9753600']
assert len(posters)==1,len(posters)
pic=posters[0];nv=pic.find(q(P,'nvPicPr'));cnv=nv.find(q(P,'cNvPr'));spid=cnv.get('id');cnv.set('name','CJ-DocGuard 系统介绍（02:00）');cnv.set('descr','真实网页操作，含中文配音和字幕，点击播放。')
E.SubElement(cnv,q(A,'hlinkClick'),{'action':'ppaction://media'})
app=nv.find(q(P,'nvPr'))
E.SubElement(app,q(A,'videoFile'),{q(R,'link'):'rIdDocGuardVideo'})
lst=E.SubElement(app,q(P,'extLst'));ext=E.SubElement(lst,q(P,'ext'),{'uri':'{DAA4B4D4-6D71-4841-9C94-3DE7FCFB9230}'})
E.SubElement(ext,q(P14,'media'),{q(R,'embed'):'rIdDocGuardMedia'},nsmap={'p14':P14})
rels=E.fromstring(parts['ppt/slides/_rels/slide4.xml.rels'])
for rid,typ in [('rIdDocGuardVideo',R+'/video'),('rIdDocGuardMedia','http://schemas.microsoft.com/office/2007/relationships/media')]:E.SubElement(rels,q(REL,'Relationship'),{'Id':rid,'Type':typ,'Target':'../media/cj-docguard-system-intro.mp4'})
assert slide.find(q(P,'timing')) is None
# Indefinite start uses the native media click action; no automatic narration over the speaker.
timing=E.SubElement(slide,q(P,'timing'));tn=E.SubElement(timing,q(P,'tnLst'));par=E.SubElement(tn,q(P,'par'));root=E.SubElement(par,q(P,'cTn'),{'id':'1','dur':'indefinite','restart':'never','nodeType':'tmRoot'});children=E.SubElement(root,q(P,'childTnLst'));v=E.SubElement(children,q(P,'video'),{'fullScrn':'0'});media=E.SubElement(v,q(P,'cMediaNode'),{'vol':'100000','showWhenStopped':'0'});ctn=E.SubElement(media,q(P,'cTn'),{'id':'2','fill':'remove','display':'0'});conditions=E.SubElement(ctn,q(P,'stCondLst'));E.SubElement(conditions,q(P,'cond'),{'delay':'indefinite'});target=E.SubElement(media,q(P,'tgtEl'));E.SubElement(target,q(P,'spTgt'),{'spid':spid})
content=E.fromstring(parts['[Content_Types].xml'])
if not any(x.get('Extension')=='mp4' for x in content):E.SubElement(content,q(CT,'Default'),{'Extension':'mp4','ContentType':'video/mp4'})
parts['ppt/slides/slide4.xml']=E.tostring(slide,xml_declaration=True,encoding='UTF-8',standalone=True);parts['ppt/slides/_rels/slide4.xml.rels']=E.tostring(rels,xml_declaration=True,encoding='UTF-8',standalone=True);parts['[Content_Types].xml']=E.tostring(content,xml_declaration=True,encoding='UTF-8',standalone=True);parts['ppt/media/cj-docguard-system-intro.mp4']=video.read_bytes()
with ZipFile(output,'w',ZIP_DEFLATED,compresslevel=6) as z:
 for n,data in parts.items():z.writestr(n,data)
print('Embedded native MP4',len(parts['ppt/media/cj-docguard-system-intro.mp4']),'bytes','shape',spid,'sha256',hashlib.sha256(video.read_bytes()).hexdigest())
