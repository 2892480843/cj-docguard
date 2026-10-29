"""Create a poster from a real frame; never substitute the poster for the video."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import sys
frame,output,fonts=map(Path,sys.argv[1:])
im=Image.open(frame).convert('RGBA');layer=Image.new('RGBA',im.size);d=ImageDraw.Draw(layer)
d.rounded_rectangle((510,350,1410,715),radius=26,fill=(28,35,40,220),outline=(239,230,199,255),width=4)
d.ellipse((875,380,1045,550),fill=(248,240,216,255));d.polygon([(941,423),(941,508),(1008,465)],fill=(61,102,82,255))
f=ImageFont.truetype(str(fonts/'MaShanZheng-Regular.ttf'),58);g=ImageFont.truetype(str(fonts/'SourceHanSansSC-Regular.otf'),32)
d.text((960,567),'系统介绍',font=f,anchor='mt',fill='white');d.text((960,647),'点击播放  ·  02:00',font=g,anchor='mt',fill=(244,223,145,255))
Image.alpha_composite(im,layer).convert('RGB').save(output)
