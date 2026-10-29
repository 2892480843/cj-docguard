# 链接检查演示

本项目包含预期坏链，用于检查自动诊断。示例运行成功不表示所有文档链接通过；`check --strict` 应退出 1。

- [带百分号编码与标题](docs/target%20file.md#相同标题-1 "第二个同名标题")
- [完整引用][文档]
- [折叠引用][]
- [快捷引用]
- [带空格的尖括号路径](<docs/target file.md#setext-heading> '标题')
- [路径转义](docs/part\(1\).md)
- [手写 HTML 锚点](docs/target%20file.md#manual-id)
- ![本地图标](assets/icon.svg "检查图片目标")
- [预期文件缺失](docs/intentionally-missing.md)
- [预期转义锚点不存在](docs/target%20file.md#escaped-ghost)
- <https://cangjie-lang.cn>

[文档]: docs/target%20file.md#相同标题 "参考定义"
[折叠引用]: docs/target%20file.md
[快捷引用]: docs/part(1).md

以下是代码，不应被算成坏链：

`[内联代码](missing-inline-code.md)`

```markdown
[围栏代码](missing-fenced-code.md)
```

<!-- [注释](missing-comment.md) -->
