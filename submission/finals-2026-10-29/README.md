# CJ-DocGuard 决赛版本（2026-10-29）

**最新答辩材料：[手写视频版：10页主讲＋4页备查、两分钟真实系统介绍与逐页讲稿](roadshow-v6-video/README.md)。标准安排7分20秒，视频已内嵌第4页，只采用功能源码 `068a22a` 的当前结果。**

旧版材料：[v2归档](roadshow-v2/README.md)。下列源码标签和验收附件为此前冻结批次，保留原始身份与口径；最新版答辩以v5-rich目录为准；[v3仪表盘版](roadshow-v3/README.md)保留当前结果来源，[v4手写版](roadshow-v4-notebook/README.md)继续归档。

## 已归档的发布批次

上一版答辩：[可编辑 PPTX](CJ-DocGuard-决赛答辩-20261029.pptx) · [PDF 预览](CJ-DocGuard-决赛答辩-20261029.pdf) · [生成源码及逐页检查](slides/QA.md)。

验收：[最终123项验证](VERIFICATION.md) · [公开克隆运行回执](PUBLIC-CLONE.md) · [材料文件摘要](FILES.json)。

入口：[评委克隆运行指南](../../docs/judge-quickstart.md) · [本轮迭代](../../docs/finals-iteration-2026-10-29.md) · [6～8 分钟网页演示提纲](../../docs/finals-demo-runbook-2026-10-29.md)。初赛材料保留原归档身份，不作为新版功能证明。

## 源码与复现

固定源码标签为 `finals-source-20261029-r2`。精确源码身份、文件摘要与验证记录随本目录的 `SOURCE.json`、`SOURCE-FILES.json` 和 `VERIFICATION.md` 发布。源码提交与后续证据提交分别记录，避免把尚未产生的提交摘要写进自身。冻结标签保存功能源码、指南和答辩稿；`SOURCE.json`、`SOURCE-FILES.json`、`VERIFICATION.md` 与 `evidence/` 属于最终验收附件，在 `main` 的本目录补充，检出标签时可回到公开 `main` 查看附件。

```bash
git clone --branch main https://atomgit.com/c2892480843s/cj-docguard.git
cd cj-docguard
git rev-parse HEAD
git rev-parse 'finals-source-20261029-r2^{commit}'
```

主仓库：[AtomGit](https://atomgit.com/c2892480843s/cj-docguard)；镜像：[GitHub](https://github.com/2892480843/cj-docguard)。按照评委指南登记两版真实仓颉 SDK 与兼容的系统 SDK 后，执行：

```bash
bash scripts/build_workbench.sh
bash scripts/workbench.sh --port 8765
```

打开 <http://127.0.0.1:8765/>。可在网页完成环境诊断、索引构建、示例验证、严格检查、API 检索、源码/配置编辑、历史比较、精确版本查询及导出。服务与核心使用仓颉；浏览器使用 HTML/CSS/JS，进程监督及信号桥使用 C，Python 用于测试和辅助工具。

独立 checkout 可运行 `python3 scripts/validate_checkout.py`，重新构建、启动临时端口，执行真实双 SDK 验证、查询、导出与包内重建；日志写入本 checkout 的 `build/checkout-validation/`，结束后关闭临时服务。

## 赛题交付映射

| #9 要求 | 当前验收入口 |
|---|---|
| 声明、参数、返回值及示例代码的结构化文档 | 网页“接口与文档”，健康样本 47 个公共符号；JSON/HTML/Markdown 产物 |
| 示例正确性验证 | 真实编译、运行和输出断言；矩阵、日志、期望/实际值、失败及仅编译状态分别展示 |
| SDK 版本对应关系自动检查 | 仓颉 1.1.3/1.2.0 独立矩阵；精确平台/版本/当前输入资格检查 |
| 索引链接自动检查并输出 | 实际 HTML URL 与预期 API 锚点均检查；Markdown 链接/标题、失败原因、来源行和筛选可在网页查看 |
| 文档完整且可检索 | 接口搜索、关联示例、源码工作区、只读证据查询；歧义符号明确报错 |

本轮关闭 F01 实际索引漏检、F02 多行 Setext 标题误判、F03 同名成员及重载示例错绑。原始问题记录保留于[修复前全面复核](../../docs/finals-comprehensive-audit-2026-10-29.md)，不会改写成原先已经通过。

## 结果口径和边界

- 健康样本预期 28 格当前记录：26 个运行验证，2 个仅编译；仅编译不等于行为断言通过。
- leven4cj 原版预期 36/40 有效，4 格 Unicode 空串断言失败；显式修复副本预期 40/40。上游缓存和断言不修改，副本记录补丁、许可证及前后摘要。实际最终结果见验证记录。
- 离线外链为 `UNVERIFIED`；无法确定的 HTML 候选集合、重复属性和 `base` 上下文不能误报通过。没有宣称完整 CommonMark/仓颉语义分析覆盖。
- 本轮完整宿主为 macOS arm64 和已安装的 SDK；新系统在线安装、其他平台、正式提交、上游采用及答辩评分没有由本地测试推定通过。
- 组委会通知要求先优化作品，按 6～8 分钟准备展示；10 月 31 日是准备目标，最终时间和材料收集以后续正式通知为准。
