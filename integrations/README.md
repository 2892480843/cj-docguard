# 固定来源集成材料

这里保存三个上游项目的固定提交摘要、许可证、作者编写的真实接口调用样例和只读复验结果，不保存完整上游仓库。

- [固定来源及全部受跟踪文件摘要](upstream-lock.json)
- [2026-10-06 实际复验摘要](audit-20261006.json)
- [完整说明、结果边界与复现命令](../docs/real-projects.md)
- [leven4cj 样例](leven4cj/sample.cj) / [Apache-2.0 许可](leven4cj/LICENSE)
- [is-png-cj 样例](is-png-cj/sample.cj) / [MIT 许可](is-png-cj/LICENSE)
- [compare-versions-cj 样例](compare-versions-cj/sample.cj) / [MIT 许可](compare-versions-cj/LICENSE)

上游源码仅按原始字节复制到本地构建缓存，并与来源摘要核对。**这属于 CJ-DocGuard 作者的独立复验，不是上游采用声明。** 当前仅登记三个样例、六个 SDK 单元；真实编译失败与输入未知结果均保留。
