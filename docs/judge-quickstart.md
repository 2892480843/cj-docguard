# 评委从公开源码复现

本文以 **macOS arm64** 为已验证宿主，使用仓颉 SDK（软件开发工具包）1.1.3 和 1.2.0。已有工具链的干净源码目录复现已记录在[全面复核](finals-comprehensive-audit-2026-10-29.md)；**没有声称全新操作系统已完成在线安装验收**。Linux 等其他平台不属于本轮完整验收范围。

## 1. 获取当前源码

默认使用公开主仓库的 `main`，不从旧初赛 ZIP 开始：

```bash
git clone --branch main https://atomgit.com/c2892480843s/cj-docguard.git
cd cj-docguard
git rev-parse HEAD
```

GitHub 镜像为 `https://github.com/2892480843/cj-docguard.git`。最新版答辩对应功能源码 `068a22a8a4d1987ac0aac837da22b39c8224417f`，固定复现可执行 `git checkout 068a22a8a4d1987ac0aac837da22b39c8224417f`；最新版讲稿及页面入口见[答辩材料](../submission/finals-2026-10-29/roadshow-v3/README.md)。此前冻结批次保留 `finals-source-20261029-r2` 标签；其发布身份以[迭代说明](finals-iteration-2026-10-29.md)和发布记录为准。首次克隆没有本地第三方缓存、验证历史及既有项目 ID，不能直接套用作者机器上的 ID。

## 2. 准备工具链

正式构建与服务需要 `git`、`bash`、`cc`、`ar`、`zip` 及仓颉 SDK；浏览器无需 npm 安装。Python 标准库用于 SDK 安装器、CLI 辅助、测试及 MCP（模型上下文协议）适配器，**不提供正式 HTTP 服务**。安装器最低 Python 3.11.4，原因是安全解包过滤参数；见 [Python 官方说明](https://docs.python.org/3.11/library/tarfile.html#extraction-filters)。Node.js 仅在运行网页脚本测试时需要。

可从[官方 1.1.3 下载页](https://cangjie-lang.cn/download/1.1.3)和[官方 1.2.0 下载页](https://cangjie-lang.cn/download/1.2.0)手动下载 macOS aarch64 归档，校验值见[工具链记录](toolchains.md)。将解包后的 `cangjie` 目录以绝对路径登记：

```bash
export CJ_DOCGUARD_SDK_1_1_3=/absolute/path/sdk-1.1.3/cangjie
export CJ_DOCGUARD_SDK_1_2_0=/absolute/path/sdk-1.2.0/cangjie
```

或者显式运行官方归档安装器；它下载并核验固定摘要，不覆盖已存在目录，不安装 Apple 系统 SDK：

```bash
python3 scripts/install_sdk.py --sdk 1.1.3
python3 scripts/install_sdk.py --sdk 1.2.0
```

安装目标为 `.local/sdks/<版本>/cangjie`，构建脚本可自动发现；另支持上级 `.toolchains/<版本>/cangjie`。已有安装不需重复运行安装器。

### Apple 系统 SDK 与缺失诊断

仓颉 SDK 与 Apple 系统 SDK 是两种独立依赖。Apple 提供 [Xcode 与附加命令行工具入口](https://developer.apple.com/xcode/resources/)；旧版 Xcode、Command Line Tools 可通过 [Apple 官方下载页](https://developer.apple.com/download/all/)按账户登录获取。下载页需登录，本次只验证官方入口，未验证任一全新机器的安装过程或账户可见归档。

```bash
uname -sm
command -v cc ar bash zip
xcrun --sdk macosx --show-sdk-path
```

`xcrun` 显示当前选中开发工具的系统 SDK 路径，不证明仓颉链接器兼容它。本机 Xcode 27 默认 SDK 与旧仓颉链接器的 `.tbd` 格式存在已复现兼容问题，本轮使用已安装的 macOS 15.4 系统 SDK：

```bash
export CJ_DOCGUARD_SYSTEM_SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
test -f "$CJ_DOCGUARD_SYSTEM_SDKROOT/usr/lib/libSystem.tbd"
```

**只在该路径确实存在时使用上述值**；其他机器应改为实际已安装的兼容 SDK 绝对路径。若 `xcrun` 报缺失工具、`test` 失败或辅助命令报告 `system SDK lacks usr/lib/libSystem.tbd`，先从 Apple 官方渠道安装/选择工具并检查路径。若出现 `.tbd` 解析错误，记录系统 SDK 与链接器版本，选择经过实际编译验证的兼容 SDK；脚本不会自动安装、降级或修改全局 Xcode 选择。

```bash
python3 scripts/dev.py probe --sdk 1.1.3
python3 scripts/dev.py probe --sdk 1.2.0
```

## 3. 构建并打开工作台

在同一终端保留上面的环境变量：

```bash
bash scripts/build_workbench.sh
bash scripts/workbench.sh --port 8765
```

打开 <http://127.0.0.1:8765>。正式进程是 `build/cj-docguard-workbench`，无需 Python 服务。先在“项目配置”确认工具链，再从“项目概览”或“任务中心”依次执行检查环境、生成文档、运行测试和检查链接。默认健康样本首次没有历史报告是正常状态；两个 SDK 可用且输入未改动时，预期 **28 格当前有效，其中 26 格运行验证、2 格仅编译**。仅编译不代表行为断言通过。

继续在“接口文档 / 示例测试 / SDK 测试矩阵”查看接口和结果，在“源码编辑”查看登记源码，在“测试结果查询”指定SDK与平台进行只读查询，在“历史记录”查看过去尝试，从“项目概览”导出示例包及包内重建脚本。详见[原生工作台指南](native-workbench.md)。服务仅绑定本机，不作为公网服务器或任意代码安全沙箱。

CLI（命令行界面）可由辅助脚本正确设置运行库后执行：

```bash
python3 scripts/dev.py run -- doctor --config examples/healthy/docguard.toml
python3 scripts/dev.py run -- verify --matrix --config examples/healthy/docguard.toml
python3 scripts/dev.py run -- check --strict --config examples/healthy/docguard.toml
```

也可在 Bash 中加载同一环境后直接执行原生程序：

```bash
bash -c 'source scripts/native_env.sh; build/cj-docguard verify --matrix --config examples/healthy/docguard.toml'
```

## 4. 对照复现真实库原版与本地修复版

先阅读锁定来源 `integrations/upstream-lock.json` 和[修复说明](real-library-unicode-repair-2026-10-29.md)。以下明确联网取得已审阅、固定提交的公开源码，分别写入两个输出根目录；不会抓取任意仓库或执行上游测试脚本：

```bash
python3 scripts/real_projects.py --project leven4cj --cache build/reviewed-upstream-cache --fetch --output build/judge-original
python3 scripts/real_projects.py --project leven4cj --cache build/reviewed-upstream-cache --output build/judge-fixed --apply-reviewed-fixes
```

已有经审阅缓存时，将 `--cache` 改为实际路径，并省略 `--fetch`。缓存必须是锁定提交、完整文件摘要匹配且工作树干净；不满足则拒绝。修复仅显式应用于新生成的副本，不改变缓存、锁或既有断言，保留 Apache-2.0 许可证。

每条命令打印 `Audit record: .../audit.json`；打开该记录，查看 `projects[].command` 中的配置绝对路径和 `exit_code`。**编排脚本退出 0 表示审计过程完成，并不表示库全部断言通过**：原版原生 verify 预期退出 1（36/40 当前有效、4 断言失败），本地修复版预期退出 0（40/40 当前有效）。异常安装/审计失败另报非零。

在工作台“项目与配置 → 登记已有配置”，分别粘贴本次记录中的 `docguard.toml` 绝对路径；名称区分原版和 local fixed。以网页新生成的项目 ID 为准，随后诊断、构建索引、运行验证、检查并比较矩阵。可把实际配置路径传给上述 CLI 的 `--config` 重新核验；原版严格检查预期 1，修复版预期 0。不要将历史截图或审计过程退出码替代本次结果。

## 5. 运行完整验收

```bash
python3 scripts/test.py
node tests/test_workbench_ui.mjs
python3 scripts/validate_checkout.py
```

真实库扩展测试需要前述原版源码副本：`tests/test_real_projects.py` 的原版/修复 Unicode 对照默认显式启用。将经锁验证的原版放在 `build/workbench/projects/leven4cj/upstream` 后执行 `CJ_DOCGUARD_TEST_REAL_UNICODE=1 PYTHONPATH=scripts:tests python3 -m unittest test_real_projects -v`。离线新克隆没有该缓存时，相关跳过会在日志中明确显示；它不等于真实库验证通过。

若要通过正在运行的工作台重新执行原版/修复版对照及双 SDK 导出重建，传入本次审计产生的实际配置路径：

```bash
python3 scripts/validate_finals.py --original-config /absolute/path/original/docguard.toml --fixed-config /absolute/path/fixed/docguard.toml
```

该工具会登记两个项目、运行真实任务、保存报告，并核对原版预期失败与修复版通过。含坏链的专用样本严格检查预期退出 1；工具整体退出 0 表示这些正负用例均符合预期。

R2 已修复真实库脚本的环境白名单：显式登记的 `CJ_DOCGUARD_SYSTEM_SDKROOT` 会传递给原生验证进程。只看到编排退出 0 仍须检查审计中的项目退出码和矩阵；如出现全部编译失败，应查看实际编译日志，不能当作预期的四个行为断言失败。
