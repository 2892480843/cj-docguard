from pathlib import Path
import json,re,subprocess,math,os,shutil,sys
p=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent.parent/'video'
ff=os.environ.get('FFMPEG') or shutil.which('ffmpeg');probe=os.environ.get('FFPROBE') or shutil.which('ffprobe');assert ff and probe
c=json.loads((p/'chapters.json').read_text())
c[1]['cuts']=[[11.4,9],[218,9]];c[3]['cuts']=[[93,7],[103,17]];c[5]['cuts']=[[169,7],[184,13]];c[6]['cuts']=[[229,8]]
(p/'chapters.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
def run(args):subprocess.run([str(x) for x in args],check=True,stdout=subprocess.DEVNULL)
def seconds(t):
 h,m,s=t.replace(',','.').split(':');return int(h)*3600+int(m)*60+float(s)
def ass_time(t):
 x=round(t*100);return f'{x//360000}:{x//6000%60:02}:{x//100%60:02}.{x%100:02}'
def srt_time(t):
 x=round(t*1000);return f'{x//3600000:02}:{x//60000%60:02}:{x//1000%60:02},{x%1000:03}'
head='''[Script Info]
Title: CJ-DocGuard 系统介绍
ScriptType: v4.00+
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes
WrapStyle: 2

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Subtitle,Source Han Sans SC,42,&H00FFFFFF,&H0000FFFF,&H0025201B,&H90000000,-1,0,0,0,100,100,0,0,1,0,0,2,200,200,35,1
Style: Chapter,Ma Shan Zheng,40,&H00363026,&H0000FFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1
Style: Brand,Chalkboard SE,27,&H006A7067,&H0000FFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,9,0,0,0,1
Style: Draw,Source Han Sans SC,20,&H002D2722,&H0000FFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,7,0,0,0,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
'''
events=[];cues=[]
def event(layer,a,b,style,text):events.append(f'Dialogue: {layer},{ass_time(a)},{ass_time(b)},{style},,0,0,0,,{text}')
pastels=['&HC7E7D6&','&HCCE7FF&','&HE9D8E3&','&HD7EBC6&','&HCBD8F3&','&HE5E0CB&','&HC7E7D6&']
for i,ch in enumerate(c):
 a=ch['start'];b=a+ch['seconds'];voice=p/f"voice-{ch['id']}.mp3"
 d=float(subprocess.check_output([probe,'-v','error','-show_entries','format=duration','-of','csv=p=0',str(voice)]))
 assert d+.4 <ch['seconds'],(ch['id'],d)
 ch['voice_duration']=d;ch['voice_offset']=.35
 raw=(p/f"voice-{ch['id']}.srt").read_text(); words=[];text=ch['text'];pos=0
 for block in raw.strip().split('\n\n'):
  lines=block.splitlines()
  if len(lines)<3:continue
  ta,tb=lines[1].split(' --> ');word=''.join(lines[2:]);idx=text.find(word,pos)
  if idx<0:raise ValueError((word,text[pos:]))
  end=idx+len(word)
  while end<len(text) and text[end] in '，。！？；：、,.!?;:':end+=1
  words.append([a+.35+seconds(ta),a+.35+seconds(tb),text[idx:end]]);pos=end
 assert pos==len(text),(pos,len(text))
 group=[]
 for wi,w in enumerate(words):
  group.append(w);joined=''.join(x[2] for x in group)
  islast=wi==len(words)-1
  if joined[-1:] in '。！？' or len(joined)>=22 or (len(joined)>=12 and joined[-1:] in '，；：') or islast:
   st=group[0][0];en=min(b-.15,group[-1][1]+.25)
   if not islast:en=min(en,words[wi+1][0]-.03)
   cues.append([st,en,joined]);group=[]
 # Editorial chapter tab, hand marker underline, and quiet progress rail.
 color=pastels[i]
 event(0,a,b,'Draw',r'{\an7\pos(34,18)\1c'+color+r'\p1}m 0 6 l 718 0 724 47 4 52 c')
 event(1,a,b,'Chapter',r'{\an7\pos(54,24)\fad(160,120)}'+ch['id']+'  '+ch['title'])
 event(1,a,b,'Brand',r'{\an9\pos(1870,28)}CJ-DocGuard / 02:00')
 event(0,a,b,'Draw',r'{\an7\pos(38,1068)\1c&HDBDDD0&\p1}m 0 0 l 1844 0 1844 5 0 5 c')
 # A segment marker denotes chapters, not a fabricated application progress percentage.
 for j in range(i+1):event(1,a,b,'Draw',r'{\an7\pos('+str(38+j*264)+r',1068)\1c&H7B6B51&\p1}m 0 0 l 248 0 248 5 0 5 c')
 # Chapter-specific annotation is deliberately outside the product's controls.
 labels=['本地网页工作台','声明  ·  参数  ·  返回类型','26 运行通过  /  2 仅编译','当前输入变化后需要重测','预置坏链 × 2  /  外链未确认','同一 SDK 与平台','仓颉核心与本地服务']
 event(1,a+.25,b-.25,'Chapter',r'{\an9\pos(1865,54)\fs24\1c&H8A6552&\fad(180,120)}'+labels[i])
# Subtitle background follows utterances instead of covering the UI during pauses.
keywords=['运行通过','仅编译','四十二','有效记录','重新测试','旧成功','预置坏链','未确认','导出成功','仓颉']
for st,en,tx in cues:
 event(2,st,en,'Draw',r'{\an7\pos(220,973)\1c&H302925&\alpha&H18&\p1}m 18 0 l 1462 0 b 1474 0 1480 6 1480 18 l 1480 64 b 1480 76 1474 82 1462 82 l 18 82 b 6 82 0 76 0 64 l 0 18 b 0 6 6 0 18 0 c')
 styled=tx
 for kw in keywords:styled=styled.replace(kw,r'{\1c&H9BEEFF&}'+kw+r'{\1c&HFFFFFF&}')
 event(3,st,en,'Subtitle',r'{\an2\pos(960,1040)\fad(100,100)}'+styled)
(p/'subtitles.ass').write_text(head+'\n'.join(events)+'\n',encoding='utf-8')
(p/'subtitles.srt').write_text('\n\n'.join(f'{i+1}\n{srt_time(st)} --> {srt_time(en)}\n{tx}' for i,(st,en,tx) in enumerate(cues))+'\n',encoding='utf-8')
(p/'chapters.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n')
# Native recording excerpts preserve their original 60 Hz timebase and actual UI motion.
clips=[]
for ch in c:
 for k,(st,dur) in enumerate(ch['cuts']):
  out=p/f"clip-{ch['id']}-{k}.mp4";clips.append(out)
  if not out.exists():run([ff,'-y','-hide_banner','-loglevel','error','-ss',st,'-i',p/'system-raw.mp4','-t',dur,'-an','-c:v','libx264','-preset','veryfast','-crf','18','-pix_fmt','yuv420p','-r','60','-fps_mode','cfr',out])
(p/'concat.txt').write_text(''.join("file '"+str(x)+"'\n" for x in clips))
run([ff,'-y','-hide_banner','-loglevel','error','-f','concat','-safe','0','-i',p/'concat.txt','-c','copy',p/'edited-raw.mp4'])
# Voice is generated after capture, then placed without pitch or speed changes.
args=[ff,'-y','-hide_banner','-loglevel','error']
for ch in c:args+=['-i',p/f"voice-{ch['id']}.mp3"]
filters=[]
for i,ch in enumerate(c):filters.append(f'[{i}:a]aresample=48000,adelay={round((ch["start"]+.35)*1000)}:all=1[a{i}]')
filters.append(''.join(f'[a{i}]' for i in range(len(c)))+f'amix=inputs={len(c)}:normalize=0,apad,atrim=0:120,loudnorm=I=-16:TP=-1.2:LRA=9[a]')
run(args+['-filter_complex',';'.join(filters),'-map','[a]','-ar','48000','-ac','2','-c:a','pcm_s16le',p/'narration.wav'])
# Compose a notebook frame; crop excludes browser chrome and all unrelated tabs.
fc="[0:v]crop=1920:978:0:0,scale=1848:942:flags=lanczos[screen];color=c=0xf9f5e9:s=1920x1080:r=60:d=120,drawgrid=w=40:h=40:t=1:c=0xcbd5c8@0.4[paper];[paper][screen]overlay=36:80,ass=filename="+str(p/'subtitles.ass')+':fontsdir='+os.environ.get('DOCGUARD_VIDEO_FONTS',str(Path.home()/'Library/Fonts'))+',format=yuv420p[v]'
run([ff,'-y','-hide_banner','-loglevel','error','-i',p/'edited-raw.mp4','-i',p/'narration.wav','-filter_complex',fc,'-map','[v]','-map','1:a','-t','120','-frames:v','7200','-r','60','-fps_mode','cfr','-c:v','libx264','-preset','fast','-crf','19','-profile:v','high','-level','4.2','-c:a','aac','-b:a','192k','-movflags','+faststart',p/'CJ-DocGuard-系统介绍-2分钟-1080p60.mp4'])
print('VIDEO_COMPLETE',flush=True)
