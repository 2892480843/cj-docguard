import asyncio,json,time,sys
from pathlib import Path
import edge_tts
p=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parent.parent/'video'
async def main():
    assert (p/'recording.json').exists(), 'Record first, then synthesize voice'
    stats=json.loads((p/'recording.json').read_text())
    assert stats['writer_status']==2
    sem=asyncio.Semaphore(3)
    async def make(c):
        async with sem:
            if (p/f"voice-{c['id']}.txt").exists() and (p/f"voice-{c['id']}.txt").read_text()==c['text']:return
            sub=edge_tts.SubMaker()
            (p/f"voice-{c['id']}.txt").write_text(c['text'],encoding='utf-8')
            log={'voice':'zh-CN-XiaoyiNeural','rate':'+0%','pitch':'+0Hz','synth_started_at':time.time(),'raw_completed_at':stats['completed_at']}
            assert log['synth_started_at']>log['raw_completed_at']
            with (p/f"voice-{c['id']}.mp3").open('wb') as f:
                async for chunk in edge_tts.Communicate(c['text'],'zh-CN-XiaoyiNeural',rate='+0%',pitch='+0Hz',boundary='WordBoundary').stream():
                    if chunk['type']=='audio':f.write(chunk['data'])
                    elif chunk['type']=='WordBoundary':sub.feed(chunk)
            (p/f"voice-{c['id']}.srt").write_text(sub.get_srt(),encoding='utf-8')
            (p/f"voice-{c['id']}.json").write_text(json.dumps(log,indent=2),encoding='utf-8')
            print('SYNTHESIZED',c['id'],flush=True)
    await asyncio.gather(*(make(c) for c in json.loads((p/'chapters.json').read_text())))
asyncio.run(main())
