# 原生报告模块实施报告

日期：2026-10-06。任务范围仅为 `src/report.cj`、`tests/native_report.cj` 与本报告；未修改其他模块，未提交 Git。当前平台已通过 `uname` 与实际编译器确认：macOS / arm64，编译目标 `aarch64-apple-darwin`。

## 实现结果

公开入口：`writeReports(output: String, report: J): Unit`，包名 `docguard`。生产渲染与文件写入全部由仓颉原生实现；前端仅有固定的离线过滤脚本。

| 输出 | 内容 |
|---|---|
| `api.json` | 输入报告的 `api` 对象，保留符号、诊断与文件字段 |
| `report.json` | 完整输入报告，保留未知扩展字段，不改写验证状态或 freshness |
| `manifest.json` | 输入清单、指纹和闭包信息 |
| `report.md` | 中文接口、示例、SDK结果、原始证据、链接与诊断报告 |
| `site/index.html` | 独立离线网站，CSS和搜索脚本均内联，JSON/Markdown为本地相对链接 |

缺字段使用“未提供”，不存在的数组使用空集合；缺失记录不会被填充成验证成功。可以重复向同一输出目录写入，也可以创建不存在的多级目录。渲染全部内容完成后才开始文件写入，格式错误在写入前报错；文件系统故障仍可能造成部分写入，本模块未声明原子发布。

## 页面与内容

采用纸色背景、深色导航、青色证据状态、清晰间距和系统字体；适配窄屏，保留焦点样式、表头、输入标签与减少动画偏好。

- 首屏常驻 **“冻结的静态快照”**、生成时间、输入指纹、引擎及数据版本。
- 明确注明 **“不能证明当前仓库状态”**，`CURRENT` 仅表示报告生成时记录的输入匹配情况；页面不重新计算 freshness（输入与记录是否匹配）。
- API（公共接口）卡片展示名称、包、类型、所属对象、声明、参数、返回值、源码位置、符号ID、注释和关联示例。
- 按名称/包名离线搜索，支持大小写归一、空白处理、匹配计数、无结果提示和清空恢复。
- SDK（仓颉开发工具包）矩阵保留同一示例/SDK的每条尝试；不选择历史成功遮盖较新失败或取消。展示状态与输入匹配情况。
- 状态计数既保留常见状态的0计数，也保留未知扩展状态的原值与数量。
- 每条尝试展示SDK、平台、尝试ID、序号、原因、编译/运行退出码、命令参数、超时/截断标记、标准输出/错误输出、断言与完整原始JSON。
- 包含环境指纹/工具链原始信息、工程/接口诊断、接口文件、输入闭包及链接检查。
- 链接目标匹配符号ID时，生成的HTML片段锚点与 `symbols.id` 完全一致。外部或未匹配目标仅作为文本呈现。

## 内容安全

所有用户字符串进入HTML之前统一转义 `&`、`<`、`>`、单双引号；包括文本、属性、源码声明、日志、原始JSON和注释。用户内容没有拼入脚本。搜索脚本使用静态选择器、`dataset`、`hidden` 和 `textContent`，没有使用 `innerHTML`、网络请求或字符串执行。

Markdown中的用户内容同时转义HTML与影响Markdown解释的标记，原始记录放入转义的 `<pre>`，避免代码围栏被用户文本关闭。HTML没有CDN（外部静态资源网络）、`fetch`或外部字体依赖。

## 测试先行与原生验证

1. 先编写原生报告测试，再放入只输出空对象的占位渲染器。
2. 真实编译运行后观察预期失败：`Exception: FAIL report: full JSON artifact`。
3. 实现原生渲染器，逐步增加缺字段、属性引号、伪造HTML元素、脚本闭合片段、取消/过期/未知状态及未来扩展字段的保留检查。
4. SDK1.1.3、1.2.0分别重新编译运行最终测试；均 **34个断言通过，退出码0**。

```sh
# 在 cj-docguard 项目目录执行；改为1.2.0可验证第二套SDK。
export CANGJIE_HOME="$(cd .. && pwd)/.toolchains/1.1.3/cangjie"
export PATH="$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:$PATH"
export DYLD_LIBRARY_PATH="$CANGJIE_HOME/runtime/lib/darwin_aarch64_cjnative"
export SDKROOT="$(xcrun --show-sdk-path)"
cjc --version
cjc src/primitives.cj src/report.cj tests/native_report.cj -Woff unused -o /tmp/docguard-native-report
/tmp/docguard-native-report
```

最终输出：

```text
Cangjie Compiler: 1.1.3 (cjnative)
Target: aarch64-apple-darwin
PASS native report: 34 assertions; files, snapshot, escaping, evidence, offline search
Cangjie Compiler: 1.2.0 (cjnative)
Target: aarch64-apple-darwin
PASS native report: 34 assertions; files, snapshot, escaping, evidence, offline search
```

测试输出放在 `/tmp/cj-docguard-native-report`，包含完整夹具、缺字段和恶意HTML夹具的三个站点。

## 本地结构与脚本验证

另用 Python标准库 `HTMLParser` 检查实际生成文件：只有一个固定脚本、没有外部资源、锚点目标存在、ID不重复、没有外部/`javascript:`链接，名称/包属性解析后保持原始文字。恶意 `</script><script>` 在普通文本节点中，没有生成第二个脚本；伪造 `<img>` 没有生成元素。

将实际生成的固定搜索脚本置于 Node `vm`（独立JavaScript执行上下文）中，用最小DOM接口对象验证名称、包名、大小写、首尾空白、无匹配和清空过滤。这是脚本逻辑验证，不是浏览器布局验证。

可复验脚本逻辑：

```sh
node <<'JS'
const fs = require('fs');
const vm = require('vm');
const html = fs.readFileSync('/tmp/cj-docguard-native-report/site/index.html', 'utf8');
const scripts = Array.from(html.matchAll(/<script>([\s\S]*?)<\/script>/g));
if (scripts.length !== 1) throw Error('unexpected script count');
const cards = [{ dataset: { name: '文档函数', package: 'demo.docs' }, hidden: false }];
let callback;
const input = { value: '', addEventListener: (event, fn) => { callback = fn; } };
const count = { textContent: '' };
const empty = { hidden: true };
const nodes = { 'api-search': input, 'search-count': count, 'search-empty': empty };
const document = { getElementById: id => nodes[id], querySelectorAll: () => cards };
vm.runInNewContext(scripts[0][1], { document });
for (const q of ['文档', 'DEMO.DOCS', '  demo.docs  ']) {
  input.value = q; callback();
  if (cards[0].hidden || !empty.hidden) throw Error('match failed');
}
input.value = 'missing'; callback();
if (!cards[0].hidden || empty.hidden || count.textContent !== '0 / 1 个接口') throw Error('empty failed');
input.value = ''; callback();
if (cards[0].hidden || count.textContent !== '1 / 1 个接口') throw Error('clear failed');
console.log('PASS local fixed-script verification: name/package/case/trim/no-match/clear');
JS
```

## 验证边界

**实际浏览器布局/交互未验证**：当前浏览器工具的安全策略拒绝 `file:///` 协议，且明确禁止通过HTTP、替代浏览器、间接执行或其他绕行实现同一访问。按要求停止该访问路径，仅做本地原生、结构与脚本验证，未绕过拒绝。

报告只呈现引擎传入的证据；状态判定、最新尝试选择、指纹计算、执行与权限边界仍属于引擎。完整项目集成由根任务继续验证。本任务三个文件经检查均为UTF-8无BOM。

## 最终集成修复与回归

集成复验在 28 格矩阵的 `rAttempts` 可变集合遍历中复现 `ConcurrentModificationException`。原 CLI 在同一独立目录稳定返回 2；渲染改为固定数组快照后，SDK 1.1.3 / 1.2.0 编译的完整 CLI 共六次构建均返回 0。此对照证明已知报告失败的兼容修复有效，未证明 SDK 内部的异常原因。原始失败与实际尝试记录保留，没有用重试隐藏失败或回退放行。

最终原生报告测试为每 SDK **40 项断言**，新增 384 条历史与 28 格前后连续渲染、结果保留、源码 `path/code` 与 `source/code` 可达锚点及转义。接口搜索另限定 `#api-list .api-card`，避免源码卡片被计数或隐藏。独立结构/脚本回归见 `scripts/check_report_site.py`：原页面失败 `source cards counted as APIs`，修正后接口与源码分别计数，名称/包名/大小写/空白/空匹配/恢复检查通过。

```bash
python3 scripts/check_report_site.py examples/healthy/.docguard/site/index.html --node /absolute/path/to/node
```

这条命令只读取本地 HTML 并在 Node 的隔离脚本上下文检查逻辑；不启动浏览器，也不证明页面布局。
