# 查询命令与筛选范围

CLI（命令行程序）与 MCP（供 AI 助手调用工具的协议）使用同一组原生查询工具。查询目标由 `--config FILE` 指定；工具名错误、不适用的筛选参数、必需环境参数缺失或仅含 ASCII 空白，均在读取配置、创建探针或报告之前返回 `2`。SDK 是否登记等与项目有关的检查，仍需读取配置后判断。

| 查询工具 | 接受的筛选参数 | 必需条件 | 返回内容 |
|---|---|---|---|
| `list_symbols` | `--symbol`，匹配名称或符号 ID | 无 SDK / 平台条件 | 当前解析到的公共声明，不提供运行成功保证 |
| `get_verified_examples` | `--symbol`、`--example`、`--sdk`、`--platform` | SDK 与平台必须显式指定，不能为空或仅含 ASCII 空白 | 当前证据充分、实际运行断言通过的示例 |
| `get_evidence` | 同上 | 同上 | 与当前证据查询相同的准入规则及拒绝原因 |

`query` 默认工具为 `list_symbols`，因此也不接受 `--sdk`、`--platform`、`--example`；这些条件不会被静默忽略。`evidence` 是 `get_evidence` 的快捷命令，不接受 `--tool`。未支持的工具明确报错。SDK 与平台按原始字符串精确匹配，不自动修剪、转换或跨版本回退。

```bash
# 公共声明查询，支持名称或符号 ID
python3 scripts/dev.py run -- query --config examples/healthy/docguard.toml --symbol add

# 按登记符号名称查询有实际运行证据的示例
python3 scripts/dev.py run -- query --config examples/healthy/docguard.toml \
  --tool get_verified_examples --symbol add --sdk 1.1.3 --platform Darwin-arm64

# 精确定位登记的例子
python3 scripts/dev.py run -- evidence --config examples/healthy/docguard.toml \
  --example arithmetic --sdk 1.1.3 --platform Darwin-arm64
```

证据查询的 `--symbol` 当前按登记例子的符号名称精确匹配；声明查询另支持符号 ID，二者的范围不混淆。若目标 SDK 未在配置中登记，返回 `2`。不匹配的实际平台或不存在的例子返回空集合；证据过期、未知、仅编译或不完整时，通过拒绝原因说明，不能回退到旧成功。

有效查询仍会重新计算输入身份、检查 SDK 并写入私有探针日志，受项目互斥目录保护；不会执行登记例子。无参数副作用的保证仅针对上述参数校验失败，不适用于有效查询过程中的所有环境错误。

R02 的实际修复及原始回归记录见 [持续优化记录](optimization-log.md)。MCP 适配器的参数范围在 `scripts/mcp_stdio.py` 中定义；核心证据准入始终由仓颉程序判断。
