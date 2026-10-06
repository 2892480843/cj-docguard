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

## 下一轮候选

1. 审查查询工具层的筛选参数：`list_symbols` 是否还有被忽略的 SDK、平台或例子条件；用可复现回归明确契约。
2. 将示例拓展集中在真实库的常用接口和失败路径，逐步推进累计 60 例目标；完整保留来源、许可与未支持情况。
3. 从实测命令耗时定位日常使用瓶颈，先确定性能基线再优化；证据完整性不能因缓存提速而放宽。

浏览器本地报告预览曾被安全策略拒绝；不能通过其他访问路径绕行。HTML 结构与 Node 脚本检查只证明结构/脚本，不证明浏览器视觉表现。其他平台、复杂 Markdown、多包构建及 AI 效果研究仍待验证。
