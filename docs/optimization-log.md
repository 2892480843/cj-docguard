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

## 下一轮候选

1. **R03 首要：定位并修复长历史验证后续流程的内存异常。** 使用完整冻结历史对比 `verify`、`check` 和序列化路径，先获得可重复基线及阶段/内存证据，再最小修复；保留所有历史及证据准入规则，重新完成双 SDK 和健康矩阵验证。
2. 将示例拓展集中在真实库的常用接口和失败路径，逐步推进累计 60 例目标；完整保留来源、许可与未支持情况。
3. 从实测命令耗时定位日常使用瓶颈，先确定性能基线再优化；证据完整性不能因缓存提速而放宽。
4. 审查声明查询的符号 ID 与登记示例符号名称的映射；明确支持范围后再扩展，避免返回未经筛选的例子。

浏览器本地报告预览曾被安全策略拒绝；不能通过其他访问路径绕行。HTML 结构与 Node 脚本检查只证明结构/脚本，不证明浏览器视觉表现。其他平台、复杂 Markdown、多包构建及 AI 效果研究仍待验证。
