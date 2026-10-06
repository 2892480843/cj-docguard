# 工具链来源与复验

实测宿主：macOS，Darwin 25.6.0，arm64，zsh。工具链安装在本项目外工作区 `.toolchains`；用户已有 Downloads/cangjie 1.0.5 未被修改。

| SDK | 官方归档 | SHA256 |
|---|---|---|
| 1.1.3 | cangjie-sdk-mac-aarch64-1.1.3.tar.gz | `7eff8d3b9119535cf3d05cb81526c5df391137dce908d744449f4edb99da3199` |
| 1.2.0 | cangjie-sdk-mac-aarch64-1.2.0.tar.gz | `de88d6ba2185c94979e0ab2fe8ac1d81535dfdff3fcb51fbba71e4b99d851f97` |

归档校验值来自官网公开下载页数据；本机下载后独立计算一致，并实际运行 cjc/cjpm 版本探针以及两个版本的原生编译/运行测试。校验值不等同供应链签名认证。

官方来源：[1.1.3 下载](https://cangjie-lang.cn/download/1.1.3)、[1.2.0 下载](https://cangjie-lang.cn/download/1.2.0)。准确下载参数及预期值固定在 `scripts/install_sdk.py`，内容不符时拒绝安装。

SDK1.0.5 本机默认链接器不能处理当前系统 SDK 的 tbd 文件。探索期间验证了该局限，正式版本使用 1.1.3/1.2.0，不通过修改用户旧 SDK 掩盖问题。

```bash
python3 scripts/dev.py probe --sdk 1.1.3
python3 scripts/dev.py probe --sdk 1.2.0
python3 scripts/dev.py build
python3 scripts/test.py
```

脚本显式设置工具链 PATH、CANGJIE_HOME、运行库路径及 macOS SDKROOT；没有执行会修改 SDK 签名/扩展属性的 envsetup.sh。正式验证为各版本重新编译独立程序。

`cjpm build` 也已实际通过；它构建仓颉程序。随附 C 监督器由 `scripts/dev.py build` 构建，运行原生程序时必须设置 `CJ_DOCGUARD_RUNNER`。直接执行 cjc/cjpm 产物还须配置相应仓颉运行库环境。

官方 API 依据：[release/1.1 AST 文档](https://github.com/cangjielanguage/cangjie_runtime/blob/release/1.1/stdlib/doc/libs/std/ast/ast_package_api/ast_package_funcs.md)、[进程 API](https://github.com/cangjielanguage/cangjie_runtime/blob/release/1.1/stdlib/doc/libs/std/process/process_package_api/process_package_funcs.md)、[环境 API](https://github.com/cangjielanguage/cangjie_runtime/blob/release/1.1/stdlib/doc/libs/std/env/env_package_api/env_package_funcs.md)。关键使用方式另由本机两个真实 SDK 编译/运行交叉验证，不以文档可用代替工程验收。

自动安装器使用 `tarfile` 的安全解包过滤，最低 Python 3.11.4；该版本条件依据 [Python 官方文档](https://docs.python.org/3.11/library/tarfile.html#extraction-filters)，本机安装检查实测 Python 3.14.6。其他 Python 版本没有逐一运行本套检查。
