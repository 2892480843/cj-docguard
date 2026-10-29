# leven4cj Unicode 空字符串修复记录（2026-10-29）

## 结论与范围

本地平台实测为 Darwin arm64（macOS），使用仓颉 SDK（软件开发工具包）1.1.3、1.2.0；系统链接库使用 `/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk`。修复仅改变两个空字符串分支，保留锁定提交、原始源码副本、所有既有样例及断言。这里记录独立复验和本地修复，不代表上游接受补丁或采用本工具。

来源锁定：`integrations/upstream-lock.json` 中 leven4cj，提交 `da69d981027b9fcbe12d09cfbb275b4ce8acc91d`，Apache-2.0。未联网重新判定上游当前状态。

## 四个失败单元的根因

编辑距离是将一个字符串转换为另一个字符串所需的最少插入、删除和替换次数。库的非空分支先执行 `toRuneArray()`，按 Unicode 码点（字符的编码值，不等同于人眼看到的完整字形）计算；两个空字符串分支却直接返回 `String.size`。独立程序实测此处返回 UTF-8 字节数：`你` 为 3，`😀` 为 4，故与非空分支计数单位不一致。

| 原始样例 | SDK | 保持不变的期望 | 原始实际 | 修复实际 | 原因 |
|---|---|---:|---:|---:|---|
| `unicode-empty`: `leven("", "你")` | 1.1.3 | 1 | 3 | 1 | `firstString.isEmpty()` 返回第二参数字节数 |
| `unicode-empty`: `leven("", "你")` | 1.2.0 | 1 | 3 | 1 | 同上 |
| `emoji-empty`: `leven("😀", "")` | 1.1.3 | 1 | 4 | 1 | `secondString.isEmpty()` 返回第一参数字节数 |
| `emoji-empty`: `leven("😀", "")` | 1.2.0 | 1 | 4 | 1 | 同上 |

修复对应为 `return secondString.toRuneArray().size` 和 `return firstString.toRuneArray().size`。没有修改动态规划主体，也没有变更任何断言以迎合输出。

## 可追溯补丁

人工可审阅差异：`integrations/leven4cj/patches/unicode-empty.patch`；机器约束：同目录 `manifest.json`。

| 对象 | SHA-256（内容摘要，用于检测字节变化） |
|---|---|
| 原始 `src/leven.cj` | `8481682b4bc61c821a817aaa8b998542b179c41a5ddb8ddde11eef81b6cd12de` |
| 修复后 `src/leven.cj` | `f428ecb81b588fb37d91c4cf06c2eb39779e0d11a66f836c82bdce6a4bd362fa` |
| 补丁文件 | `999ac6e4ab93d7113e6c1aa6949c141f20667615e692cfc2efa390018db27bf4` |

`harness(..., apply_reviewed_fixes=False)` 保持原默认行为。仅显式传入 `True` 或 CLI 参数 `--apply-reviewed-fixes` 才在复制后的目标应用补丁；先验证锁内原始摘要、目标原始摘要、补丁摘要，再验证转换后的摘要和补丁文本与实际转换一致。任何漂移拒绝继续。原始缓存与锁文件不改写。

修复项目 `provenance.json` 明确记录 `source_modified: true`、`reviewed_fixes`、`modified_files_sha256`；原始 `files_sha256` 仍表示锁定的上游输入，实际改动摘要另列。配置项目名称标记 `local fixed integration: leven4cj`，README 同步说明本地修复。

## 验证

先新增显式修复选项回归测试，旧实现触发 `TypeError: harness() got an unexpected keyword argument 'apply_reviewed_fixes'`，随后实现并通过。

```bash
CJ_DOCGUARD_SYSTEM_SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
CJ_DOCGUARD_TEST_REAL_UNICODE=1 \
python3 -m unittest discover -s tests -p test_real_projects.py
```

结果：6 项测试通过。原始和修复后源码分别用两个 SDK 的实际 `cjc` 编译、执行；48 次算法调用（12 组参数 × 2 源码版本 × 2 SDK），与独立 Python 码点编辑距离参考实现比较。测试使用临时程序，不覆盖共享的 `build/cj-docguard`。

| 参数（按顺序） | 原始输出（两个 SDK 相同） | 修复输出（两个 SDK 相同） |
|---|---|---|
| `("", "")` | 0 | 0 |
| `("", "你")`, `("你", "")` | 3, 3 | 1, 1 |
| `("", "😀")`, `("😀", "")` | 4, 4 | 1, 1 |
| `("", "你😀a")`, `("你😀a", "")` | 8, 8 | 3, 3 |
| `("你好", "你们")` | 1 | 1 |
| `("😀a", "😀b")` | 1 | 1 |
| `("你😀", "😀你")` | 2 | 2 |
| `("kitten", "sitting")` | 3 | 3 |
| `("e\u0301", "é")`（组合字符与预组合字符） | 2 | 2 |

此外，直接编译未改动的 `integrations/leven4cj/cases/unicode-empty.cj` 与 `emoji-empty.cj`，在两个 SDK 上分别链接原始/修复源码，观察 3/4 → 1/1，退出码均为 0。断言失败来自标准输出不匹配，不是程序崩溃。

## 工作台交付与边界

原始工作台项目保持在 `build/workbench/projects/leven4cj`；从其已逐文件校验的原始副本创建 `build/workbench/projects/leven4cj-fixed`，保留许可证与测试排除配置，20 个既有样例、两个 SDK 不变。准备阶段未运行完整 40 单元工作流；原生引擎重建后的注册、完整工作流及浏览器展示由集成步骤执行。

本修复保持码点语义，不引入 Unicode 规范化或按字形簇（多个码点可能组成的一个可见字符）计算的语义变化。已验证的是上述平台与 SDK，未声称覆盖其他平台或上游全部测试。

## 最终完整集成补充

最终工具在完整回归结束后，通过真实仓颉 HTTP 服务重新执行：原始版 verify/check 为 1，保留 36 当前有效与 4 断言失败；本地修复版 verify/check 均为 0，40/40 当前有效。原先四个失败单元在精确 SDK 下查询均返回 stdout `1\n`；两个 SDK 的独立导出包真实重建也均输出 `1\n`。网页已实际查看矩阵与断言详情，既有断言和缓存保持原字节。

最终证据目录 `build/link-repair-validation/20261029-124027/`；整个功能与网页验收见[链接与 Unicode 验收记录](links-unicode-verification-2026-10-29.md)。

## 从公开源码直接复现两份项目

先按[评委复现指南](judge-quickstart.md)准备两个 SDK、系统 SDK 并构建原生程序。新克隆不含第三方缓存或作者的项目 ID；以下两条命令分别生成原版与修复版，保留各自证据：

```bash
python3 scripts/real_projects.py --project leven4cj --cache build/reviewed-upstream-cache --fetch --output build/judge-original
python3 scripts/real_projects.py --project leven4cj --cache build/reviewed-upstream-cache --output build/judge-fixed --apply-reviewed-fixes
```

`--fetch` 仅获取锁内已审阅的公开固定提交；已有审阅缓存可省略它并替换 `--cache` 路径。第二条显式选择本地补丁，不改变缓存或锁。两份输出都保留上游许可证；可核对生成的 `provenance.json` 与补丁摘要。

命令打印 `Audit record: .../audit.json`。从记录的 `projects[].command` 读取本次 `docguard.toml` 绝对路径，在工作台“项目与配置 → 登记已有配置”分别登记。使用新返回的项目 ID，再运行诊断、构建索引、验证和检查；不要沿用旧本机 ID。

编排脚本正常结束均可退出 0；应查看记录中的原生 `exit_code`：原版 verify 预期 1（36 当前有效、4 断言失败），修复版预期 0（40 当前有效）。将各自实际配置路径代入以下命令，原版严格检查预期 1、修复版预期 0：

```bash
python3 scripts/dev.py run -- check --strict --config /absolute/path/from-audit/docguard.toml
```

以上是可执行复现路径与预期，最终结果以本次生成的日志和报告为准。
