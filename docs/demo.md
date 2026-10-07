# 实际命令演示与复现

本地视频为 [CJ-DocGuard 三分半演示](../build/release/cj-docguard-gap-demo-0d08f76.mp4)。已核对 SHA-256 `14a33b4cc809d07776b5ffcd482cec5d13ab78ddccb8c92f76605e7b27d7adff`；时长 210.021333 秒，1920×1080，H.264 视频和 AAC 音频。8 幅画面已逐幅检查，FFmpeg 完整解码退出 0；未进行人工听音检查。**视频是实际命令日志的静态重绘，配 macOS「婷婷」合成语音，不是浏览器录屏或直播操作。**

## 画面与原始证据

| 时段 | 画面 | 可追溯的实际结果 |
|---|---|---|
| 0:00–0:26 | 健康矩阵 | 14 例 × 两个 SDK 共 28 格，其中 26 格实际运行验证、2 格仅编译；`02-matrix` 退出 0 |
| 0:26–0:52 | 当前查询 | `04-current` 返回 `arithmetic` 当前且可用的结果 |
| 0:52–1:19 | 只改演示副本 | 加法改减法后，`05-stale-query` 拒绝旧记录，`06-stale-strict` 退出 1 |
| 1:19–1:45 | 真正重新运行 | `07-broken-verify` 退出 1；断言实际标准输出 `-2\n`，预期 `42\n`；`08-failed-query` 不回退到旧成功 |
| 1:45–2:11 | 恢复与历史 | `09-restored-matrix` 退出 0；最终历史 70 条，包含刚才的失败；两个 SDK 查询恢复可用 |
| 2:11–2:38 | MCP 查询 | 实际标准输入/输出握手、工具列表和只读查询，保留请求与响应 |
| 2:38–3:04 | 导出与复现 | 两个 SDK 的 `build.sh` 均退出 0、输出 `42\n`；仅编译例导出退出 1，未创建目标 |
| 3:04–3:30 | 适用边界 | 展示引擎摘要、日志路径和待本人提交事项 |

上述时间为每幅 26.25 秒的分镜范围，视频文件包含尾帧。原始命令清单与退出码在 `build/gap-closure/demo-final/commands.json`，每条命令对应同名 `*.stdout`、`*.stderr`；`facts.json` 保留画面取值，`frozen-report.json` 是恢复后的最终报告。`facts.json` 的 `actual_failure` 记录中间失败时点；最终报告里的最新结果已经恢复为成功，历史仍保留失败。20 条命令均按各自预期退出码完成，包括预期的拒绝退出 1。原始采集脚本为 `build/gap-closure/demo-final/capture.py`，画面来源脚本为 `build/gap-closure/demo-final/render-layout-v2.py`；这些一次性脚本与原始日志保存在本地证据目录。

## 重新采集

当前实测环境是 macOS arm64、仓颉 SDK 1.1.3 和 1.2.0。先按 [README](../README.md) 的构建步骤准备原生 CLI、C 监督器和两个 SDK，再执行：

```bash
python3 scripts/record_demo.py --out build/gap-closure/demo-rerun-001 \
  --binary build/cj-docguard
```

`--out` 必须是 `build/gap-closure/` 下**尚不存在**的目录；工具拒绝覆盖，复制 `examples/healthy` 作为故障注入副本，并冻结所指定 CLI 到输出目录。它运行真实编译器和程序，不把受控替身当成编译结果。每步原始输出、错误输出、命令、退出码即时写盘；任何非预期退出都会停止并留下已采集证据。MCP 子进程（模型上下文协议的标准输入/输出适配程序）使用当前 `sys.executable`，避免 SDK 缩短的 `PATH` 选错 Python。仅复现演示中的登记断言；导出的单例程序不保证所有接口及输入正确。Linux 证据另见 [独立记录](linux-verification.md)，本视频只展示上述 macOS 捕获。

复现渲染需 FFmpeg、Pillow、能显示中文的字体以及 macOS「婷婷」语音；现有一次性渲染脚本依赖 `build/gap-closure/demo/narration.json` 和语音文件。永久工具仅负责可复用的实际命令采集，既有成片已存于 `build/release/`。如果修改画面或配音，应在**新目录**渲染、核对全部画面、音轨、时长和完整解码，并给新视频独立摘要；不能把新采集直接说成现有视频的来源。
