# Linux aarch64 双 SDK 实测

本页只描述 `cjdg-gap-linux-20261007` 容器中的 Ubuntu 22.04 aarch64 实测。宿主为 macOS arm64；本次修复后的完整链保存在 `build/gap-closure/linux-final/verification-20261007-v3/summary.json` 和相邻的 `commands/`。它记录真实 `uname`、镜像身份、完整选定输入清单、验证器和解压 SDK 摘要，以及每条命令的参数、环境摘要、原始 stdout/stderr 的摘要、退出码和最终状态。旧版 `verification-20261007/` 与 `verification-20261007-v2/` 保留原样，不能作为新版恢复清单使用。

## 来源与范围

| 项目 | 固定来源与实测边界 |
|---|---|
| SDK 1.1.3 | [官网下载页](https://cangjie-lang.cn/download/1.1.3)列出 `cangjie-sdk-linux-aarch64-1.1.3.tar.gz`；官网页面脚本中的 SHA-256 为 `0b0ce42ce2492f654b00029687229188c82751418cb34df7990efd43eaf9c41f`。归档及来源参数记录于 `build/gap-closure/official/linux-1.1.3.json`。 |
| SDK 1.2.0 | [官网下载页](https://cangjie-lang.cn/download/1.2.0)列出 `cangjie-sdk-linux-aarch64-1.2.0.tar.gz`；官网页面脚本中的 SHA-256 为 `40e3962472d6d1b181e685198b193b904a385ac8dbbdff8aa9c52c4bb6f6e0f1`。归档及来源参数记录于 `build/gap-closure/official/linux-1.2.0.json`。 |
| 镜像 | `arm64v8/ubuntu:22.04`，Docker 镜像摘要 `sha256:050dd71fd48cf03db1924609facd0f51dc148e9055276e45aade78f2abafdc10`。仅操作上述专用容器。 |
| 适用范围 | 只验证此次真实 `Linux-aarch64` 容器。Linux x86_64、Windows 与其他 Linux 发行版未在本任务验证。 |

SDK 摘要来自同一官方发布方的下载页面与页面脚本，属于单一发布方证据；归档字节经独立 SHA-256 计算复核。摘要能检查下载一致性，不等同供应链签名证明。

## 复现

容器既有挂载：`/input` 是仓库只读副本，`/sdks` 是已下载并解压的双 SDK 只读目录，`/out` 映射到 `build/gap-closure/linux-final`。验证器只用 Python 标准库，在 `/work` 新建源码副本，不覆盖健康样本的 macOS 历史，也不自动下载依赖。

```bash
docker exec cjdg-gap-linux-20261007 /usr/bin/python3 /input/scripts/linux_verify.py \
  --output /out/verification-NEW-NAME
```

一次中断或验证器自身故障后，核对既有 `summary.json` 再继续，可复用已保存的成功命令与同一 `/work` 副本：

```bash
docker exec cjdg-gap-linux-20261007 /usr/bin/python3 /input/scripts/linux_verify.py \
  --output /out/verification-NEW-NAME --resume
```

`--resume` 只接受新版完整清单：逐一比较当前 `/input` 与冻结 `/work` 的 `src/`、`scripts/`、`tests/`、`examples/healthy/` 文件摘要（排除生成的 `build/`、`.docguard/`、`__pycache__/`），还比较验证器字节、两版 SDK 解压树、归档、每条命令的参数、工作目录、环境摘要、预期与实际退出码，以及原始日志字节摘要。旧版缺少这些身份字段，必须在新目录重跑；摘要采用临时文件加原子替换，避免中断时截断可恢复状态。最终 `summary.json` 的 `complete` 字段表示整条验证链是否完成。脚本逐步执行两版 `cjc`/`cjpm` 探针、真实 C 监督器构建、双版原生测试编译与运行、两版 CLI 构建、健康样本 `doctor`、28 格 `verify --matrix`、`check --strict`、双版 `query`、各一格 `export` 与 `build.sh` 重建运行，以及双版仅编译案例的导出拒绝。

## 先前失败与修复

修复前，在真实 Linux aarch64 容器执行 `python3 scripts/dev.py probe --sdk 1.1.3`，`cjc` 返回 0；`cjpm` 返回 127，缺少 `libcangjie-runtime.so`。原始输出在 `build/gap-closure/linux-baseline/probe-1.1.3.stdout`。根因是 `scripts/dev.py` 对所有非 Darwin 主机固定选择 `linux_x86_64_cjnative` 运行库目录；实际 SDK 包含 `linux_aarch64_cjnative`。回归测试先失败，再按真实系统与架构选择运行库，未知组合与 SDK 中缺失的目录显式报错。macOS arm64 的 SDK 探针和构建已回归。

## 验收口径

`RUN_VERIFIED` 指登记的运行断言在该 SDK 与平台下通过；`COMPILE_ONLY` 只证明编译通过。严格检查允许当前有效的仅编译格，但 `get_verified_examples` 查询与导出只接受运行验证格。

| 实测项 | 结果 |
|---|---|
| 1.1.3 与 1.2.0 SDK 探针 | 两版 `cjc`、`cjpm` 均退出 0，目标 `aarch64-unknown-linux-gnu` |
| 原生测试 | 每版 7 个测试程序，编译与运行各 7 次，均退出 0 |
| 健康矩阵 | `verify --matrix` 退出 0；28 格均为 `CURRENT`，其中 26 格 `RUN_VERIFIED`、2 格 `COMPILE_ONLY` |
| 严格检查 | `check --strict` 退出 0 |
| 查询 | 每版各有 13 条运行验证结果；仅编译项在 `rejected` 中 |
| 导出与重放 | 每版导出 `arithmetic` 一格，执行真实 `build.sh` 均退出 0；验证器逐字节断言 stdout 为 `42\n`。两版 stderr 各有 21 条编译警告，均保留原始字节及摘要，并归类为编译诊断。 |
| 拒绝边界 | 每版导出 `compile-only` 均返回预期退出码 1，且目标目录不存在 |

v3 完整链包含 49 条逐命令记录，最终 `summary.json` 为 `complete: true`。首次调用执行到第 36 条后 Docker 服务连接消失，宿主 `docker exec` 返回 255；专用容器当时显示退出码 137、`OOMKilled=false`，原因未证实。Docker 恢复后，仅重启该专用容器；第二次调用通过严格身份与日志检查，从第 37 条继续并退出 0。两次调用的原始 stdout、stderr 和退出码单独保存在 `build/gap-closure/linux-fix/`。日志不可用时不能将脚本或文档当作实测通过证明。

警告来源有明确边界：两版 `native-platform` 编译的 stderr 各有 2 条 `CurrentProcess.current` 弃用警告，位置为 `tests/native_platform.cj:57` 与 `:59`；两版重放的 stderr 各有 21 条警告，其中 1 条是导出样本 `src/src/demo.cj:118` 的冗余 `public` 修饰符，另 20 条是同一示例文件中的未使用函数。它们不是程序 stdout，也没有从原始日志中删除；本任务不修改这些原生测试和样本源码。
