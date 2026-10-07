# 持续优化记录

## 执行约定

从 2026-10-06 起已启用当前聊天的每小时跟进任务 `cj-docguard`。每轮完成一项可验证的改进；只在完成、失败或需要人工处理时通知。后续先读此文件、验收记录、待办和 Git 状态，接续未完成项并保留用户修改。

优先级：证据可靠性与命令/配置正确性 → 工作中复用与演示 → 真实项目例子 → 实测性能。平台以当轮实际探针为准；不保证奖项、不自动发布或提交参赛。

## R01：拒绝命令中被静默忽略的参数

- 日期：2026-10-06；实际环境：Darwin arm64 / macOS，zsh。
- 状态：**完成，构建、回归及当前证据刷新均通过**；未发布迭代。
- 问题：通用参数解析器接受所有命令的参数，操作层仅读取部分参数。例如 `query --project other-project` 仍使用当前配置，`evidence --tool list_symbols` 被覆写，帮助命令忽略额外参数；`init` 两种目标参数同时出现时静默选择 `--config`。
- 修复：在命令分派前校验各命令允许的参数，拒绝不适用项；初始化目标参数互斥。错误返回 `2`，校验失败不加载项目配置、不创建项目文件。
- 兼容性：此前被忽略的参数现在报错；选查询项目应指定 `--config`。未改变证据准入、矩阵分母或失败历史。
- 复现：新测试在旧程序上实际失败，11 个不适用参数场景及 1 个初始化目标冲突，共 12 个子用例失败，日志 `build/optimization-r01-red.log`。
- 针对性验证：`python3 -m unittest discover -s tests -p test_cli_metadata.py -v`，4 项通过、无跳过，14.356 秒；日志 `build/optimization-r01-green.log`。
- 构建：1.1.3 主程序与 1.2.0 完整程序均退出 0；1.2.0 另外通过 4 个实际运行检查（无效查询参数、初始化路径冲突、帮助、版本）。首次手工命令误写不存在的 `src/project.cj`，编译器在参数检查阶段退出 1；改为真实文件 `src/engine.cj` 后成功，不视作产品回归。
- 全面验证：`python3 scripts/test.py` 退出 0；两个 SDK 的 10 个原生测试程序通过，**41 项 Python 测试通过、无跳过，200.451 秒**。原始结果已另存 `build/optimization-r01/test-results/`，避免后续覆盖；汇总日志 `build/optimization-r01/suite.log`。
- 外部项目：仅从已审核固定提交的本地缓存重验，`python3 scripts/real_projects.py --cache ../.research/external`，调度脚本退出 0；三个项目原生退出码依次为 0、1、1。`leven4cj` 两格当前通过，`is-png-cj` 两格运行成功但未知，`compare-versions-cj` 两格编译失败；不能把调度脚本成功当成全部项目成功。新原始审计：`build/real-projects/20261006T124133721713Z/audit.json`。不拉取或发布，不宣称上游采用。
- 基线：0.1.0 固定源码包与证据包保留。此前 [验证记录](verification.md) 和 [干净目录复验](clean-reproduction.md) 属于旧二进制归档；当前性以本轮重验为准。

### 本轮当前证据

| 检查 | 实际结果 | 原始记录 |
|---|---|---|
| 健康矩阵重验 | 28 格均 `CURRENT`：26 `RUN_VERIFIED`、2 `COMPILE_ONLY`；47 个公共符号 | `build/optimization-r01/healthy-report.json` |
| 严格检查 | 退出 0 | `build/optimization-r01/strict.stdout` |
| 精确 1.1.3 / Darwin-arm64 查询 | 13 条有效运行证据；1 条仅编译项明确拒绝 | `build/optimization-r01/query.stdout` |
| 离线报告结构 / 搜索脚本 | 87 个唯一 ID、112 个链接；47 接口 / 1 源码卡片；退出 0 | `build/optimization-r01/site.stdout` |
| 历史保留 | 原 196 次保留，新增 197–224 次；总计 224 次 | 健康项目 `.docguard/attempts`、`evidence`、`snapshots` |

本轮主程序 SHA-256（内容摘要）：`ad8427075d7c01afeeec0b4135ab43d0898794e8883dfc20a7abaa10903aa52e`；1.2.0 构建：`5c76b970b3113942b9d808dc11af24acd6111d605df658c27e8be94da934b0fc`。健康报告生成时间 `2026-10-06T20:47:08.217198+08:00`，输入指纹 `de45e49728db3cbdc65042b1ff6a62cdfe8af0a5a5982d4a2bce2d95d0905d6d`。汇总、实际命令、退出码和核心源码摘要存于 `build/optimization-r01/summary.json`；之后核心程序或输入变化仍须重验。

## R02：按查询工具提前校验筛选条件

- 日期：2026-10-06；实际平台仍为 Darwin arm64 / macOS，zsh。
- 状态：**查询参数修复已验证**；全面回归、双 SDK 查询与当前证据检查通过；重验后续内存异常尚未修复，列为下一轮首要项。
- 原因：R01 按命令允许参数，但 `query` 包含三种工具，各工具实际接受的筛选不同。`list_symbols` 无视 SDK / 平台 / 示例条件，返回未经这些条件筛选的声明；证据工具与未知工具在 SDK 检查、探针写入之后才检查参数。
- 方案：复用查询参数校验函数，命令入口先校验，再进入项目处理；报告查询也使用同一函数。`list_symbols` 仅接受声明筛选，证据工具要求精确 SDK / 平台且不能缺失或仅含 ASCII 空白；没有自动修剪实际匹配字符串。
- 复现：新增三项实际原生回归，旧程序 7 项元数据测试中 **22 个场景失败**，耗时 57.006 秒；覆盖默认/显式声明查询、两种证据工具及快捷命令、未知工具、参数错误产生文件副作用。日志 `build/optimization-r02/red.log`。
- 构建过程：初次使用 `String.trim()` 失败，原始输出保留于 `build/optimization-r02/build-failed-trim.log`；改为 `trimAscii()` 后 1.1.3 构建退出 0。接口参考为 [官方 String 文档（1.1.0-beta.23）](https://docs.cangjie-lang.cn/docs/1.1.0-beta.23/libs/std/core/core_package_api/core_package_structs.html)，其 ASCII 空白范围为 0x09–0x0D、0x20。官方 1.2.0 相同路径本轮不可访问，不用 beta 文档代替实际 SDK 兼容性验证。
- 协作：开始时发现 `README.md` 已修改，以及未跟踪的 `skills/cj-docguard/README.md`；保留原字节，本轮不编辑或纳入提交。原始副本及摘要存于 `build/optimization-r02/preexisting-user-files/` 和 `preexisting-user-files.json`。
- 查询契约见 [查询命令说明](query-options.md)。有效查询仍写入私有环境探针，不宣称所有查询都无副作用；参数早期拒绝不执行项目例子。
- 针对性回归：`python3 -m unittest discover -s tests -p test_cli_metadata.py -v`，7 项通过，无跳过，8.975 秒；日志 `build/optimization-r02/green.log`。帮助文本随后同步更新，最终源码由全面回归及双 SDK 实测再次检查。
- 双 SDK 实测：两个完整 CLI 最终构建退出 0；各在临时独立项目执行 35 个实际命令检查，涵盖 22 个拒绝且不改项目文件的场景、默认声明查询、名称/ID 筛选、实际编译运行一例、三个证据查询入口、错误平台/示例以及带空格的平台不自动规范化。原始命令/退出码/输出保留于 `build/optimization-r02/sdk-smoke.json`；仅证明这些范围，不外推其他平台或未支持输入。
- 全面回归：`python3 scripts/test.py` 退出 0；两个 SDK 的 10 个原生测试程序全部通过，**44 项 Python 测试通过、无跳过，227.181 秒**。原始结果另存 `build/optimization-r02/test-results/`，汇总 `suite.log`；不覆盖 R01 冻结结果。
- 健康重验发生异常：新主程序首先拒绝旧二进制的历史证据，精确查询返回 0 条、拒绝 14 条 `STALE`；随后 `verify --matrix` 新增 225–252 次记录，28 条均 `COMPLETED`，26 运行验证、2 仅编译，但原生命令在后续流程报 `Out of memory` 并退出 1。完整错误及退出码保留于 `refresh.log`、`verify.stdout`、`refresh-commands.json`，没有将该命令写成成功。
- 独立恢复检查：原样保留所有 252 次历史，不重跑或改写执行记录；实际 `check --strict` 退出 0，28 格恢复 `CURRENT`。精确查询返回 13 条当前运行证据，1 条仅编译项明确拒绝；站点 87 个 ID、112 个链接、47 接口 / 1 源码卡片，结构与搜索脚本通过。浏览器视觉检查未做。
- 内存诊断边界：本机物理内存探针为 16 GiB，观察到较多内存压缩；独立检查的 `ru_maxrss` 原始值 307200000，记录于 `direct-memory-check.json`。首次外层 `/usr/bin/time` 测量因动态库加载失败而退出 -6，记录在 `memory-check.json`，不算产品内存复现；改用直接子进程后严格检查成功。尚不能确认环境压力、验证路径重复加载历史、报告生成或 JSON 连续拼接各自的贡献，也不宣称内存问题已修复。
- 固定来源复验：三个项目、六格重新执行，原生退出码仍为 0、1、1，保留通过、未知及编译失败；调度脚本退出 0。新审计 `build/real-projects/20261006T135227664534Z/audit.json` 与本轮二进制摘要匹配，执行前后未变化。
- 过程中另出现未跟踪的 `docs/prd-export.md`；同样不编辑或纳入本轮提交。

本轮主程序 SHA-256：`10d026e7f94ef9c5a77a8435b2ecc7c6c9f273eb86a3f1284e3dff49d5bd0e2a`；1.2.0 构建：`89e91bb087a407267fd497435ad286cc0976c6b8f3129d0aa95455fbcc7522a5`。恢复后的健康报告生成时间 `2026-10-06T21:56:46.558909+08:00`，指纹 `e0b6622516087a33b2c1108179edf906f81be79dd9fc8772f5855b8706779e06`。冻结汇总与报告分别为 `build/optimization-r02/summary.json`、`healthy-report.json`，显式同时记录 `verify_command_exit_code=1` 与 `strict_recovery_exit_code=0`；旧交付包不覆盖。

## R02：导出当前有效示例包（最终验收完成）

- 日期：2026-10-06；实测平台 Darwin arm64。原生 `export` 限制为单个已登记、`CURRENT` 且 `eligible=true` 的格，并复用快照、阶段日志、断言与完整性检查。导出包包含项目相对路径下的库源码、原示例、可选包装、实际编译单元、`build.sh`、清单和边界说明。
- 参数及路径：`--config`、`--example`、`--sdk`、`--platform`、`--out` 全部必填。相对 `--out` 依照 CLI 当前工作目录解析；拒绝 `..` 相对穿越、符号链接、源码/私有输出重叠和非空目录。拒绝后不留持久导出文件或项目探针；验证期间临时锁与系统临时探针会清理。不能据此声称目录修改时间完全不变。
- 测试先行：旧二进制运行三项新增集成测试，均因不认识 `--out` 按预期失败；原始记录 `build/export-implementation/export-red.log`。
- 实施阶段源码的双 SDK 原生导出测试：1.1.3、1.2.0 均实际编译并运行导出单元，核对清单、文件、过期/未知/仅编译拒绝；还用各自真实 CLI 核对缺参、越权参数、非空目标原字节保留。`build/export-implementation/native-exclusive.log` 两版编译和运行均退出 0；该测试另实证 `File.create` 拒绝已存在文件且不改其内容。
- Python 真实 CLI 集成覆盖完整导出复现、片段包装、0–255 二进制文件原字节复制、过期/未知/仅编译/未审核导入/日志破损拒绝、特殊文件名的脚本引用、路径别名、`./example.cj`、缺失 SDK 以及现有空目录。实施阶段七项针对性测试 **7 通过、0 跳过，148.390 秒**，见 `build/export-implementation/export-seven-final.log`；全量结果和最终健康矩阵由最终验收补充，**不得将针对性通过替代 28 格最终重验**。
- 本地 1.1.3 完整 CLI 构建退出 0，SHA-256 为 `3f9b27cf0526c7b86d583b1c2b96e52dacea094e88355ad8f23c3af68e572890`；命令记录 `build/export-implementation/build-final-focused.log`。此摘要仅对应本节实施阶段二进制，最终验收若重新构建需记录其实际身份。
- 未修改 `engine.cj`、`evidence.cj` 或 MCP 写入工具；旧尝试、快照和报告完整保留。导出脚本只证明登记断言在记录环境下可复现，不证明 API 全行为或 AI 生成成功率。

### 最终验收及需求分析结论

- 实际基线为 `6c63b43`，保留已完成的 R02 查询校验；PRD 原文中的 `f369030` 和截止说明作为当时要求保留，未将其当作本轮官方比赛规则核验。实现限于受审查的本地单包，未增加批量、历史导出、依赖下载或 MCP 写工具。
- `src/export.cj` 最终 **243 行**，保留五参数入口；`src/engine.cj`、`src/evidence.cj` 和 MCP 适配未修改。库文件采用 `src/<原始相对路径>` 保持映射唯一；相对 `--out` 从 CLI 工作目录解析。
- 准入复用现有当前性、最新尝试和完整性检查；额外调用既有 `projectApi` 完成输入闭合审查，与查询口径一致。所有导出字节来自证据对应的冻结快照，脚本只重建精确校验的记录命令。
- 终审发现合法 SDK `home` 的末尾斜杠/符号链接会被旧固定占位格式误拒绝。两 SDK × 两种路径的真实 verify/query 均成功、旧 export 均退出 2；永久测试先出现四项失败，再经最小导出模块修复通过（54.322 秒）。脚本继续只输出 `${CJ_SDK_HOME}`，没有放宽任意命令执行；证据为 `alias-red.log`、`alias-test-red.log`、`alias-test-green.log`，复审见 `final-review.md`。

| 最终命令或范围 | 实际结果 | 原始记录（主要保留于 build/export-implementation/） |
|---|---|---|
| 两版完整 CLI 构建 | 1.1.3 与 1.2.0 均退出 0 | final/build.*、final/build-1.2.0.* |
| `python3 scripts/test.py` | 退出 0；52 项 Python、0 跳过（563.177 秒），双 SDK 共 12 个原生模块程序及两个匹配 CLI 构建均通过 | final/test-results/、final/suite.* |
| 健康 `verify --matrix` | 退出 0（34.81 秒）；28 格 CURRENT，26 RUN_VERIFIED、2 COMPILE_ONLY；追加 a-281–a-308，全部 308 次历史保留 | final/matrix.*、final/healthy-report.json |
| `check --strict` | 退出 0（6.44 秒） | final/strict.* |
| 26 格 export → build.sh | 每格导出、真实对应 SDK 编译运行均退出 0，输出/退出断言匹配；最小环境仅 PATH 和 CJ_SDK_HOME | final/exports/、final/export-count.json、final/export-*、final/replay-* |
| 两个仅编译格 export | 退出 1，拒绝内容与 query 一致，不创建目标 | final/refuse-compile-* |
| 独立真实 CLI 负向与恢复验收 | 74 条命令符合预期，其中 56 条预期非零；54 项持久目录/文件摘要不变检查；错误 SDK 的脚本退出 2，特殊文件名未执行 shell 内容 | negatives/commands.json、negatives/*.stdout、negatives/*.stderr |
| PRD 原样导出验收命令与脚本 | 导出及运行均退出 0，arithmetic 标准输出为 42 | final/exact-smoke-*、build/export-smoke/arithmetic/ |
| 离线 HTML 与 Node 脚本检查 | 退出 0；仅结构和脚本逻辑，不代表实际浏览器视觉通过 | final/report-site.* |
| 固定第三方三仓库再验 | 审计流程退出 0，原生项目退出 0 / 1 / 1；2 当前通过、2 输入未知、2 真实编译失败 | final/real-projects-audit.json、final/real-projects-current.* |

- 最终 1.1.3 CLI SHA-256：`e67f62ac9c4d0aefc474b9b56873d78f41c8f65d747e12264fd12dad29058eed`；1.2.0 CLI：`61bb42b6781f7c5a0b8d4705e609ffda1440a7031cbb7db1ff26e8304474fb4a`。健康输入指纹：`f1672fe2dddb8c05ba504dbbca8cd4a756d3fa8902189bdaad681bd29da033f4`；冻结报告 SHA-256：`861df937262b274f8764cd8c5be25694b365bbe29b83330bd3eecddeb2e673c7`。完整命令、工作目录、退出码与耗时保留于 `final/commands.json`；源码冻结摘要在 `final/code-freeze.json`。
- 原始 PRD 和用户已有 Skill README 字节保留；README 统计表保留并更新为本轮实际数字。修复前 51 项全量通过、独立命令和旧二进制证据另存 `pre-alias-final/`、`pre-alias-negatives/`，未覆盖；旧候选源码/证据包继续归档。
- **拒绝无副作用的实测口径为持久目录清单和文件字节不变**，不宣称目录时间戳不变；环境探针和自身保留锁只在临时路径/原输出中存在并清理。两 SDK 各 12 个原生进程争抢同一文件，仅 1 个成功、11 个拒绝且成功内容完整，见 `exclusive-probe.json`；这是排他创建 API 实测，不代替任意并发主机防篡改证明。
- 附加验收脚本曾误把临时 add 例的 `3` 作为健康 arithmetic 的期望值，导致脚本断言退出 1；实际导出和运行均退出 0，输出 `42` 与登记断言一致。已保留 `final/supplementary-precheck-failure.json` 与旧脚本，改按清单断言核对，重放及结构检查均退出 0；该纠正没有改产品源码，也没有覆盖首轮实际输出。
- 历史 `Out of memory` 本轮基线及最终矩阵均未复现，没有修改既有内存路径或宣称已修复；保留后续调查待办。支持范围仍为实测 macOS arm64、SDK 1.1.3 / 1.2.0。AI 效果、实际浏览器视觉、远程发布及比赛提交均未因本轮验收而完成。

## R03：本轮缺口收尾（2026-10-07）

实际宿主 Darwin 25.6.0 arm64、Python 3.14.6；独立平台 Ubuntu 22.04 Linux aarch64 容器。依据已授权的“完成缺口”计划实施，原始 PRD、用户 Skill 草稿、旧候选和失败日志保留，没有发布、报名或提交。

| 缺口 | 完成证据 | 结论边界 |
|---|---|---|
| 真实项目规模 | 60 个不同调用、双 SDK 120 格，固定三仓库；当前有效 36、断言失败 4、未知运行 40、未知编译失败 40；调度 0，三个原生项目均 1 | 实际调用和断言人工复核；不声称上游采用或三项目通过。`build/real-projects/20261007T060602079955Z/audit.json` |
| 长历史内存 | 308 次隔离历史、旧 128MB check/verify 内存不足；新 query/verify/check 0/0/0，历史保留；线性/流式序列化及分阶段报告 | 修复受控负载，历史默认堆事件唯一原因仍未知。RSS 100ms 采样为峰值下界，不是堆限制或普遍性能增益。`build/gap-closure/memory/review-fix/` |
| Linux | 官方两版 SDK、Ubuntu22.04 aarch64，真实 49 命令；cjc/cjpm/原生测试/健康矩阵/严格检查/查询/导出重建按预期 | 原 cjpm 127 因运行库架构路径硬编码；按平台选择修复。v3 首轮 Docker 中断 255，36 条已有成功；严格输入/SDK/环境/日志/断言核对后恢复13条，退出0。非所有 Python 工作流或其他系统。`build/gap-closure/linux-final/verification-20261007-v3/` |
| AI 对照 | 预先固定 30 对，60 次独立生成；功能两组均30/30；综合基础30/30、证据29/30 | 一次禁止工具调用保留失败，未见提升。初始插值误判旧脚本/分数保留、5项回归后同60候选统一纠正；人工60调用一致，禁止调用未放行。`build/gap-closure/ai-evaluation/2026-10-07T055856Z-pilot/` |
| 视频 | 20 条实际命令（4 个预期非零）、70 次演示副本历史；8 幅画面检查、210.021333 秒1920×1080 H264/AAC完整解码退出0 | 实际日志重绘、macOS Tingting合成配音；音轨存在且非静音，未人工聆听，不代表浏览器检查。`build/release/cj-docguard-gap-demo-0d08f76.mp4` |
| 官方 Word | 原模板固定官方提交，6 页填写版及 PDF；全6页图像检查，无观察到裁切或孤立标题；其余13包部件字节保持 | 姓名/联系方式/签字/日期/公开链接/提交及任务9完整条款待本人。`build/release/cj-docguard-gap-application-0d08f76.docx`、相邻 PDF/JSON |

核心冻结之后执行 `python3 scripts/dev.py build` 退出0（13.46秒），第二版完整 CLI 构建0（12.04秒），`python3 scripts/test.py` 整体0（500.50秒）：72项Python通过、0跳过（336.100秒），双版共14个原生测试程序及2个匹配CLI构建均0。冻结源码清单 `build/gap-closure/final/code-freeze.json` 在完整运行结束时字节未变；随后仅AI插值评分和演示捕获辅助工具变化，以对应聚焦回归覆盖，未改原生核心/监督器/构建平台选择。

最终健康 verify / strict 均0，28CURRENT、26RUN_VERIFIED、2COMPILE_ONLY，全部364次历史保留；26格export→对应真实build.sh均0并匹配逐项断言，两个compile-only拒绝1且无目标。命令参数/工作目录/实际退出与计时保留 `build/gap-closure/final/commands.json`；两条独立验收流水同时写临时命令表，完整原始表先分别归档再按相同命令名合并，没有重建或编造计时。原生主二进制 `5d785e4ec67b6dc993ad5d1fbc79a4ca0ffe33a80d3fba284ec259573f2a9c41` 在矩阵、26次重建和真实项目审计前后未变；第二版 `c1232286c35a3af1c386368624e0dc6f18244bb042a08dd4dd3225bfd92f13a4`。健康报告 SHA256 `2ddc392f49c4bfcc03fad164e435a8d30a576d5687dfde06e3cfb6b21a822dd4`，输入 `bd746ccc056437d9e002858713da8a9c071b9fa46169953edd98e2861d42be52`。

HTML/Node检查0：47接口/1源码卡片、87ID/112链接；没有浏览器视觉通过声明。附加检查首次误用 `.docguard/index.html` 返回1（路径不存在），改为实际 `.docguard/site/index.html` 返回0，原日志保留。演示首捕获使用缩短PATH中的系统Python导致动态库加载退出−6；改实际 `sys.executable` 后完整20命令按预期，不覆盖首轮失败。

Task1–4 独立审查已通过；流式序列化排序去重和Linux恢复身份/精确输出/原子记录等审查问题修复后有覆盖回归及复审。剩余细节已记录 [待办](TODO-OPT.md)：词法调用验证不是语义证明，未来人工审查门槛；Linux警告分类宽、STALE解释文案、CLI状态库警告；不以这些边界抹去实际失败。永久演示捕获工具 `scripts/record_demo.py` 的 7 项控制退出 0，覆盖短超时部分原始字节留证、预期非零、错误留证、最新失败、精确查询、输出路径及当前解释器；新校验函数与既有实际20命令档案一致。新工具整条真实采集未单独再跑，不冒充其运行证据。最终整体审查两项阻断已经批量修复并通过复审，见下述收尾记录。

本轮汇总 `build/gap-closure/final/summary.json` 逐项记录不同验证范围及身份；旧 R02 源码包 SHA256 `2c5dd596dd49ee7efb59ad2853a5b0ad98c0c623351e5cd33200b608ea4ee71e` 保持不变。新 R03 本地源码/证据候选采用独立文件名，后续修改须重新验证，未自动上传。

## 下一轮候选

1. 围绕 Unicode 断言失败与上游旧API讨论实际行为和兼容修复，扩大真实使用反馈。
2. 按固定负载测量不同历史规模及宿主，继续调查原默认堆间歇事件，不放宽准入。
3. 演示与申报材料的本人信息、公开链接、签字和任务9最新明细确认。
4. 按 [待办](TODO-OPT.md) 接续边界改进；浏览器拒绝不绕行，Markdown、多包、其他系统与未来决赛差异不提前写成已完成。

### R03 最终交付收尾

整体复审 `final-re-review.md` 结论 Yes：原生核心和现存实测范围无新增阻断；两项 Important 已关闭。打包扩展名过滤漏原始证据的问题通过来源完整性门禁修复：60 个 AI 原始事件、228 原评分 + 12 补测 + 4 控制双流、MCP 请求、三份上游许可证和全部原始阶段日志均按字节核对。新测试在没有 `.research/build` 的干净源码副本先复现失败（1）；合成临时上游控制修复后，本地及干净副本 4/4 均为0，测试专属提交 `28ec250`。没有改原生核心、重生成模型结果或重跑未改变的重型套件。

前两版独立打包候选分别因旧申报答案草稿收录、忽略审计脚本随后变化而弃用，原档和 SUPERSEDED 标记保留。第三版验证候选161源码/7952证据逐字节及CRC/摘要通过，正式交付另用最终提交身份命名，并补入 `final/completion-proof/` 的9份红/绿控制日志、已完成修复/复审报告与固定生产器副本；最终ZIP检查这些原始字节，避免仅对已选择内容自洽校验。

原打包器是忽略的一次性工具，修改前没有独立源码备份；保留的红选择审计记录304个AI原始文件漏项，但不能称其为旧生产器源码快照。旧R02包、当前视频/Word/PDF及原用户文件均保持字节；正式包结果和摘要在 `build/release/cj-docguard-R03-gap-manifest-<最终提交>.json`，仅本地交付。本人信息、签字、公开链接、任务9最新条款及比赛提交尚未办理。

## R04：配音连贯性与音色优化（2026-10-07）

用户要求视频话语流畅、消除卡顿、使用可爱音色。实际平台 Darwin 25.6.0 arm64。先对旧片执行 `ffmpeg ... -af silencedetect=noise=-38dB:d=0.45 -vn -f null -`，退出 0：八个固定分镜尾部静音共 89.21227 秒，最长 13.0435 秒。原因是原旁白约 13～17 秒、每幕固定 26.25 秒，`apad` 补齐空白。

采用已安装 edge-tts 7.2.8 的 `zh-CN-XiaoyiNeural` 轻快合成女声，语速 `+3%`、音高 `+12Hz`。八幕讲稿改为口语，段落连续合成；只裁去句段外静音，保留低能量语音边缘和句间停顿，加入短淡入淡出；按语音实际长度切换画面。整段旁白统一音量，再一次性编码 AAC，避免逐幕编码后拼接。原始音频及 33 条字幕时间标记全部留存。八幕证据面板的上部 776 像素与旧图逐字节相同，沿用 R03 的实际命令来源；不冒称新采集。

| 执行/核验 | 实际结果 | 原始记录 |
|---|---|---|
| 旧片静音检测及声音列表 | 退出 0 | `build/voice-optimization-20261007/setup-commands.json`、`baseline-silence.stderr` |
| 语音试音与完整生成 | 初次连接、TLS/代理试验失败均保留；等价 HTTPS 升级试音成功，仍有间歇连接重置；首完整生成退出 1，有限重试接续退出 0，八段最终全部生成 | `sample-*.json`、`sample-*.stderr`、`synthesis-commands.json`、`synthesis-retry-commands.json`；成功段按摘要复用，无覆盖失败文件 |
| 第一次渲染 | 退出 1；FFmpeg 响度 JSON 后附诊断输出，严格整段 JSON 解析报 Extra data | `render.py`、`render.stdout/stderr`、`render/`、`render-v1-failure.json` |
| 最小解析修正与第二次渲染 | `render-v2.py` 退出 0，17 条 FFmpeg/FFprobe 命令均 0，原始失败目录保留 | `render-v2.stdout/stderr`、`render-v2/commands.json` |
| 最终结构、静音、音量 | 182.433333 秒、1920×1080、30帧/秒 H264/AAC；相同参数最长静音 0.641583 秒，未检出超过 1 秒静音；综合响度 −16.03 LUFS | `render-v2/ffprobe.json`、`silence-detect.stderr`、`final-loudness.stderr` |
| 画面、字幕与连续音轨 | 八幕最长字幕图像检查无观察到裁切；33 条字幕无重叠、末条覆盖到音轨末尾；8552 个 AAC 包，最大时间间隙约 0.000001 秒 | `caption-qa-scenes-1-4.png`、`caption-qa-scenes-5-8.png`、`delivery-verification.json`、原始包时间戳 |
| 交付保护 | 20 个旧 release 文件、原 PRD、用户 Skill README、原生 CLI 摘要均保持 | `old-release-sha256.json`、`delivery-verification.json` |

交付 [新版视频](../build/release/cj-docguard-demo-cute-smooth-20261007.mp4)、[旁白 MP3](../build/release/cj-docguard-narration-cute-20261007.mp3)、[SRT 字幕](../build/release/cj-docguard-demo-cute-smooth-20261007.srt) 和 [核验 JSON](../build/release/cj-docguard-demo-cute-smooth-20261007.json)。视频 SHA-256 `cf704cc024389bf8b0cbd0aaf702a18ca28d7e86b12f462c8cd309d922af6bed`；MP3 SHA-256 `21ba16715f4e8250f6f2e68148373ae787e7805118321feb3e94e0940a82ef9f`。

支持边界：本轮只调整离线媒体与说明，核心验证仍为 R03 的冻结记录；不是浏览器录屏或新执行证据。完整音视频及独立 MP3 解码均退出 0，但没有人工听审，自动静音/时序检查不保证主观可爱程度、每词发音或绝对无口语瑕疵。网络重置的唯一原因未确认；不修改全局代理、不关闭证书验证，接续最多五次并保存每次失败。没有新增付费资源、上传或提交；旧源码/证据包仍为历史归档，不替换旧摘要。

## R05：整体独立评测（2026-10-07）

用户要求重新评测整个项目。本轮确认 Darwin 25.6.0 arm64，以提交 `4910c15c12587ee001a30ec74363db0d2b64eaf5` 的161个受版本管理文件建立干净副本，显式注册真实 SDK 1.1.3 / 1.2.0 与已有官方归档缓存。没有复制原构建产物或真实上游缓存；没有修改产品代码。[整体评测报告](project-evaluation-2026-10-07.md) 区分当前运行、历史实验和待核验事项。

原始命令、实际退出码、双流日志和身份保留于 `build/project-evaluation-20261007T080339Z/`，总索引 [evaluation-summary.json](../build/project-evaluation-20261007T080339Z/evaluation-summary.json)。`python3 .../evaluate_runtime.py` 实际退出1：驱动为子进程注册 SDK，但遗漏其自身后续 `dev.sdk_env()` 调用，产品已完成的构建/全量测试/矩阵/查询/首次导出均0。保留原驱动、失败堆栈与失败汇总；新驱动补注册并核对源码/二进制/报告身份，仅接续剩余阶段，`python3 .../evaluate_runtime_remaining.py` 退出0。不能把驱动首轮退出1改写成成功或产品失败。

| 当前验证 | 实际结果 |
|---|---|
| `python3 scripts/dev.py build` | 退出0，约6.19秒 |
| `python3 scripts/test.py` | 退出0，80项Python通过、0跳过（309.501秒）；双SDK共14个原生程序及两次匹配CLI构建通过；总流程414.34秒 |
| `verify --matrix` / `check --strict` | 退出0/0，47个公共符号、28 CURRENT，其中26 RUN_VERIFIED、2 COMPILE_ONLY；副本新历史28条 |
| 导出与对应SDK重建 | 26格导出及真实`build.sh`均0，逐项断言匹配；两个仅编译格按预期拒绝1，目标不存在 |
| 查询 / MCP / 页面 | 两版各13个有效示例；两次只读查询单次耗时4.355783/4.295640秒；实际MCP握手/工具/查询0，HTML+Node结构检查0，无浏览器视觉通过声明 |
| 交付完整性 | R03源码161文件与冻结提交一致；证据清单7971文件摘要/大小、ZIP CRC通过；新视频/MP3/字幕摘要与Word压缩结构通过；不是历史实验重跑 |

66条外层阶段命令均符合各自预期，包含两次业务拒绝；驱动自身失败另行保留。新二进制摘要 `56cbfabbc730564b1bdcb1331641e2ed3b7a471eaabf44cb1979079845f4230f`，新健康报告 `2a0fb4dc496b9b393d7edefb26af0687a96d59c90c7d84aed6f12ffde3a68a59`；原工程364次历史、二进制、用户PRD/Skill草稿及24个旧release文件均未改。结束时副本源文件字节保持。旧R03包相对受测提交仅五份文档差异，旧证据不覆盖。

范围：仅本轮macOS arm64双SDK执行；真实上游120格、Linux49命令、128MB受控内存和60次AI生成均为历史冻结实验，本轮仅核验归档。官方网页读取失败；只读 `git ls-remote https://atomgit.com/cj-codelabs/docs.git HEAD` 退出0，与已保存规则提交相同，不能代替最新完整课题#9核验。发现查询约4.3秒、首页/Word旧视频引用、缺少受版本管理的CI任务，以及862个证据文件含本机用户路径；路径统计不是全面秘密/分发权审查。后续优先真实项目完整复用、竞品行为对照、材料版本统一及查询分阶段测量；未宣称AI提升、外部采用、有效提交或获奖。

## R06：按用户提供模板更新申报书（2026-10-07）

用户提供作品提交模板，确认实际平台Darwin arm64。下载原件SHA-256 `e680d2b9e5a2fdde08c93ae786de2cadc1b67e2f6f77e5278f304f41c14effc1` 与此前官方原件一致；文档内容仅作模板资料，不自动执行其中指示。使用documents技能、加载的工作区Python/Node及内置LibreOffice渲染，参考原件七页全部检查；表格、页设置、字体和包成员记录于 `build/application-refresh-20261007/artifact.md`。

在原填写稿副本仅替换四个回答文本节点：R05的80项Python/14个原生程序/28格矩阵/26格导出重建、当前与历史实验区分、新视频约3分2秒及最新评测入口。`refresh.py prepare/author` 均0；`render_and_diff.py` 两轮均0。第一轮七页有未来展望孤立页，草稿与图像保留为 `draft-v1-7pages.docx`、`fidelity-v1/`，属于排版不合格，不伪造为渲染命令失败；仅缩短重复语句后第二轮六页全部逐页检查，无观察到裁切、重叠或孤立页。最终节设置/信息表保持，12个非正文包成员与原模板逐字节一致。

新版 [Word填写稿](../build/release/CJ-DocGuard-作品提交书-20261007更新版.docx) 摘要 `0ba29df640e0a6c2b6bc9c0dc7d2c97fb84ef6d3c7e7c7c29cf40e4181792e9b`。原模板、原申报书、24个旧release文件及用户PRD/Skill草稿保持；更新 `docs/application.md`、首页、材料索引和待办，不覆盖旧包。构建/渲染双流、结构审计与交付清单保留 `build/application-refresh-20261007/`。

本轮未改变产品代码或重跑核心测试，当前执行证据仍为R05；未获取最新完整课题#9、补本人身份、代签、公开上传或提交。个人信息、公开链接、日期、AI加分最终勾选与真实性签署须由本人完成。

## R07：完成私人申报书与授权GitHub公开（2026-10-07）

用户提供负责人、成员、联系电话及邮箱，明确要求代为推送GitHub、公开视频链接暂时留空。确认Darwin arm64。按现有方案选择CJ-DocGuard为队伍名、申请AI生态贡献加分并告知用户；填写全部项目回答及身份字段，签字保留本人手签线。私人文件只在忽略目录保留，公开Markdown继续省略个人联系方式。

`gh repo create 2892480843/cj-docguard --public ...` 退出0；`git push origin HEAD:refs/heads/main` 退出0，公开属性和main分支核验，首推本地/远端/API一致为 `4b7f41d68c912946d83d47ef283b16bbf065f658`。公开地址 [2892480843/cj-docguard](https://github.com/2892480843/cj-docguard)。选定模式扫描238个历史Git文本对象无命中，不代表全面秘密或第三方分发权审计；SDK、原始证据、视频及私人Word没有随源码推送。发布范围由本回合明确授权，比赛提交仍未执行。

`complete.py prepare/author` 及两轮渲染均0；首轮七页排版不合格但不是命令失败，保留草稿。第二轮缩短一段重复文案、邮箱在@后换行，保留字体/字号/列宽，六页逐页检查。91个非空文本片段字体族与字号核对，六个原空信息槽显式复制原字体；12个非正文包部件字节保持。只读初始字体审计曾因脚本选择属性或原有粗体差异误判，未改Word字体；最终审计限于字体族/字号并保留原粗体。

收尾检查器首轮退出1：对XML序列化字节比较把命名空间前缀差异当作页设置变化；改为展开XML名称/属性/内容比较，退出0，原脚本和堆栈保留。进一步发现旧生成稿的 `mc:Ignorable` 引用w14/w15/wp14却未保留声明，虽可渲染仍不能视为兼容性完备。以原模板命名空间映射生成独立终稿，不改正文或字体；旧候选及归档说明保留。`restore-template-namespaces.py` 退出0；渲染首次误用 `--out_dir` 退出2（未开始渲染），改为实际 `--outdir` 后退出0；终稿六页重新逐页检查。`finalize-v3.py` 退出0，节/样式审计均0，原模板直接格式保留，未强行规范化标题。

最终本地 [Word终稿](../build/release/CJ-DocGuard-作品提交书-完整填写终稿-20261007.docx) 摘要 `29d4a5ce355623b4bfc16808ceb960272629b7a95a52f755d20d56ed0a252d3b`，原25个release文件、模板及用户PRD/Skill草稿均保持。原始双流与命令、字体核对、命名空间修正及终稿交付核验在 `build/application-completion-20261007/`；不同失败、候选和证据未覆盖。原模板缺省页边距未人为补设；本机渲染的字体回退不等于修改Word字体，也没有Microsoft Word应用运行验证。

本轮只修改本地申报书和公开说明，核心程序/验证规则未改，当前全量执行证据仍为R05。未代签、上传视频、发送邮件、正式报名或提交，最新完整课题#9、资格与签署仍需负责人处理。新源码链接已闭环；旧冻结源码/证据包继续归档，不被本次GitHub入口替代。

## R08：产品发布演示动画重剪（2026-10-07）

用户要求重剪并加入动画，随后明确选择“产品发布演示：明亮、精致、流程动画”。实际平台由 `uname -sm` 确认为Darwin arm64。旧片问题为长时间静态终端面板、密集小字；在冻结真实日志与既有旁白上重制8章32镜头，大字结论配矩阵、流程、代码片段和历史时间线动画。保留晓伊音色与语速，只去除175.841～180.247秒已过时的公开链接句、剪接处加6毫秒淡化；不新增音乐、付费资源或网络语音生成。

| 命令/核验 | 实际结果 | 原始记录（均在 `build/video-motion-20261007/`） |
|---|---|---|
| `python3 edit.py prepare` | 1：输入实际为双声道，旧断言错误要求单声道；没有修改输入 | `prepare.stdout/stderr`、原脚本 |
| `python3 edit-v2.py prepare`、`python3 edit-v3.py prepare` | 均0；按双声道帧剪接，v3另修正状态卡含义并增加代码逐字动画 | `prepare-v2.*`、`prepare-v3.*` |
| v2/v3六秒试片及 `python3 edit-v3.py render` | FFmpeg均0，最终渲染0 | `commands.json`、`render.*`、`motion-encode.*` |
| `python3 verify.py` | 1：检查器错误要求输出等于5341个原始输入帧，实际 `-t 178.004` 输出5340帧；成片没有重渲染 | `verify.*`、`qa-v1-commands.json` |
| `python3 verify-v2.py` | 0：按一帧量化范围核对，实际音视频差4毫秒 | `verify-v2.*`、`qa-commands.json` |
| 全片解码、静音、峰值、抽帧 | 各命令0；最长静音0.641583秒（−38dB / 最小0.45秒），峰值−4.5dB | `v2-decode-entire-video.*`、`v2-final-silence.*`、`v2-final-volume.*` |
| 图形运动与视觉抽查 | 64帧两两比较：31/32镜头图形区域变化，排除字幕/进度；32制作静帧与32成片样帧均按八章拼图检查，无观察到裁切重叠 | `verification.json`、`stills-v3/`、`encoded-frames/`、`motion-samples/` |
| `python3 deliver.py` | 0：新名字独占创建视频/字幕/JSON，复制后摘要相同；30旧文件及4输入保持 | `deliver.stdout/stderr`、`delivery-verification.json` |

交付 [动画视频](../build/release/cj-docguard-demo-motion-20261007.mp4)：178.004秒、1920×1080、30帧/秒、5340帧、H.264/AAC、32条连续字幕。视频SHA-256 `207247c73c59d8c18c5e6fda05c91d50be62bea3cf431ac97109bdfd8692ab3d`；[字幕](../build/release/cj-docguard-demo-motion-20261007.srt) SHA-256 `b6ee9c925e955c5c1931a12ea6dfcf857bd2f67bd5cd78733945da51e1b9db2d`。制作及自动QA的旧记录不覆盖，最终抽查结论另存 [交付JSON](../build/release/cj-docguard-demo-motion-20261007.json)。

来源仍为此前20条真实命令：26格运行/2格仅编译，70条历史来自故障演示副本；动画状态没有把历史成功写成当前准入。每镜头只抽样检查，不等于全帧或人工音频听审，不保证主观效果；最后链接卡刻意保持静止。无产品代码变更及新核心测试，当前全量执行仍为R05；未执行浏览器预览、远端推送、视频上传或正式提交。私人Word和旧包未改，材料版本统一及公开视频链接仍待正式提交时处理。

## R09：补公开视频链接并整理提交材料（2026-10-07）

用户提供B站BV1R5HC6MEDo链接并要求整理文件。实际 `uname -sm` 为Darwin arm64。去掉跟踪参数，使用 `https://www.bilibili.com/video/BV1R5HC6MEDo/`；B站及AtomGit页面直接抓取未成功，链接按用户提供填写，未声称在线播放、审核状态或线上媒体与本地一致。现有规则快照要求AtomGit报名、作品仓库及组织同步，两个快照的同步组织描述不同，以当前提交页面为准；不以GitHub发布冒称已提交。

保留当前用户修改后的私人Word为底稿（SHA-256 `c712df85867201a0758ab9e493c475f2a0701113d8de14312313d5909c428071`，18个包成员），没有恢复旧候选。只改3个文本节点，补视频链接并同步约2分58秒/动画文件名；全部119个运行格式属性、字体字号、表格及页设置保持。为消除独立留白页，仅取消第九节标题强制换页，不改正文。最终5页逐页检查无观察到裁切、重叠、缺字或孤立页，签字栏原样保留。

制作中实际失败：`prepare.py`退出1，因检查器错误要求旧版本含姓名的签字文字；`render_docx.py`随后因输入尚未生成退出1，双流保留。改为核对当前签字段落后，`prepare-v2.py`退出1：写ZIP时复用ZipInfo会修改读取句柄偏移；候选未交付，原件字节未改。`prepare-v3.py`复制ZipInfo后退出0。初渲染退出0但中文为方框，不合格；补本地字体目录后渲染0但7页有留白；仅为未安装等线指定Heiti SC渲染替代后0、6页，仍有第九节强制换页留白；`finish-layout.py`及最终 `render-v6.py`均0、5页通过。DOCX仍为Arial/等线，PDF是本机字体替代后的未签字预览，不保证Microsoft Word效果或嵌入等线。探测字体的fontTools导入不可用，改用已有Pillow读取本地字体，不安装资源。PDF文本检查首次误用不存在的override/pdftotext失败；改用发现的捆绑Poppler路径退出0，视频ID、身份和签字文字均存在。

`python3 build/submission-organize-20261007/package.py`退出0，交付目录 `build/release/CJ-DocGuard-提交材料-20261007/` 共9文件：说明、Word、未签字预览PDF、源码ZIP、MP4、SRT、验证ZIP、摘要清单与可复制简介/链接。源码164文件及独立身份记录，58个src/scripts/tests/examples文件与R05干净受测副本逐字节一致；源码包是当前工作树快照，不能称为全新受测Git提交。验证附件225份真实日志/摘要选摘，记录原件与脱敏副本摘要，将本机用户目录替换为LOCAL_HOME；不把脱敏副本当作原始准入指纹，不冒称完整历史7971文件证据包。换环境仍须复验。

总ZIP SHA-256 `83df812fef0fe199069d2bcd0fd1f1716bede7380d7713bda3e2258d10b501f3`，8252121字节；Word摘要 `cb20f9e5d9e0e21c9884e024ec5557dbcdc7ec2b8e844b4b314d7a514ee4b9e3`。外包、源码ZIP、验证ZIP和DOCX的CRC与路径检查均通过，外包成员逐字节匹配目录，31旧release文件及2用户文件保持。原始制作、失败、字体配置、渲染、清单和回执在 `build/submission-organize-20261007/`；源码冻结之后的本节交付记录不反写旧包。新增公开索引但未远端推送，不公开私人Word/整包，不创建AtomGit仓库、同步、代签或正式提交。签字、资格、任务#9及平台回执仍待本人完成；当前核心执行仍为R05，没有新核心或AI实测。


## R10 AtomGit仓库整理（2026-10-07）

用户明确要求放入AtomGit仓库。macOS arm64环境；通过已登录账号导入完整GitHub代码及22次历史提交，实际仓库为`https://atomgit.com/c2892480843s/cj-docguard`，`git ls-remote`确认main为`0fda18b0db805f4bbf13c979701b66b846dbb808`。公开材料副本位于`submission/`，包含五页模板Word/PDF、225份必要日志与汇总ZIP、字幕、索引和校验清单。Word分片邮箱按完整段落匹配隐藏，字体字号与其余部件保持；首轮发现分片邮箱仍可见，未上传，修正后重新渲染并逐页检查。`prepare.py`和PDF提取退出0，ZIP校验、五项附件摘要和用户文件保留检查通过。发布增量和远端复核接续记录在本轮日志中。

核心源码未变，本轮没有新构建、核心测试、Linux运行、远端CI或AI效果验证；最新完整执行仍为R05。私人完整模板与旧包不覆盖。当前赛事页面确认提交作品须同步`cj-codelabs`并另送本人签字PDF；本轮未代签、发邮件、同步组织或正式提交。B站线上播放和课题#9完整要求待核验。


R10远端复核完成：`git push atomgit HEAD:main`退出0，服务端Git检查通过，main更新至`a78dc2c19ea0b9bc9d08cc0a0b1d66013498074a`。随后`git fetch atomgit main`、`git ls-remote`退出0，11个必需入口及附件与本地逐字节一致，18个测试文件在远端树中；浏览器确认`submission`目录已显示。公开模板5页、119段运行字体属性及其余部件保持，分片邮箱和电话均隐藏，用户私人Word、PRD及未跟踪Skill文件保留。原始命令、渲染及远端校验记录位于忽略目录`build/atomgit-publish-20261007/`。上述结论只证明仓库发布及文件身份，没有正式赛事提交回执。


R10可见性补充：导入表单默认生成私有项目，第一次清空凭据助手的匿名`git ls-remote`退出128，需要登录。已在AtomGit项目设置选择公开并保存；同一匿名命令随后退出0，返回main `5494f28047054ab8af37a7823398ae431db1032b`。先前带凭据的远端核验只证明授权读取，不能证明公开访问；最终公开状态以该匿名检查为准。此补充不改变源码或附件。

## R11 AI生态贡献独立仓库及申请材料 2026年10月7日

平台为Darwin arm64。用户要求完成AI生态贡献加分材料，沿用已授权的AtomGit发布范围。本轮不修改产品核心，复制固定主仓库`8a886f73f28d29c7fe92f2ea9dbebaa205b7f68a`的Skill、MCP适配器与LICENSE；新增独立README、配置示例、提示模板、工作流、自建单包样例、申请说明及分发清单。用户未跟踪的Skill README、PRD和旧发布材料保持原摘要，未纳入独立分发。

工作目录`build/ai-contribution-20261007/`保留原始双流、命令、退出码和构建副本。`verify.py`流程完成13条子命令：真实构建退出0；主仓库`python -m unittest discover -s tests -p test_mcp.py -v`的13协议单元+1原生集成共14项通过、0跳过；SDK 1.1.3/1.2.0自建add例矩阵、strict、真实stdio握手/三个工具查询均退出0。错误平台、缺环境和执行工具被拒绝；修改输入使旧结果不准入；故意断言失败的verify退出1并原样留存，查询不回退；恢复源码仍须重验，重验/导出/独立`bash build.sh`均退出0且输出3。独立分发`python -m unittest discover -s tests -p test_mcp.py -v`另行13协议单元通过。两套单元覆盖重叠；不是27个不同测试。原summary计数字段误写14单元+1集成，依据原始日志另存summary-corrected.json为13+1，公开汇总使用修正口径，没有重写原日志或伪造重跑。

独立贡献仓库[AtomGit](https://atomgit.com/c2892480843s/cj-docguard-ai)的main为`4b07cb87f641fe1d8052a780626d29247b922534`；git push退出0，关闭凭据助手的匿名git ls-remote退出0且提交一致。公开分发54份文件，ZIP SHA-256 `b2aa2a099a5506182246e41c55969a66c5359b10cd9aea8f8e08e8e20855cd62`；UTF-8/JSON/本地链接、逐文件摘要和ZIP CRC核对。公开日志对私有路径做副本脱敏，原始日志保留；文件清单同时记录原始/公开摘要。没有SDK、编译产物、私人联系方式或新付费资源。

新公共/私人Word分别只改1个贡献链接段落；119个运行格式属性及其他包部件保持，旧稿摘要不变。两次render_docx退出0、各5页全页图像检查无观察到裁切/重叠；公共Word SHA-256 `ef02b9e234389f476906f1f7ad68660f55ebba0ab0d73e3ab499ed5281988c61`，本地私人Word `53efc8f179fe4f03a3a4043844d6e6876455407caf4556555a3491fc12a6d186`。公共副本继续隐藏联系方式，私人完整稿只在忽略目录；签字保持本人签署空白。PDF采用本机替代字体，仅为预览，不宣称Microsoft Word实际打开。

本轮范围为固定核心的聚焦协议/复用验证、独立分发与文档更新；没有新全量核心回归、健康矩阵覆盖、Linux运行、GUI客户端集成、模型效果实验或第三方采用证据。R05完整回归保留为历史独立记录。没有自动全局安装Skill、邮件发送、组织同步、报名或比赛正式提交；加分由组委会决定，决赛需以真实最终版本另行迭代验证。

R11发布前检查：独立匿名fetch退出0，54份远端文件与本地逐字节一致；ZIP清单/CRC、两份PDF文本与五页数、116个相对文档链接、公开附件摘要、用户文件保留和git diff --check通过。第一次检查器把公开账号c2892480843s中的数字误当作邮箱而退出1；保留脚本和失败记录，改为匹配完整私人邮箱后退出0，未改动文档或联系方式。记录在build/ai-contribution-20261007/final-check.json。

## R12 按初赛评分标准补强证据与复用材料 2026年10月7日

依据用户提供的30/20/20/15/10/5六维100分标准，优先补评审证据定位、真实库发布检查和缺失PPT。用户已授权迭代和AtomGit公开材料发布；本轮不修改原生核心、监督器、构建/测试或MCP适配器。保留45份用户文件与旧release材料摘要，原PRD和未跟踪Skill README不改。

Darwin arm64，固定0a4d81e772d5613c7ad491a675b11a47fcba9c5b的干净git archive副本。真实构建0；scripts/real_projects.py --project leven4cj --cache 已审核缓存 --output 独立目录退出0，固定上游da69d981027b9fcbe12d09cfbb275b4ce8acc91d、全部生产源码保持、20不同调用×两SDK=40格。36 RUN_VERIFIED/CURRENT有效、4 ASSERTION_FAILED/CURRENT，原生verify退出1，strict也退出1。unicode-empty与emoji-empty两版失败保留。不是整个库发布通过，也未证明上游采用。

13条实际命令记录在build/rubric-optimization-20261007/logs/commands.json：两版本upstream-api query、export、导出目录bash build.sh均0，输出3\n2\n3\n。隔离生产源码末尾加入注释后，query 0但items为空、freshness=STALE，export 1且目标不存在。未登记新执行尝试，恢复原始字节后query恢复有效；不把该恢复场景与R11较新失败后的必须重验混淆。只读旧报告仍显示历史成功，形成同一输入的最小对照，不宣称优于任何第三方产品。原生二进制前后摘要一致，源身份与支持范围在summary.json。

实际失败及接续：外层检查器误用MCP包装records字段读取CLI的items，第一次进程退出1；原query本身0。保存v1-run.*及脚本，按实际JSON修正后在已完成构建/矩阵身份上接续，最终0，不重写旧日志。本轮不新增模型调用或全套核心回归。初次字体/构建工作目录读取用错目录的辅助命令失败留在工具记录；没有修改技能或用户应用。

公开真实库ZIP328文本文件，SHA-256 bb2710cec475e3b9369c2d2705977f3416787f9a0bf5c36edb3bf81090a93d78，包含40格阶段日志/尝试、报告、13命令、来源与LICENSE、两版导出源码及脚本。排除可执行文件、.cjo和SDK。原始双流本地保留，路径脱敏副本另存，FILES同时记录原始与公开SHA；脱敏后不是原生准入目录。CRC、UTF-8/JSON和选择的路径/联系方式检查0。

新增10页16:9可编辑PPT，使用Artifact Tool及实有Heiti SC字体，六张原生表格与一张原生双SDK堆叠图表，来源放逐页备注。首次finalizer遗漏表格验证参数而失败，第二次缺RUNTIME_NODE_MODULES导入失败；保存两轮候选/双流，补所声明表格参数及正确捆绑运行时后完整finalizer0。初稿逐页检查后修正STALE表述和图表文字对比度，另存新版，最终10页渲染逐页检查无观察到裁切/重叠。原生图表工作簿快照与导入、字体、完整性、几何验证通过；最终PPT SHA-256 1b8f7978aaa5913563fa2135a91fa3d9ea147581ff20a5e004b9ae47f2a9d39c。没有Microsoft PowerPoint实际打开声明。

新增架构/可靠性、真实库教程、原需求完成度、六维评审证据和CONTRIBUTING，连接README及提交索引。2026-10-07直接观察AtomGit主项目页Star 0、Fork 0，只有该页面计数快照，不外推社区受欢迎程度；未代为Star/Fork或联系社区。模型历史实验未提升、GUI客户端未实测、浏览器报告预览拒绝、CI/性能剖析待办仍保持。没有报名、组织同步、代签、发邮件或比赛正式提交。

R12发布完成：git push atomgit HEAD:main退出0，首批17份文件提交`c5ee8423ad327d62564a8d294105b3a62882e16c`。关闭凭据助手的匿名ls-remote/fetch均0，main身份一致，17份文件与本地逐字节匹配；174相对链接、328附件摘要/CRC、10页PPT原生6表/1图及工作簿、固定上游/导出源码字节和45保留文件核对0。计划完成状态在发布核验后标记，本地最终回执保存在build/rubric-optimization-20261007/publication-final.json。没有赛事提交回执。

## R13 四类必交材料核对与统一 2026年10月7日

本轮实际Darwin arm64，从Git状态、优化/验收/TODO及最新用户四类清单开始。未覆盖用户未跟踪Skill README、PRD或旧release文件。重新从指定组委会模板页下载DOCX，SHA-256 e680d2b9e5a2fdde08c93ae786de2cadc1b67e2f6f77e5278f304f41c14effc1，与原下载底稿一致。核对完整源码/许可/说明/开源来源/变更记录及18测试源文件（11Python、7仓颉）；验证附件分别228成员（225日志汇总+3说明身份清单）、328真实库证据、54独立AI贡献文件，CRC及既有摘要一致。

发现旧统一模板未直接给主作品仓库链接，旧本地综合ZIP缺R11/R12新附件。新公开/私人模板仅改两段材料说明，补主作品AtomGit链接并按独立包实际SOURCE.json引用引擎身份。119个运行格式属性、所有非文本结构、字体字号及其他包部件逐字节保持；两次最终渲染退出0，各5页所有页面检查无观察到裁切/缺字/重叠，联系方式仅私人版保留。DOCX仍用模板Arial/等线；PDF本机中文替代字体，不宣称真实Word实测或严格模板PDF。公共稿SHA37ec7c0fc7e52b37f1b10dd6a9496a7a1ed784e040d434d1adf4b3a61c11a28a；私人稿SHA43057aafb3f5b17104904ad34ea254405cc8805ffe340bafc0e68563b57bd823。

初稿错误引用SOURCE-ENGINE.md，未交付，候选和两次首轮渲染双流保留；修正SOURCE.json后另行渲染0。首轮audit.py退出1，检查器错误要求官方XML序列化字节相同；独立复查styles规范化内容相同，用户底稿字体目录曾重排并加未使用字体，正文实际字体/字号集合与官方一致。本轮字体目录对用户底稿字节保持。audit_v2.py退出0，59相对链接、14分发清单项、55旧附件与用户文件保留核对。改动范围为文档与材料，没有新产品、SDK、模型、Linux、远端CI或健康矩阵执行结论。

浏览器B站页面已打开实际作品标题/简介，观察到播放器00:05推进至02:58以及实际动画画面；总时长显示02:59，结束时显示02:58。自动连播后首张留证属于下一条推荐视频，已标为不适用，返回作品并暂停后另存bilibili-playback-v2.jpg。不把标题/进度观察当作全片人工音频听审、匿名播放或线上与本地逐字节一致性。材料清单记录视频流程与边界；没有下载远程视频或绕行被拒绝的本地报告预览。

原始脚本、失败/成功双流、渲染、附件身份和核验汇总在build/submission-audit-20261007。先固定本轮公开材料源码快照，再建立新的本地完整包，构建及发布回执接续记录；旧包冻结。本人签字、课题#9完整要求与正式提交仍待负责人，没有代签、组织同步、邮件或报名提交。

R13本地完整包完成：package.py退出0，14交付文件，186份固定Git源码文件逐一与提交`f744bd0e764e234d66973e83240a093d0119b454`一致，18测试源文件齐备。外包及源码/验证/AI/Word/PPT各内包CRC、成员路径和复制身份通过，55既有附件与用户文件保持。新包SHA-256 `a0662ace5038bb1332d7cdb8572a271d92a1b842b36d0b81496f1e3fad54c28f`，10079364字节；真实联系方式稿只留本地，旧包未覆盖。完整包冻结后本段回执不反写其源码ZIP；产品代码无差异，不冒称新核心回归。公开分发推送及匿名身份结果记录于build/submission-audit-20261007/publication-final.json。
