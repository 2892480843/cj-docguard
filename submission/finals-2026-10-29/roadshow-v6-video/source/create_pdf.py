"""Create the static handout from the imported final deck's rendered pages."""
from pathlib import Path
from reportlab import rl_config
rl_config.useA85=0
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from pypdf import PdfReader
b=Path('build/finals-ppt-video');out=b/'validated/video-static.pdf'
c=canvas.Canvas(str(out),pagesize=(960,540),pageCompression=1)
c.setTitle('CJ-DocGuard 决赛答辩 · 手写视频版（静态阅读）');c.setAuthor('CJ-DocGuard')
for n in range(1,15):
 c.drawImage(ImageReader(str(b/f'final-render/slide-{n}.png')),0,0,960,540);c.showPage()
c.save();assert len(PdfReader(out).pages)==14
print('PDF pages: 14; bytes:',out.stat().st_size)
