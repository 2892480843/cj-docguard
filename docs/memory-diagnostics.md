# 历史记录内存诊断（macOS arm64，2026-10-07）

## 结论与边界

R02 原始事件是在默认运行条件下，`verify --matrix` 已保存 28 条完整尝试记录（序号 225–252）后报 `Out of memory`，退出 1；随后独立 `check --strict` 退出 0。后续含 280、308 条历史的默认条件验收也成功。因此**原始间歇性异常的唯一根因仍未确认**，不能将本页受限堆实验等同于当时的默认条件。

隔离的 308 条完整历史使内存压力可重复：旧二进制在 `cjHeapSize=128MB` 下 `check` 和 `verify` 都在报告阶段报内存不足；`verify` 的 28 条新记录已完整落盘。临时编译副本的阶段标记显示旧代码最先在 `report.dump()` 失败，跳过该分配后还会在后续报告写入阶段失败。这说明**多个同时驻留的大型报告对象和字符串共同造成受限堆失败**，单改一处字符串拼接不够。

修复保留所有历史与报告字段：JSON 序列化改为线性追加，报告 JSON 分块写入临时目录，其他报告文件逐个生成后再发布；只读脱敏过程共享未改变的子树。这里的共享仅适用于 `reportFor` 及后续只读报告路径，`J` 本身并未变成不可变类型。最终新二进制在 `128MB` 下完整执行 `verify`，生成 336 条历史与 28 格报告，随后 `check --strict` 退出 0。对旧二进制留下的 308 条过期证据直接执行新 `check` 时，也完整生成报告，但因 `STALE`（证据对应旧二进制）而按严格检查规则退出 1；**这不是内存不足**。

## 可复现命令

使用真实 SDK 1.1.3 和本机 Darwin arm64。脚本拒绝超过 400 条历史的源样本，先复制完整工程（macOS 使用 APFS 写时复制），所有产品命令只运行在新目录。`--commands` 可选 `check query verify`，`verify` 会追加新记录，应放最后。

```bash
python3 scripts/diagnose_memory.py \
  --source build/gap-closure/memory/history-308 \
  --binary build/cj-docguard \
  --output build/gap-closure/memory/diagnostic-128mb \
  --heap 128MB
```

输出目录包含 `summary.json`、各命令完整的 `.stdout`/`.stderr`、完整工程副本和尝试记录摘要。`maximum_observed_rss_kib` 是每 0.1 秒采样到的最大常驻内存，**只是实际峰值的下界，不能当作真实峰值**；退出码、运行时错误和文件更新事件分别记录。超时会杀死诊断子进程并明确标记，不能计为通过。再次运行请选新输出目录，不会覆盖证据。

| 输入/二进制/堆 | `check` | `query` | `verify` | 观察到的最大 RSS |
|---|---:|---:|---:|---:|
| 308 条；旧 `e67f62ac…`；默认堆 | 0 | 未测 | 未测 | `check` 235840 KiB |
| 308 条；旧 `e67f62ac…`；128MB | 1，OOM | 0 | 1，28 条写完后 OOM | `check` 154304 KiB；`verify` 152224 KiB |
| 308 条；最终新 `98ab81a8…`；128MB | 1，完整报告、证据 `STALE` | 未测 | **0，历史增至 336 条** | `check` 140736 KiB；`verify` 131008 KiB |
| 最终新二进制验证后的 336 条；128MB | **0，严格检查通过** | 未测 | 未重复 | `check` 135328 KiB |
| 308 条；旧/新；192MB | 旧 1，OOM；新 1，过期证据 | 未测 | 未测 | 旧 184688 KiB；新 183456 KiB |

OOM 为运行时 `Out of memory`，与新二进制完整写出报告、随后因证据 `STALE` 返回的业务退出码 1 不同。旧、新二进制在 `128MB` 下的 `query` 均退出 0；旧证据在新二进制中返回空的当前有效结果，符合证据准入规则。原始日志在 `build/optimization-r02/verify.stderr` 和 `refresh-commands.json`；上述受控原始输出在 `build/gap-closure/memory/`。旧二进制 SHA-256 为 `e67f62ac9c4d0aefc474b9b56873d78f41c8f65d747e12264fd12dad29058eed`，最终诊断新二进制 SHA-256 为 `98ab81a8bba1eb08b0377da44cb1cac2ea9606d5270948cfc36e070390159a37`。合并重建后哈希会改变，应以每次 `summary.json` 为准。

## 完整性与验证

- 336 条报告历史的前 308 条与隔离源报告按 JSON 值逐条相等；源目录中 308 个尝试文件与新副本对应文件逐字节相同。新历史仍保留序号、状态、编译/运行日志及断言。
- 原生报告测试比较 `writeReports` 写出的 `report.json`、`api.json`、`manifest.json` 与 `J.dump()` 的**精确字节**；测试还验证循环树拒绝后无正式报告与残留临时目录。
- 原生导出测试验证脱敏前源记录未改变、脱敏后的父对象独立，以及现有证据准入拒绝行为；没有修改 `eligible`、`freshness` 或证据 Schema。
- Python 诊断测试覆盖隔离复制、完整 stdout/stderr、退出码、采样、超时及快速报告更新。双 SDK 1.1.3/1.2.0 的 `memory`、`report`、`export` 原生测试均退出 0。

当前结论仅覆盖所测 macOS arm64、两版真实 SDK 的原生回归，以及 SDK 1.1.3 的受限堆 CLI 实验。历史默认堆异常是否与宿主内存压力、运行时回收或其他因素有关，仍需在再次出现时保留 `MRT_REPORT` 与完整阶段日志进一步核验。
