# CJ-DocGuard

**决赛当前入口：[评委克隆运行指南](docs/judge-quickstart.md) · [决赛源码与验证证据](submission/finals-2026-10-29/README.md) · [6～8 分钟PPT、讲稿与评委问答](submission/finals-2026-10-29/roadshow-v2/README.md)。源码冻结标签为 `finals-source-20261029-r2`；精确提交、测试结果及公开克隆回执见决赛证据目录。**

2026-10-07 的[四类初赛材料](submission/正式提交材料/README.md)继续归档，不能代替本轮网页功能与源码验证。

[AtomGit源码仓库](https://atomgit.com/c2892480843s/cj-docguard) · [演示视频](https://www.bilibili.com/video/BV1R5HC6MEDo/) · [参赛材料与模板](submission/README.md) · [独立AI贡献仓库](https://atomgit.com/c2892480843s/cj-docguard-ai)

**为仓颉 API 文档和示例提供实际运行证据；输入变化后拒绝把旧成功当作当前成功。**

适合库维护、发布检查、个人作品集和 AI 辅助编码。源码提取、配置、指纹、实际执行编排、准入判断、报告及本地 HTTP 服务均使用仓颉实现。Unix 进程组监督器使用 C；构建与启动使用 Bash；测试辅助和只读 MCP 协议适配使用 Python 标准库。核心没有模拟编译器或模型自评。

本轮决赛完整验证宿主为 **macOS arm64，仓颉 SDK 1.1.3 / 1.2.0**；历史版本另有 Ubuntu 22.04 Linux aarch64 工作流验证，范围与原始身份见 [Linux 验证](docs/linux-verification.md)，不能替代本轮 Linux 回归。Windows 暂不支持。可执行输入限于审核过的本地、单包项目；广泛第三方依赖、宏展开、完整语义推断不在首版支持范围。

## 本地网页工作台

先按[评委指南](docs/judge-quickstart.md)登记两版 SDK（软件开发工具包）并选择兼容的 Apple 系统 SDK。运行 `bash scripts/build_workbench.sh`，再运行 `bash scripts/workbench.sh --port 8765`，在浏览器打开 `http://127.0.0.1:8765`。正式 HTTP（网页请求服务）进程由仓颉实现。工作台支持接口检索、示例测试、SDK 测试矩阵、任务管理、链接检查、历史对比、测试结果查询、源码编辑、配置管理和示例包导出；默认使用独立演示副本。网页使用离线内置中文黑体，[仪表盘新版页面与检查记录](docs/ui/2026-10-29-dashboard/README.md)列出实际操作及截图。

[仓颉原生服务指南](docs/native-workbench.md) · [服务迁移验收](docs/native-workbench-verification-2026-10-29.md) · [链接与真实库修复验收](docs/links-unicode-verification-2026-10-29.md) · [工作台完整指南](docs/workbench.md)说明首次运行、故障演示、系统 SDK 选择、证据边界和验收方法。原有静态报告继续作为离线快照使用。

## 决赛三项功能修复

| 问题 | 当前实现与回归入口 |
|---|---|
| F01 实际索引链接漏检 | 扫描生成 HTML 的真实 `href`、`src` 等静态 URL，按索引文件所在目录解析，保留预期 API 锚点检查；[原生回归](tests/native_index.cj)与 CLI/HTTP 回归覆盖文件和锚点损坏 |
| F02 多行 Setext 标题锚点错误 | 按完整标题段落生成锚点，处理容器及重复标题；[链接解析回归](tests/native_links.cj) |
| F03 同名成员和重载示例错绑 | 先解析完整符号目录，再以所属类型、限定名或精确符号 ID 绑定；歧义/未知绑定明确拒绝成为证据；[绑定回归](tests/test_bindings.py) |

HTML 候选集合、重复属性或 `<base>` 等无法可靠解释的情况明确为 `UNVERIFIED`（未验证）；离线外链也不宣称可访问。完整范围见[决赛迭代说明](docs/finals-iteration-2026-10-29.md)。

## 评审与真实库复用

[六项评分证据索引](docs/rubric-evidence.md)提供源码、测试、资源控制、实用案例和完成度的直接入口。[10页答辩PPT](submission/CJ-DocGuard-初赛答辩-亲切手绘版-20261007.pptx)为可编辑辅助材料，[真实库接入教程](docs/real-library-walkthrough.md)与[验证附件](submission/CJ-DocGuard-真实库复用证据-20261007.zip)展示固定leven4cj的40格双SDK检查和有效单例导出重建。该初赛附件保留原版36格有效、4格断言失败和严格检查返回1。决赛增加显式本地 Unicode（字符码点）修复副本：原版仍保留36/40，修复副本预期40/40，不修改断言或上游缓存；[修复与复现说明](docs/real-library-unicode-repair-2026-10-29.md)及本轮实际结果见决赛证据。有效单例的两版重建输出一致。输入变化后当前查询和导出拒绝旧成功。[架构审阅](docs/architecture.md)、[需求完成度](docs/requirements-status.md)和[贡献指南](CONTRIBUTING.md)说明支持范围及参与方法。

## 测试与验证证据速览

**本轮完整回归、真实 HTTP 工作流和公开克隆验收的精确结果，以[2026-10-29 决赛证据](submission/finals-2026-10-29/README.md)为准。** 以下为有固定身份的历史基线和样本口径；不同测试的断言数不可相加为普遍准确率。

| 证据 | 历史基线 / 样本口径 |
|---|---|
| 仓颉原生模块断言（每个 SDK 独立执行） | 基础 86 项、AST 提取 37 项、报告 43 项、平台 46 项 |
| 核心完整回归（R05 冻结源码） | 80 项 Python 通过，零跳过；双 SDK 共 14 个原生程序通过；2026-10-07 R05 记录，非本轮决赛套件 |
| 导出包真实复现 | 26 个当前有效格全部导出、编译运行，登记断言匹配；2 个仅编译格拒绝导出 |
| 健康样本执行矩阵 | 14 个登记例 × 2 个真实 SDK＝28 格：26 格运行验证、2 格明确仅编译 |
| 提取覆盖 | 健康样本 47 个公共符号，含位置/注释/重载/泛型边界 |
| 第三方固定版本接入 | 3 个授权开源项目、60 个不同调用 × 2 SDK＝120 格：36 当前有效、4 当前断言失败、40 运行过但输入未知、40 真实编译失败；不宣称采用 |
| Linux 原生工作流 | 双 SDK 49 条实际命令按预期完成，含矩阵、严格检查、查询及导出重建；非完整 Python 套件 |
| AI 成对试验 | 30 对、60 次独立生成：功能均 30/30，综合基础组 30/30、证据组 29/30；未见提升 |
| 负向场景 | 过期输入、验证中修改、取消、缺日志、最新失败优先、严格退出码均有实测记录 |

## 快速运行

需要 Python 3.11.4+、系统 C 编译器和对应官方仓颉 SDK（本机实测 Python 3.14.6）。不要将 SDK 放进待扫描示例目录。

```bash
# 已有 SDK：分别指向含 bin/cjc 的根目录。
export CJ_DOCGUARD_SDK_1_1_3=/absolute/sdk-1.1.3/cangjie
export CJ_DOCGUARD_SDK_1_2_0=/absolute/sdk-1.2.0/cangjie

# 没有 SDK 时可执行；仅支持 macOS arm64，约需数百 MB 下载。
python3 scripts/install_sdk.py --sdk 1.1.3
python3 scripts/install_sdk.py --sdk 1.2.0

python3 scripts/dev.py probe --sdk 1.1.3
python3 scripts/dev.py build
python3 scripts/dev.py run -- doctor --config examples/healthy/docguard.toml
python3 scripts/dev.py run -- verify --config examples/healthy/docguard.toml --matrix
python3 scripts/dev.py run -- check --config examples/healthy/docguard.toml --strict
python3 scripts/dev.py run -- query --config examples/healthy/docguard.toml \
  --tool get_verified_examples --symbol add --sdk 1.1.3 --platform Darwin-arm64
```

已有 SDK 与自动安装是两种设置方法，任选一种。开发脚本也会识别上级工作区 `.toolchains/<版本>/cangjie`。`run --` 后的参数原样交给原生程序，避免开发脚本与产品的 `--sdk` 混淆。

报告位于 `examples/healthy/.docguard/site/index.html`，直接在自己的浏览器打开即可离线使用；同时生成 `api.json`、`manifest.json`、`report.json`、`report.md`。查看源码、按名称/包名搜索、SDK 矩阵、断言、完整记录和诊断都在同一页面。**静态页面是生成时的快照，当前性必须重新查询或检查。**

健康样本包含 47 个公共符号、14 个登记示例、两个实际 SDK 共 28 格。13 个运行示例每个版本均有输出/退出码断言；另 1 个只检查编译，明确标为 `COMPILE_ONLY`。自建样本不代表第三方采用。

## 接入自己的项目

```bash
python3 scripts/dev.py run -- init --project /absolute/project
# 编辑 /absolute/project/docguard.toml，登记真实源码、示例、SDK 和预期值。
python3 scripts/dev.py run -- build --config /absolute/project/docguard.toml
```

初始化不会覆盖现有配置或 `docguard-demo`，默认 `trusted=false`、`closed_inputs=false`。只有维护者审核源码、示例、外部输入和断言之后才设置这两个字段。`trusted` 允许本地执行；`closed_inputs` 是对审核范围的声明，不能替代依赖审查。源码目录与输出目录必须互不包含，因此 `sources=["."]` 不支持；选择具体源码目录或文件。

配置使用受限 TOML（可读的配置文件格式）：字符串、布尔、十进制整数、字符串数组、普通表和数组表。复杂 TOML、未知字段、重复 ID、逃逸路径和输出重叠会被拒绝。完整配置见 [健康样本](examples/healthy/docguard.toml)。

```toml
[project]
name = "My library"
sources = ["src"]
documents = ["README.md"]
output = ".docguard"
trusted = true
closed_inputs = true
exclude = []

[[sdks]]
version = "1.1.3"
# home 可省略，使用 CJ_DOCGUARD_SDK_1_1_3。

[[examples]]
id = "add"
file = "examples/add.cj"
symbol = "add"
kind = "program"
mode = "run"
stdout = "3\n"
expected_exit = 0
timeout_ms = 10000
required = true
```

只执行显式登记的例子；不会执行 README 中任意代码块。片段必须登记 `kind="snippet"` 和带 `{{code}}` 的包装模板，原始片段与实际包装源码均留存。每个例子与库源码须属于同一包，直接由 cjc 一起编译；首版不自动 cjpm 下载依赖或跨包构建。

默认审核的标准库导入白名单为 `std.core`、`std.collection`、`std.math`、`std.sort`、`std.convert`。其他导入、宏/条件编译/扩展等未支持结构使闭包未知：可以展示真实执行记录，但不会进入当前有证据查询。无法确定类型时明确显示 `TYPE_UNKNOWN`，不编造推断结果。

## 命令与状态

| 命令 | 行为 |
|---|---|
| `init --project DIR` / `init --config FILE` | 创建配置及显式演示；不执行 |
| `doctor --config FILE` | 实际 SDK 身份、平台、环境与内容指纹 |
| `build --config FILE` | 生成文档；退出 0 不代表示例验证通过 |
| `verify --config FILE [--sdk VERSION / --matrix]` | 独立编译与运行，追加尝试，前后复核当前输入 |
| `check --config FILE --strict` | 重新读取输入/环境，检查必需结果及链接 |
| `query --tool ... --config FILE` | 当前符号或满足准入条件的运行证据 |
| `evidence --example ID --sdk VERSION --platform OS-ARCH --config FILE` | 当前证据查询的快捷命令 |
| `export --config FILE --example ID --sdk VERSION --platform OS-ARCH --out DIR` | 将当前有效的单例证据和冻结源码导出为可运行目录 |
| `history --report REPORT.json [--example ID] [--sdk VERSION]` | 显式读取归档，统一标为 `FROZEN`、`eligible=false` |
| `diff --old A.json --new B.json` | 对比两个固定报告的输入、状态和符号变化 |

参数必须适用于所选命令。无效参数、重复参数和 `init` 同时指定 `--project` / `--config` 会返回 `2`；命令不再静默忽略其他命令的参数。选择当前查询项目使用 `--config FILE`；`--project` 仅用于初始化。`evidence` 固定查询运行证据，不接受 `--tool`。

严格门禁的退出码：`0` 必需范围满足，`1` 失败/过期/未知/跳过/未执行或链接问题，`2` 配置/环境/工具错误。`--sdk` 只限制本次执行范围，严格门禁仍检查配置的完整目标矩阵；只执行一个版本时，其他必需格未验证会返回 1。

验证状态与输入匹配状态分别记录。只有最新登记尝试满足 `RUN_VERIFIED + COMPLETED + CURRENT + 实际SDK/平台一致 + 完整证据 + 必需断言通过`，才能返回 `eligible=true`。无断言、仅编译、过期、未知、缺日志、较新失败或进行中的尝试均不返回旧成功。

`.docguard/attempts` 保存尝试，`.docguard/evidence` 保存真实有界日志和控制结果，`.docguard/snapshots` 保存原始冻结输入。已完成尝试不会被下一次验证覆盖。输入变化采取全项目保守失效；不按修改时间缓存 SDK 身份，工具内容同大小、同时间被修改也会失效。输出、`.git`、`target`、`.env*` 等明确排除；项目外依赖不自动被视为封闭。

查询会产生私有环境探针日志和互斥保留目录，但不执行项目示例、不修改项目源码。多个命令串行执行。中断留下 `writer.lock` 时先确认没有活动验证进程；维护者再删除该保留目录。工具不会自动清除它或回退到旧成功。

## 导出可运行示例包

先用精确 SDK 与平台查询确认示例 `eligible=true`，再导出：

```bash
python3 scripts/dev.py run -- export --config examples/healthy/docguard.toml \
  --example arithmetic --sdk 1.1.3 --platform Darwin-arm64 \
  --out build/export-smoke/arithmetic
cd build/export-smoke/arithmetic
CJ_SDK_HOME=/absolute/sdk-1.1.3/cangjie bash build.sh
```

`--out` 相对路径从 CLI 当前工作目录解析；拒绝 `..` 相对穿越、符号链接、源码或私有输出重叠及非空目录。导出包含冻结源码、实际编译单元、运行脚本和 `manifest.json` 证据清单。仅 `RUN_VERIFIED`、`CURRENT`、证据完整且断言通过的单包示例可导出；拒绝时不留下导出文件。**证据只证明登记断言在记录环境下通过；输入或环境变化后须重新查询。**

## AI 只读复用

MCP（模型上下文协议）只开放 `list_symbols`、`get_verified_examples`、`get_evidence`。证据查询必须指定 SDK 与实际平台，没有匹配结果返回空和拒绝原因，不跨版本回退。

```bash
python3 scripts/mcp_stdio.py \
  --binary /absolute/cj-docguard/build/cj-docguard \
  --config /absolute/project/docguard.toml
```

启动适配器时设置 `CJ_DOCGUARD_RUNNER=/absolute/cj-docguard/build/cjdg-runner`、SDK 注册变量及对应运行库环境，或使用 `scripts/dev.py` 的 `sdk_env()` 启动。协议入口固定项目和程序，不接受任意路径、命令、验证或构建工具。使用指南见 [Skill](skills/cj-docguard/SKILL.md)，可复制到自己的助手技能目录；未自动安装到全局配置。

申请AI生态贡献的独立分发见 [cj-docguard-ai](https://atomgit.com/c2892480843s/cj-docguard-ai)，含Skill、只读适配器、配置示例、提示模板、复现工作流及公开实测日志。[贡献申请说明](docs/ai-ecosystem-contribution.md)列明源码依赖、运行方法和评审边界。本轮在固定主仓库提交`8a886f7`完成14项MCP测试（13协议单元、1真实原生集成，零跳过）、双SDK自建样例验证与导出重建；独立分发的13项协议单元另行通过。未新增模型效果实验或外部采用证据。

## 测试与证据

```bash
python3 scripts/test.py
node tests/test_workbench_ui.mjs
# 仅双 SDK 原生模块测试：
python3 scripts/test.py --native-only
# 可选：结构与脚本逻辑检查（需要显式 Node 路径；不代替浏览器验收）
python3 scripts/check_report_site.py examples/healthy/.docguard/site/index.html --node /absolute/path/to/node
# 可复验的第三方固定版本接入（首次需要网络）：
python3 scripts/real_projects.py --fetch
```

输出保存在 `build/test-results`。原生模块覆盖 JSON/TOML/SHA、AST 提取、证据筛选、报告和平台执行；集成测试通过真实编译器验证错误分类、输入变更、验证中修改、取消、日志完整性、最新尝试优先和严格退出码。MCP 单元测试使用明确标注的协议替身，另有真实 CLI 查询测试，二者分开记录。

参见 [持续优化与最新验证](docs/optimization-log.md)、[0.1.0 基线验证](docs/verification.md)、[验收映射](docs/acceptance.md)、[真实项目接入](docs/real-projects.md)、[工具链来源](docs/toolchains.md)、[支持范围](docs/support.md)、[演示与提交材料](docs/submission.md)。

## 已知边界

这是经审核项目的开发工具。进程组超时、取消和后代清理不构成操作系统安全沙箱。默认编译 60 秒、运行 10 秒、每个输出流 1 MiB；超时、截断或日志损坏不得晋升通过。

SDK 指纹覆盖实际编译器、工具、模块、库、运行时和受控环境，未遍历整个操作系统或 Apple 系统 SDK；结果依赖审核时固定的宿主环境。报告会映射已知项目/SDK 私人路径；原始归档保持实际证据，公开前仍需按项目权利与内容审核。

已执行一轮 AI 对照实验，未观察到提升，详见 [实验说明](docs/ai-evaluation.md)。[AtomGit源码仓库](https://atomgit.com/c2892480843s/cj-docguard) 提供完整代码、配置、示例与测试。[参赛材料](submission/README.md) 包含填写后的统一模板公开副本、未签字PDF预览、验证附件及视频入口；私人完整模板与旧材料保留在本地。视频依据真实命令日志制作约2分58秒的解释性动画，并沿用可爱合成配音。签字和赛事正式提交尚待完成。

许可证：[Apache-2.0](LICENSE)。上游接入项目保留各自许可证，未重新许可其源码。

2026-10-07提交材料入口：[B站演示视频](https://www.bilibili.com/video/BV1R5HC6MEDo/) 与 [提交材料索引](docs/submission-index.md)。视频链接由负责人提供；本地申报书副本已补链接，尚无比赛提交回执。
