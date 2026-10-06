# 原生基础模块实施报告

日期：2026-10-06。范围：`src/primitives.cj`、`tests/native_primitives.cj`、本报告。平台由 `uname -s`、`uname -m` 和编译器输出确认：Darwin / arm64，目标 `aarch64-apple-darwin`。

## 结果

已完成工程契约要求的原生 `J`、`parseJson`、`parseToml`、`sha256(Array<Byte>)`。两套正式 SDK 均真实编译并运行 **86 个断言，全数通过**；未调用 Python 或外部程序实现生产解析或哈希。

| 文件 | 实现 |
|---|---|
| `src/primitives.cj` | JSON（结构化数据格式）树、严格 JSON 读写、受限 TOML（配置文件格式）读入、SHA-256（生成256位输入指纹的摘要算法） |
| `tests/native_primitives.cj` | 标准摘要向量、独立二进制参考向量、类型严格读取、Unicode、错误解析、配置冲突与资源边界 |

### J 接口

- `kind` 固定使用 `string`、`number`、`boolean`、`array`、`object`、`null`；`text` 保存标量，`items`、`fields` 分别保存数组和对象。
- 工厂：`str`、`num`、`boolean`、`arr`、`obj`、`nil`。
- `get` 要求接收者为对象；缺字段返回 `J.nil()`。`s/i/b` 不做跨类型转换。
- `i()` 只接受严格十进制整数词法，拒绝小数、指数形式和 Int64 越界；正确覆盖 `-9223372036854775808` 和 `9223372036854775807`。
- `add/put` 校验容器类型，返回接收者，支持链式调用。
- `dump` 对对象键排序，保持确定性；字符串控制字符按 JSON 转义。数字保留读入词法，因此 `1e-9999` 可准确往返，而不会被浮点舍入。

### JSON 边界

支持所有 JSON 值类型；字符串支持原生 Unicode、全部标准转义和 UTF-16 代理对（以两个 Unicode 转义表示辅助平面字符）。拒绝单独代理项、非法/未闭合转义、原始控制字符、重复对象键、尾逗号、非法数字和多余内容。解析/序列化深度上限为256；循环构造的 `J` 树会因深度保护报错，不会无限递归。

### TOML 子集（主动拒绝范围外语法）

支持：

- 顶层 bare key（ASCII 字母、数字、`_`、`-`）。
- 单层 `[table]` 与 `[[array_of_tables]]`。
- 单行 basic/literal 字符串；basic 字符串支持 `\b`、`\t`、`\n`、`\f`、`\r`、`\"`、`\\`、`\uNNNN`、`\UNNNNNNNN`。
- 布尔值、Int64 范围内十进制整数、同一行字符串数组（可为空）。
- 注释、空白、LF 与 CRLF 换行；字符串中的 `#` 不会被误判成注释。
- 重复键、重复普通表、键与表类型冲突会报错；重复数组表头正常追加对象，但普通字符串数组不能再变成数组表。

**不支持且拒绝**：多层/dotted key 或表、quoted key、行内对象、多行字符串/数组、数字数组、浮点数、日期时间、正号整数、整数下划线分隔、非十进制整数、数组尾逗号、代理项 Unicode 转义。该实现是项目配置子集解析器，不声明完整 TOML 规范兼容。

### SHA-256

原生实现消息填充、64轮压缩与64位长度编码。使用 UInt64 加法再截取低32位，避免依赖整数溢出行为。输出64字符小写十六进制摘要。

测试含11个摘要输入：空输入、`abc`、标准多块向量、百万个 `a`、55/56字节填充边界，以及包含零字节/高位字节的63、64、65、256、1024字节输入。后5项预期值由本机 Python `hashlib.sha256` 独立生成并固定到原生测试，生产实现不依赖 Python。

## 测试先行证据

按 test-driven-development 和 verification-before-completion 技能执行。

1. 首先写入完整原生测试和占位 API；SDK1.0.5 语法编译通过，但默认链接器无法处理本机 macOS26.5 开发包的 libSystem.tbd。
2. 对该探索性测试显式使用已安装的 macOS15.4 开发包后成功链接，运行返回1，原始错误为：`Exception: FAIL: SHA256 empty`。这证明断言在实现前实际失败。
3. 完成原生实现后，正式 SDK1.1.3 默认链接器成功运行测试。
4. 追加“普通数组重声明成数组表”的回归测试，先观察运行失败：`Exception: FAIL: reject TOML p=[]`；再增加数组表声明集合修复根因。
5. 扩充 Unicode、严格类型、配置冲突、深度保护和独立摘要输入；SDK1.1.3、1.2.0 均重新编译运行最终测试。

## 可复验命令

在项目目录运行，切换 `1.1.3` 为 `1.2.0` 即可验证另一套 SDK。没有 source 既有 SDK 的 envsetup，也没有修改既有 SDK。

```sh
export CANGJIE_HOME="$(cd .. && pwd)/.toolchains/1.1.3/cangjie"
export PATH="$CANGJIE_HOME/bin:$CANGJIE_HOME/tools/bin:$PATH"
export DYLD_LIBRARY_PATH="$CANGJIE_HOME/runtime/lib/darwin_aarch64_cjnative"
export SDKROOT="$(xcrun --show-sdk-path)"
cjc --version
cjc src/primitives.cj tests/native_primitives.cj -o /tmp/docguard-native-primitives
/tmp/docguard-native-primitives
```

实际最终输出：

```text
Cangjie Compiler: 1.1.3 (cjnative)
Target: aarch64-apple-darwin
PASS native primitives: 86 assertions; SHA256 vectors, JSON strict parsing/Unicode/types, TOML subset/errors
Cangjie Compiler: 1.2.0 (cjnative)
Target: aarch64-apple-darwin
PASS native primitives: 86 assertions; SHA256 vectors, JSON strict parsing/Unicode/types, TOML subset/errors
```

两个编译/运行步骤退出码均为0，没有跳过项目。

## 适用边界

- 本报告证明本机 macOS arm64 上的原生模块行为，未验证其他操作系统/CPU或项目整体集成。
- `sha256` 当前复制并填充完整输入，内存使用随输入线性增加；适用于项目文档、代码和快照，未提供流式摘要接口。
- JSON 树公开容器可被调用者修改；序列化再次检查类型/数字及递归上限，调用者仍应按工厂契约构造数据。
- 三个文件以 UTF-8 无 BOM 保存；未修改其他模块或提交 Git。
