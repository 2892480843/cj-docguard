# CJ-DocGuard 参赛材料

作品：CJ-DocGuard 项目级 API 文档生成及示例证据验证。负责人：陈帅；成员：沈均皓、袁雨芳。

| 必交材料 | 仓库入口 |
|---|---|
| 完整源码、许可、说明、开源来源、变更记录、测试 | [源码首页](../README.md)、[LICENSE](../LICENSE)、[README.OpenSource](../README.OpenSource)、[CHANGELOG](../CHANGELOG.md)、[tests](../tests) |
| 实验过程、验证方法、数据和复现 | [整体评测](../docs/project-evaluation-2026-10-07.md)、[验收](../docs/acceptance.md)、[复现](../docs/demo.md)、[验证附件](CJ-DocGuard-验证材料-20261007.zip) |
| 演示视频链接 | [B站演示视频](https://www.bilibili.com/video/BV1R5HC6MEDo/)、[字幕](CJ-DocGuard-演示字幕.srt) |
| 填写后的统一作品提交模板 | [Word最新AI贡献公开未签字版](CJ-DocGuard-作品提交书-AI贡献公开未签字版.docx)、[PDF最新未签字预览](CJ-DocGuard-作品提交书-AI贡献公开未签字版.pdf) |

公开模板保持原模板字体字号，隐藏电话、邮箱并清理作者元数据。包含真实联系方式的完整填写版及旧材料保留在负责人本地，不属于公开仓库。签字需本人完成，未签字预览不能当作已签署申报书。PDF渲染使用本机中文替代字体；严格模板字体PDF可由安装等线字体的Word导出。

验证ZIP包含225份必要日志和汇总及文件清单，保留成功、失败、未知、仅编译的区别。本地用户路径已替换为`<LOCAL_HOME>`；脱敏副本校验值与原始校验值分别记录。它不是完整历史冻结包，也不作为产品当前证据准入文件。

最新完整核心执行对应`4910c15c12587ee001a30ec74363db0d2b64eaf5`：80项Python测试、双SDK共14个原生程序、28格健康矩阵（26运行、2仅编译）和26格导出重建。该记录属于R05完整回归；R11独立AI贡献分发另行运行聚焦MCP与复用验证，不替代全量回归。AI成对试验未证明效果提升，Windows未支持。

视频链接由负责人提供，线上播放和与本地成片的一致性尚待本人确认。推荐本地动画版约2分58秒，基于真实命令日志制作，并非现场屏幕录制。

仓库发布不等于赛事正式提交。赛事页面要求在赛题发布处提交作品并勾选同步到`cj-codelabs`；统一模板本人签字后转换PDF并按页面要求发送。具体流程见[官方赛事页](https://competitions.atomgit.com/competition/2090379383571447809/intro)。本次未代签、发送邮件或正式提交。

## AI生态贡献加分申请材料

- [独立贡献仓库](https://atomgit.com/c2892480843s/cj-docguard-ai)，固定初始分发提交`4b07cb87f641fe1d8052a780626d29247b922534`。
- [加分申请说明](AI生态贡献加分申请.md)与[运行、安装和复用说明](https://atomgit.com/c2892480843s/cj-docguard-ai/blob/main/README.md)。
- [独立贡献离线包](CJ-DocGuard-AI生态贡献包-20261007.zip)：54份文件，含Skill（助手技能指令）、MCP（模型上下文协议）只读适配器、配置、提示模板、样例、测试及本轮日志；不含SDK或私人联系方式。
- [验证细节](https://atomgit.com/c2892480843s/cj-docguard-ai/blob/main/docs/verification.md)：macOS arm64，固定主引擎`8a886f73f28d29c7fe92f2ea9dbebaa205b7f68a`；主仓库14项MCP测试、独立包13项协议测试、真实SDK 1.1.3/1.2.0自建样例及导出后输出3。两套单元测试覆盖重叠，不相加为独立测试数。

旧公开Word/PDF和旧提交ZIP保留为归档。最新模板只更新独立贡献链接，原字体字号与119个运行格式属性保持，五页渲染已检查；完整联系方式版另存于负责人本地。最高10分由组委会评审决定，初赛与决赛分别评分，正式申请仍需本人签字并随赛事提交。
