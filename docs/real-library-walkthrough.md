> 2026-10-29 补充：下文保留 2026-10-07 原始上游的历史失败记录。现已查明空串分支使用字节数、主体使用 Unicode 码点数的缺陷；保持断言不变的显式本地修复与来源记录见[Unicode 修复说明](real-library-unicode-repair-2026-10-29.md)。原始上游和本地修复版分别展示，不把修复版冒充原始上游通过。

# 真实开源库发布检查与示例复用

本教程面向仓颉库维护者，使用固定版本leven4cj（字符串编辑距离库）演示发布检查、当前证据查询和独立源码导出。完整源码范围和许可见[真实项目说明](real-projects.md)，本轮证据见[验证附件](../submission/CJ-DocGuard-真实库复用证据-20261007.zip)。本次是在隔离副本复验上游代码，没有证明上游团队采用本工具。

## 实测身份与结果

| 项目 | 本轮结果 |
|---|---|
| 主引擎源码提交 | `0a4d81e772d5613c7ad491a675b11a47fcba9c5b` |
| 平台与SDK | Darwin-arm64，真实仓颉SDK 1.1.3 / 1.2.0 |
| 固定上游 | `da69d981027b9fcbe12d09cfbb275b4ce8acc91d`，Apache-2.0 |
| 覆盖范围 | 全部1份生产源码，显式排除1份上游测试源码；20个登记调用 |
| 最新矩阵 | 40格：36当前有效、4登记断言失败 |
| 严格检查 | 退出1，未允许整个库通过发布门禁 |
| 有效单例导出 | `upstream-api`两套SDK分别导出并独立重建，输出`3\n2\n3\n` |
| 输入变化 | 当前query返回空，`freshness=STALE`；export退出1、无目标目录 |

失败来自`unicode-empty`和`emoji-empty`两例，各两个SDK。登记断言分别按字符编辑距离解释，上游运行结果与其不一致；需与上游讨论语义，不能为通过检查而随意修改断言或生产源码。40格分母及全部失败记录保留。单例可复现不代表整个库可发布，也不代表所有接口正确。

## 准备与来源审核

按照[主README](../README.md)准备真实SDK与C编译器。Python脚本负责固定来源核验和调度，仓颉引擎负责实际状态和准入。上游来源由[integrations/upstream-lock.json](../integrations/upstream-lock.json)固定，要求提交、干净工作区、全部跟踪文件摘要和生产源码范围一致。不要用未审核的远程源码替换缓存。

```bash
export CJ_DOCGUARD_SDK_1_1_3=/absolute/sdk-1.1.3/cangjie
export CJ_DOCGUARD_SDK_1_2_0=/absolute/sdk-1.2.0/cangjie
python3 scripts/dev.py build
python3 scripts/real_projects.py --project leven4cj \
  --cache /absolute/reviewed-upstream-cache \
  --output build/real-projects-review
```

本轮实际使用已审核缓存，联网`--fetch`分支未在本轮执行。缺失缓存应先获取并审核锁定来源，不能把缺环境改写为通过。调度脚本退出0表示审计完成，必须继续查看输出的每项目原生退出码。本例原生verify为1。

## 严格检查与当前查询

调度输出最后一行`Audit record:`指向新建UTC目录。将以下`review_run`替换为该目录，避免误读其他轮次。`review_config`指向新副本的配置，不是上游缓存。

```bash
review_run=/absolute/cj-docguard/build/real-projects-review/ACTUAL_UTC_DIRECTORY
review_config="$review_run/leven4cj/docguard.toml"
python3 scripts/dev.py run -- check --config "$review_config" --strict
# 本例预期退出1，因为有4格真实登记断言失败。
python3 scripts/dev.py run -- query --config "$review_config" \
  --tool get_verified_examples --example upstream-api \
  --sdk 1.1.3 --platform Darwin-arm64
```

CLI（命令行工具）的查询JSON使用`items`和`rejected`字段。有效单例应在`items`中返回一条`eligible=true`记录，带真实尝试编号和断言。`query`退出0只表示查询成功，空结果不表示验证通过。MCP（供助手调用工具的协议）适配器会包装结果，解析时应依据各接口实际结构。

在持续集成或发布脚本中直接使用strict的退出码阻止后续发布：0表示必需范围满足，1表示质量问题，2表示配置或环境错误。当前仓库没有远端CI成功记录，本教程只给出可接入的命令契约。

## 导出与独立重建

```bash
python3 scripts/dev.py run -- export --config "$review_config" \
  --example upstream-api --sdk 1.1.3 --platform Darwin-arm64 \
  --out build/review-export-1.1.3
cd build/review-export-1.1.3
CJ_SDK_HOME=/absolute/sdk-1.1.3/cangjie bash build.sh
```

本轮标准输出为三行`3`、`2`、`3`，退出0。对1.2.0使用新空目录与相应SDK重复，结果一致。查看`manifest.json`中的实际SDK、平台、尝试编号、断言及冻结输入身份。导出脚本只编译冻结的单包源码，不自动下载依赖。

公开验证ZIP提供两套源码与脚本，不含SDK、二进制或`.cjo`。上游LICENSE与来源记录位于ZIP顶层，复制或分发示例时一起保留。附件是冻结历史，不能作为自己的工程当前验证结果；换源码或环境仍需复验。

## 输入变化对照

本轮在隔离生产源码末尾加入注释，内容摘要改变但没有执行新的verify。旧报告的历史状态仍为`RUN_VERIFIED`，重新query的`items`为空、`freshness=STALE`，export退出1且没有创建目录。恢复原始字节后，在没有较新执行尝试的条件下查询恢复当前有效。

这里比较的是静态报告读取和重新查询当前输入，不是第三方产品对照，也不测模型效果。恢复源码后若存在较新的失败、取消或进行中尝试，必须依最新记录判断，不能回退历史成功；该路径已有[R11验证](acceptance.md)。当前STALE条目的`reason`可能保留历史说明，应以`freshness`与`eligible`判断，说明文案优化仍在待办。

## 证据范围

本轮真实构建及13条命令包含两个预期质量失败：strict和过期export各退出1；矩阵调度退出0、内部原生verify退出1。一次外层检查器误用`records`字段，依据CLI真实`items`修正后在同一源码/二进制身份接续，原日志保留。这不是产品故障或全套回归重跑。

328份公开文本附件包含40格原生阶段日志、尝试、报告、命令、来源、两套导出源码及摘要映射。公开路径脱敏改变字节，原始指纹不能重新匹配；这些副本供审阅，不可作为准入目录。未重新验证全部三个上游项目、Linux、模型、第三方生产使用或浏览器报告页面。
