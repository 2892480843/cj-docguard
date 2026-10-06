# 真实开源仓库固定提交复验

2026-10-06 在本地 **macOS / Darwin arm64** 上完成三个真实开源仓库的独立复验，共登记 **3 个样例、6 个 SDK 单元**。`leven4cj` 两个单元通过并具有当时的当前证据；`is-png-cj` 两个单元运行断言通过，但输入闭合审查不足；`compare-versions-cj` 两个单元实际编译失败。**这些结果不代表上游采用 CJ-DocGuard，也没有达到累计 60 个真实项目样例的目标。**

SDK（软件开发工具包，包含编译器和标准库）分别为实际安装并核验版本的 Cangjie 1.1.3、1.2.0；API（公共编程接口）通过原生语法树提取。下面的 `CURRENT` 是执行时的状态，离线文档不能证明读者当前机器的文件状态。

## 固定来源与许可

| 项目 | 固定提交 | 许可 | 完整生产源码 / 排除的测试源码 |
|---|---|---|---|
| [leven4cj](https://github.com/cangjielanguage-tpc/leven4cj/tree/da69d981027b9fcbe12d09cfbb275b4ce8acc91d) | `da69d981027b9fcbe12d09cfbb275b4ce8acc91d` | [Apache-2.0](../integrations/leven4cj/LICENSE) | 1 / 1 文件 |
| [is-png-cj](https://github.com/cangjielanguage-tpc/is-png-cj/tree/e1fdf9b6b3c2cdbf7ba85d94828729d4fb857028) | `e1fdf9b6b3c2cdbf7ba85d94828729d4fb857028` | [MIT](../integrations/is-png-cj/LICENSE) | 2 / 1 文件 |
| [compare-versions-cj](https://github.com/cangjielanguage-tpc/compare-versions-cj/tree/d0f664c9b25c4cda41238f7a0406004faa6a82a6) | `d0f664c9b25c4cda41238f7a0406004faa6a82a6` | [MIT](../integrations/compare-versions-cj/LICENSE) | 5 / 5 文件 |

执行前已阅读实际生产源码、测试源码、上游样例、许可证、项目配置和构建脚本。选定的调用执行纯算法或内存字节判断；没有调用上游构建脚本、测试宏、Git 钩子或外部下载程序。进程监督器提供超时和进程组清理，**不提供安全沙箱**。

[upstream-lock.json](../integrations/upstream-lock.json) 固定提交和全部受 Git 跟踪文件的 SHA-256（内容摘要，用于发现字节变化），包括许可证、文档、源码和测试。脚本执行前要求提交匹配、工作目录干净、文件清单匹配、每个文件摘要匹配且没有符号链接，并核对生产源码范围。三份上游许可证原文保留在集成目录。

## 实际结果

执行时间（UTC）：2026-10-06T12:13:27.369833+00:00 至 2026-10-06T12:13:59.675952+00:00。当时原生 CLI（命令行程序）二进制 SHA-256 为 `2590b9c4a86d57a40617efde1091753ea0f130ba568b9f8ed5633bfa0acf7c3b`。报告对应此二进制；后续代码构建应重新复验。

| 项目 | SDK 1.1.3 | SDK 1.2.0 | 原生 CLI 退出码 | 公共符号 / 输入闭合 |
|---|---|---|---:|---|
| leven4cj | `RUN_VERIFIED` / `CURRENT` | `RUN_VERIFIED` / `CURRENT` | 0 | 1 / 完成 |
| is-png-cj | `RUN_VERIFIED` / `UNKNOWN_CURRENT` | `RUN_VERIFIED` / `UNKNOWN_CURRENT` | 1 | 2 个重载 / 未完成 |
| compare-versions-cj | `COMPILE_FAILED` / `UNKNOWN_CURRENT` | `COMPILE_FAILED` / `UNKNOWN_CURRENT` | 1 | 5 / 未完成 |

`RUN_VERIFIED` 表示登记的退出码和标准输出断言均通过；`CURRENT` 表示当时输入、环境和完整证据匹配；`UNKNOWN_CURRENT` 表示尚不能认定证据对应完整受审查输入；`COMPILE_FAILED` 表示真实编译器拒绝源码。运行断言通过与输入闭合是两个独立条件。

- [leven4cj 样例](../integrations/leven4cj/sample.cj)：编辑距离 `kitten → sitting`、中文句子两个字符替换、空字符串至 ASCII 文本；实际标准输出为 `3\n2\n3\n`，两个 SDK 运行退出码均为 0。空字符串与多字节文本的其他边界没有在此样例中验证。
- [is-png-cj 样例](../integrations/is-png-cj/sample.cj)：正确八字节 PNG 标识、过短标识、末字节错误；实际标准输出为 `true\nfalse\nfalse\n`，两个 SDK 运行退出码均为 0。这里只检查标识，不证明完整 PNG 内容有效；`InputStream` 重载未运行。两份生产文件的 `std.io.*` 导入触发 `INPUT_CLOSURE_UNKNOWN`，因此没有将通过运行升级为当前可用证据。
- [compare-versions-cj 样例](../integrations/compare-versions-cj/sample.cj)：登记大于、等于、小于的版本比较及合法/非法严格版本判断；预期标准输出为 `1\n0\n-1\ntrue\nfalse\n`。**编译失败，未实际得到该输出，未执行运行断言。**

`compare-versions-cj` 两个 SDK 的编译器均报告上游 `MatchData.matchStr`、`ArrayList.append` 不存在，`remove(Int64)` 与当前重载不匹配，以及 `matches(...)` 返回值无法调用 `isSome()`。具体位置为 `satisfies.cj:113/126`、`util.cj:83/90/100`、`validate.cj:42`。上游 `cjpm.toml` 声明旧编译器版本 `0.55.3`；本次没有用该旧版本复验，也没有修改源码以强行通过。完整编译输出的可读副本： [1.1.3](../integrations/compare-versions-cj/compiler-1.1.3.txt)、[1.2.0](../integrations/compare-versions-cj/compiler-1.2.0.txt)。副本仅移除终端颜色控制码，原始字节日志仍保留在构建证据中。

语法提取还明确报告 `compare.cj:35` 缺少显式返回类型为 `AST_TYPE_UNKNOWN`，`util.cj:95` 扩展声明为 `AST_UNSUPPORTED_EXTEND`；`std.regex.*` 导入同样触发输入闭合未知。五份生产文件中四份提取 `OK`，`util.cj` 为 `PARTIAL`，没有宣称完整支持其公共接口。

## 覆盖范围与复现

编译范围是各仓库 **全部 `src/**/*.cj` 生产源码**，不改写任何上游字节。测试明确排除：

| 项目 | 显式排除 |
|---|---|
| leven4cj | `src/test/leven_test.cj` |
| is-png-cj | `src/is_png_test.cj` |
| compare-versions-cj | `src/compare_test.cj`、`src/compare_version_test.cj`、`src/satisfies_test.cj`、`src/util_test.cj`、`src/validate_test.cj` |

这些测试源仍复制进本地缓存并在来源文件中记录摘要，配置排除决定生产分析和编译范围。许可证、README、`cjpm.toml`、完整摘要来源文件及自建调用样例一并进入原生项目输入快照。运行样例与上游库使用同包，验证真实公共函数调用；没有验证独立库发布、跨包导入或上游整个测试套件。完整上游仓库不写入本项目源码树。

在项目根目录执行；Python 3.11+ 仅负责固定来源检查和原生 CLI 调度，证据状态由仓颉引擎产生：

```sh
python3 scripts/dev.py build
python3 scripts/real_projects.py --cache ../.research/external
```

另一个机器可获取相同固定提交；该联网获取分支本次没有执行验证：

```sh
python3 scripts/real_projects.py --fetch
```

可用 `--sdk 1.1.3` 或 `--project leven4cj` 缩小范围。SDK 位置由 `scripts/dev.py` 及显式 `CJ_DOCGUARD_SDK_1_1_3` / `CJ_DOCGUARD_SDK_1_2_0` 注册处理。子进程环境只保留工具链关键变量及 `C` 区域设置，不继承其他凭据。

每次运行建立唯一 `build/real-projects/<UTC时间>/` 目录，保存每项目 `docguard.toml`、未改写的生产源码、原生 `.docguard/report.json`、输入快照、编译/运行日志和 `audit.json`；调度日志在项目输入目录之外。脚本记录二进制执行前后的摘要，若执行期间二进制变化则明确失败，要求固定二进制重新运行。脚本退出 0 表示审计流程完成，**不表示项目全部验证通过**；各项目原生 CLI 退出码和单元状态保留在 `audit.json`。来源不匹配、执行基础设施错误或二进制变化退出 2。

## 保留证据与检查

[只读审计摘要](../integrations/audit-20261006.json) 保存三个项目、六个单元的真实时间、原生退出码、断言结果、输入/环境指纹、诊断及报告摘要。原始完整证据保留于本地 [审计目录](../build/real-projects/20261006T121327259937Z/audit.json)；编译日志的原始摘要和完整报告摘要也写入只读摘要。

另外完成 35 项来源及集成检查：三个缓存均与固定提交和全部摘要一致、生成配置排除规则正确、生成生产文件/许可证/上游说明/配置与原始字节一致、编译失败日志摘要匹配，以及内容摘要不匹配和缺失缓存被拒绝。另有两个临时隔离调度测试确认日志写在输入目录之外、保留项目非零退出码，以及执行中二进制变化会保存证据后拒绝；这些测试使用临时替代执行结果，不计入上面的真实 SDK 单元。上游工作目录保持干净。脚本帮助、语法、文档链接和 UTF-8 编码均经过本地检查。

这些结果支持此处列出的三个固定来源及样例，不推断未运行的函数、操作系统、SDK 版本或第三方生产使用情况。
