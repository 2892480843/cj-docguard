# CJ-DocGuard 决赛答辩 · 手写笔记版

按指定的 Notebook / napkin math / brainstorming 风格重排：轻揉皱方格纸、粗马克笔边线、手绘箭头、圈注和荧光笔重点。主讲10页、备查4页，标准7分钟，含80秒网页现场操作。

- [可编辑 PPTX](output/CJ-DocGuard-决赛答辩-手写笔记版-20261029.pptx)
- [固定画面 PDF](output/CJ-DocGuard-决赛答辩-手写笔记版-20261029.pdf)
- [逐页讲稿及6分钟、8分钟安排](../roadshow-v3/逐页讲稿.md)
- [20题评委问答](../roadshow-v3/评委问答.md)
- [80秒现场操作卡](../roadshow-v3/现场操作卡.md)

## 内容和数据

只调整视觉风格与页面措辞，沿用[当前结果](../roadshow-v3/README.md)及功能源码 `068a22a8a4d1987ac0aac837da22b39c8224417f`：47个公共接口、14个登记示例；两版SDK共26条运行通过、2条仅编译。当前报告、专项链接结果及来源见 [facts.json](facts.json)，测试范围与原始记录见 [v3检查说明](../roadshow-v3/CHECKS.md)。本次为材料版式修改，没有重新声称执行功能套件。

标题、正文、圈注、箭头、表格和图表可编辑。产品画面沿用当前网页实际截图，未改写截图中的内容。纸张底纹为生成素材，用于视觉排版，不作为运行记录。

## 字体与投屏

中文手写字体为 **Ma Shan Zheng**，英文及数字手写字体为 **Chalkboard SE**，代码使用 **Source Han Sans SC**。这些字体已在当前macOS环境确认可用。跨电脑编辑PPT需检查字体可用性和换行；PDF把字体和布局固定在画面中，可直接投屏，PDF正文不是可编辑文字。

PPT仍为原生可编辑文件：5页原生表格，1页原生图表及嵌入数据工作簿；图表数值与v3相同。自由曲线箭头保留为可编辑形状。最终文件已逐页渲染检查，不声称通过Microsoft PowerPoint或Google Slides原生打开测试。

## 视觉素材与生成源

- 背景：[assets/graph-paper.png](assets/graph-paper.png)，使用内置图像生成工具制作；提示词见 [source/paper-prompt.txt](source/paper-prompt.txt)。
- 网页截图：本目录assets中的api、export、links图片，复用v3实际截图。
- PPT生成源：[source/build.mjs](source/build.mjs)，依赖Codex内置 `@oai/artifact-tool` 和PPT技能运行时；产品本身不需要它。
- 内容、时间与来源：[content.json](content.json)。页面标题已作手写版适配，讲述和时间安排继续沿用v3。

在具备相同运行时的环境中，从仓库根目录设置 `RUNTIME_NODE_MODULES`、`PRESENTATIONS_SKILL_DIR`、`PRESENTATIONS_PYTHON` 后，可用 `DECK_REV=06 node submission/finals-2026-10-29/roadshow-v4-notebook/source/build.mjs` 生成下一份私有草稿及检查文件。检查完成后再复制到本目录output中。目录文件摘要见 `FILES.json`。
