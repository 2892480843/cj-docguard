# CJ-DocGuard 自建健康样本

这是为 CJ-DocGuard 构造的本地测试库，**不是第三方采用案例，也不代表真实项目规模或生态采纳数量**。库包含 47 个原生公共符号，注册 14 类示例；其中 12 个完整程序和 1 个片段要求运行断言，另 1 个只检查编译。

库源码为 [src/demo.cj](src/demo.cj)，配置为 [docguard.toml](docguard.toml)。全部文件使用 `docguard_demo` 包；每个完整程序与库源码一起编译。

## 复验

SDK（软件开发工具包）1.1.3 和 1.2.0 必须由主工程安装或通过 `CJ_DOCGUARD_SDK_1_1_3`、`CJ_DOCGUARD_SDK_1_2_0` 明确注册。主工程的 `scripts/dev.py` 会使用已校验的本地 SDK。

在主工程目录直接审计所有示例：

```sh
python3 examples/healthy/verify.py
```

[独立审计脚本](verify.py)逐个调用主工程的构建脚本，使用真实编译器，核对运行输出与退出码；临时产物位于系统临时目录，结束后删除。它只继承明确列出的 SDK 变量和固定语言环境。

构建 CJ-DocGuard 后，通过原生引擎生成持久证据：

```sh
python3 scripts/dev.py build
python3 scripts/dev.py run -- verify --config examples/healthy/docguard.toml
```

运行必须由已审核配置显式允许。进程监管不是安全沙箱。原生引擎的断言与输入/环境指纹负责当前证据状态；直接审计记录是一次检查结果，不能替代后续的当前状态查询。

## 示例矩阵

每项均登记 `expected_exit=0`、两个 SDK、`required=true`；运行项还登记精确 `stdout`，运行超时预算为 10000 毫秒（10 秒）。

| 示例 | 类型与覆盖 | 期望标准输出 |
|---|---|---|
| [arithmetic](programs/arithmetic.cj) | 整数运算 | `42\n` |
| [strings](programs/strings.cj) | 中文文本、文本重复 | `你好，仓颉\n好好\n` |
| [booleans](programs/booleans.cj) | 布尔结果 | `true\nfalse\n` |
| [arrays](programs/arrays.cj) | 数组 | `10\n` |
| [generic-function](programs/generic-function.cj) | 泛型函数，保留不同参数类型 | `7\n类型保留\n` |
| [generic-class](programs/generic-class.cj) | 泛型类 | `容器\n` |
| [mutable-class](programs/mutable-class.cj) | 构造器、可变字段、命名参数、属性 | `5\n7\n0\n` |
| [struct](programs/struct.cj) | 不可变结构体 | `11\n5\n` |
| [enum](programs/enum.cj) | 枚举构造项与成员方法 | `2\n` |
| [interface](programs/interface.cj) | 接口及其类实现 | `接口\n` |
| [optional](programs/optional.cj) | 可选结果，明确处理除数为零 | `4\n-1\n` |
| [callback](programs/callback.cj) | 函数作为参数 | `7\n` |
| [snippet-wrapper](snippets/add.cj) | 片段通过[完整程序模板](wrappers/main.cj.txt)包装 | `42\n` |
| [compile-only](programs/compile-only.cj) | 只检查编译，未证明运行行为 | 无运行断言 |

## 公共接口清单

全部普通声明显式使用 `public`。枚举构造项按公共枚举的可见性列出；同名成员由所属类型区分。除枚举构造项外，每个公共声明都有紧邻中文文档注释。

| 组别 | 计数 | 符号 |
|---|---:|---|
| 顶层函数、常量、变量、别名 | 19 | `add`、`subtract`、`multiply`、`absValue`、`maxValue`、`minValue`、`isEven`、`isPositive`、`greet`、`repeatText`、`sumArray`、`factorial`、`clamp`、`divideSafe`、`identity<T>`、`applyTwice`、`defaultStep`、`globalGreeting`、`Count` |
| `Counter` 类型及成员 | 7 | `Counter`、`value`、`init`、`increment`、`reset`、`read`、`current` |
| `Pair` 类型及成员 | 6 | `Pair`、`first`、`second`、`init`、`sum`、`difference` |
| `Box<T>` 类型及成员 | 4 | `Box`、`value`、`init`、`get` |
| `Shade` 类型及构造项/方法 | 5 | `Shade`、`Red`、`Green`、`Blue`、`code` |
| `Named` 类型及成员 | 2 | `Named`、`name` |
| `Label` 类型及成员 | 4 | `Label`、`value`、`init`、`name` |
| 合计 | **47** | 原生 AST 提取状态为 `OK`，诊断为 0 |

样本只验证已登记输入。整数溢出、无效区间和阶乘上界仍受源码中的检查约束；没有宣称所有输入、所有平台或所有 SDK 版本均正确。实际复验结果见[审计记录](verification.md)。
