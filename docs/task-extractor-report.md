# 原生 API 提取验收记录

2026-10-06；平台已确认：macOS / Darwin，实际运行使用 darwin_aarch64_cjnative 仓颉 SDK。

本任务仅实现 `src/extractor.cj`、`tests/native_extractor.cj` 与本文档。`extractSource(source: String, path: String): J` 使用真实 `std.ast.cangjieLex` 和 `parseProgram`；JSON（结构化数据表示）使用项目 `src/primitives.cj` 的 `J`。

## 范围与行为

| 内容 | 已实现行为 |
|---|---|
| 返回对象 | `symbols`、`diagnostics`、`imports`、`package`、`status`；契约字段完整 |
| 公共接口 | 仅明确 `public` 的顶层函数、变量、类型别名、类、结构体、接口、枚举以及可见父类型下明确 `public` 的成员 |
| 父类型可见性 | 非公共父类型的公共成员不会输出为公共 API |
| 函数与构造器 | 普通函数、重载、操作符重载、`init` 和主构造器；保留原始声明头中的泛型、约束、参数默认值及命名参数标记 |
| 参数与类型 | 参数名和源码中的显式类型；元组、可选类型、函数类型、泛型类型；不执行完整类型推断 |
| 类型未知 | 缺少显式函数返回类型或变量类型时，`returns="unknown"`、`status="TYPE_UNKNOWN"`，并产生 `AST_TYPE_UNKNOWN` 警告；`Unit` 不作隐式推断 |
| 枚举构造项 | 可见枚举的构造项随枚举可见性输出；无参数名的载荷用 `arg0` 等占位名，类型取显式源码 |
| 原始位置与注释 | 声明起始行、UTF-8 字节列、源码路径、原始声明头；紧邻的 `///` 与 `/** ... */` 中文文档注释 |
| 不支持结构 | 宏/注解、条件编译、`extend`、公共解构变量以及未覆盖的声明节点都有警告，不静默当作完整提取 |
| 条件与宏 | 不执行宏展开或分支判定；带注解声明及其子成员保守跳过，状态为 `PARTIAL` |
| 错误 | 词法/语法失败为 `PARSE_FAILED`、空符号数组与 `AST_PARSE_FAILED`；提取阶段异常单独标为 `PARTIAL` 和 `AST_EXTRACTION_FAILED` |

文件状态为 `OK / PARTIAL / PARSE_FAILED`；符号状态为 `SUPPORTED / TYPE_UNKNOWN`。`SUPPORTED` 表示已覆盖的语法提取，不证明类型检查、链接或运行正确。

诊断字段统一为 `rule`、`severity`、`message`、`source`、`line`、`column`。解析器异常没有稳定的结构化位置接口，因此错误诊断的未知位置显式使用 `0:0`；支持节点与预扫描警告保留原始位置。符号 ID 由主引擎添加。

## 测试证据

先用完整测试调用返回空结果的最小提取器，真实 SDK 1.1.3 编译成功后观察到预期失败：`extractor test failed: package preserved`。随后实现真实 AST 提取，补充条件编译接口不得误认定为支持、字符串字面值不得误认为关键字两项回归测试；两项都分别观察到失败后修复。

最终测试使用真实 `primitives.cj`，不使用临时替身。

| 验证 | SDK 1.1.3 | SDK 1.2.0 |
|---|---|---|
| 37 个手工逐项枚举的公共符号，核对名称、所属类型、包与来源 | 通过 | 通过 |
| 泛型与约束、函数重载、显式参数/返回类型 | 通过 | 通过 |
| 字段、属性、枚举构造载荷、操作符、主构造器 | 通过 | 通过 |
| 私有父类及私有成员排除、未知返回/变量类型披露 | 通过 | 通过 |
| 无效语法、宏、条件编译、扩展、解构未支持警告 | 通过 | 通过 |
| 中文标识符、中文行/块文档注释、UTF-8 字节列 | 通过 | 通过 |
| 注释/字符串中的关键字与单独 `macro` / `@` 字面值不误报 | 通过 | 通过 |

从项目目录编译：

```sh
python3 scripts/dev.py compile --sdk 1.1.3 --output /tmp/docguard-extractor/final-1.1.3 src/primitives.cj src/extractor.cj tests/native_extractor.cj -Woff unused
python3 scripts/dev.py compile --sdk 1.2.0 --output /tmp/docguard-extractor/final-1.2.0 src/primitives.cj src/extractor.cj tests/native_extractor.cj -Woff unused
```

运行编译产物时使用对应 SDK 的 `sdk_env`；例如：

```python
import importlib.util
import pathlib
import subprocess

spec = importlib.util.spec_from_file_location("dev", pathlib.Path("scripts/dev.py"))
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)
for version in ("1.1.3", "1.2.0"):
    subprocess.run(["/tmp/docguard-extractor/final-" + version],
                   env=dev.sdk_env(version), check=True)
```

两次最终运行输出均为：

```text
native extractor: 37 symbol cases and boundary tests passed
exit_code: 0
```

本地证据互证：官方 AST 文档的 节点结构存档（原工作区 `.research/ast-classes.md`） 与 [官方解析函数文档](https://github.com/cangjielanguage/cangjie_runtime/blob/release/1.1/stdlib/doc/libs/std/ast/ast_package_api/ast_package_funcs.md)，以及两个真实 SDK 的执行测试。额外探针确认：`Decl.beginPos/endPos` 与类型位置可靠，部分 `Body/Block/Constructor` 节点位置为 `0:0`，但相应花括号/标识符词法单元位置可靠；生产代码据此使用词法单元位置。

## 已知边界

- 没有语义分析、继承成员展开、跨文件名称绑定、全类型推断、宏执行或条件分支求值。任意注解保守视为未支持，可能少列出本可静态读取的接口，但不会把其语义认定为已验证。
- 仅支持明确 `public` 的普通声明；未显式写出的默认可见性不推定。枚举构造项按可见枚举继承可见性。
- 原始签名保留书写差异；格式变更可能影响主引擎基于签名生成的 ID。重载以不同声明头区分，不执行语义等价判断。
- 文档注释只读取紧邻声明前的文档块，不将远处注释自动绑定到声明；同一行前置注释暂不绑定。
- `imports` 保留 AST 可提供的源码或格式化文本；不解析依赖图或证明导入有效。
- 已实测 macOS ARM64 下 SDK 1.1.3/1.2.0；未验证其他操作系统或架构。
