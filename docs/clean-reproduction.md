# 干净目录复现记录

**最终正式输入的干净目录复验已通过。** 2026-10-06 在本地 macOS / Darwin arm64、Python 3.14.6 上，从无旧构建和报告的独立副本编译 C 监督器与仓颉核心，再用真实 Cangjie 1.1.3 / 1.2.0 验证健康样例。最新 28 个单元为 **26 `RUN_VERIFIED`、2 `COMPILE_ONLY`、28 `CURRENT`**；严格检查退出 0。

本结论对应第六个独立目录及明确同步后的最终 README / 10 秒配置。较早失败、诊断副本和同步前的执行日志全部保留。

## 最终证据与输入隔离

最终目录为 `build/clean-reproduction/20261006T121714841394Z/project`。从项目原始字节复制 78 文件、450,573 字节，递归排除 `.git`、`build`、`target`、`.local`、`.docguard`、`__pycache__`、`.DS_Store`。首次构建前确认没有构建目录、示例报告或历史尝试；没有复制根目录任何执行产物。

复制前后核对全部 `src` / `scripts` / `tests` 的 SHA-256（逐字节内容摘要），并核对副本内容。随后按明确指令将健康 README 从“1000 毫秒”同步为“10000 毫秒（10 秒）”，记录原文、更新文本、前后摘要及同步时间，完成真实再次验证。最终输入为 450,598 字节；最终执行前后，核心源码与完整健康输入均与原目录字节匹配。副本其余说明文档保留复制时的快照。

- [初始复制清单](../build/clean-reproduction/20261006T121714841394Z/copy-manifest.json)：完整路径、字节数、摘要、递归排除规则及显式工具链注册。
- [README 同步记录](../build/clean-reproduction/20261006T121714841394Z/input-adjustments/record.json)与[最终输入清单](../build/clean-reproduction/20261006T121714841394Z/final-input-manifest.json)。
- [最终结果](../build/clean-reproduction/20261006T121714841394Z/result.json)与[全部命令日志索引](../build/clean-reproduction/20261006T121714841394Z/commands.json)。
- [最终真实验证报告](../build/clean-reproduction/20261006T121714841394Z/verified-report.json)及[源码变化后的拒绝报告](../build/clean-reproduction/20261006T121714841394Z/stale-report.json)。

SDK（软件开发工具包，提供真实编译器和标准库）使用已有安装的显式注册，不复制既有编译程序。新的 C 监督器和仓颉 CLI（命令行程序）均在独立目录自行构建。子进程仅保留明确的工具链路径、SDK 注册、`C` 区域设置和新编译的监督器位置；包管理器探针使用独立空配置目录。

本次原生产物摘要：

| 产物 | SHA-256 |
|---|---|
| 仓颉 CLI | `656f2ebbf6333b45c1f5cc182434c3ad5f80b4dc6665022b8eb984cef99179f0` |
| C 监督器 | `271fb80b9a191f1ac260e559637d8b2c54d7fbdad11a8b1046b6333e891d919f` |
| 最终健康配置 | `cf63f893eecdebac5239682114c4ff5781db246afee002ecead28957a8b6e496` |

## 实际检查

最终真实再次验证执行于 2026-10-06 20:20:20–20:20:47（UTC+08:00），后续查询、结构检查及变化拒绝完成于 20:21:18。

| 检查 | 观察结果 |
|---|---|
| 独立 C / 仓颉构建 | `scripts/dev.py build` 退出 0 |
| 两个 SDK 探针 | 实际 `cjc` / `cjpm` 各报告 1.1.3、1.2.0，均退出 0；编译器目标均为 `aarch64-apple-darwin` |
| 原生 `doctor` | 两个编译器及包管理器均可用，退出 0 |
| 完整健康矩阵 | 14 个登记样例 × 2 SDK；26 个运行输出及退出码断言通过，2 个只编译；最新 28 个均 `CURRENT` |
| 精确 SDK / 平台查询 | `1.1.3` / `Darwin-arm64` 返回 13 个可用运行样例；只编译样例不进入行为已验证结果 |
| 严格检查 | 未变更输入时退出 0；66 项原生链接检查均 `PASS` |
| 源码追加注释后 | 可用查询结果 0，14 个目标记录均拒绝为 `STALE`；严格检查退出 1，28 个矩阵单元全部过期 |
| 原始源码字节恢复后 | 没有新增尝试，原证据重新匹配相同输入；可用查询恢复 13，严格检查恢复退出 0 |
| 报告文件和锚点 | 47 个 API（公共编程接口）符号；87 个唯一 HTML ID、108 个内部锚点链接、4 个产物链接及源码查看入口均存在 |
| 搜索脚本 | Node v22.23.2 VM 检查通过：47 个接口卡片、1 个源码卡片；接口搜索不隐藏源码入口 |

第六目录内有 56 个历史尝试：首次执行产生 1–28，README 明确同步后的真实再验证产生 29–56。最终结果仅按最新 29–56 判定。全部历史均由该独立目录自行执行生成；没有复制旧成功证据来取得当前状态。

页面检查使用 `HTMLParser`（HTML 结构解析器，检查文件链接和锚点）以及 Node VM（为脚本提供最小页面对象、检查过滤结果的单元测试上下文）。**没有执行浏览器或视觉布局检查。** Node VM 测试不是浏览器访问，也不构成安全沙箱验证。

## 复现操作

在项目根目录先将两个 SDK 注册变量设为真实安装目录，再用 Python 标准库复制项目到新目录：

```sh
export CJ_DOCGUARD_SDK_1_1_3=/absolute/path/to/1.1.3/cangjie
export CJ_DOCGUARD_SDK_1_2_0=/absolute/path/to/1.2.0/cangjie
task_clean=$(python3 - <<'PY'
from pathlib import Path
import shutil, tempfile
destination = Path(tempfile.mkdtemp(prefix='cjdg-clean-')) / 'project'
shutil.copytree(Path.cwd(), destination, ignore=shutil.ignore_patterns(
    '.git', 'build', 'target', '.local', '.docguard', '__pycache__', '.DS_Store'))
print(destination)
PY
)
cd "$task_clean"
python3 scripts/dev.py build
python3 scripts/dev.py probe --sdk 1.1.3
python3 scripts/dev.py probe --sdk 1.2.0
python3 scripts/dev.py run -- doctor --config examples/healthy/docguard.toml
python3 scripts/dev.py run -- verify --matrix --config examples/healthy/docguard.toml
python3 scripts/dev.py run -- check --strict --config examples/healthy/docguard.toml
python3 scripts/dev.py run -- query --config examples/healthy/docguard.toml \
  --tool get_verified_examples --sdk 1.1.3 --platform Darwin-arm64
python3 scripts/check_report_site.py examples/healthy/.docguard/site/index.html
```

提供实际 Node 可执行路径后可加 `--node /absolute/path/to/node` 检查搜索脚本。上述命令保留可读入口；本次实际直接调用原生二进制的完整参数、显式环境、时间和输出详见命令日志索引。

## 发现问题与正式预算

复验过程中真实发现无 `HOME` 的包管理器探针失败，以及报告生成时的 `ConcurrentModificationException`。修复分别使用受控的空包管理器配置目录和报告集合的固定数组快照；后续完整复验通过。底层运行时原因未单独确认。搜索计数还修正为仅选择接口区域的卡片，最终脚本检查确认源码查看入口保持可见。

主任务在并发构建期间曾保留一次包装样例的 1 秒预算耗尽记录 `a-137`：输出为预期 `42`，但退出码为 125 且 `timed_out=true`。正式健康配置将全部 14 个样例预算改为产品默认的 **10000 毫秒（10 秒）**；该超时没有被删除，尚未独立确定其 SDK / 运行时原因。最终本记录使用更新后的配置及 README。

先前独立目录继续保存于 `build/clean-reproduction/`：首个探针失败、第二个报告异常、第三个修复后的版本探针、第四个完整诊断、第五个 1 秒预算的成功复验均有原始记录。第四个执行末尾检测到源文件修改，拒绝做最终源码声明；第六个同步前同样检测到 README 变化，再经明确同步和真实再验证取得最终匹配证据。

## 安装器检查

[test_install_sdk.py](../tests/test_install_sdk.py) 的 9 项测试在本机及第五个独立副本通过；第六轮安装器与测试源码摘要保持相同，未重复执行。测试包含固定版本元数据、摘要不匹配拒绝、已有目录不覆盖、普通合成归档解包，以及合成的父目录逃逸、绝对符号链接、相对符号链接逃逸、特殊 FIFO 文件拒绝。**合成归档不是官方 SDK 安装证据。**

对两份实际缓存归档重新计算 SHA-256，与安装器固定值一致，并逐成员执行安装器采用的 `tarfile.data_filter` 路径保护检查：

| SDK | 归档字节数 | 全部通过路径保护的成员 | SHA-256 |
|---|---:|---:|---|
| 1.1.3 | 245,449,232 | 307 | `7eff8d3b9119535cf3d05cb81526c5df391137dce908d744449f4edb99da3199` |
| 1.2.0 | 163,787,681 | 314 | `de88d6ba2185c94979e0ab2fe8ac1d81535dfdff3fcb51fbba71e4b99d851f97` |

[归档检查记录](../build/clean-reproduction/official-archives.json) 保存精确摘要、成员数和字节数。本轮没有新增网络下载或将实际归档解包安装到新 SDK 目录，不作完整在线安装成功声明。缓存不可用时测试明确跳过归档校验。
