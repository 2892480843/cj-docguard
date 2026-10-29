# 链接解析与真实库 Unicode 修复验收（2026-10-29）

> 本文保留当时的检查身份与结果。后续修复、冻结源码和最终公开复现以[2026-10-29 决赛交付记录](../submission/finals-2026-10-29/README.md)为准。

本轮目标是补足文档链接解析、查明并修复原始 leven4cj 的四个断言失败单元，并使真实结果可在仓颉 HTTP 工作台查看。以下只对应本轮 macOS Darwin-arm64 和真实仓颉 SDK 1.1.3 / 1.2.0。

## 实现范围

核心链接处理在 `src/links.cj`，文件存在性、安全路径及发布判断仍由 `src/engine.cj` 处理。支持行内链接、完整/折叠/快捷引用、图片、尖括号自动链接、嵌套括号、反斜杠转义、可选标题、UTF-8 百分号路径、查询串与片段、ATX/Setext 标题、重复标题锚点、HTML id 和 a[name]。引用定义以首个有效定义为准。每条报告保留原始目标、来源行、语法、结果与原因，另有 `link_summary` 汇总。

测试针对代码/注释污染、列表和嵌套引用漏检、跨行代码、伪 HTML、缺失引号、未知实体、中文 HTML 字节边界、链接目标和标题内伪标签导致假锚点等逐项加入反例。真实报告索引也通过实际 `writeReports → checkLinks` 验证，防止只在手工小样本中成立。

路径穿越、绝对路径、NUL/无效 UTF-8/错误百分号编码、不安全协议以及不存在的目标或锚点不能 PASS；既有原生路径及符号链接保护继续适用。普通远程网址保持离线 UNVERIFIED，不发起网络请求。常见命名实体及数字实体可解析；未知命名实体明确未验证，单个标题中的未知实体不使其他有效锚点丢失。没有宣称通过完整 CommonMark 渲染一致性认证；Unicode 非 ASCII 大小写折叠、任意深度复杂容器和完整命名实体表仍有边界。

参考原始规范：[CommonMark 0.31.2 链接/引用/代码/标题规则](https://spec.commonmark.org/0.31.2/)、[GFM 规范](https://github.github.com/gfm/)、[GitHub 章节链接说明](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links)。这些来源用于界定语法与设计，不代替本地执行证据。

## 真实库根因与修复

详见[逐项根因、补丁摘要和复现命令](real-library-unicode-repair-2026-10-29.md)。四个单元来自两个调用乘以两个 SDK：

| 调用 | 原始实际 | 原断言期望 | 修复实际 |
|---|---:|---:|---:|
| `leven("", "你")` / SDK 1.1.3 | 3 | 1 | 1 |
| `leven("", "你")` / SDK 1.2.0 | 3 | 1 | 1 |
| `leven("😀", "")` / SDK 1.1.3 | 4 | 1 | 1 |
| `leven("😀", "")` / SDK 1.2.0 | 4 | 1 | 1 |

根因是两个空串分支使用 UTF-8 字节数，而非空动态规划使用 Unicode 码点数。只修复两个分支为 `toRuneArray().size`，不改预期、不跳过失败、不扩大字符语义为字形簇。补丁默认不应用，只有 `--apply-reviewed-fixes` 显式启用；应用前后与补丁本身均核验内容摘要。上游锁定提交和缓存不变，修复副本记录 `source_modified: true`、变更摘要、补丁和许可。

## 网页入口

打开本地工作台，在项目选择中分别查看原始 leven4cj、本地修复版以及“链接检查演示（含预期坏链）”。

- “问题与诊断 → 链接检查结果”列出 PASS/FAIL/UNVERIFIED 全部行，支持状态筛选、搜索、来源行及原生详情；按钮实际启动 Cangjie check，完成后重新加载报告。
- 矩阵/问题详情直接展示失败断言的期望、实际、SDK 和原始日志，不把 0、false 或空字符串当作缺失。
- `examples/link-checks` 为可重复演示：含两条预期坏链和一个离线外链。程序运行通过仍应因坏链导致严格检查退出 1。

## 验证记录

| 验证层 | 本轮最终结果 | 原始记录 |
|---|---|---|
| 完整回归命令 | `CJ_DOCGUARD_TEST_REAL_UNICODE=1 python3 scripts/test.py`，退出 0；两个 SDK 共 16 个原生测试程序、两次 CLI 构建、原生服务构建均成功 | `build/links-unicode-full-regression-complete.log`、`build/test-results/summary.json` |
| Python 集成 | 118 项全部通过，464.896 秒；包含真实仓颉 HTTP 和双 SDK Unicode 对照，不是 Python HTTP 服务 | `build/test-results/python-integration.log` |
| 原生链接测试 | 两个实际 SDK 各 67 条断言通过，包含真实报告生成与索引检查 | `build/test-results/links-1.1.3-run.log`、`links-1.2.0-run.log` |
| Unicode 独立参考对照 | 6 项集成控制通过，48 次算法调用对照，以及原样例的双版本原始/修复执行 | `build/unicode-repair-tests-final.log` |
| 前端回归 | 20 个有/无报告页面场景及新增链接计数、筛选、转义、详情、真实事件、原生任务完成刷新和断言值检查均通过 | `build/links-unicode-ui-tests.log` |
| 最终工具真实库流程 | 原始版 36/40 有效、4 断言失败；本地修复版 40/40 当前有效，verify/check 均退出 0；四个原断言不变 | `build/link-repair-final-e2e.log` |
| 双 SDK 查询/导出/重建 | 修复版两例均由原生查询返回当前有效；两 SDK 各导出 unicode-empty ZIP，独立重建均输出 `1\n` | `build/link-repair-validation/20261029-124027/` |
| 链接样本 | 12 条：9 PASS、2 预期 FAIL、1 UNVERIFIED；两程序运行通过，严格检查因坏链退出 1，代码/注释假链接未进入报告 | 同目录 `links-report.json` |
| 运行身份 | 8765 为仓颉二进制监听，记录最终 CLI/服务/解析源码摘要 | `build/links-unicode-runtime-identity.json` |

本轮先观察到原有引用解析测试失败，再逐项修复。探索中捕获并修复了注释/围栏污染、代码内定义、伪 HTML 锚点及真实中文 HTML 字节截断等问题。首轮完整测试的 HTTP 新用例漏算了一条自动生成索引 PASS；修正期望后，最终完整回归 118 项通过。探索日志与最终日志分开保留，不改写之前失败。

完整回归会重新构建工具，使旧环境证据失效。因此最终真实库流程在全部测试结束后又完整执行一遍，最后以 `20261029-124027` 目录为准；之前 `20261029-123516` 是中途验证，不作为最终资格证明。

网页实测：登记原始与修复项目，查看原始失败 `期望 1 / 实际 3`；修复矩阵中 unicode-empty 和 emoji-empty 两个 SDK 均 RUN_VERIFIED / CURRENT，断言期望与实际均为 1；链接表显示全部 12 条，FAIL 筛选为 2 条、UNVERIFIED 搜索为 1 条，详情包含 README 来源行和目标。网页按钮实际发出原生 check；含坏链样本的退出 1 为预期结果。新增链接面板在 390×844 下整页宽度为 390，表格局部滚动；恢复默认桌面尺寸。截图为 `build/unicode-original-failure.jpg`、`build/unicode-fixed-40-pass.jpg`、`build/link-check-mobile.jpg` 和 `build/link-check-final-desktop.jpg`。

原有健康演示也重新完整执行 16 步：诊断、索引、双 SDK 验证、检查、故障注入、失效、失败、拒绝导出、恢复、重验、导出、独立重建输出 `42\n`、冻结历史和报告对比均通过。记录：`build/links-unicode-workbench-final-e2e.log`，证据目录 `build/workbench-validation/20261029-124329/`。默认健康演示已恢复至 26 个当前有效运行结果和 2 个仅编译结果。

最终网页按钮任务 `526e90bd8f047f69d8c27dd42e43a6fd` 实测返回退出 1（两条预期坏链），运行证据为 2 CURRENT / 2 VERIFIED_CURRENT；完成后页面刷新至 9 PASS / 2 FAIL / 1 UNVERIFIED，控制台未见 error/warn。
