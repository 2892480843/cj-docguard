# 仓颉网页工作台迁移验收记录（2026-10-29）

> 本文保留当时的检查身份与结果。后续修复、冻结源码和最终公开复现以[2026-10-29 决赛交付记录](../submission/finals-2026-10-29/README.md)为准。

本轮在 macOS Darwin-arm64 实测。正式 HTTP 服务进程为 `build/cj-docguard-workbench`，HTTP、状态、文件、任务编排均为仓颉；浏览器为 HTML/CSS/JavaScript。C 监督器、POSIX 信号桥和系统 zip 的职责见[原生服务指南](native-workbench.md)。Python 只承担测试客户端和既有辅助工具。本记录不是组委会验收结论。

## 可复现验证

| 验证 | 本轮结果 | 本地原始证据（build 不纳入源码提交） |
|---|---|---|
| 两 SDK 原生测试 | 1.1.3 / 1.2.0 各 7 个程序通过，另有两次 CLI 构建通过 | `build/test-results/*-run.log`、`build/native-migration-full-regression.log` |
| 完整集成测试最终重跑 | 115 项，512.000 秒，全部通过，包含 19 项真实仓颉 HTTP 服务测试 | `build/native-migration-python-final.log` |
| 原生 HTTP + 历史行为对照 | 33 项全部通过；历史 Python 实现只为测试夹具 | `build/native-workbench-final-regression-fixed.log` |
| 网页渲染与交互回归 | 20 种有/无报告页面场景及检索、状态、转义、表单、源码、查询、恢复和任务同步检查通过 | `node tests/test_workbench_ui.mjs` |
| 真实 HTTP 完整流水线 | 16 步通过；故障/拒绝/恢复、冻结历史、对比、导出 ZIP 和包内真实重建输出 42 | `build/native-workbench-final-e2e.log`、`build/workbench-validation/20261029-110108/` |
| 服务端运行身份 | 8765 监听程序为仓颉二进制，bootstrap 声明与进程证据一致 | `build/native-server-provenance.json` |
| 1.2.0 服务构建启动 | 编译、bootstrap 请求、SIGTERM 正常退出通过；不扩大为该服务版本全流程验证 | `build/native-workbench-1.2.0-smoke.log` |
| 真实库复验 | leven4cj 共 40 格：36 个运行通过、4 个断言失败，退出码 1；保留原始失败 | `build/native-real-library-result.json` |

最初的一次组合测试因历史夹具仍引用已移除模块而失败，已修复引用并完整重跑 115 项。保留最初 `build/test-results/summary.json` 及日志，不改写失败记录；合并结果见 `build/native-migration-final-results.json`。

```bash
export CJ_DOCGUARD_SYSTEM_SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
python3 scripts/test.py
node tests/test_workbench_ui.mjs
python3 scripts/validate_workbench.py --url http://127.0.0.1:8765
```

系统 SDK 路径是本机旧仓颉链接器与 Xcode 27 的兼容选择，其他机器按实际环境配置。运行全套集成测试可能重建工具或临时操作测试 SDK，结束后应重新验证演示副本，避免把之前的环境快照当作当前结果。

## 浏览器实际操作

在 `http://127.0.0.1:8765` 使用真实仓颉服务完成以下操作：

- 源码工作区打开 `programs/arithmetic.cj`，把加法改为减法，明确确认后按读取时的 SHA-256 保存；检查出现 STALE，验证出现 2 个 ASSERTION_FAILED。随后恢复原文并重验证，得到 26 RUN_VERIFIED + 2 COMPILE_ONLY，覆盖两个 SDK。
- 取消真实验证任务，退出码 137；在项目配置检查残留锁，确认原归属进程不存在后手动申请恢复。旧锁、活进程、额外文件、符号链接等拒绝路径由原生 HTTP 测试覆盖。
- 网页选择 arithmetic / 1.1.3 / Darwin-arm64 导出，任务 `6091b9247be76ff2191c2c53a433c575` 成功并显示真实 ZIP 下载链接。
- 网页调用 get_verified_examples，任务 `01d76ad71265ea5d9d14e1bb220f5b7d` 成功，返回真实断言和 stdout `42`，保留完整原生 JSON。
- 实际任务完成后验证概览报告同步；修复手动刷新先读到完成状态时遗漏报告更新的竞争问题，并补充首次观察即完成、取消及避免重复处理的回归检查。
- 390×844 下依次打开全部 10 个页面，每页 document.scrollWidth = 390；桌面和窄屏均目视截图检查。源码编辑、长日志和表格各自滚动。浏览器仅为本机环境验证，不推断所有浏览器兼容性。

最终完整回归结束后，网页任务 `b26a94b99b1069822c08659eeb253ed7` 重新验证成功；检查任务 `ffc8824abbd71783ef26275cfa72c1ee` 退出码 0，28 CURRENT、26 VERIFIED_CURRENT、2 COMPILE_ONLY。最终桌面截图：`build/native-workbench-final-desktop.jpg`。浏览器控制台本轮未见 error/warn。

## 公开赛题三项交付对应验收

详细信源、时效冲突和最新群通知见[赛题证据核验](finals-requirement-evidence-2026-10-29.md)。以下仅按已取得的 #9 公开摘要核验。

| 公开交付项 | 实现与网页入口 | 验证及范围 |
|---|---|---|
| 声明、参数、返回值、示例代码的结构化 API 文档及检索 | 仓颉提取/报告；接口文档、示例、源码工作区 | 原生 extractor 测试、网页检索/字段/关联代码检查；仅支持[支持矩阵](support.md)列出的语法子集 |
| 示例代码正确性测试 | 真正调用 SDK 编译器、执行并检查登记断言；矩阵、任务详情、诊断 | 双 SDK 健康样本、真实库失败、故障注入、旧证据失效、恢复、日志完整性及取消回归；COMPILE_ONLY 不冒充运行通过 |
| SDK 对应关系及索引链接自动检查 | 精确版本/平台/环境指纹；矩阵、检查、问题列表 | 两实际 SDK、缺失 SDK、声明与实际版本不符、故意缺失本地链接导致严格检查失败；外链离线 UNVERIFIED，不宣称已验证 |

## 准备状态与限制

用户提供的新通知要求先优化作品、仓库、说明和测试材料，暂不提交；路演按 6～8 分钟准备，PPT 模板及“初赛后改进”章节可选。10 月 31 日为准备目标，决赛时间未定。本轮没有提交材料或同步线上仓库。

目前可以证明公开三项交付在声明范围内实现并有实测证据；尚未取得完整 #9 专项任务书，不能断言全面符合未知条款或替代评委认定。原生新服务本轮在 macOS 实测，Linux/Windows 服务行为未据此认证。无完整仓颉语义分析、无公网部署能力、外链不联网判定；真实库仍保留 4 个断言失败。网页源码保存不会自动授权执行，项目须审阅配置及代码后显式开启信任。
