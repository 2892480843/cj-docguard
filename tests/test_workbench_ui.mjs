// Pure renderer regression checks; run with: node tests/test_workbench_ui.mjs
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
const source=await readFile(new URL('../web/views.js',import.meta.url),'utf8');
const V=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const report=JSON.parse(await readFile(new URL('./fixtures/workbench-report.json',import.meta.url),'utf8'));
const examples=[...new Map(report.api.symbols.flatMap(x=>x.examples||[]).map(x=>[x.id,x])).values()];
const state={report,examples,project:{id:'demo',name:'测试',demo:true,sdk_versions:['1.1.3']},history:report.history||[],jobs:[],search:'',kind:'',sdk:'',status:'',platform:'Darwin-arm64'};
for(const populated of [false,true]){
 const s={...state,report:populated?report:null,examples:populated?examples:[],history:populated?state.history:[]};
 for(const name of ['overview','apiView','examplesView','matrix','tasks','issues','history','ai','sourceView','settings'])assert.ok(V[name](s).length,`${name} ${populated}`);
}
const selected=report.api.symbols.find(x=>x.name==='multiply').id;
assert.match(V.apiView({...state,selected,search:'greet'}),/<h2>greet<\/h2>/);
assert.doesNotMatch(V.apiView({...state,selected,search:'greet'}),/<h2>multiply<\/h2>/);
assert.doesNotMatch(V.apiView({...state,selected,search:'__no_match__'}),/两个整数相乘/);
assert.match(V.apiView({...state,selected,search:'__no_match__'}),/无匹配接口/);
assert.doesNotMatch(V.apiView({...state,selected,search:'__no_match__'}),/尚无接口索引/);
const detail=V.apiView({...state,selected});
assert.match(detail,/参数/);assert.match(detail,/返回类型/);assert.match(detail,/Int64/);
const diagnostic={source:'src/a.cj',line:4,rule:'test',message:'同一诊断'};
assert.equal(V.issueItems({diagnostics:[diagnostic,diagnostic],api:{diagnostics:[diagnostic]}}).length,1);
assert.equal(V.issueItems({api:{diagnostics:[diagnostic]},manifest:{diagnostics:[diagnostic]}}).length,1);
for(const value of ['UNSUPPORTED','NOT_RUN','STALE','cancelled','NOT_VERIFIED','PASS_UNKNOWN'])assert.doesNotMatch(V.badge(value),/badge good/);
for(const value of ['RUN_VERIFIED','PASS','SUPPORTED','succeeded'])assert.match(V.badge(value),/badge good/);
const injection='<img src=x onerror=alert(1)>';
assert.doesNotMatch(V.button(injection,'result'),/<img/);
assert.match(V.button(injection,'result'),/&lt;img/);
assert.doesNotMatch(V.badge(injection),/<img/);
assert.doesNotMatch(V.apiView({...state,report:{api:{symbols:[{id:'x',name:injection,parameters:[],examples:[],source:'a',declaration:injection}],files:[]}}}),/<img/);
assert.match(V.history(state),/download-report/);
const largeReport={...report,history:Array(30).fill({stdout:'x'.repeat(100000)})};
assert.ok(Buffer.byteLength(JSON.stringify(largeReport))>2*1024*1024);
const compact=JSON.parse(JSON.stringify(largeReport,(key,value)=>['history','stdout','stderr','code'].includes(key)?undefined:value));
assert.ok(Buffer.byteLength(JSON.stringify({old:compact,new:compact}))<2*1024*1024);
// UI repair regressions: readable dates, snapshot breakdown, resilient partial reports.
assert.equal(V.time('not-a-date'), '时间未记录');
assert.match(V.overview(state), /运行测试通过记录占比/);
assert.match(V.overview(state), /仅编译/);
assert.doesNotThrow(()=>V.apiView({...state,report:{...report,api:{symbols:report.api.symbols}}}));

assert.match(V.ai(state), /type="submit"[^>]*data-action="query"/);
assert.match(V.settings(state), /type="submit"[^>]*data-action="save-config"/);
console.log('Workbench UI: 20 render scenarios plus search, status, escaping, dates, partial reports, progress and submit regressions passed.');
// Native service identity is opt-in; legacy backends never expose write controls.
assert.match(V.serverIdentity(state),/尚未确认/);
assert.doesNotMatch(V.serverIdentity(state),/服务端：Cangjie/);
const native={...state,implementation:'Cangjie',capabilities:{native_server:true},report:{...report,manifest:{files:[{path:'src/a.cj'},{path:'README.md'},{path:'src/a.cj'}]}}};
assert.deepEqual(V.sourceFiles(native),['src/a.cj']);
assert.match(V.sourceView(state),/当前服务未提供源码编辑/);
assert.doesNotMatch(V.sourceView(state),/save-source/);
assert.match(V.sourceView(native),/data-key="src\/a.cj"/);
const draft={path:'src/a.cj',content:'<script>changed</script>',original:'original',sha256:'abc',saved:false};
const editor=V.sourceView({...native,sourceDraft:draft});
assert.match(editor,/未保存修改/);assert.match(editor,/expected|检查文件内容校验值/);
assert.match(editor,/original/);assert.match(editor,/&lt;script&gt;/);assert.doesNotMatch(editor,/<script>/);
assert.match(editor,/type="submit"[^>]*data-action="save-source"/);
assert.match(editor,/source-reload/);
assert.match(V.apiView(native),/source-open/);
const q={tool:'get_evidence',sdk_version:'1.1.3',platform:'Darwin-arm64',items:[],rejected:[{example_id:'a',status:'STALE',reason:'source changed'}]};
assert.match(V.querySummary(q),/0 条有效记录/);assert.match(V.querySummary(q),/源码已变化/);
assert.match(V.querySummary(q),/Darwin-arm64/);
assert.doesNotMatch(V.querySummary({tool:'list_symbols',items:[{}]}),/1 条有效记录/);
const workflow=V.workflow({...native,jobs:[{id:'real-job',project_id:'demo',action:'verify',status:'failed'}]});
assert.match(workflow,/real-job/);assert.match(workflow,/badge bad/);assert.match(workflow,/服务端：Cangjie/);
console.log('Native frontend identity, source capability gate/editor, workflow provenance, and query summary regressions passed.');
// Recovery requires explicit server capability and a positive inspection result.
assert.equal(V.lockRecovery(state),'');
const recovery={...native,capabilities:{native_server:true,lock_recovery:true}};
assert.match(V.lockRecovery(recovery),/inspect-lock/);
assert.doesNotMatch(V.lockRecovery(recovery),/data-action="recover-lock"/);
for(const lockState of [{exists:false,recoverable:false,reason:'no lock'},{exists:true,recoverable:false,reason:'owner alive'},{exists:true,recoverable:'true',reason:'invalid type'}]){
 assert.doesNotMatch(V.lockRecovery({...recovery,lockState}),/data-action="recover-lock"/);
 assert.match(V.lockRecovery({...recovery,lockState}),new RegExp(lockState.reason));
}
const recoverable=V.lockRecovery({...recovery,lockState:{exists:true,recoverable:true,reason:'owner exited'}});
assert.match(recoverable,/name="acknowledge" required/);
assert.match(recoverable,/type="submit"[^>]*data-action="recover-lock"/);
assert.match(recoverable,/owner exited/);
assert.match(V.settings(recovery),/中断任务恢复/);
assert.doesNotMatch(V.settings(state),/中断任务恢复/);
console.log('Explicit capability-gated lock inspection and recovery rendering regressions passed.');
// A job may finish during manual refresh or before its first poll. Both must
// refresh the report once, without requiring a previously observed running state.
const interactionSource=await readFile(new URL('../web/interaction.js',import.meta.url),'utf8');
const I=await import('data:text/javascript;base64,'+Buffer.from(interactionSource).toString('base64'));
const seen=new Set(['historical']);
const finished=[{id:'historical',status:'succeeded'},{id:'verify',status:'succeeded'},{id:'query',status:'running'},{id:'cancel',status:'cancelled'}];
assert.deepEqual(I.unhandledCompletedJobs(finished,seen).map(j=>j.id),['verify','cancel']);
seen.add('verify');seen.add('cancel');
assert.deepEqual(I.unhandledCompletedJobs(finished,seen),[]);
assert.deepEqual(I.unhandledCompletedJobs([{id:'query',status:'failed'}],seen).map(j=>j.id),['query']);
console.log('First-observed completion, manual refresh, cancellation and once-only report synchronization regressions passed.');
// All native link rows have an independent filter and keep report indices for details.
const links=[
 {from:'README.md',line:3,target:'docs/ok.md',status:'PASS',reason:'exists',syntax:'inline'},
 {from:'README.md',line:8,target:'missing.md',status:'FAIL',reason:'missing',syntax:'reference'},
 {from:'guide.md',line:9,target:'https://example.test/<img>',status:'UNVERIFIED',reason:'offline'},
];
const linkState={...state,report:{links},linkStatus:'',linkSearch:''};
const allLinks=V.linkResults(linkState);
for(const [status,count] of [['PASS',1],['FAIL',1],['UNVERIFIED',1]])assert.ok(allLinks.includes(`${V.statusLabel(status)} · ${count}`));
assert.match(allLinks,/README.md:3/);assert.match(allLinks,/data-action="job" data-key="check"/);
assert.equal((allLinks.match(/data-action="link-detail"/g)||[]).length,3);
assert.match(allLinks,/https:\/\/example.test\/&lt;img&gt;/);assert.doesNotMatch(allLinks,/<a |<img/);
const failedLinks=V.linkResults({...linkState,linkStatus:'FAIL',search:'unrelated',status:'RUN_VERIFIED'});
assert.equal((failedLinks.match(/data-action="link-detail"/g)||[]).length,1);
assert.match(failedLinks,/data-action="link-detail" data-key="1"/);
assert.match(failedLinks,/通过 · 1/); // totals stay report-wide
assert.doesNotMatch(V.linkResults({...linkState,linkSearch:'OFFLINE'}),/data-key="0"/);
assert.match(V.linkResults({...linkState,linkSearch:'OFFLINE'}),/data-key="2"/);
assert.match(V.linkResults({...linkState,linkStatus:'PASS',linkSearch:'missing'}),/没有匹配链接/);
assert.match(V.linkResults({...state,report:null}),/尚无链接检查报告/);
assert.match(V.linkResults({...state,report:{}}),/未记录链接/);
assert.match(V.linkDetail(links[0]),/inline/);
const failedRecord={status:'ASSERTION_FAILED',sdk_version:'1.2.0',platform:'Darwin-arm64',code:'<bad>',assertions:[{kind:'stdout',expected:'',actual:0,passed:false},{kind:'flag',expected:false,actual:false,passed:true}, {kind:'absent'}]};
const assertions=V.assertionTable(failedRecord);
assert.match(assertions,/<pre>&quot;&quot;<\/pre>/);assert.match(assertions,/<pre>0<\/pre>/);assert.match(assertions,/<pre>false<\/pre>/);
assert.match(assertions,/未记录/);assert.equal((assertions.match(/badge bad/g)||[]).length,1);
assert.match(V.failureSummary(failedRecord),/1.2.0/);assert.match(V.failureSummary(failedRecord),/ASSERTION_FAILED/);
console.log('All-link counts, scoped filters, safe text, original detail indices, empty reports and native assertion values passed.');
// Execute real app event handlers and detail dispatch with a minimal DOM boundary.
const {runInNewContext}=await import('node:vm');
const appSource=await readFile(new URL('../web/app.js',import.meta.url),'utf8');
const listeners={};let renders=0,focused=false;
const searchInput={focus(){focused=true},setSelectionRange(a,b){assert.equal(a,2);assert.equal(b,2)}};
const appContext={V,console,unhandledCompletedJobs:I.unhandledCompletedJobs,document:{addEventListener(name,fn){listeners[name]=fn},querySelector(selector){if(selector==='#evidence')return {addEventListener(){}};if(selector==='#link-search')return searchInput;return null}},window:{addEventListener(){}}};
runInNewContext(appSource.replace(/^import .*;\n/gm,'').replace(/render\(\);bootstrap\(\);\s*$/,''),appContext);
runInNewContext('render=()=>{testRender()};openEvidence=(type,key,data)=>{testOpen(type,key,data)};',Object.assign(appContext,{testRender(){renders++},testOpen(type,key,data){appContext.opened={type,key,data}}}));
runInNewContext('state.search="global";state.status="RUN_VERIFIED";state.sourceDraft={content:"draft"};state.report=testReport;',Object.assign(appContext,{testReport:{links}}));
listeners.change({target:{id:'link-status',value:'FAIL'}});
listeners.input({target:{id:'link-search',value:'missing',selectionStart:2}});
assert.equal(renders,2);assert.equal(focused,true);
assert.equal(runInNewContext('state.linkStatus',appContext),'FAIL');assert.equal(runInNewContext('state.linkSearch',appContext),'missing');
assert.equal(runInNewContext('state.search',appContext),'global');assert.equal(runInNewContext('state.status',appContext),'RUN_VERIFIED');assert.equal(runInNewContext('state.sourceDraft.content',appContext),'draft');
await runInNewContext('act("link-detail","0")',appContext);
assert.equal(appContext.opened.type,'link');assert.equal(appContext.opened.data.status,'PASS');
assert.equal(appContext.opened.data.target,'docs/ok.md');
// The actual dialog body uses readable assertion results for an issue and escapes code.
runInNewContext('state.drawer={type:"issue",data:testFailure};state.tab="logs";',Object.assign(appContext,{testFailure:failedRecord}));
const issueBody=runInNewContext('evidenceBody()',appContext);
assert.match(issueBody,/输出检查失败/);assert.match(issueBody,/1.2.0/);assert.match(issueBody,/ASSERTION_FAILED/);
runInNewContext('state.tab="code"',appContext);
assert.equal(runInNewContext('evidenceBody()',appContext),'<pre>&lt;bad&gt;</pre>');
console.log('Real link filter events preserve global filters/source drafts; PASS detail and native failure dialogs passed.');
// The panel dispatches the native check action and completion reloads actual report data.
let started,reportReloads=0;
appContext.testStart=action=>{started=action};
runInNewContext('startJob=async action=>testStart(action)',appContext);
await runInNewContext('act("job","check")',appContext);assert.equal(started,'check');
appContext.testJobs={items:[{id:'link-check-real',project_id:'demo',action:'check',status:'succeeded',exit_code:0}]};
appContext.testRequest=async path=>{if(path==='/api/jobs')return appContext.testJobs;throw new Error(path)};
appContext.testReload=async()=>{reportReloads++};
runInNewContext('state.project={id:"demo"};state.view="issues";request=testRequest;reloadReport=testReload;notify=()=>{};updateBusy=()=>{};',appContext);
await runInNewContext('refreshJobs()',appContext);await runInNewContext('refreshJobs()',appContext);
assert.equal(reportReloads,1);
console.log('Native check dispatch and once-only report refresh on link job completion passed.');
// Product wording applies to system copy in all ten populated and empty pages.
const renderers=['overview','apiView','examplesView','matrix','tasks','issues','history','ai','sourceView','settings'];
for(const populated of [false,true])for(const name of renderers){
 const html=V[name]({...native,report:populated?native.report:null,examples:populated?examples:[],history:populated?state.history:[]});
 assert.doesNotMatch(html,/证据|准入|快照|承诺|闭环|冻结/,`${name}: plain system copy`);
}
assert.deepEqual(V.navs.map(x=>x[2]),['项目概览','接口文档','示例测试','SDK 测试矩阵','任务中心','链接与问题','历史记录','测试结果查询','源码编辑','项目配置']);
assert.match(V.ai({...state,queryResult:q}),/<details><summary>完整 JSON/);
assert.doesNotMatch(V.ai(state),/>AI|人工智能/);
for(const [value,label] of [['COMPILE_ONLY','仅编译'],['CURRENT','未变更'],['STALE','需重测'],['RUN_VERIFIED','运行通过'],['FROZEN','历史记录'],['UNVERIFIED','未确认']]){
 assert.match(V.badge(value),new RegExp(`data-status="${value}"`));
 assert.ok(V.badge(value).includes(`>${label}</span>`));
}
assert.doesNotMatch(V.badge('COMPILE_ONLY'),/badge good|运行通过/);
assert.doesNotMatch(V.badge('CURRENT'),/运行通过/);
assert.match(V.badge(injection),/&lt;img/);
assert.match(V.matrix({...state,report:{results:[{example_id:'only',sdk_version:'test',status:'COMPILE_ONLY',freshness:'STALE'}]}}),/<option value="COMPILE_ONLY"[^>]*>仅编译<\/option>/);
assert.match(V.apiView(state),/<option value="function"[^>]*>函数<\/option>/);
for(const action of ['doctor','build','verify','check','export'])assert.match(V.tasks(state),new RegExp(`data-action="job" data-key="${action}"`));
for(const tool of ['list_symbols','get_verified_examples','get_evidence'])assert.match(V.ai(state),new RegExp(`option value="${tool}"`));
const queryRows=V.querySummary({...q,items:[{example_id:'ok',status:'RUN_VERIFIED'}],rejected:[{example_id:injection,status:'COMPILE_ONLY',reason:injection}]});
assert.match(queryRows,/1 条有效记录/);assert.match(queryRows,/1 条被拒绝/);assert.match(queryRows,/仅编译/);assert.doesNotMatch(queryRows,/<img/);
assert.match(V.overview(state),/源码或工具链变化后/);
assert.match(appSource,/aria-label="关闭详情"/);assert.match(appSource,/aria-label="详情内容"/);
assert.match(appSource,/源码或工具链变化后/);
assert.doesNotMatch(appSource,/证据|准入|快照|承诺|闭环|冻结/);
// The existing real-event harness must retain raw matrix filter values as well.
listeners.change({target:{id:'status',value:'COMPILE_ONLY'}});
assert.equal(runInNewContext('state.status',appContext),'COMPILE_ONLY');
listeners.change({target:{id:'kind',value:'function'}});
assert.equal(runInNewContext('state.kind',appContext),'function');
console.log('Twenty-page plain wording, translated labels with raw values, read-only query, changed/compile-only semantics and filter events passed.');
for(const unknown of ['__proto__','constructor','CUSTOM_STATUS']){
 assert.equal(V.statusLabel(unknown),unknown);
 assert.equal(V.actionLabel(unknown),unknown);
 assert.equal(V.reasonLabel(unknown),unknown);
}
// User-authored content remains verbatim (HTML-escaped), even when it uses product-avoided words.
const authored='用户注释：证据与快照 <script>';
assert.match(V.apiView({...state,report:{api:{symbols:[{id:'user',name:'user',comment:authored,parameters:[],examples:[]}],files:[]}}}),/用户注释：证据与快照 &lt;script&gt;/);
console.log('Unknown protocol strings and user-authored content remain intact and escaped.');

for(const [kind,label] of [['type_alias','类型别名'],['field','字段'],['enum_constructor','枚举值']]){
 const html=V.apiView({...state,report:{api:{symbols:[{kind,name:'item',parameters:[],examples:[]}],files:[]}}});
 assert.ok(html.includes(`<option value="${kind}" >${label}</option>`));
}
console.log('All native declaration type names have readable labels and unchanged filter values.');
// Completed query jobs display the same readable result table as the query page.
appContext.queryJob={id:'plain-query',action:'query',status:'succeeded',exit_code:0,result:q,stdout:'RAW_QUERY_OUTPUT',stderr:''};
runInNewContext('state.drawer={type:"job",data:queryJob};state.tab="logs";',appContext);
const queryJobBody=runInNewContext('evidenceBody()',appContext);
assert.match(queryJobBody,/0 条有效记录/);
assert.match(queryJobBody,/<details><summary>查看原始输出<\/summary><pre class="terminal">RAW_QUERY_OUTPUT<\/pre><\/details>/);
console.log('Completed query job shows readable results and collapses the original output.');
