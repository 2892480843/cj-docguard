import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {execFileSync} from 'node:child_process';
const runtimeModules=process.env.RUNTIME_NODE_MODULES;
const {Presentation,PresentationFile}=await import(pathToFileURL(path.join(runtimeModules,'@oai/artifact-tool/dist/artifact_tool.mjs')).href);
const root=process.cwd(),out=path.join(root,'submission/finals-2026-10-29/roadshow-v6-video'),build=path.join(root,'build/finals-ppt-video');
const skill=process.env.PRESENTATIONS_SKILL_DIR||'/Users/a111/.codex/plugins/cache/openai-primary-runtime/presentations/26.1020.11618/skills/presentations';
const py=process.env.PRESENTATIONS_PYTHON||'/Users/a111/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3';
const {finalizePresentation,applyPresentationChartFont}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')).href);
const content=JSON.parse(await fs.readFile(path.join(out,'content.json'),'utf8')),facts=JSON.parse(await fs.readFile(path.join(out,'facts.json'),'utf8'));
const H='Ma Shan Zheng',L='Chalkboard SE',CODE='Source Han Sans SC';
const C={paper:'#faf6eb',ink:'#2a302d',muted:'#626b67',blue:'#28638c',green:'#397b60',yellow:'#fff09b',mint:'#deedda',pink:'#f6d2bf',red:'#aa554b',line:'#8c9385',white:'#fffdf7'};
const p=Presentation.create({slideSize:{width:1280,height:720}});p.theme.defaultFont=H;
p.theme.colorScheme={name:'Notebook Marker',themeColors:{accent1:C.blue,accent2:C.green,accent3:'#d89e38',accent4:C.red,accent5:'#8d9d86',accent6:'#77654f',bg1:C.paper,bg2:C.white,tx1:C.ink,tx2:C.muted,dk1:'#000000',dk2:C.ink,lt1:'#ffffff',lt2:C.paper,hlink:C.blue,folHlink:C.green}};
const assets={};for(const name of ['graph-paper.png','api.png','export.png','links.png','overview.png','config.png','matrix.png','history.png','query-result.png','query-form.png','output-check.png','source-editor.png','project-options.png','task-running.png','video-poster.png'])assets[name]=new Uint8Array(await fs.readFile(path.join(out,'assets',name)));
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
 if(title){highlight(s,66,109,Math.min(1145,title.length*33+34),23);text(s,title,70,67,1140,68,42,C.ink,H);if(sub)text(s,sub,73,146,1135,46,25,C.muted,H);}
 const d=content.slides[n-1];s.speakerNotes.text=`${n<=10?`主讲时段：${d.start}至${d.end}，${d.seconds}秒（第4页包含视频播放）。\n`:''}${d.spoken}\n\n动作：${d.action}\n\n来源：${d.sources}\n\n视觉：底纹为图像生成的纸张纹理，不是产品运行记录；本次网页操作由真实录屏呈现，矩阵与测试统计沿用当前功能源码068a22a的已记录结果。`;
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

function shot(s,name,x,y,w,h,crop){rect(s,x,y,w,h,C.white);picture(s,name,x+5,y+5,w-10,h-10,crop);rough(s,x,y,w,h,{color:C.ink,width:2});}
// 1 · Product, audience, working interface and current scale.
{
 const s=base(1);highlight(s,73,106,190,29);text(s,'决赛答辩',80,86,420,55,35,C.blue);
 text(s,'CJ-DocGuard',73,163,570,92,62,C.ink,L);text(s,'仓颉项目级 API\n文档生成及测试',77,267,557,105,38,C.ink);
 text(s,'面向仓颉库维护者\n维护接口说明、受测示例与版本关系\n在一个本地工作台查看检查结果',79,393,554,119,28,C.muted);
 shot(s,'overview.png',657,204,549,349,{left:.2,top:.19,right:.015,bottom:.08});text(s,'当前工作区：接口、示例、版本结果集中查看',661,563,545,47,24,C.blue);
 highlight(s,78,544,530,27,C.mint);text(s,'本地网页 · 原生仓颉服务与核心',85,523,552,54,31,C.green);
 text(s,'47',90,603,110,65,48,C.blue,L);text(s,'公共接口',211,623,220,45,28,C.ink);
 text(s,'14',464,603,110,65,48,C.blue,L);text(s,'登记示例',586,623,220,45,28,C.ink);
 text(s,'2',881,603,70,65,48,C.blue,L);text(s,'SDK 版本',967,623,230,45,28,C.ink);
 text(s,'当前完整实测：macOS arm64；仓颉 1.1.3 / 1.2.0',81,683,1125,29,22,C.muted);
}
// 2 · Requirements mapped to concrete entry points, with actual project registration.
{
 const s=base(2,'赛题交付与库维护流程','从接入项目，到生成文档、执行示例和定位问题');
 table(s,[['交付要求','网页入口','实际产物与检查'],['结构化文档','接口文档\n源码编辑','声明、参数、返回类型\n关联示例及源码位置'],['示例正确性\n测试','示例测试\n任务中心','真实编译与运行\n退出码、期望/实际输出'],['SDK 版本与\n索引链接测试','SDK 测试矩阵\n链接与问题','按SDK和平台保留结果\n目标文件、锚点与来源']],75,218,752,328,[186,202,364],24);
 text(s,'接入现有库',866,217,340,45,30,C.blue);shot(s,'config.png',865,269,340,168,{left:.225,top:.16,right:.34,bottom:.69});
 text(s,'登记本地配置绝对路径；\n登记不会自动授予执行信任。',869,452,336,73,25,C.ink);
 text(s,'接入 → 诊断环境\n生成文档 → 运行与检查\n查看结果 → 修改后重测',870,549,336,111,27,C.muted);
 highlight(s,77,598,734,27,C.mint);text(s,'把查文档、核示例、比版本\n放进可重复执行的维护流程。',84,568,741,98,32,C.green);
 text(s,'API：应用程序接口；SDK：仓颉编译器、运行库等开发工具。',80,683,1125,29,21,C.muted);
}
// 3 · An actual public declaration linked to its runnable example and registered expectation.
{
 const s=base(3,'从接口说明，找到可运行的示例','声明、源码位置、参数、返回类型和登记示例互相关联');
 rough(s,77,217,516,139,{fill:C.white,color:C.blue});text(s,'add · 公共函数',96,232,479,42,30,C.blue);text(s,'public func add(a: Int64,\n                b: Int64): Int64',96,286,478,63,23,C.ink,CODE);
 text(s,'登记示例 arithmetic（摘录）',84,378,508,42,29,C.ink);rough(s,77,424,516,112,{fill:C.white,color:C.ink});text(s,'main(): Unit {\n    println(add(20, 22))\n}',97,436,475,91,23,C.ink,CODE);
 text(s,'期望：退出码 0；输出 "42\\n"',84,555,509,45,27,C.green);text(s,'可搜索、跳转源码、查看关联示例\n生成 JSON / HTML / Markdown 文档',84,610,514,72,25,C.muted);
 shot(s,'api.png',638,216,568,421,{left:.414,top:.33,right:0,bottom:.08});text(s,'重名与重载需明确身份，不能随意绑定示例。',643,651,560,54,24,C.blue);
}
// 4 · Native embedded MP4, added by the OOXML media helper after export.
{
 const s=base(4);text(s,'系统介绍 · 02:00',73,69,1120,46,32,C.blue);
 const poster=picture(s,'video-poster.png',128,116,1024,576);poster.name='CJ-DocGuard-System-Video';
 rough(s,126,114,1028,580,{color:C.ink,width:2.5});
}
// 5 · Architecture plus code-module map, actual division of responsibilities.
{
 const s=base(5,'仓颉服务、核心模块与真实工具链','浏览器负责交互；本地服务和核心处理由仓颉实现');
 const a=note(s,77,215,270,121,'浏览器页面','HTML / CSS / JavaScript',{size:24});const b=note(s,416,215,310,121,'仓颉本地服务','HTTP、项目、配置与任务',{fill:C.yellow,size:24});const c=note(s,794,215,412,121,'仓颉核心','声明提取、测试与结果判断',{size:25});connector(s,a,b);connector(s,b,c);
 text(s,'std.ast → 结构化声明 → 关联登记示例',80,365,1123,48,31,C.blue);
 table(s,[['主要源码','职责'],['workbench_native/','HTTP 请求、项目和任务管理'],['src/extractor.cj','提取公共声明、参数和返回类型'],['src/evidence.cj','判断当前输入与执行记录是否匹配'],['src/export.cj','校验指定环境后生成可重建示例包']],77,430,656,224,[238,418],23);
 const sdkNode=note(s,794,427,412,112,'真实 SDK 1.1.3 / 1.2.0','编译 → 运行 → 登记输出核对',{fill:C.mint,color:C.green,size:25});connector(s,c,sdkNode,'bottom','top');
 text(s,'C：子进程监督与信号\nBash：构建与启动\nPython：测试和只读适配等辅助',800,561,406,103,26,C.muted);
 text(s,'解析限于已实现、已测试的声明子集；进程资源控制不等于完整安全沙箱。',81,683,1125,29,21,C.muted);
}
// 6 · Editable data chart and table next to the real per-example matrix.
{
 const s=base(6,'双 SDK 结果：统计与矩阵同时查看','14 个登记示例 × 2 个 SDK；仅编译不等于运行通过');
 const rows=[...facts.by_sdk].reverse();const chart=s.charts.add('bar',{position:{left:76,top:209,width:543,height:272},categories:rows.map(x=>'SDK '+x.sdk),series:[{name:'运行通过',values:rows.map(x=>x.run_verified),fill:'#9fbaa5',line:line(C.green,2)},{name:'仅编译',values:rows.map(x=>x.compile_only),fill:'#efd18c',line:line('#a87630',2)}],hasLegend:true,legend:{position:'bottom',textStyle:{fontSize:22,fill:C.ink}},barOptions:{direction:'bar',grouping:'stacked',gapWidth:92,overlap:100},dataLabels:{showValue:true,position:'center',textStyle:{fontSize:25,fill:C.ink}},xAxis:{textStyle:{fontSize:23,fill:C.ink},line:line('none',0)},yAxis:{min:0,max:14,majorUnit:2,textStyle:{fontSize:20,fill:C.muted},majorGridlines:line('#cbd2c3',1)},chartFill:'none',chartLine:line('none',0),plotAreaFill:'none',plotAreaLine:line('none',0)});applyPresentationChartFont(chart,{fontFamily:L});chart.legend.textStyle.typeface=H;
 shot(s,'matrix.png',649,211,557,269,{left:.225,top:.17,right:.025,bottom:.53});text(s,'实际矩阵节选：按示例和SDK定位，\n点开单元格查看日志与期望/实际输出。',654,489,548,61,24,C.blue);
 text(s,'26 条运行通过 + 2 条仅编译 = 28 条记录',83,492,553,61,29,C.green);
 table(s,[['SDK 版本','运行通过','仅编译','合计'],...facts.by_sdk.map(x=>[x.sdk,String(x.run_verified),String(x.compile_only),String(x.total)])],77,561,1129,115,[337,273,247,272],25);
 text(s,'数量描述当前登记样例，不是项目正确率或全语言覆盖率。',81,688,1125,25,20,C.muted);
}
// 7 · Concrete rejection cases and a separate history view.
{
 const s=base(7,'当前可用结果，怎样判定？','查询与导出共用判断规则，保留历史但不回退旧成功');
 text(s,'核对六项条件',81,218,634,43,31,C.blue);text(s,'源码 / 配置 / 工具链 / 平台\n记录完整性 / 相应环境的最新尝试',83,273,633,80,29,C.ink);
 table(s,[['触发情形','当前处理'],['源码或配置变化','标记需重测，重新执行'],['最新一次尝试失败','不以较早成功替代失败'],['SDK 或平台不匹配','不跨环境返回有效示例']],77,381,640,270,[245,395],25);
 text(s,'历史保留，当前另行判断',751,219,456,45,30,C.blue);shot(s,'history.png',748,280,458,245,{left:.225,top:.38,right:.025,bottom:.02});
 text(s,'739 条历史完整保留\n列表不直接代表当前结果\n导出前仍校验当前输入与环境',756,552,449,112,28,C.muted);
 text(s,'输出检查只覆盖登记的受测行为，不能据一次成功推断所有输入都正确。',81,683,1125,29,21,C.muted);
}
// 8 · The actual bad-link page, exact locations, scopes and separately counted results.
{
 const s=base(8,'链接检查：发现问题，也解释原因','保留来源、行号、原始目标与失败原因；两组样例分开统计');
 table(s,[['来源','原始目标','检查结果'],['README.md:13','docs/intentionally-missing.md','目标文件不存在'],['README.md:14','docs/target%20file.md\n#escaped-ghost','目标标题或锚点不存在']],77,218,1129,221,[244,516,369],24);
 shot(s,'links.png',77,476,627,183,{left:.225,top:.365,right:.025,bottom:.365});
 text(s,'本地文件 / 锚点 / 索引链接',743,460,463,44,29,C.blue);text(s,'URL解码后定位文件与标题；\nHTML索引与Markdown链接分别检查。\n专项：23通过 / 2失败 / 1未确认。\n健康工作区：178条通过（另计）。',747,512,458,147,25,C.ink);
 text(s,'两处预置坏链导致严格检查退出1，符合预期；离线外链保持未确认。',81,683,1125,29,21,C.muted);
}
// 9 · Two real UI pictures plus scoped current checks and retained history.
{
 const s=base(9,'近期工程优化：控件、任务与长期工作区','原生仓颉服务；查询与导出统一校验；链接与控件回归');
 text(s,'控件与条件',81,216,540,43,31,C.blue);text(s,'任务状态与进度',706,216,499,43,31,C.blue);
 shot(s,'project-options.png',78,271,285,219,{left:.2,top:.015,right:.605,bottom:.755});text(s,'实际项目选项\nSDK与平台条件联动\n禁用与忙碌反馈\n键盘选择和空态',389,276,236,196,27,C.ink);
 shot(s,'task-running.png',706,271,499,179,{left:.055,top:.40,right:.04,bottom:.235});text(s,'实际运行画面（准备阶段）。\n无数量进度时显示状态条，\n结束后再展示返回结果。',712,469,488,87,25,C.muted);
 underline(s,80,557,1122,C.ink);
 for(const [i,v,label] of [[0,'23','原生 HTTP 专项\n回归通过'],[1,'20','页面场景\n及交互回归'],[2,'30','三档十页\n布局检查'],[3,'739','历史记录完整保留\n任务默认堆上限1GB']]){const x=88+i*290;text(s,v,x,578,236,61,47,i===3?C.green:C.blue,L);text(s,label,x,642,264,59,24,C.ink);}
}
// 10 · Deliverable package contents, source editor and reproducible entry point.
{
 const s=base(10,'交付、复现与持续维护','交付的不只是页面，也有可检索文档、测试记录与可重建示例');
 text(s,'维护者拿到什么？',81,219,536,45,32,C.blue);rough(s,77,276,540,221,{fill:C.white});text(s,'示例 ZIP 包\n├─ examples/.../arithmetic.cj\n├─ src/...（关联编译单元）\n├─ manifest.json（环境与检查）\n└─ build.sh / README.md',97,293,501,187,23,C.ink,CODE);
 shot(s,'source-editor.png',664,219,541,270,{left:.225,top:.365,right:.025,bottom:.39});text(s,'网页审阅并保存登记源码；\n保存须校验文件版本、路径并明确确认。',671,506,533,66,25,C.blue);
 highlight(s,80,570,534,27,C.mint);text(s,'固定功能源码：068a22a',87,546,535,59,34,C.green);
 text(s,'按运行指南准备双SDK与兼容系统SDK，\n构建原生服务后从本机8765端口打开。',84,615,536,73,26,C.ink);
 text(s,'价值：接口、示例和版本结果共同维护。\n当前完整实测：macOS arm64。',672,603,533,76,27,C.ink);
 text(s,'atomgit.com/c2892480843s/cj-docguard · docs/native-workbench.md',82,693,940,22,18,C.muted,L);text(s,'谢谢大家！',1021,682,185,34,28,C.blue);
}
// 11 · More detailed support boundaries, without unsupported platform claims.
{
 const s=base(11,'备查：支持范围与实现边界','按已实现、已测试的范围回答；不以样例数量代替覆盖率');
 table(s,[['范围','当前已实现 / 已实测','边界'],['宿主与工具链','macOS arm64\nSDK 1.1.3 / 1.2.0','其他宿主需单独复验'],['声明解析','std.ast 与已测试声明子集\n保留参数、返回类型、来源','不宣称完整语义覆盖'],['示例正确性','真实编译、运行及登记输出核对','不证明全部输入正确'],['外部链接','离线未检查时保留未确认','不能当作远端可访问'],['执行项目','维护者明确授权的可信本地项目','资源限制不是完整安全沙箱']],77,220,1129,415,[208,513,408],25);
 text(s,'复杂语法、其他平台与更大项目，需要扩展样例并重新验证。',84,661,1121,41,26,C.muted);
}
// 12 · Actual exit-code and stdout comparison beside the state definitions.
{
 const s=base(12,'备查：状态含义与输出核对','仅编译、运行通过、需重测与历史记录分别保留');
 table(s,[['状态','判断条件 / 解释'],['运行通过','实际运行且登记输出检查通过'],['仅编译','编译完成，未验证运行行为'],['需重测','源码、配置或工具链等输入变化'],['历史记录','保留过去尝试，不直接当作当前可用']],77,222,633,364,[161,472],25);
 text(s,'arithmetic · SDK 1.1.3',747,223,458,42,28,C.blue,L);shot(s,'output-check.png',747,275,458,247,{left:.145,top:.17,right:.145,bottom:.17});text(s,'退出码：期望0，实际0\nstdout：均为 "42\\n"\n检查结果单独显示通过',755,546,450,114,27,C.ink);
 highlight(s,80,658,643,27);text(s,'26 / 28 = 92.9%：记录占比，不是项目正确率。',86,630,650,70,28,C.ink);
}
// 13 · Concrete clone/build commands and the prerequisites that make them valid.
{
 const s=base(13,'备查：从源码启动工作台','先准备兼容工具链，再构建服务；首次没有报告是正常状态');
 rough(s,77,224,756,305,{fill:C.white});text(s,'export CJ_DOCGUARD_SDK_1_1_3=/absolute/path/sdk-1.1.3/cangjie\nexport CJ_DOCGUARD_SDK_1_2_0=/absolute/path/sdk-1.2.0/cangjie\n\ngit clone https://atomgit.com/c2892480843s/cj-docguard.git\ncd cj-docguard\ngit checkout 068a22a8a4d1987ac0aac837da22b39c8224417f\nbash scripts/build_workbench.sh\nbash scripts/workbench.sh --port 8765',98,248,714,250,22,C.ink,CODE);
 text(s,'运行前检查',876,225,330,45,32,C.blue);text(s,'git / bash / cc / ar / zip\n仓颉1.1.3与1.2.0\n兼容的 Apple 系统 SDK\n示例路径需替换为本机目录\n按指南诊断缺失依赖',880,286,326,223,27,C.ink);
 highlight(s,81,586,955,32,C.mint);text(s,'打开 http://127.0.0.1:8765/',88,554,1116,70,42,C.green);
 text(s,'环境诊断 → 生成文档 → 运行测试 → 检查链接。\n服务仅绑定本机；其他宿主或工具链变化需要完整复验。',86,642,1116,68,26,C.muted);
}
// 14 · Concrete config fragment and its matching real query form.
{
 const s=base(14,'备查：一份配置连接文档、示例和环境','登记的符号、运行方式与SDK，决定文档关联和查询维度');
 rough(s,77,220,594,400,{fill:C.white});text(s,'登记片段：docguard.toml',96,234,554,43,28,C.blue);text(s,'[[sdks]]\nversion = "1.2.0"\n\n[[examples]]\nid = "arithmetic"\nfile = "programs/arithmetic.cj"\nsymbol = "add"\nmode = "run"\nstdout = "42\\n"\nexpected_exit = 0',98,292,554,311,22,C.ink,CODE);
 text(s,'网页选项来自实际配置与记录',718,220,489,45,30,C.blue);shot(s,'query-form.png',718,278,487,252,{left:.225,top:.235,right:.025,bottom:.36});text(s,'SDK / 平台 / 示例条件联动\n最终有效性仍由本地服务判断\n界面选择不会绕过当前结果校验',727,550,477,101,27,C.ink);
 text(s,'完整项目字段见 examples/healthy/docguard.toml；片段仅说明示例与环境如何登记。',85,665,1117,43,24,C.muted);
}
if(p.slides.items.length!==14)throw Error('14 slides required');
if(facts.summary.RUN_VERIFIED!==26||facts.summary.COMPILE_ONLY!==2||facts.summary.TOTAL!==28)throw Error('Wrong current values');
const rev=process.env.DECK_REV||'01';await fs.mkdir(path.join(build,'draft'),{recursive:true});await fs.mkdir(path.join(build,'validated'),{recursive:true});await fs.mkdir(path.join(build,'preview'),{recursive:true});
const candidate=path.join(build,'draft',`rich-${rev}.pptx`);await (await PresentationFile.exportPptx(p)).save(candidate);
for(const [i,s] of p.slides.items.entries()){const png=await p.export({slide:s,format:'png',scale:1});await fs.writeFile(path.join(build,'preview',`slide-${i+1}.png`),new Uint8Array(await png.arrayBuffer()));console.log('Rendered',i+1);}
const packed=path.join(build,'draft',`rich-${rev}-packed.pptx`);execFileSync(py,[fileURLToPath(new URL('./dedup_media.py',import.meta.url)),candidate,packed],{stdio:'inherit'});
const embedded=path.join(build,'draft',`video-${rev}-embedded.pptx`);execFileSync(py,[fileURLToPath(new URL('./embed_video.py',import.meta.url)),packed,path.join(out,'output/CJ-DocGuard-系统介绍-2分钟-1080p60.mp4'),embedded],{stdio:'inherit'});
const owners=[2,5,6,7,8,11,12];await finalizePresentation({workspaceDir:root,candidatePath:embedded,finalPath:path.join(build,'validated',`rich-${rev}.pptx`),pythonExecutable:py,integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit',...owners.flatMap(n=>['--require-native-table-slide',String(n)])],fontPolicy:{basis:'design',families:[H,L,CODE]},explicitTotalSlideCount:14,requiredNativeTableOwnerSlides:owners,requiredNativeChartOwnerSlides:[6],materializeLiteralChartWorkbooks:true,verifyArtifactToolImport:true,receiptPath:path.join(build,`validation-${rev}.json`)});console.log('Finalized',rev);
