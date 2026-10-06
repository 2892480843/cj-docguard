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

## 下一轮候选

1. **R03 首要：定位并修复长历史验证后续流程的内存异常。** 使用完整冻结历史对比 `verify`、`check` 和序列化路径，先获得可重复基线及阶段/内存证据，再最小修复；保留所有历史及证据准入规则，重新完成双 SDK 和健康矩阵验证。
2. 将示例拓展集中在真实库的常用接口和失败路径，逐步推进累计 60 例目标；完整保留来源、许可与未支持情况。
3. 从实测命令耗时定位日常使用瓶颈，先确定性能基线再优化；证据完整性不能因缓存提速而放宽。
4. 审查声明查询的符号 ID 与登记示例符号名称的映射；明确支持范围后再扩展，避免返回未经筛选的例子。

浏览器本地报告预览曾被安全策略拒绝；不能通过其他访问路径绕行。HTML 结构与 Node 脚本检查只证明结构/脚本，不证明浏览器视觉表现。其他平台、复杂 Markdown、多包构建及 AI 效果研究仍待验证。
