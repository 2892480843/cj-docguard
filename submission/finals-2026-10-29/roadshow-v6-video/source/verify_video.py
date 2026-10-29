from pathlib import Path
import subprocess,json,hashlib,os,shutil,sys
p=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent.parent/'video';f=p.parent/'output/CJ-DocGuard-系统介绍-2分钟-1080p60.mp4';probe=os.environ.get('FFPROBE') or shutil.which('ffprobe');ff=os.environ.get('FFMPEG') or shutil.which('ffmpeg');assert ff and probe
info=json.loads(subprocess.check_output([probe,'-v','error','-count_frames','-show_streams','-show_format','-of','json',str(f)]))
v=next(x for x in info['streams'] if x['codec_type']=='video');a=next(x for x in info['streams'] if x['codec_type']=='audio')
assert (v['width'],v['height'],v['avg_frame_rate'],v['r_frame_rate'],v['nb_read_frames'])==(1920,1080,'60/1','60/1','7200')
assert abs(float(v['duration'])-120)<.001 and a['codec_name']=='aac'
pts=json.loads(subprocess.check_output([probe,'-v','error','-select_streams','v:0','-show_frames','-show_entries','frame=best_effort_timestamp_time','-of','json',str(f)]))['frames'];ts=[float(x['best_effort_timestamp_time']) for x in pts];d=[ts[i+1]-ts[i] for i in range(len(ts)-1)];assert len(ts)==7200 and max(abs(x-1/60) for x in d)<.000002
raw=json.loads((p/'recording.json').read_text());speech=[json.loads(x.read_text()) for x in sorted(p.glob('voice-*.json'))];assert all(x['synth_started_at']>raw['completed_at'] for x in speech)
c=json.loads((p/'chapters.json').read_text());assert sum(x['seconds'] for x in c)==120
text=''.join(x['text'] for x in c)
assert not any(w in text for w in ['评委','评审','评分','打分','得分','演示','初赛','证据'])
subprocess.run([ff,'-hide_banner','-loglevel','error','-i',str(f),'-f','null','-'],check=True)
result={'file':f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'duration_seconds':120,'width':1920,'height':1080,'video_codec':v['codec_name'],'audio_codec':a['codec_name'],'pixel_format':v['pix_fmt'],'fps':'60/1','decoded_frames':7200,'frame_interval_min':min(d),'frame_interval_max':max(d),'full_decode':'pass','raw_capture':raw,'record_before_voice':True,'voice':'zh-CN-XiaoyiNeural','voice_rate':'+0%','voice_pitch':'+0Hz','chapters':len(c),'subtitle_cues':(p/'subtitles.srt').read_text().count(' --> '),'note':'原生窗口按60Hz采集并以固定时钟编码。静态画面保留上一帧，不声称静态页面每秒产生60个不同画面。两分钟从四分钟真实录屏剪辑，未加速操作。'}
(p.parent/'checks/video-checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False,indent=2))
