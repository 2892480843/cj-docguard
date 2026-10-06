# 健康样本直接审计记录

2026-10-06；实际平台 macOS ARM64。使用主工程 `scripts/dev.py compile`，分别由真实仓颉 SDK 1.1.3 和 1.2.0 编译每个登记示例；SDK 路径通过明确环境变量注册。

执行命令：

```sh
python3 examples/healthy/verify.py
```

| SDK | 编译成功 | 精确输出与退出码通过 | 仅编译 |
|---|---:|---:|---:|
| 1.1.3 | 14 | 13 | 1 |
| 1.2.0 | 14 | 13 | 1 |
| 合计 | **28** | **26** | **2** |

审计输出：

```text
PASS healthy audit: 28 real builds, 26 exact-output runs, 2 compile-only cases
```

原生 `std.ast` 提取同一库源码：`status=OK symbols=47 diagnostics=0`。公共接口名称和所属类型的手工清单见 [README](README.md)。库及示例共用单一 `docguard_demo` 包；片段先按登记模板生成完整程序，再使用相同真实编译流程。

编译器提醒接口成员的显式 `public` 为冗余修饰符。该写法为验证“明确公共声明”保留，不影响编译或运行；没有将编译器警告描述为完全没有警告。

**证据边界：**该记录来自自建样本的直接审计，不能认定为第三方采用，也不能在线证明后续仓库状态。持久执行证据、最新尝试优先和修改后的过期判定由 CJ-DocGuard 原生引擎另行复验。`compile-only` 项只编译，没有执行，也没有 `RUN_VERIFIED` 行为证明。
