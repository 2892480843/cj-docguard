# CJ-DocGuard 缺口补齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 补齐已批准 PRD 的真实案例规模、Linux 实证、内存排查和本地演示/申报材料，并开展可复现 AI 实验；将必须本人办理或实际条件不足的事项明确列为未完成。

**Architecture:** 保留原生证据准入和单包构建契约。扩展固定上游集成的样例登记，不改上游生产字节；各平台记录真实编译器、二进制和命令身份，演示只使用实际命令输出。原始证据及旧候选包全部保留。

**Tech Stack:** Cangjie 1.1.3/1.2.0、C runner、Python 标准库、现有 Docker Linux aarch64、现有 FFmpeg。

## Global Constraints

- 不自动发布远程仓库、发送邮件、报名或提交比赛；不新增付费资源。
- 浏览器已拒绝本地报告预览，不能通过其他访问路径绕行；结构检查不算视觉验收。
- 不覆盖 `skills/cj-docguard/README.md`、旧候选包或原始历史。未知、失败、未执行均不能算通过。
- 上游生产源码保持逐字节相同、固定提交和许可；合成示例不能冒充上游测试或第三方采用。
- 只有真实 SDK 编译/执行才作为平台验证；替身只可用于注明的控制单元测试。
- 原生核心改变后重新构建、完整回归、刷新健康矩阵和第三方当前证据。

### Task 1: 60 个有独立断言的固定上游登记例

**Files:** Modify `scripts/real_projects.py`, `integrations/upstream-lock.json`; Create `integrations/*/cases/`, `tests/test_real_projects.py`, `docs/real-project-cases.md`.

- [x] 读三个已固定本地上游及其测试/README，设计总计至少 60 个实际库调用的不同测试场景，覆盖空值、边界、Unicode、算法关系和 PNG 文件头各字节/长度；保留版本比较库的真实失败。每个案例记录目的、参数、预期输出与独立计算/官方文档依据。
- [x] 测试先行：登记多个不同样例，断言生成配置完整、ID 唯一、原字节复制及全部断言；非法/重复/越界样例在运行前拒绝。`python3 -m unittest discover -s tests -p test_real_projects.py -v` 先观察旧脚本不支持的失败。
- [x] 最小扩展锁中的 `examples` 列表，明确 `id/file/symbol/stdout/expected_exit` 字段；保留老单例兼容。所有样例在输入复制前校验路径、ID、文件摘要/断言字段；使用固定 10000ms 产品默认预算，调度外层预算随登记格数有界增长。结果保留 `example_id`，统计总例数、矩阵格数和真实分类，调度退出 0 不代表各格通过。
- [x] 运行聚焦控制回归及实际双 SDK 上游复验：`python3 scripts/real_projects.py --cache ../.research/external`。记录实际退出码、失败和未知原因；核对上游 HEAD/库存/摘要始终不变。不得扩大标准库白名单来凑通过。
- [x] 写任务报告到 `build/gap-closure/task-1-report.md`。提交仅此任务文件，控制器负责总体文档和候选包；不要改其他任务文件。报告包含红绿命令、实测目录、计数与限制。

### Task 2: 历史内存异常的隔离复现

**Files:** Create `scripts/diagnose_memory.py`, `tests/test_memory_diagnostics.py`, `docs/memory-diagnostics.md`; production source only if reproduced root cause warrants minimal fix.

- [x] 核对原 R02 异常/后续成功日志和当前调用链。先隔离复制原健康完整输入/历史，严格不改旧证据。
- [x] 用 Python 子进程与内存采样测量 `check/query/verify`，记录实际峰值/阶段、完整 stdout/stderr、退出码；限制样本规模不主动耗尽宿主内存。对诊断脚本可复现实验做聚焦回归。
- [x] 若不能复现明确写“根因未确认”，交付自动诊断与实测边界，不把删历史或限流当修复。若复现按红绿回归最小修复，并完成全量核心验证。

#### 经复现实测批准的最小扩展

- 生产代码所有权包含 `src/primitives.cj`、`src/engine.cj` 的 `publicValue`、`src/report.cj` 的报告写出，以及 `scripts/test.py` 的永久原生内存用例登记。可更新 `tests/native_memory.cj`、`tests/native_report.cj`、`tests/native_export.cj` 的相关回归。
- 基线为不可修改的 308 次健康历史隔离副本；实测旧版在 128MB 下 check / verify 退出 1，query 退出 0。保留默认堆当前成功与历史默认堆 OOM 根因未确认的区别。
- 不删除历史、不截断报告、不改变证据准入、字段顺序、JSON/报告字节和路径脱敏顺序，不修改输入树。畸形报告树必须在任何公开输出可见前拒绝。临时分段/流式处理要有清理与等价回归。
- 根控制器在源码冻结后负责最终全量双 SDK、健康矩阵、当前第三方证据刷新；实现者先完成相关原生与 Python 聚焦回归、实际同负载红绿、采样指标与边界报告，再提交其所有权文件。

### Task 3: 真实 Linux 双 SDK

**Files:** Create `scripts/linux_verify.py`, `docs/linux-verification.md`; platform fixes only following real failed baseline.

- [x] 官方 SDK 下载页核对 Linux aarch64 双版本归档与发布摘要。使用已存在 Docker，单独运行容器，不触及其他容器/镜像/卷。
- [x] 在项目副本安装经摘要验证的双 SDK，实际构建 CLI/runner、原生测试、健康矩阵/strict/query/export/replay。保留容器平台、镜像身份、源码摘要、版本、原始日志和每条命令退出码。
- [x] 对真实失败最小修复并重验；容器只能证明本次 Linux aarch64 环境，不外推 x86/Windows。缺资源时保留可执行路径和明确未测原因。

### Task 4: 实际 AI 成对实验

**Files:** Create `scripts/ai_evaluation.py`, `integrations/ai-evaluation/`, `docs/ai-evaluation.md`.

- [x] 使用既有本地 AI 工具/账户，不开新付费资源；先验证执行接口、可用模型与授权范围。30 对任务、同模型/预算、固定随机顺序、基础上下文与当前验证证据两组；独立保存原输出与时间/身份。
- [x] 预先锁定客观编译/运行断言及评分，先观察控制测试失败，再实现脚本；用真实 SDK 评分，不用模型自评。保留失败，统计分母、成功率差与样本限制；不得保证提升目标。
- [x] 无法真实执行时交付已验证的实验工具、任务和锁定评分，标记未执行，继续其他任务。

### Task 5: 演示视频与申报材料

**Files:** Create `scripts/record_demo.py`, `docs/application.md`, `docs/demo.md`; Modify `docs/submission.md`.

- [ ] 录制副本中的实际健康查询、修改拒绝、失败、恢复、双 SDK 和 export/replay，全量命令与结果保存；利用本机 FFmpeg 制作字幕视频并检查帧/音轨/时长。不可把重绘的输出当浏览器实录。
- [ ] 查询官方当前任务/模板；可获取时严格逐项映射，无法取得则明确未核验。形成可审核申报内容、来源/许可/语言比例、技术边界和答辩说明。
- [ ] 姓名/联系方式待用户实际提供，签名/资格核验/公开 URL/提交回执须本人处理；不得代填、伪造或自动对外操作。

### Task 6: 审查、当前验收与独立新包

**Files:** Modify `docs/acceptance.md`, `docs/optimization-log.md`, `docs/TODO-OPT.md`, `README.md`; new immutable outputs `build/gap-closure/`, `build/release/*<new-commit>*`.

- [ ] 按任务审查并修复重要问题；最终整体审查所有修改和证据，不重新执行无变化的重型测试。
- [ ] 验证适用回归、编码、差异检查和原用户文件摘要，统一记录当前/历史结果和无法完成的本人/环境事项。
- [ ] 本地提交，按新提交生成源码与证据包及摘要；不覆盖旧包，不发布。更新验收与待办，把未确认内存根因等诚实保留。
