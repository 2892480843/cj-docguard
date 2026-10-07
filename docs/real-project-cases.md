# 固定上游真实 API 案例登记

三个仓库均固定在 [锁文件](../integrations/upstream-lock.json) 中的提交；每个案例独立编译并断言标准输出及退出码。这里的“案例”是本项目编写的同包调用程序，并非上游测试或第三方采用。原 `sample.cj` 三份保持字节不变。

预期值以独立 Python 动态规划、PNG 固定八字节签名及上游 API 文档/测试计算或核对。Unicode 编辑距离按码点计算，故空串与非 ASCII 的案例可以揭示上游字节长度分支问题，不能为通过而改动期望。版本库在当前两版 SDK 的整库编译失败时，这些运行期断言保持未执行。

| 仓库 | ID | 目的 | 参数或调用 | 预期 stdout | 依据 |
|---|---|---|---|---|---|
| leven4cj | upstream-api | 保留原三调用样例 | `见 sample.cj` | `'3\n2\n3\n'` | 原固定样例；上游 README 与 src/test/leven_test.cj |
| leven4cj | empty-empty | 双空串 | `'', ''` | `0\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | empty-ascii | 单字符插入 | `'', 'x'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | ascii-empty | 三字符删除 | `'xyz', ''` | `3\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | equal-ascii | 相等短串 | `'same', 'same'` | `0\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | substitute | 中位替换 | `'cat', 'cut'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | insert-front | 前缀插入 | `'cat', 'scat'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | insert-middle | 中间插入 | `'cat', 'cart'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | insert-end | 后缀插入 | `'cat', 'cats'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | delete-middle | 中位删除 | `'cart', 'cat'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | transpose | 交换需要两步 | `'ab', 'ba'` | `2\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | case-sensitive | 大小写差异 | `'A', 'a'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | digit-letter | 数字字母替换 | `'1', 'a'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | unequal-length | 不同长度 | `'abc', 'abcdef'` | `3\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | unicode-equal | 中文完全相等 | `'你好', '你好'` | `0\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | unicode-substitute | 中文单字替换 | `'你好', '你们'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | unicode-insert | 中文插入 | `'中文', '中英文'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | unicode-empty | 空串到中文字符 | `'', '你'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | emoji-empty | 表情字符到空串 | `'😀', ''` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| leven4cj | emoji-substitute | 表情字符替换 | `'😀', '😁'` | `1\n` | 独立 Python Unicode 码点动态规划；上游 README 定义 |
| is-png-cj | upstream-api | 保留原三调用样例 | `见 sample.cj` | `'true\nfalse\nfalse\n'` | 原固定样例；上游 src/is_png_test.cj |
| is-png-cj | empty | 零字节 | `空数组` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | prefix-1 | 仅前 1 字节 | `89` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | prefix-2 | 仅前 2 字节 | `89 50` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | prefix-3 | 仅前 3 字节 | `89 50 4E` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | prefix-4 | 仅前 4 字节 | `89 50 4E 47` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | prefix-5 | 仅前 5 字节 | `89 50 4E 47 0D` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | prefix-6 | 仅前 6 字节 | `89 50 4E 47 0D 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | prefix-7 | 仅前 7 字节 | `89 50 4E 47 0D 0A 1A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-0 | 第 1 位错误 | `88 50 4E 47 0D 0A 1A 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-1 | 第 2 位错误 | `89 51 4E 47 0D 0A 1A 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-2 | 第 3 位错误 | `89 50 4F 47 0D 0A 1A 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-3 | 第 4 位错误 | `89 50 4E 46 0D 0A 1A 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-4 | 第 5 位错误 | `89 50 4E 47 0C 0A 1A 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-5 | 第 6 位错误 | `89 50 4E 47 0D 0B 1A 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-6 | 第 7 位错误 | `89 50 4E 47 0D 0A 1B 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | bad-byte-7 | 第 8 位错误 | `89 50 4E 47 0D 0A 1A 0B` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | valid-with-payload | 正确签名后有载荷 | `89 50 4E 47 0D 0A 1A 0A 00 01 02 03` | `true\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | valid-with-zero | 正确签名后有零字节 | `89 50 4E 47 0D 0A 1A 0A 00` | `true\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| is-png-cj | offset-signature | 签名在偏移一处 | `00 89 50 4E 47 0D 0A 1A 0A` | `false\n` | PNG 八字节签名 89 50 4E 47 0D 0A 1A 0A；上游 src/is_png.cj 与测试 |
| compare-versions-cj | upstream-api | 保留原三调用样例 | `见 sample.cj` | `'1\n0\n-1\ntrue\nfalse\n'` | 原固定样例；上游 doc/feature_api.md |
| compare-versions-cj | major-greater | 主版本大于 | `compareVersions("2.0.0", "1.9.9")` | `1\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | major-less | 主版本小于 | `compareVersions("1.9.9", "2.0.0")` | `-1\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | minor-greater | 次版本大于 | `compareVersions("1.3.0", "1.2.9")` | `1\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | minor-less | 次版本小于 | `compareVersions("1.2.9", "1.3.0")` | `-1\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | patch-greater | 补丁版本数值比较 | `compareVersions("1.2.10", "1.2.9")` | `1\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | patch-less | 补丁版本逆序 | `compareVersions("1.2.9", "1.2.10")` | `-1\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | equal | 相同版本 | `compareVersions("1.2.3", "1.2.3")` | `0\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | prerelease | 预发布低于正式版 | `compareVersions("1.0.0-rc.1", "1.0.0")` | `-1\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | metadata | 构建元数据不参与排序 | `compareVersions("1.0.0+build.1", "1.0.0+build.2")` | `0\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | compare-gt | 大于操作符 | `compare("2.0.0", "1.0.0", ">")` | `true\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | compare-lt | 小于操作符 | `compare("1.0.0", "2.0.0", "<")` | `true\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | compare-eq | 等于操作符 | `compare("1.0.0", "1.0.0", "=")` | `true\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | compare-ne | 不等操作符 | `compare("1.0.0", "2.0.0", "!=")` | `true\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | compare-ge | 大于等于反例 | `compare("1.0.0", "2.0.0", ">=")` | `false\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | validate-stable | 严格合法稳定版 | `validateStrict("1.2.3")` | `true\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | validate-prerelease | 严格合法预发布版 | `validateStrict("1.2.3-rc.1")` | `true\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | validate-empty | 严格校验空值 | `validateStrict("")` | `false\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | validate-short | 严格校验缺补丁 | `validateStrict("1.2")` | `false\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |
| compare-versions-cj | validate-wildcard | 严格校验拒绝通配符 | `validateStrict("1.x")` | `false\n` | 上游 doc/feature_api.md 与 src/compare_version_test.cj；构建元数据/预发布遵循 SemVer |

每条锁定样例的 SHA-256 与源文件逐字节核对，原生矩阵结果和实际失败见 `build/real-projects/<运行时间>/audit.json`。
