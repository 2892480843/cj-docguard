# 决赛 R2 最终验证记录

**冻结源码：`075aeb38fc32d46680f312e8ac3647a0977e1366`，标签 `finals-source-20261029-r2`。** 首发标签保持原身份。`main` 包含源码冻结后的证据与材料补充；[SOURCE.json](SOURCE.json)记录167个受测源码文件，[SOURCE-FILES.json](SOURCE-FILES.json)记录源码标签的完整树。完整树摘要应对照标签对象；`main` 的验证附件允许新增，不能把不同身份混为一谈。

| 检查 | 实际结果 | 公开证据 |
|---|---|---|
| 双 SDK 原生构建/回归 | SDK1.1.3/1.2.0，两次 CLI 构建、20个原生程序及仓颉 HTTP 构建全部退出0；每SDK包括链接97断言、实际索引13断言 | [完整输出](evidence/full-validation.txt)、[原生结果](evidence/native-tests.txt)、[汇总](evidence/suite-summary.json) |
| 最终完整集成 | **123项，515.939秒，全部通过，零跳过、零失败**；真实 Unicode 扩展已启用 | [逐项记录](evidence/integration-tests.txt) |
| 原生网页服务 | 完整套件包含22项真实 HTTP 回归；约20MB、640条、每条64字段的结构化归档，12并发两轮读取及两次中途断连，完整记录和原文件保留，临时响应清理 | [集成记录](evidence/integration-tests.txt) |
| 前端脚本 | 20种有/无报告页面场景，以及链接筛选/详情、转义、断言值、实际事件和原生任务刷新等通过 | [前端记录](evidence/ui-regression.txt) |
| 独立干净源码 | 重新编译/启动；47接口，28 CURRENT（26运行/2仅编译），178链接PASS；两个SDK查询各13条，导出重建分别输出42；167源码摘要与冻结版本相同 | [预发布干净目录记录](evidence/local-clean-source-summary.json) |
| 实际网页完整工作流 | 16步：诊断、构建、双SDK验证、检查、变化失效、最新失败优先、拒绝导出、恢复、重验、导出重建42、冻结历史及报告比较均符合预期 | [工作流](evidence/live-workflow.txt)、[最终汇总](evidence/live-summary.json) |
| 原版/修复真实库 | 原版36/40当前有效、4断言失败；显式修复副本40/40当前有效；断言和上游缓存不改，两SDK查询/导出/重建均符合预期 | [真实库工作流](evidence/live-libraries.txt)、[最终汇总](evidence/live-summary.json) |
| 现有大历史持续读取 | 13,465,735字节、655条真实归档，12并发×10轮，120/120返回200；所有记录相同、原文件摘要不变，无内存错误 | [压力结果](evidence/live-history-pressure.json) |
| 系统SDK参数 | 白名单保留显式Apple系统SDK且排除无关私密变量；新回归先红后绿；独立目录实际原版36/40、修复40/40 | [修复前](evidence/system-sdk-forwarding-before.txt)、[独立7项测试](evidence/unicode-regression.txt) |

完整回归命令：

```bash
CJ_DOCGUARD_SYSTEM_SDKROOT=<实际兼容的系统SDK路径> CJ_DOCGUARD_TEST_REAL_UNICODE=1 python3 scripts/test.py
node tests/test_workbench_ui.mjs
```

新克隆没有真实库缓存时，先按[评委指南](../../docs/judge-quickstart.md)取得并锁验原版；不能把默认跳过当作通过。正式监督器在测试开始构建后保持摘要不变，监督器测试改在临时目录构建，避免干扰运行中的环境指纹。

## 首发之后发现并关闭的问题

1. `real_projects.py` 的精简环境漏掉 `CJ_DOCGUARD_SYSTEM_SDKROOT`，导致指定15.4系统SDK没有传入原生验证，回退到不兼容的默认SDK，出现40格编译失败。它不同于原库应保留的4个行为断言失败；R2补充参数传递回归及实际库复验。
2. 首轮响应串行化只消除了并发倍增；约11.8MB字段密集报告仍能在全新服务顺序读取时触发内存错误。R2保留完整JSON字段和历史，使用临时文件流式序列化及64KiB分块发送，正常、失败和断连均清理临时文件；未扩大运行时堆参数，也未删除历史。[修复前内存错误](evidence/large-history-before.txt)。

课题F01实际HTML索引漏检、F02多行Setext标题、F03同名成员/重载错绑均已纳入最终回归。[F01修复前](evidence/f01-before.txt)、[F03修复前](evidence/f03-before.txt)保留反例，不改写旧失败。

公开仓库已重新匿名克隆并通过构建、原生服务运行、两SDK查询/导出/重建，以及新缓存原版36/40和修复版40/40复验，见[公开克隆回执](PUBLIC-CLONE.md)；本地复制没有冒充公开克隆。后续证据提交只补充验证材料，功能代码与冻结标签保持相同。

本轮完整宿主是macOS arm64及已安装的仓颉1.1.3/1.2.0与兼容Apple系统SDK；未声称全新操作系统安装、其他平台、无限大报告、完整语言语义、上游采用或正式赛事提交通过。离线外链保持UNVERIFIED，仅编译不等于运行断言通过。

答辩材料：[10页PPTX](CJ-DocGuard-决赛答辩-20261029.pptx)、[PDF](CJ-DocGuard-决赛答辩-20261029.pdf)、[逐页检查](slides/QA.md)、[网页操作稿](../../docs/finals-demo-runbook-2026-10-29.md)。讲稿约7分15秒是安排建议，未冒称现场计时。
