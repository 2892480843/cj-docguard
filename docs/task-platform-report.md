# 原生命令执行与 SDK 身份验收记录

2026-10-06；已确认当前平台为 macOS ARM64，`uname` 返回的操作系统与架构用于实际身份，不采用声明推定。

本任务修改 `src/platform.cj`、`tests/native_platform.cj` 和本文档；经主代理追加授权，仅重构 `src/primitives.cj` 的 SHA-256（内容摘要算法，用于识别内容变化）部分并增加文件流式入口，不修改 JSON/TOML 行为。

## 实现契约

`runCommand(runner, argv, cwd, logDir, environment, timeoutMs): J` 通过 `std.process.launch` 调用随项目提供的 Unix C 进程监管器。参数为超时、`1048576` 字节日志上限、工作目录、标准输出文件、标准错误文件、结果文件、`--` 和原始参数数组；不插入 shell 拼接。

- 每次调用用 `Directory.createTemp` 创建独立日志目录，防止旧日志覆盖新证据。
- 子进程环境仅采用传入的显式映射；输入丢弃，监管器内部再将被测程序的输入连接到 `/dev/null`。
- 监管器的小量诊断用管道和 `waitOutput` 收集；被测程序的大量输出写入有上限的证据文件。
- 返回监管器原始 `exit_code / timed_out / truncated / interrupted / io_error / elapsed_ms / pid`，以及实际 `stdout / stderr` 文本、`argv`、开始结束时间、日志路径。环境值仅作为 `environment_hashes` 返回，不写明文秘密。
- 监管器失败、证据缺失、错误 JSON 或 I/O 错误明确抛异常，不伪造成功。

`inspectSdk(sdk, runner, workDir): J` 返回 `declared_version / version / available / reason / home / compiler / platform / environment / fingerprint`，以及内部计数 `hashed_entries`。

- SDK（软件开发工具包）目录来自明确 `home`，或 `CJ_DOCGUARD_SDK_1_1_3` 等注册变量，要求绝对路径。
- 调用真实 `cjc --version`，版本不一致则 `available=false`，保留实际版本和原因。
- 环境只有 SDK 工具路径、固定系统工具路径、`CANGJIE_HOME`、相应运行库路径、macOS `SDKROOT` 以及 `LANG/LC_ALL=C`。不继承当前进程其他变量。
- 指纹包含 `bin / tools / third_party / modules / lib / runtime` 目录的实际文件内容与规范路径、显式环境、真实平台/版本、规则版本及 C 监管器内容。`third_party` 包含随 SDK 提供的链接工具。
- 每次检查重读内容；只在同一次目录遍历内复用相同规范目标的摘要，处理 SDK 自身符号链接，避免重复读同一文件。不用文件大小或修改时间作为跨次成功缓存。
- `sha256File(path)` 使用 64 KiB 读缓冲和固定 SHA 状态，关闭文件；数组入口 `sha256(Array<Byte>)` 与文件入口共用压缩算法。

## 验证证据

先将返回空输出的最小函数替身与原生测试一起编译，观察到预期失败：`platform test failed: actual stdout/stderr text`。测试设置阶段遇到原共享工具函数 `currentProcess` 未声明，主代理已修正为 `Process.current`；最终全部使用项目真实共享文件，没有私有替身。

| 验证 | SDK 1.1.3 构建/运行 | SDK 1.2.0 构建/运行 |
|---|---|---|
| 原生平台测试：46 项断言 | 通过 | 通过 |
| 真实 1.1.3 和 1.2.0 编译器版本检查 | 通过 | 通过 |
| 输出、非零退出、启动失败、时间戳、独立日志目录 | 通过 | 通过 |
| 100 毫秒超时、1 MiB 截断、监管器中断、正常父进程退出后的后代清理 | 通过 | 通过 |
| 空参数、监管器缺失、证据缺失、I/O 异常 | 通过 | 通过 |
| 不继承凭据测试变量、环境值哈希、输入结束 | 通过 | 通过 |
| SDK 缺失、版本声明不符、环境注册、稳定指纹 | 通过 | 通过 |
| 保持大小和修改时间的编译器内容变化；模块、运行库、链接工具内容变化 | 通过 | 通过 |
| 11 个文件长度的流式/数组 SHA 一致性 | 通过 | 通过 |
| 原有基础测试：86 项断言 | 通过 | 通过 |

项目目录下可复验：

```sh
python3 scripts/dev.py compile --sdk 1.1.3 --output /tmp/docguard-extractor/platform-final-1.1.3 src/primitives.cj src/util.cj src/platform.cj tests/native_platform.cj -O2 -Woff unused -Woff deprecated
python3 scripts/dev.py compile --sdk 1.2.0 --output /tmp/docguard-extractor/platform-final-1.2.0 src/primitives.cj src/util.cj src/platform.cj tests/native_platform.cj -O2 -Woff unused -Woff deprecated
python3 scripts/dev.py compile --sdk 1.1.3 --output /tmp/docguard-extractor/primitives-new src/primitives.cj tests/native_primitives.cj -O2 -Woff unused
python3 scripts/dev.py compile --sdk 1.2.0 --output /tmp/docguard-extractor/primitives-1.2.0 src/primitives.cj tests/native_primitives.cj -O2 -Woff unused
```

产物运行须使用 `scripts/dev.py` 的 `sdk_env(version)` 注入相应 SDK 运行库环境。两套平台产物最终都返回退出码 0，输出：

```text
PASS native platform: 46 assertions; SDK identity, bounded execution, timeout, truncation, environment, streaming SHA
```

基础测试输出：

```text
PASS native primitives: 86 assertions; SHA256 vectors, JSON strict parsing/Unicode/types, TOML subset/errors
```

### 大文件问题与改进

真实 SDK 1.1.3 的 `bin/cjc` 为 166,060,136 字节。旧版 `sha256(File.readFrom(...))` 在默认运行时限制下失败，输出 `Out of memory`，测得约 243 MB 峰值常驻内存。流式版本在同一文件上哈希约 0.495 秒，整个进程约 0.99 秒，峰值约 7.7 MB；这是一次本机测量，不作为跨平台性能承诺。

流式结果：`8aa2577ca2ee376d9bf17a5f6db6f3ae42022f27954a5072c0cf432a837b50a3`，与 Python 标准库 `hashlib.file_digest(..., 'sha256')` 对同一真实文件的结果一致。原有标准 SHA 向量和边界长度测试均保持通过。

证据互证：本地 [官方进程函数文档](https://github.com/cangjielanguage/cangjie_runtime/blob/release/1.1/stdlib/doc/libs/std/process/process_package_api/process_package_funcs.md)、[官方进程类文档](https://github.com/cangjielanguage/cangjie_runtime/blob/release/1.1/stdlib/doc/libs/std/process/process_package_api/process_package_classes.md)、文件接口存档（原工作区 `.research/fs-classes.md`），以及双 SDK 实际运行。标准输入的 `Discard` 模式另经[官方枚举文档](https://docs.cangjie-lang.cn/docs/1.1.0/libs/std/process/process_package_api/process_package_enums.html)与实际 SDK 编译/运行交叉核验。

## 边界

- 进程组清理与资源上限不是安全沙箱；执行权限仍须由上层显式可信项目约束。
- 指纹检查证明指定时间点读取到的工具内容，不提供整个运行期间的文件锁或不可变宿主机保证；上层须执行输入/环境前后复核。
- SDK 身份通过内容、路径和实际版本输出绑定，不是官方签名认证。变异测试中的小型 shell 编译器替身仅用于证明内容变化可检测，不作为真实 SDK 验收证据。
- 指纹覆盖随 SDK 提供的相关内容与 `SDKROOT` 路径；未遍历整个操作系统或 Apple 系统 SDK 内容。宿主系统外部依赖不能据此宣称完整封闭。
- 当前已实测 macOS ARM64；Linux 分支有明确架构判断，但未在 Linux 运行验证。
- 证据文本要求有效 UTF-8；无法按 UTF-8 读取会抛异常，原始受限日志文件仍保留。
