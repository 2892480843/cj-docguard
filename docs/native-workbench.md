# 仓颉原生网页工作台

本地 HTTP 服务、项目状态、配置与源码读写、任务编排、查询和导出适配现由仓颉可执行程序 `build/cj-docguard-workbench` 提供。浏览器仍使用 HTML/CSS/JavaScript；C 监督器负责进程资源控制，小型 POSIX 信号桥只传递退出信号及查询进程存活。ZIP 打包调用系统 `/usr/bin/zip`。Python 用于测试和辅助工具，不是正式 HTTP 服务进程。

## 构建与运行

需要已安装的仓颉 SDK、C 编译器、ar、Bash 和 zip。默认以 1.1.3 构建，SDK 位置支持已有环境变量、上级 `.toolchains` 和本地 `.local/sdks`。无需 pip/npm 或网络下载。

```bash
bash scripts/build_workbench.sh
bash scripts/workbench.sh --port 8765
```

本机 Xcode 27 与旧仓颉链接器存在已复现的系统 SDK 格式兼容问题，因此本机实际命令是：

```bash
export CJ_DOCGUARD_SYSTEM_SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
bash scripts/build_workbench.sh
bash scripts/workbench.sh --port 8765
```

只为启动时选择系统 SDK，也可向仓颉程序传 `--system-sdk /absolute/system-sdk`。这不改变系统 Xcode 配置。路径须按实际安装调整，不自动选择或安装其他 SDK。

打开 `http://127.0.0.1:8765`。默认状态目录为 `build/workbench`，保留此前已登记的项目和 ID；也可用 `--state-dir /absolute/state` 指定独立目录。服务只绑定本机 IPv4。SIGINT/SIGTERM 会停止接收请求、中断并等待已登记的原生任务。

旧入口 `python3 scripts/workbench.py` 仅通过 exec 转入 Bash 和仓颉程序，便于旧命令继续使用；推荐直接使用上面的 Bash 入口。旧 Python 服务移入 `tests/reference_workbench.py`，只用于历史测试对照，不参与正式启动。

## 网页完整操作路径

1. 项目与配置：登记已有配置或初始化新项目；检查配置、源码范围、断言及信任字段。新项目不会自动授权执行。
2. 诊断环境、构建索引：实际读取 SDK 身份，生成公开声明、参数、返回类型和关联示例。
3. 接口/示例/矩阵：检索声明与注释，查看登记代码和精确 SDK/平台下的记录。
4. 源码工作区：从接口或输入清单打开 `.cj` 文件，编辑后确认保存。提交时携带读取版本的 SHA-256，文件已变化则返回冲突并保留草稿。保存不会自动验证。
5. 运行验证、检查证据：执行真实编译和断言，查看原始日志、错误、链接检查和版本关系。成功/失败/过期/仅编译分别显示。
6. AI 证据查询：三种只读原生工具；显示精确环境、可用项和拒绝原因，保留完整 JSON。
7. 历史与对比：查看冻结证据、下载报告、比较两份报告的输入、接口和状态变化。
8. 导出：选择示例、SDK 和平台；原生重新核验后下载 ZIP，按包内脚本真实重建。
9. 中断恢复：取消任务后如留有写锁，在设置页检查归属。只有元数据匹配、进程确定不存在、锁内没有额外文件，才允许勾选确认后恢复。旧锁、活进程、未知状态、符号链接和额外文件一律拒绝；不自动删锁。

源码接口只开放登记范围。配置输出目录、`.git`、`.docguard`、`target`、`.env*` 和排除路径不会暴露；源码目录仅开放 `.cj`，其他文件须明确登记。既有文件最大 512 KiB，不提供任意路径或任意 shell 命令接口。

## 实现与边界

| 文件 | 职责 |
|---|---|
| `workbench_native/http.cj` | 标准库 TCP、本机 HTTP 解析、请求边界、响应及连接清理 |
| `workbench_native/main.cj` | 参数、服务初始化、信号退出 |
| `workbench_native/service.cj` | API 路由、项目、配置、报告、源码与制品 |
| `workbench_native/storage.cj` | 随机令牌、原子写入、路径、对比和锁恢复判断 |
| `workbench_native/jobs.cj` | 固定命令、原生任务、日志、取消、导出打包和初始化 |
| `src/*.cj` | 原有仓颉验证和证据核心 |

HTTP 实现面向本地浏览器工作台，支持每连接单个 HTTP/1.1 请求并关闭连接。16 个并发客户端、16 KiB 请求头、2 MiB 请求体，拒绝重复头和 Transfer-Encoding，读写及请求阶段有超时。写请求校验本机 Host、同源 Origin 和会话令牌。它不是公网 Web 服务器或任意代码安全沙箱。

原生任务全局串行，UI 每流日志保留末尾 256 KiB，结构化结果上限 16 MiB，超限明确失败。任务列表只属于当前服务会话；项目登记和原生证据历史持久化。报告仍是快照，不把静态 CURRENT 直接视为最新资格。

## 测试与要求核验

```bash
node tests/test_workbench_ui.mjs
python3 -m unittest discover -s tests -p 'test_native_workbench.py' -v
python3 scripts/validate_workbench.py --url http://127.0.0.1:8765
python3 scripts/test.py
```

Python 在这些命令中是测试客户端，不提供被测 HTTP 服务。测试启动、连接并终止真实仓颉二进制；实际编译器与模拟进程结果不混作同类证据。

[决赛要求证据核验](finals-requirement-evidence-2026-10-29.md)区分公开课题摘要、通用决赛规则及尚缺的完整任务书/最终通知。不能将网页显示 Cangjie 或本地测试通过解释为组委会最终认定。

本轮具体结果、失败记录修复说明、浏览器操作和三项交付对应证据见[迁移验收记录](native-workbench-verification-2026-10-29.md)。
