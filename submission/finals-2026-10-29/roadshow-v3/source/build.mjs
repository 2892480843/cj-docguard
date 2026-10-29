import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const runtimeModules=process.env.RUNTIME_NODE_MODULES;
const {Presentation,PresentationFile}=await import(runtimeModules?pathToFileURL(path.join(runtimeModules,'@oai/artifact-tool/dist/artifact_tool.mjs')).href:'@oai/artifact-tool');
const root=process.cwd();
const output=path.join(root,'submission/finals-2026-10-29/roadshow-v3');
const build=path.join(root,'build/finals-ppt-v3');
const skill=process.env.PRESENTATIONS_SKILL_DIR||'/Users/a111/.codex/plugins/cache/openai-primary-runtime/presentations/26.1020.11618/skills/presentations';
const runtimePython=process.env.PRESENTATIONS_PYTHON||'/Users/a111/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3';
const {finalizePresentation,applyPresentationChartFont}=await import(pathToFileURL(path.join(skill,'container_tools/artifact_tool_utils.mjs')));
const content=JSON.parse(await fs.readFile(path.join(output,'content.json'),'utf8'));
const facts=JSON.parse(await fs.readFile(path.join(output,'facts.json'),'utf8'));
const F='Source Han Sans SC';
const C={bg:'#f9fafb',nav:'#111827',ink:'#111827',muted:'#647084',line:'#e5e7eb',accent:'#6063eb',soft:'#eef0ff',green:'#15803d',greenBar:'#10b981',amber:'#a16207',amberBar:'#f59e0b',red:'#b91c1c',white:'#ffffff'};
const p=Presentation.create({slideSize:{width:1280,height:720}});
p.theme.defaultFont=F;
p.theme.colorScheme={name:'DocGuard Dashboard',themeColors:{accent1:C.accent,accent2:C.greenBar,accent3:C.amberBar,accent4:C.red,accent5:'#94a3b8',accent6:'#475569',bg1:C.bg,bg2:C.white,tx1:C.ink,tx2:C.muted,dk1:'#000000',dk2:C.nav,lt1:C.white,lt2:C.line,hlink:C.accent,folHlink:'#4f46e5'}};
const line=(fill=C.line,width=1)=>({fill,width,style:'solid'});
function rect(s,x,y,w,h,fill=C.white,border=C.line,r=12){return s.shapes.add({geometry:r?'roundRect':'rect',position:{left:x,top:y,width:w,height:h},fill,line:line(border,border==='none'?0:1),...(r?{borderRadius:r}:{})});}
function txt(s,text,x,y,w,h,size=26,color=C.ink,bold=false,align='left'){
 const shape=s.shapes.add({geometry:'textbox',name:String(text).slice(0,36),position:{left:x,top:y,width:w,height:h},fill:'none',line:line('none',0)});
 shape.text=text;shape.text.style={typeface:F,fontSize:size,color,bold,alignment:align,verticalAlignment:'top',insets:0,autoFit:'none',wrap:'square'};return shape;
}
function image(s,name,x,y,w,h,crop){const bytes=assets[name];return s.images.add({blob:bytes,contentType:'image/png',alt:`当前源码068a22a的实际工作台截图：${name}`,fit:'contain',position:{left:x,top:y,width:w,height:h},...(crop?{crop}:{})});}
const assets={};for(const name of ['overview.png','api.png','export.png','links.png'])assets[name]=new Uint8Array(await fs.readFile(path.join(output,'assets',name)));
const topics=['赛题与交付','网页操作','仓颉实现','当前测试','复现与边界'];
function chapter(n){return n<=2?0:n<=4?1:n===5?2:n<=9?3:4;}
function base(n,title,subtitle){
 const s=p.slides.add();s.background.fill=C.bg;
 rect(s,0,0,192,720,C.nav,'none',0);
 txt(s,'CJ-DocGuard',24,38,154,38,22,C.white,true);
 txt(s,'仓颉文档工作台',24,83,152,30,18,'#b9c2d1');
 txt(s,'内容',24,157,140,28,17,'#97a2b6');
 topics.forEach((t,i)=>{const y=209+i*67;if(i===chapter(n))rect(s,16,y-10,160,51,'#ffffff15','none',8);txt(s,String(i+1).padStart(2,'0'),28,y,25,28,16,i===chapter(n)?'#b6b8ff':'#94a3b8');txt(s,t,62,y-2,113,35,20,i===chapter(n)?C.white:'#b9c2d1',i===chapter(n));});
 txt(s,'源码版本',24,617,144,24,16,'#97a2b6');txt(s,'068a22a',24,648,144,28,20,'#dce2ec');
 if(title){txt(s,title,240,58,992,62,42,C.ink,true);if(subtitle)txt(s,subtitle,242,136,982,44,24,C.muted);}
 txt(s,n<=10?`${String(n).padStart(2,'0')} / 10`:`备查 ${n-10} / 4`,1120,680,112,24,16,C.muted,false,'right');
 const d=content.slides[n-1];s.speakerNotes.text=`${n<=10?`【主讲时段】${d.start}–${d.end}，目标${d.seconds}秒（含操作）。\n`:''}【讲述】${d.spoken}\n\n【动作】${d.action}\n\n【来源】${d.sources}`;
 return s;
}
function panel(s,x,y,w,h,title,body,{fill=C.white,titleColor=C.ink,size=26}={}){const sh=rect(s,x,y,w,h,fill);txt(s,title,x+22,y+21,w-44,38,28,titleColor,true);if(body)txt(s,body,x+22,y+69,w-44,h-82,size,C.muted);return sh;}
function table(s,values,x,y,width,height,widths,font=24){
 const t=s.tables.add({rows:values.length,columns:values[0].length,left:x,top:y,width,height,columnWidths:widths,values});
 t.styleOptions={headerRow:true,bandedRows:false};t.borders.assign(line(C.line,1));
 for(let r=0;r<values.length;r++)for(let c=0;c<values[0].length;c++){
  const cell=t.getCell(r,c);cell.fill=r===0?'#eef0ff':C.white;
  cell.text.style={typeface:F,fontSize:r===0?font-1:font,color:r===0?'#4546a2':C.ink,bold:r===0,verticalAlignment:'middle',insets:{left:14,right:14,top:10,bottom:10},wrap:'square',autoFit:'none'};
 }
 return t;
}
function arrow(s,a,b,fromSide='right',toSide='left'){return s.shapes.connect(a,b,{kind:'straight',fromSide,toSide,line:line('#a6adc1',2),tail:{type:'triangle',width:'med',length:'med'}});}
function metric(s,value,label,x,y,width=230,color=C.accent){txt(s,String(value),x,y,width,82,60,color,true);txt(s,label,x,y+86,width,38,25,C.muted);}
// 1 · minimal cover, with a current product view rather than decorative imagery.
{
 const s=base(1);txt(s,'决赛答辩',242,82,850,38,25,C.accent,true);
 txt(s,'CJ-DocGuard',240,164,950,86,64,C.ink,true);
 txt(s,'仓颉项目级 API 文档生成及测试',242,270,958,64,38,C.ink,true);
 txt(s,'在本地工作台中生成文档、运行示例，\n检查开发工具包版本和索引链接。',242,357,920,92,30,C.muted);
 rect(s,242,494,960,115,C.white);
 txt(s,'47',267,514,110,56,44,C.accent,true);txt(s,'公共接口',380,530,150,40,25,C.muted);
 txt(s,'14',563,514,110,56,44,C.accent,true);txt(s,'登记示例',676,530,150,40,25,C.muted);
 txt(s,'2',870,514,70,56,44,C.accent,true);txt(s,'SDK 版本',950,530,220,40,25,C.muted);
 txt(s,'当前实测：macOS arm64 · 仓颉 1.1.3 / 1.2.0',242,637,920,30,20,C.muted);
}
// 2 · requirement mapping is a real editable table.
{
 const d=content.slides[1],s=base(2,d.title,d.subtitle);
 table(s,[['赛题交付','网页入口','生成或检查的内容'],['结构化 API 文档','接口文档 / 源码编辑','声明、参数、返回类型\n关联示例与源码位置'],['示例代码正确性测试','示例测试 / 任务中心','真实编译、运行\n输出检查与执行记录'],['SDK 版本关系\n与索引链接测试','SDK 测试矩阵\n链接与问题','独立版本结果\n目标文件、锚点与来源']],242,216,964,338,[284,270,410],24);
 txt(s,'API：应用程序接口；SDK：仓颉编译器、运行库等开发工具。',242,594,964,66,22,C.muted);
}
// 3 · editable explanation plus an untouched current UI capture.
{
 const d=content.slides[2],s=base(3,d.title,d.subtitle);
 rect(s,242,210,446,168,C.white);txt(s,'add',264,229,400,38,30,C.accent,true);
 txt(s,'public func add(\n  a: Int64, b: Int64\n): Int64',264,279,400,91,25,C.ink);
 txt(s,'参数',244,416,120,34,26,C.ink,true);txt(s,'a、b：Int64',374,416,306,38,26,C.muted);
 txt(s,'返回',244,476,120,34,26,C.ink,true);txt(s,'Int64',374,476,306,38,26,C.muted);
 txt(s,'关联示例',244,536,180,34,26,C.ink,true);txt(s,'arithmetic\nsnippet-wrapper',244,580,438,72,26,C.muted);
 rect(s,714,210,493,442,C.white);image(s,'api.png',727,222,468,415,{left:0.414,top:0.33,right:0,bottom:0.08});
}
// 4 · an editable flow and an actual completed export.
{
 const d=content.slides[3],s=base(4,d.title,'现场操作：检索 → 查看记录 → 指定环境查询 → 导出 ZIP');
 const stages=[['检索接口','声明与示例'],['查看矩阵','区分结果状态'],['查询记录','指定 SDK / 平台'],['导出示例','本地检查后下载']];
 const nodes=stages.map(([a,b],i)=>{const x=242+i*246,sh=rect(s,x,213,220,103,i===2?C.soft:C.white);txt(s,a,x+17,231,186,35,27,i===2?C.accent:C.ink,true);txt(s,b,x+17,276,186,28,20,C.muted);return sh;});nodes.slice(0,-1).forEach((x,i)=>arrow(s,x,nodes[i+1]));
 image(s,'export.png',242,361,611,253,{left:0.14,top:0.235,right:0.14,bottom:0.235});
 txt(s,'当前实际导出',883,368,320,38,27,C.ink,true);
 txt(s,'arithmetic\nSDK 1.2.0\nDarwin-arm64',883,426,320,124,26,C.muted);
 txt(s,'ZIP 下载已生成',883,579,320,38,25,C.green,true);
 txt(s,'全量矩阵在准备阶段运行；现场查询和导出单独说明任务状态。',242,641,970,33,20,C.muted);
}
// 5 · actual language responsibilities, with native editable connectors.
{
 const d=content.slides[4],s=base(5,d.title,d.subtitle);
 const browser=panel(s,242,221,244,157,'浏览器页面','HTML / CSS\nJavaScript',{size:24});
 const http=panel(s,538,221,254,157,'仓颉本地服务','HTTP 请求、任务\n项目与配置管理',{fill:C.soft,titleColor:C.accent,size:24});
 const core=panel(s,844,221,362,157,'仓颉核心','声明提取、文档生成\n测试编排与结果判断',{size:24});arrow(s,browser,http);arrow(s,http,core);
 const sdk=panel(s,844,437,362,123,'真实仓颉工具链','SDK 1.1.3 / 1.2.0',{size:24});arrow(s,core,sdk,'bottom','top');
 txt(s,'std.ast 提取公共声明',242,433,552,42,28,C.ink,true);
 txt(s,'C：子进程监督与信号处理\nBash：构建与启动\nPython：测试和只读协议适配等辅助',242,495,558,132,25,C.muted);
 txt(s,'网页服务及核心处理由仓颉承担，浏览器使用标准网页技术。',242,647,964,32,21,C.muted);
}
// 6 · editable chart and table use the same source-backed values.
{
 const d=content.slides[5],s=base(6,d.title,d.subtitle);
 const chartRows=[...facts.by_sdk].reverse();
 const chart=s.charts.add('bar',{position:{left:242,top:205,width:622,height:279},categories:chartRows.map(x=>'SDK '+x.sdk),series:[{name:'运行通过',values:chartRows.map(x=>x.run_verified),fill:C.greenBar},{name:'仅编译',values:chartRows.map(x=>x.compile_only),fill:C.amberBar}],hasLegend:true,legend:{position:'bottom',overlay:false,textStyle:{fontSize:20,fill:C.muted}},barOptions:{direction:'bar',grouping:'stacked',gapWidth:95,overlap:100},dataLabels:{showValue:true,position:'center',textStyle:{fontSize:23,fill:'#052e23',bold:true}},xAxis:{textStyle:{fontSize:20,fill:C.muted},line:line('none',0)},yAxis:{min:0,max:14,majorUnit:2,textStyle:{fontSize:18,fill:C.muted},majorGridlines:line('#edf0f5',1)},chartFill:C.bg,chartLine:line('none',0),plotAreaFill:C.bg,plotAreaLine:line('none',0)});applyPresentationChartFont(chart,{fontFamily:F});
 metric(s,26,'条运行通过',902,213,300,C.green);metric(s,2,'条仅编译',902,367,300,C.amber);
 table(s,[['SDK 版本','运行通过','仅编译','合计'],...facts.by_sdk.map(x=>[x.sdk,String(x.run_verified),String(x.compile_only),String(x.total)])],242,499,964,150,[280,232,220,232],23);
 txt(s,'仅编译不计入运行通过；数量描述当前样例，不等于全语言覆盖率。',242,657,964,28,18,C.muted);
}
// 7 · native explanation of currentness, not an unsupported accuracy promise.
{
 const d=content.slides[6],s=base(7,d.title,d.subtitle);
 const a=panel(s,242,214,280,147,'输入匹配','源码、配置\nSDK 与平台',{size:25});
 const b=panel(s,566,214,280,147,'真实执行','编译、运行\n登记输出检查',{size:25});
 const c=panel(s,890,214,316,147,'当前结果','查询和导出\n使用同一规则',{fill:C.soft,titleColor:C.accent,size:25});arrow(s,a,b);arrow(s,b,c);
 panel(s,242,417,463,168,'源码变化 → 需重测','旧记录继续保留，\n重新测试后再判断当前结果。',{size:25});
 panel(s,731,417,475,168,'最新失败 → 不回退旧成功','按相应环境的最新尝试判断，\n历史成功不会覆盖后续失败。',{size:25});
 txt(s,'历史记录用于追溯；输出检查只覆盖登记的受测行为。',242,632,964,42,23,C.muted);
}
// 8 · the negative fixture was checked again during this rewrite.
{
 const d=content.slides[7],s=base(8,d.title,'专项样例预置缺失文件与缺失锚点，本轮已重新检查');
 table(s,[['来源','原始目标','检查结果'],['README.md:13','docs/intentionally-missing.md','目标文件不存在'],['README.md:14','docs/target%20file.md\n#escaped-ghost','目标标题或锚点不存在']],242,219,964,241,[206,455,303],23);
 metric(s,23,'条本地链接通过',246,505,360,C.green);metric(s,2,'处预置坏链被定位',602,505,350,C.red);metric(s,1,'条外链未确认',951,505,250,C.amber);
 txt(s,'专项样例共26条链接；严格检查退出1表示正确发现问题。',242,654,964,30,20,C.muted);
}
// 9 · only finals-current implementation and newly scoped tests.
{
 const d=content.slides[8],s=base(9,d.title,d.subtitle);
 panel(s,242,213,596,186,'可操作的网页控件','真实选项与查询联动；\n源码、配置、任务和导出均有入口。',{size:26});
 panel(s,864,213,342,186,'任务状态清晰','排队 / 运行 / 结束\n运行通过 / 仅编译',{fill:C.soft,titleColor:C.accent,size:25});
 panel(s,242,425,390,201,'23 项服务回归','本版原生 HTTP 回归通过\n另有三档十页布局检查',{size:25});
 panel(s,658,425,548,201,'739 条历史完整保留','任务采用显式内存上限；\n当前双 SDK 任务已完成。',{size:26});
 txt(s,'数据对应当前源码068a22a；测试项数与页面检查次数分别记录。',242,654,964,30,20,C.muted);
}
// 10 · end of the timed main talk.
{
 const d=content.slides[9],s=base(10,d.title,d.subtitle);
 txt(s,'按说明构建和启动工作台',242,225,964,70,42,C.ink,true);
 rect(s,242,333,964,158,C.white);txt(s,'源码版本  068a22a',267,359,890,47,34,C.accent,true);txt(s,'AtomGit：atomgit.com/c2892480843s/cj-docguard\n运行指南：docs/judge-quickstart.md',267,420,890,65,24,C.muted);
 txt(s,'先配置仓颉 1.1.3 / 1.2.0 与兼容系统 SDK',242,535,964,43,28,C.ink);
 txt(s,'当前完整实测：macOS arm64',242,586,964,38,26,C.muted);
 txt(s,'谢谢各位评委',242,644,860,40,30,C.accent,true);
}
// 11 · boundaries, not unseen-platform success claims.
{
 const d=content.slides[10],s=base(11,d.title,d.subtitle);
 table(s,[['范围','当前实现或结论'],['宿主与工具链','完整实测：macOS arm64；SDK 1.1.3 / 1.2.0'],['声明解析','std.ast 与已测试声明子集；不作全语义承诺'],['执行项目','维护者明确授权的可信本地项目'],['外部链接','离线未查保持未确认'],['安全边界','进程监督和资源限制不等于完整安全沙箱']],242,212,964,412,[258,706],23);
}
// 12 · status vocabulary in one editable table.
{
 const d=content.slides[11],s=base(12,d.title,d.subtitle);
 table(s,[['状态','含义','后续操作'],['运行通过','真实执行且登记输出检查通过','结合当前输入与环境使用'],['仅编译','编译完成，未验证运行行为','补充运行与输出检查'],['需重测','源码、配置或工具链等输入变化','重新生成文档并测试'],['历史记录','保留过去尝试，供追溯查看','不直接替代当前结果']],242,218,964,363,[172,462,330],23);
 txt(s,'92.9% = 26 / 28，表示记录占比，不是项目正确率。',242,620,964,42,24,C.muted);
}
// 13 · reproducible commands; toolchains must be configured first.
{
 const d=content.slides[12],s=base(13,d.title,d.subtitle);
 rect(s,242,218,964,302,C.white);
 txt(s,'git clone https://atomgit.com/c2892480843s/cj-docguard.git\ncd cj-docguard && git checkout 068a22a\nbash scripts/build_workbench.sh\nbash scripts/workbench.sh --port 8765',263,245,922,245,24,C.ink);
 txt(s,'打开 http://127.0.0.1:8765/',242,560,964,46,30,C.accent,true);
 txt(s,'前提：已登记两版仓颉 SDK 与兼容系统 SDK；完整步骤见评委指南。',242,627,964,44,23,C.muted);
}
// 14 · a large real UI view for questions about link handling.
{
 const s=base(14,'备查：链接专项检查画面','默认保留来源、行号、原始目标和检查原因');
 image(s,'links.png',242,205,964,429,{left:0.2,top:0.3,right:0,bottom:0.15});
 txt(s,'预置坏链已定位；未联网检查的外链保持未确认。',242,651,964,31,22,C.muted);
}
// Scope and arithmetic checks precede all exports.
if(p.slides.items.length!==14)throw new Error('Expected 14 slides');
if(facts.summary.RUN_VERIFIED!==26||facts.summary.COMPILE_ONLY!==2||facts.summary.TOTAL!==28)throw new Error('Current matrix changed');
if(facts.by_sdk.reduce((sum,x)=>sum+x.total,0)!==28)throw new Error('Matrix arithmetic mismatch');
const banned=/初赛|36\s*\/\s*40|655|\b123\b|49e8074|075aeb3|Qwen|qwen|bbox|准入|证据|快照|演示/;
for(const slide of content.slides)if(banned.test(JSON.stringify(slide)))throw new Error('Excluded wording in content: '+slide.index);
await fs.mkdir(path.join(build,'draft'),{recursive:true});await fs.mkdir(path.join(build,'previews'),{recursive:true});await fs.mkdir(path.join(build,'validated'),{recursive:true});
const rev=process.env.DECK_REV||'01';const candidate=path.join(build,'draft',`deck-${rev}.pptx`);
await (await PresentationFile.exportPptx(p)).save(candidate);
for(const [index,slide] of p.slides.items.entries()){
 const png=await p.export({slide,format:'png',scale:1});await fs.writeFile(path.join(build,'previews',`slide-${String(index+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));
 const layout=await slide.export({format:'layout'});await fs.writeFile(path.join(build,'previews',`slide-${String(index+1).padStart(2,'0')}.json`),await layout.text());
 console.log('Rendered slide',index+1);
}
const finalPath=path.join(build,'validated',`deck-${rev}.pptx`);
await finalizePresentation({workspaceDir:root,candidatePath:candidate,finalPath,pythonExecutable:runtimePython,integrityValidatorPath:path.join(skill,'container_tools/inspect_presentation_package_integrity.py'),layoutValidatorPath:path.join(skill,'container_tools/inspect_presentation_layout_geometry.py'),layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit',...[2,6,8,11,12].flatMap(n=>['--require-native-table-slide',String(n)])],fontPolicy:{basis:'design',families:[F]},explicitTotalSlideCount:14,requiredNativeTableOwnerSlides:[2,6,8,11,12],requiredNativeChartOwnerSlides:[6],materializeLiteralChartWorkbooks:true,verifyArtifactToolImport:true,receiptPath:path.join(build,`validation-${rev}.json`)});
await fs.writeFile(path.join(build,'last-final-path.txt'),finalPath+'\n');
console.log('Validated final:',finalPath);
