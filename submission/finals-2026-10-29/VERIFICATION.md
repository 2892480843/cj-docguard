# 最终源码验证记录

功能源码冻结于 `13566db8dc86c130fc0e0a414143ae97328b3410`，标签 `finals-source-20261029`。文件身份见 [SOURCE.json](SOURCE.json) 与 [完整冻结树摘要](SOURCE-FILES.json)。后续提交只添加材料或验证回执；默认 `main` 包含这些补充，功能源码身份保持不变。

| 检查 | 实际结果 | 可公开证据 |
|---|---|---|
| 双 SDK 完整构建与原生回归 | 两次 CLI 构建、20 个原生程序及仓颉 HTTP 构建全部退出 0；每 SDK 包含链接97断言、实际索引13断言 | [完整命令输出](evidence/full-validation.txt)、[原生结果](evidence/native-tests.txt)、[汇总](evidence/suite-summary.json) |
| 完整集成套件 | 122 项，555.480秒；全部通过，零跳过、零失败（已启用 Unicode 扩展） | [逐项日志](evidence/integration-tests.txt) |
| 显式真实库扩展 | 最终全套已启用扩展；另外6项相关测试也曾独立通过、无跳过；双 SDK 原版/修复共48次算法调用与独立码点参考对照 | [扩展日志](evidence/unicode-regression.txt) |
| 前端脚本回归 | 20种有/无报告渲染场景，链接筛选/详情、断言值、转义及实际事件等全部通过 | [网页回归](evidence/ui-regression.txt) |
| 独立源码目录 | 无预存构建/证据，外部显式登记SDK；重新编译原生服务，47接口、28 CURRENT（26运行/2仅编译）、178链接PASS；两SDK查询各13项，导出重建各输出42 | [预发布干净源码结果](evidence/local-clean-source-summary.json) |
| 修复前反例 | 实际索引漏检与历史错绑的新增断言确实先失败，修复后纳入完整套件通过 | [F01修复前](evidence/f01-before.txt)、[F03修复前](evidence/f03-before.txt) |

完整集成命令为 `CJ_DOCGUARD_SYSTEM_SDKROOT=<实际兼容SDK> CJ_DOCGUARD_TEST_REAL_UNICODE=1 python3 scripts/test.py`。真实库扩展为 `CJ_DOCGUARD_TEST_REAL_UNICODE=1 PYTHONPATH=scripts:tests python3 -m unittest test_real_projects -v`，要求有指南说明的经锁验证原版副本。最终全套没有跳过，亦单独保留扩展日志。

本机网页全工作流、原版/修复版对照及发布后的匿名克隆回执在后续证据附录分别记录，不用本地复制结果冒充公开克隆。本轮完整平台为 macOS arm64 与已安装工具链；新操作系统安装、其他平台、任意仓颉语义、上游采纳或正式赛事提交不在通过声明内。离线外链保持 UNVERIFIED，原版四个断言失败仍按实保留。

演示材料：[10页PPTX](CJ-DocGuard-决赛答辩-20261029.pptx)、[PDF预览](CJ-DocGuard-决赛答辩-20261029.pdf)、[逐页检查](slides/QA.md)、[网页路演操作稿](../../docs/finals-demo-runbook-2026-10-29.md)。讲稿约7分15秒为安排建议，没有声称已完成现场计时。

发布前新增大历史并发保护：约9.2MB、460条归档，12客户端两轮读取，旧版触发内存错误，修复后完整保留所有记录且服务可用；此用例已纳入最终122项套件。请求读取保持并发，应用响应生成与发送串行，保留发送超时和历史。

完整套件会重新编译资源监督器，环境摘要随二进制变化；最终网页报告在全部测试完成后重新验证，不能将旧环境记录冒充当前。冻结源码和后续证据提交分开发布，公开克隆回执补充在 `main`。
