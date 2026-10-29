# R2 公开仓库克隆运行回执

**已通过：从 AtomGit 主仓库匿名克隆 `main`，按指南重新构建和实际运行，没有复制作者的构建、报告、任务历史或第三方缓存。** 使用已有、通过环境变量登记的两版仓颉 SDK 与 macOS15.4系统SDK；不是全新操作系统安装测试。

| 身份/步骤 | 实际记录 |
|---|---|
| 克隆地址 | `https://atomgit.com/c2892480843s/cj-docguard.git` |
| 实际克隆的main提交 | `ed764fef55b370fa227722553dfaeac28da2293d` |
| 功能源码提交/标签 | `075aeb38fc32d46680f312e8ac3647a0977e1366` / `finals-source-20261029-r2` |
| 匿名条件 | 禁用Git全局/系统配置及凭据助手，`GIT_TERMINAL_PROMPT=0`；不是本地目录克隆 |
| 初始状态 | 无build、缓存、旧报告或既有项目ID；167项源码SHA-256与冻结清单逐项一致 |
| 构建/启动 | 新编译CLI、C监督器/信号桥与仓颉HTTP服务，临时端口真实启动；静态页面资源返回200 |
| 文档/验证/检查 | 47个接口；28 CURRENT＝26运行验证+2仅编译；178条链接PASS，严格检查0 |
| 精确SDK查询 | 1.1.3及1.2.0分别查询到13条当前有效运行示例 |
| 两SDK导出重建 | 分别下载真实原生ZIP，运行各自build.sh，均退出0并输出 `42\n` |
| 真实库原版 | 重新联网取得锁定提交、文件摘要核验；原生verify退出1，36/40当前有效，4断言失败 |
| 真实库显式修复副本 | 使用同一新缓存并显式应用受审补丁；原生verify退出0，40/40当前有效；所有示例字节与锁相同，source_modified=true |
| 完成状态 | 临时服务正常退出；克隆目录跟踪文件无修改，原生审计前后二进制摘要不变 |

原始命令如下，SDK绝对路径须替换为实际安装位置；没有复制或上传SDK：

```bash
GIT_TERMINAL_PROMPT=0 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -c credential.helper= -c http.version=HTTP/1.1 clone --branch main https://atomgit.com/c2892480843s/cj-docguard.git
cd cj-docguard
export CJ_DOCGUARD_SDK_1_1_3=/absolute/path/sdk-1.1.3/cangjie
export CJ_DOCGUARD_SDK_1_2_0=/absolute/path/sdk-1.2.0/cangjie
export CJ_DOCGUARD_SYSTEM_SDKROOT=/absolute/path/compatible/MacOSX15.4.sdk
python3 scripts/validate_checkout.py
python3 scripts/real_projects.py --project leven4cj --cache build/reviewed-upstream-cache --fetch --output build/judge-original
python3 scripts/real_projects.py --project leven4cj --cache build/reviewed-upstream-cache --output build/judge-fixed --apply-reviewed-fixes
```

本次GitHub上游传输指定HTTP/1.1，未关闭TLS验证。真实库编排退出0只表示审计完成，项目原生退出码和失败格如上保留。[机器可读回执](evidence/public-clone.json)、[公开克隆工作流](evidence/public-clone-workflow.txt)、[评委完整运行指南](../../docs/judge-quickstart.md)。

## 网页操作核验

- R2原生服务的十个网页入口逐一打开；接口搜索add显示声明、参数、返回值及两个关联示例，浏览器未记录error/warn。
- 网页实际点击“运行原生链接检查”，任务 `89b3d2ce882df93179edb79b5ecf0ac9` 完成并退出1；专用负向样本23 PASS /2 FAIL /1离线UNVERIFIED，筛选后显示两条坏链与来源、原因。
- 原版unicode-empty显示期望1/实际3/FAIL；修复版期望1/实际1/PASS，矩阵两SDK均CURRENT。
- 健康演示已恢复，当前报告26运行验证+2仅编译、178链接PASS；页面已保留在接口文档。

截图：[接口文档](evidence/web-api.png)、[坏链筛选](evidence/web-link-failures.png)、[修复库矩阵](evidence/web-fixed-matrix.png)、[原版断言失败](evidence/web-unicode-original.png)、[修复断言通过](evidence/web-unicode-fixed.png)。

回执后的提交只增加材料和验证证据，功能源码保持冻结标签的167项摘要。无需为了把回执提交包含自身再反复修改源码身份；可执行 `git diff finals-source-20261029-r2 -- src workbench_native web scripts tests examples integrations` 检查功能代码差异。
