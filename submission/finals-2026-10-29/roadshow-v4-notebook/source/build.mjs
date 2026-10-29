import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
const runtimeModules=process.env.RUNTIME_NODE_MODULES;
const {Presentation,PresentationFile}=await import(pathToFileURL(path.join(runtimeModules,'@oai/artifact-tool/dist/artifact_tool.mjs')).href);
const root=process.cwd(),out=path.join(root,'submission/finals-2026-10-29/roadshow-v4-notebook'),build=path.join(root,'build/finals-ppt-notebook');
const skill=process.env.PRESENTATIONS_SKILL_DIR||'/Users/a111/.codex/plugins/cache/openai-primary-runtime/presentations/26.1020.11618/skills/presentations';
const py=process.env.PRESENTATIONS_PYTHON||'/Users/a111/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3';
const {finalizePresentation,applyPresentationChartFont}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const content=JSON.parse(await fs.readFile(path.join(out,'content.json'),'utf8')),facts=JSON.parse(await fs.readFile(path.join(out,'facts.json'),'utf8'));
const H='Ma Shan Zheng',L='Chalkboard SE',CODE='Source Han Sans SC';
const C={paper:'#faf6eb',ink:'#2a302d',muted:'#626b67',blue:'#28638c',green:'#397b60',yellow:'#fff09b',mint:'#deedda',pink:'#f6d2bf',red:'#aa554b',line:'#8c9385',white:'#fffdf7'};
const p=Presentation.create({slideSize:{width:1280,height:720}});p.theme.defaultFont=H;
p.theme.colorScheme={name:'Notebook Marker',themeColors:{accent1:C.blue,accent2:C.green,accent3:'#d89e38',accent4:C.red,accent5:'#8d9d86',accent6:'#77654f',bg1:C.paper,bg2:C.white,tx1:C.ink,tx2:C.muted,dk1:'#000000',dk2:C.ink,lt1:'#ffffff',lt2:C.paper,hlink:C.blue,folHlink:C.green}};
const assets={};for(const name of ['graph-paper.png','api.png','export.png','links.png'])assets[name]=new Uint8Array(await fs.readFile(path.join(out,'assets',name)));
const line=(fill=C.ink,width=3)=>({fill,width,style:'solid'});
function rect(s,x,y,w,h,fill='none',stroke='none',width=0){return s.shapes.add({geometry:'rect',position:{left:x,top:y,width:w,height:h},fill,line:line(stroke,width)});}
function text(s,t,x,y,w,h,size=30,color=C.ink,font=H,bold=false,align='left'){
 const z=s.shapes.add({geometry:'textbox',name:String(t).slice(0,50),position:{left:x,top:y,width:w,height:h},fill:'none',line:line('none',0)});z.text=t;z.text.style={typeface:font,fontSize:size,color,bold,alignment:align,verticalAlignment:'top',insets:0,autoFit:'none',wrap:'square'};return z;
}
function custom(s,x,y,w,h,commands,{fill='none',color=C.ink,width=3,name='手绘笔迹'}={}){return s.shapes.add({geometry:'custom',name,position:{left:x,top:y,width:w,height:h},fill,line:line(color,width),customPaths:[{width:w,height:h,commands}]});}
function rough(s,x,y,w,h,{fill='none',color=C.ink,width=2.5}={}){
 custom(s,x,y,w,h,[{moveTo:{x:4,y:3}},{cubicBezTo:{x1:w*.28,y1:0,x2:w*.68,y2:6,x:w-3,y:2}},{cubicBezTo:{x1:w+1,y1:h*.28,x2:w-4,y2:h*.75,x:w-1,y:h-3}},{cubicBezTo:{x1:w*.66,y1:h+1,x2:w*.29,y2:h-4,x:2,y:h-1}},{cubicBezTo:{x1:5,y1:h*.7,x2:0,y2:h*.3,x:4,y:3}},{close:{}}],{fill,color,width,name:'手绘纸面边框'});
 return rect(s,x,y,w,h);
}
function highlight(s,x,y,w,h,color=C.yellow){return custom(s,x,y,w,h,[{moveTo:{x:0,y:3}},{lineTo:{x:w-5,y:0}},{lineTo:{x:w,y:h-3}},{lineTo:{x:4,y:h}},{close:{}}],{fill:color,color:'none',width:0,name:'荧光笔高亮'});}
function underline(s,x,y,w,color=C.blue){return custom(s,x,y,w,8,[{moveTo:{x:1,y:4}},{cubicBezTo:{x1:w*.28,y1:0,x2:w*.63,y2:8,x:w-1,y:3}}],{color,width:3.4,name:'马克笔下划线'});}
function circle(s,x,y,w,h,color=C.blue){return custom(s,x,y,w,h,[{moveTo:{x:w*.6,y:4}},{cubicBezTo:{x1:w*.13,y1:-2,x2:-8,y2:h*.22,x:4,y:h*.54}},{cubicBezTo:{x1:0,y1:h*.9,x2:w*.48,y2:h+7,x:w*.81,y:h-4}},{cubicBezTo:{x1:w+8,y1:h*.9,x2:w+4,y2:h*.22,x:w*.78,y:5}},{cubicBezTo:{x1:w*.65,y1:0,x2:w*.42,y2:0,x:w*.28,y:8}}],{color,width:3.4,name:'手绘圈注'});}
function connector(s,a,b,fromSide='right',toSide='left',color=C.ink){
 const A=a.position,B=b.position;
 // Native editable freeform arrows keep the marker stroke visible in both the PPT and preview.
 if(fromSide==='bottom'){
  const h=B.top-A.top-A.height-9,x=A.left+A.width/2-13,y=A.top+A.height+4;
  return custom(s,x,y,26,h,[{moveTo:{x:12,y:1}},{cubicBezTo:{x1:15,y1:h*.28,x2:9,y2:h*.69,x:13,y:h-2}},{moveTo:{x:2,y:h-16}},{lineTo:{x:13,y:h-2}},{lineTo:{x:24,y:h-17}}],{color,width:3.4,name:'手绘向下流程箭头'});
 }
 const w=B.left-A.left-A.width-9,x=A.left+A.width+4,y=A.top+A.height/2-13;
 return custom(s,x,y,w,26,[{moveTo:{x:1,y:13}},{cubicBezTo:{x1:w*.27,y1:9,x2:w*.7,y2:16,x:w-2,y:12}},{moveTo:{x:w-17,y:2}},{lineTo:{x:w-2,y:12}},{lineTo:{x:w-17,y:24}}],{color,width:3.4,name:'手绘向右流程箭头'});
}
function picture(s,name,x,y,w,h,crop){return s.images.add({blob:assets[name],contentType:'image/png',alt:name==='graph-paper.png'?'生成的轻揉皱方格纸背景纹理':`当前功能源码068a22a的实际工作台截图：${name}`,position:{left:x,top:y,width:w,height:h},fit:name==='graph-paper.png'?'cover':'contain',...(crop?{crop}:{})});}
function base(n,title,sub){
 const s=p.slides.add();s.background.fill=C.paper;picture(s,'graph-paper.png',0,0,1280,720);
 text(s,'CJ-DocGuard / 决赛笔记',70,24,810,36,22,C.muted,H);
 text(s,n<=10?`${String(n).padStart(2,'0')} / 10`:`备查 ${n-10} / 4`,1070,28,138,34,22,C.muted,H,false,'right');
 if(title){highlight(s,66,109,Math.min(1145,title.length*37+34),23);text(s,title,70,67,1140,68,46,C.ink,H);if(sub)text(s,sub,73,146,1135,46,26,C.muted,H);}
 const d=content.slides[n-1];s.speakerNotes.text=`${n<=10?`主讲时段：${d.start}至${d.end}，${d.seconds}秒（包含现场操作）。\n`:''}${d.spoken}\n\n动作：${d.action}\n\n来源：${d.sources}\n\n视觉：底纹为图像生成的纸张纹理，不是产品运行记录；其余数据沿用当前功能源码068a22a。`;
 return s;
}
function note(s,x,y,w,h,title,body,{fill='none',color=C.ink,size=28}={}){const a=rough(s,x,y,w,h,{fill,color,width:2.7});text(s,title,x+20,y+18,w-40,43,32,color);if(body)text(s,body,x+20,y+75,w-40,h-87,size,C.muted);return a;}
function table(s,values,x,y,w,h,widths,font=28){
 const t=s.tables.add({rows:values.length,columns:values[0].length,left:x,top:y,width:w,height:h,columnWidths:widths,values});t.styleOptions={headerRow:true,bandedRows:false};t.borders.assign(line('#a6aa9a',1.2));
 for(let r=0;r<values.length;r++)for(let c=0;c<values[0].length;c++){const a=t.getCell(r,c);a.fill=r===0?'#f6e8a7':'#fffdf3e8';a.text.style={typeface:/^[\x00-\x7F]+$/.test(values[r][c])?L:H,fontSize:font,color:r===0?C.blue:C.ink,bold:false,verticalAlignment:'middle',insets:{left:17,right:12,top:10,bottom:10},wrap:'square',autoFit:'none'};}
 rough(s,x-2,y-2,w+4,h+4,{color:C.ink,width:2.1});return t;
}
function metric(s,val,label,x,y,w=220,color=C.blue){text(s,String(val),x,y,w,88,68,color,L);text(s,label,x,y+88,w+60,40,28,C.ink,H);}
function number(s,n,x,y,color=C.blue){circle(s,x,y,54,51,color);text(s,String(n),x+12,y+7,32,38,28,color,L);}
// 1: cover as a notebook spread, with editable title and meaningful paper doodles.
{
 const s=base(1);highlight(s,72,100,174,32);text(s,'决赛答辩',79,82,345,56,36,C.blue);
 text(s,'CJ-DocGuard',71,178,890,112,78,C.ink,L);
 text(s,'仓颉项目级 API\n文档生成及测试',74,303,760,148,50,C.ink);
 underline(s,74,455,652);
 text(s,'生成文档 → 运行示例 → 检查版本与链接',78,488,1090,52,32,C.muted);
 metric(s,47,'公共接口',82,570,260);metric(s,14,'登记示例',427,570,270);metric(s,2,'SDK 版本',796,570,260);
 const a=rough(s,953,221,226,172,{fill:'#fffdf4',color:C.blue,width:3});text(s,'API',1008,252,133,52,39,C.blue,L);underline(s,990,315,137);underline(s,990,342,104);circle(s,934,208,267,201,C.blue);
 text(s,'本地工作台',937,425,277,51,34,C.blue);
}
// 2: native table, with a hand-drawn outer frame.
{
 const d=content.slides[1],s=base(2,'赛题的三项交付','从网页入口，到真正生成和检查的内容');
 table(s,[['赛题交付','网页入口','实际产物 / 检查'],['结构化 API 文档','接口文档 / 源码编辑','声明、参数、返回类型\n关联示例与源码位置'],['示例正确性测试','示例测试 / 任务中心','真实编译、运行\n输出检查与执行记录'],['SDK 版本关系\n与索引链接测试','SDK 测试矩阵\n链接与问题','独立版本结果\n文件、锚点与来源']],74,221,1132,344,[310,315,507],28);
 highlight(s,75,603,675,25,C.mint);text(s,'三项能力，都能从工作台完整操作。',80,581,1040,61,35,C.green);
 text(s,'API：应用程序接口；SDK：仓颉编译器、运行库等开发工具。',80,656,1115,34,23,C.muted);
}
// 3: real API detail alongside editable declaration and handwritten annotations.
{
 const s=base(3,'接口说明与关联示例','检索 add，直接看到声明、参数、返回类型与来源');
 rough(s,74,219,503,191,{fill:C.white,color:C.blue});text(s,'add',96,233,433,45,34,C.blue,L);
 text(s,'public func add(\n  a: Int64, b: Int64\n): Int64',98,291,452,106,27,C.ink,CODE);
 text(s,'参数  a、b：Int64',86,444,491,51,32,C.ink);underline(s,81,487,393);
 text(s,'返回  Int64',86,509,491,48,32,C.ink);
 text(s,'关联示例',86,573,200,43,31,C.blue);text(s,'arithmetic / snippet-wrapper',86,620,516,40,25,C.muted,L);
 rect(s,634,212,573,446,C.white);picture(s,'api.png',645,224,549,421,{left:.414,top:.33,right:0,bottom:.08});rough(s,633,212,575,447,{color:C.ink,width:2.5});
}
// 4: a native flow and actual completed export, plus the precise environment.
{
 const s=base(4,'在网页完成一次查询与导出','现场操作约80秒：检索、查看矩阵、精确查询、下载 ZIP');
 const labels=[['检索接口','声明与示例'],['查看矩阵','区分结果状态'],['精确查询','指定 SDK / 平台'],['导出示例','检查后生成 ZIP']];
 const nodes=labels.map(([a,b],i)=>{let x=76+291*i;const z=rough(s,x,225,255,117,{fill:i===2?C.mint:'none',color:C.ink});text(s,a,x+15,242,227,43,32,i===2?C.green:C.ink);text(s,b,x+15,290,229,37,25,C.muted);return z;});nodes.slice(0,-1).forEach((x,i)=>connector(s,x,nodes[i+1]));
 picture(s,'export.png',75,391,706,290,{left:.14,top:.235,right:.14,bottom:.235});rough(s,75,391,706,290,{color:C.ink,width:2});
 text(s,'当前实际导出',833,402,375,45,34,C.blue);underline(s,830,452,297);
 text(s,'arithmetic\nSDK 1.2.0\nDarwin-arm64',837,478,370,119,29,C.ink,L);
 highlight(s,830,638,358,24,C.mint);text(s,'ZIP 下载已生成',842,618,363,46,31,C.green);
}
// 5: architecture in thick hand-drawn boxes and attached arrows.
{
 const s=base(5,'仓颉承担本地服务与核心处理','标准网页技术，连接原生编译与运行流程');
 const a=note(s,74,228,270,164,'浏览器页面','HTML / CSS\nJavaScript',{size:28});
 const b=note(s,414,228,310,164,'仓颉本地服务','HTTP、项目、配置\n任务与请求管理',{fill:C.yellow,color:C.ink,size:27});
 const c=note(s,793,228,413,164,'仓颉核心','声明提取、文档生成\n测试编排与结果判断',{size:28});connector(s,a,b);connector(s,b,c);
 const d=note(s,793,479,413,131,'真实仓颉工具链','SDK 1.1.3 / 1.2.0',{fill:C.mint,size:28});connector(s,c,d,'bottom','top');
 text(s,'std.ast 提取公共声明',78,453,675,45,34,C.blue);underline(s,76,502,563);
 text(s,'C：子进程监督与信号处理\nBash：构建与启动\nPython：测试和只读协议适配等辅助',79,530,694,133,29,C.muted);
}
// 6: exact same native chart values, now in a notebook palette.
{
 const s=base(6,'双 SDK：运行通过与仅编译分开','14 个登记示例 × 2 个 SDK，共28条当前记录');
 const rows=[...facts.by_sdk].reverse();const chart=s.charts.add('bar',{position:{left:74,top:214,width:772,height:281},categories:rows.map(x=>'SDK '+x.sdk),series:[{name:'运行通过',values:rows.map(x=>x.run_verified),fill:'#9fbaa5',line:line(C.green,2)},{name:'仅编译',values:rows.map(x=>x.compile_only),fill:'#efd18c',line:line('#a87630',2)}],hasLegend:true,legend:{position:'bottom',textStyle:{fontSize:25,fill:C.ink}},barOptions:{direction:'bar',grouping:'stacked',gapWidth:92,overlap:100},dataLabels:{showValue:true,position:'center',textStyle:{fontSize:28,fill:C.ink,bold:false}},xAxis:{textStyle:{fontSize:24,fill:C.ink},line:line('none',0)},yAxis:{min:0,max:14,majorUnit:2,textStyle:{fontSize:22,fill:C.muted},majorGridlines:line('#cbd2c3',1)},chartFill:'none',chartLine:line('none',0),plotAreaFill:'none',plotAreaLine:line('none',0)});applyPresentationChartFont(chart,{fontFamily:L});chart.legend.textStyle.typeface=H;
 metric(s,26,'条运行通过',926,227,255,C.green);circle(s,896,218,223,101,C.green);metric(s,2,'条仅编译',926,383,255,'#98682d');
 table(s,[['SDK 版本','运行通过','仅编译','合计'],...facts.by_sdk.map(x=>[x.sdk,String(x.run_verified),String(x.compile_only),String(x.total)])],75,523,1131,143,[337,273,247,274],27);
 text(s,'仅编译不计入运行通过；数量不代表全语言覆盖率。',80,681,1110,30,21,C.muted);
}
// 7: currentness is drawn as an input -> execution -> result note.
{
 const s=base(7,'什么结果，才算当前可用？','查询与导出遵循同一套判断规则');
 const a=note(s,74,221,306,151,'输入匹配','源码、配置\nSDK 与平台',{size:29});
 const b=note(s,455,221,307,151,'真实执行','编译、运行\n登记输出检查',{size:29});
 const c=note(s,837,221,368,151,'当前结果','精确查询和导出\n使用相同规则',{fill:C.mint,color:C.green,size:29});connector(s,a,b);connector(s,b,c);
 highlight(s,76,446,500,32);text(s,'源码变化 → 需重测',84,419,520,61,40,C.ink);text(s,'保留旧记录，重新测试后\n再判断当前结果。',85,500,504,91,32,C.muted);
 highlight(s,675,446,524,32,C.pink);text(s,'最新失败 → 不回退旧成功',681,419,527,65,36,C.ink);text(s,'历史成功不会覆盖后续失败，\n按相应环境的最新尝试判断。',684,500,521,96,31,C.muted);
 text(s,'历史记录用于追溯；输出检查只覆盖登记的受测行为。',82,650,1125,45,26,C.muted);
}
// 8: actual negative link fixture, not a made-up perfect score.
{
 const s=base(8,'链接出错，能找到哪一行、为什么','专项样例预置两处坏链，本轮已经重新检查');
 table(s,[['来源','原始目标','检查结果'],['README.md:13','docs/intentionally-missing.md','目标文件不存在'],['README.md:14','docs/target%20file.md\n#escaped-ghost','目标标题或锚点不存在']],76,226,1129,239,[244,516,369],27);
 metric(s,23,'条本地链接通过',94,511,370,C.green);metric(s,2,'处预置坏链被定位',519,511,380,C.red);circle(s,502,499,125,102,C.red);metric(s,1,'条外链未确认',951,511,235,'#98682d');
 text(s,'专项共26条；严格检查退出1，表示正确发现问题。',81,668,1125,35,26,C.muted);
}
// 9: final-current improvements, without preliminary data.
{
 const s=base(9,'决赛最新版，补齐操作与任务反馈','真实选项、实际进度，以及长期使用的工作区');
 number(s,1,78,229);text(s,'网页能完整操作',153,231,487,48,36,C.ink);text(s,'下拉选项对应真实配置；源码、\n配置、任务和导出都有入口。',154,301,485,102,30,C.muted);
 number(s,2,705,229,C.green);text(s,'任务状态清晰',779,231,426,48,36,C.ink);text(s,'排队 / 运行 / 结束\n运行通过 / 仅编译',780,301,426,102,31,C.muted);
 underline(s,81,436,1118,C.ink);
 number(s,3,78,481);text(s,'23 项服务回归',153,485,486,50,36,C.blue);text(s,'本版原生 HTTP 专项回归通过\n三档十页，共30次布局检查',154,554,485,101,29,C.muted);
 number(s,4,705,481,C.green);text(s,'739 条历史完整保留',779,485,427,51,35,C.green);text(s,'显式任务内存上限\n当前双 SDK 任务已完成',780,554,426,101,31,C.muted);
}
// 10: end of the seven-minute main talk.
{
 const s=base(10,'源码与说明，供评委复查','固定版本、明确前提，按说明启动');
 highlight(s,80,243,802,36);text(s,'按说明构建和启动工作台',86,211,1082,75,50,C.ink);
 rough(s,81,326,1119,169,{fill:C.white,color:C.ink});text(s,'功能源码  068a22a',109,344,1052,60,42,C.blue);
 text(s,'AtomGit：atomgit.com/c2892480843s/cj-docguard\n运行指南：docs/judge-quickstart.md',111,419,1046,68,27,C.ink,H);
 text(s,'前提：仓颉1.1.3 / 1.2.0 + 兼容系统 SDK',87,532,1108,49,34,C.ink);text(s,'当前完整实测：macOS arm64',87,593,1108,46,30,C.muted);
 text(s,'谢谢各位评委！',863,650,344,47,37,C.blue);
}
// 11-14: optional technical backup pages, outside the timed main talk.
{
 const s=base(11,'备查：当前支持范围','按已经实现、已经实测的范围回答');
 table(s,[['范围','当前实现或结论'],['宿主与工具链','完整实测：macOS arm64；SDK 1.1.3 / 1.2.0'],['声明解析','std.ast 与已测试声明子集；不作全语义承诺'],['执行项目','维护者明确授权的可信本地项目'],['外部链接','离线未查保持未确认'],['安全边界','进程监督和资源限制不等于完整安全沙箱']],76,220,1129,407,[297,832],28);
}
{
 const s=base(12,'备查：每个状态，都有明确条件','运行通过、仅编译、需重测和历史记录分别保留');
 table(s,[['状态','含义','后续操作'],['运行通过','真实执行且登记输出检查通过','结合当前输入与环境使用'],['仅编译','编译完成，未验证运行行为','补充运行与输出检查'],['需重测','源码、配置或工具链等输入变化','重新生成文档并测试'],['历史记录','保留过去尝试，供追溯查看','不直接替代当前结果']],76,222,1129,364,[213,536,380],27);
 highlight(s,77,642,1055,27);text(s,'92.9% = 26 / 28：记录占比，不是项目正确率。',84,617,1118,61,32,C.ink);
}
{
 const s=base(13,'备查：评委复现入口','先配置工具链，再构建本地服务');
 rough(s,77,226,1127,263,{fill:C.white,color:C.ink});
 text(s,'git clone https://atomgit.com/c2892480843s/cj-docguard.git\ncd cj-docguard && git checkout 068a22a\nbash scripts/build_workbench.sh\nbash scripts/workbench.sh --port 8765',103,255,1070,215,27,C.ink,CODE);
 highlight(s,80,563,816,32,C.mint);text(s,'打开 http://127.0.0.1:8765/',88,533,1113,69,43,C.green);
 text(s,'前提：已登记两版仓颉 SDK 与兼容系统 SDK；完整步骤见评委指南。',85,642,1117,49,27,C.muted);
}
{
 const s=base(14,'备查：链接专项检查的实际页面','来源、行号、原始目标和检查原因，一起保留');
 rect(s,76,216,1129,432,C.white);picture(s,'links.png',87,226,1106,412,{left:.2,top:.3,right:0,bottom:.15});rough(s,76,216,1129,432,{color:C.ink,width:2.4});
 text(s,'预置坏链已定位；未联网检查的外链保持未确认。',82,666,1122,35,27,C.muted);
}
if(p.slides.items.length!==14)throw Error('14 slides required');
if(facts.summary.RUN_VERIFIED!==26||facts.summary.COMPILE_ONLY!==2||facts.summary.TOTAL!==28)throw Error('Wrong current values');
const rev=process.env.DECK_REV||'01';await fs.mkdir(path.join(build,'draft'),{recursive:true});await fs.mkdir(path.join(build,'validated'),{recursive:true});await fs.mkdir(path.join(build,'preview'),{recursive:true});
const candidate=path.join(build,'draft',`notebook-${rev}.pptx`);await (await PresentationFile.exportPptx(p)).save(candidate);
for(const [i,s] of p.slides.items.entries()){
 const png=await p.export({slide:s,format:'png',scale:1});await fs.writeFile(path.join(build,'preview',`slide-${i+1}.png`),new Uint8Array(await png.arrayBuffer()));console.log('Rendered',i+1);
}
const packedCandidate=path.join(build,'draft',`notebook-${rev}-packed.pptx`);
execFileSync(py,[fileURLToPath(new URL('./dedup_media.py',import.meta.url)),candidate,packedCandidate],{stdio:'inherit'});
await finalizePresentation({workspaceDir:root,candidatePath:packedCandidate,finalPath:path.join(build,'validated',`notebook-${rev}.pptx`),pythonExecutable:py,integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit',...[2,6,8,11,12].flatMap(n=>['--require-native-table-slide',String(n)])],fontPolicy:{basis:'design',families:[H,L,CODE]},explicitTotalSlideCount:14,requiredNativeTableOwnerSlides:[2,6,8,11,12],requiredNativeChartOwnerSlides:[6],materializeLiteralChartWorkbooks:true,verifyArtifactToolImport:true,receiptPath:path.join(build,`validation-${rev}.json`)});
console.log('Finalized revision',rev);
