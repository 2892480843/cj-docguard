# CJ-DocGuard 决赛答辩 · 手写视频版

揉皱方格纸、手写字体、马克笔线条与重点圈注。主讲10页、技术备查4页，标准安排 **7分20秒**，其中第4页嵌入 **120秒真实系统操作视频**。另外提供6分钟和8分钟讲解安排，视频均完整保留。

- [答辩 PPTX，含内嵌视频](output/CJ-DocGuard-决赛答辩-手写视频版-20261029.pptx)
- [系统介绍 MP4，1080p / 60fps](output/CJ-DocGuard-系统介绍-2分钟-1080p60.mp4)
- [静态阅读 PDF](output/CJ-DocGuard-决赛答辩-手写视频版-静态阅读-20261029.pdf)
- [逐页讲稿](逐页讲稿.md) · [技术问答](技术问答.md) · [赛题内容对照](赛题内容对照.md)
- [原生工作台运行指南](../../../docs/native-workbench.md)

## 播放与使用

第4页点击视频封面，视频含中文配音与字幕，播放期间不重复讲解。MP4实际嵌入PPT文件内部，不依赖临时文件路径或网络播放链接。另带独立MP4，便于直接使用播放器。PDF显示固定的视频封面。

中文正文使用 Ma Shan Zheng，英文与数字使用 Chalkboard SE，代码使用 Source Han Sans SC。跨电脑编辑需要保留字体并检查换行；视频字幕已直接绘入画面，不依赖播放设备安装字体。

## 视频内容

| 时段 | 操作与说明 |
| --- | --- |
| 00:00—00:10 | 本地工作区、47个公共接口与14个登记示例 |
| 00:10—00:28 | 检索add、查看声明与参数、读取arithmetic源码 |
| 00:28—00:46 | 双SDK矩阵、退出码与stdout的预期/实际对照 |
| 00:46—01:10 | 选择SDK1.2.0、Darwin-arm64和arithmetic，查询1条有效记录 |
| 01:10—01:32 | 两处预置坏链的来源、行号和原因，区分未确认外链 |
| 01:32—01:52 | 同一环境下检查并导出代码包，显示成功与下载入口 |
| 01:52—02:00 | 仓颉核心与本地服务、维护目标 |

先用 macOS ScreenCaptureKit 录制真实系统窗口，再生成配音，最后剪辑和制作字幕。配音采用 `zh-CN-XiaoyiNeural` 活泼普通话女声，原始语速和音高，未克隆个人声音。字幕包含彩色章节条、手写提示、关键词着色和底部对白框，合计32条对白。

成片为1920×1080、H.264视频/AAC音频、恒定60fps、7200帧、120秒。四分钟原始录屏经正常剪辑选取，不加速操作。静态页面保留上一帧，不把静态内容重复编码称作每秒60个不同画面。技术记录见 [checks/video-checks.json](checks/video-checks.json)。

## 数据范围

采用功能源码 `068a22a8a4d1987ac0aac837da22b39c8224417f` 的本版记录：47个公共接口、14个登记示例，两版SDK分别13条运行通过与1条仅编译，合计26条运行通过、2条仅编译。健康工作区178条链接通过；专项链接样例另计23通过、2预置失败、1外链未确认。

录制时实际执行了SDK1.2.0 / Darwin-arm64 / arithmetic查询和导出，两项退出0；矩阵仍为同日17:22:24已记录结果。23项原生服务回归、20种页面场景及交互、30次布局检查与739条历史沿用同一功能提交的已记录检查，没有声称本次重新执行全量套件。出处见 [facts.json](facts.json) 和 [CHECKS.md](CHECKS.md)。

## 编辑与生成

文字、表格、统计图、架构图、圈注与箭头可编辑。使用11张实际产品截图与1张真实录屏封面，纸张底纹为生成素材。PPT正文和备注均使用面向技术介绍的措辞，未加入面向特定听众身份的称谓。图片来源见 [images.json](images.json)。

[source/build.mjs](source/build.mjs) 通过 Codex 内置 `@oai/artifact-tool` 编排页面，[source/embed_video.py](source/embed_video.py) 按 PresentationML 媒体关系把MP4附加到第4页，再执行结构和布局检查。该生成环境属于材料制作工具，不是工作台运行依赖。

在具备同版Codex材料运行时的环境，从仓库根目录配置 `RUNTIME_NODE_MODULES`、`PRESENTATIONS_SKILL_DIR` 与 `PRESENTATIONS_PYTHON`，运行 `DECK_REV=04 node submission/finals-2026-10-29/roadshow-v6-video/source/build.mjs` 可生成新的私有草稿及检查文件。最终文件需从检查目录复制到output。

[video/](video/) 保留配音片段、逐字时间、字幕文件、章节和采集时间；[source/](source/) 保留录制、配音、剪辑与检查脚本。原始窗口录屏保留在本机build目录，未放入公开材料。需要重新剪辑时，在独立工作目录放入 `system-raw.mp4`、`recording.json` 和video目录文件，然后执行 `source/edit_video.py <工作目录>`；需带libass的FFmpeg、相应字体，可通过 `FFMPEG`、`FFPROBE` 和 `DOCGUARD_VIDEO_FONTS` 指定路径。
