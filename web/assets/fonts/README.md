# 工作台中文字体

`docguard-sans-sc.woff2` 是随项目分发的中文无衬线可变字体，网页离线加载，不依赖字体 CDN。正文、标题与表单使用该字体；代码保留等宽字体。未收录的生僻字由系统中文字体补齐。

- 上游：Google Fonts 的 Noto Sans SC，固定版本与校验值见 `provenance.json`。
- 许可证：SIL Open Font License 1.1，完整原文见 `OFL.txt`。
- 修改：保留 GB2312 中文、拉丁字符与常用标点，保留可变字重，并将派生字体主家族名改为 `DocGuard Sans SC`。
- 运行网页直接使用已提交的 WOFF2 文件，不需要安装字体或 Python 包。

仅在需要重新制作字体时，在仓库根目录执行以下可选开发命令：

```sh
python3 -m venv build/ui-font-tools
build/ui-font-tools/bin/python -m pip install 'fonttools[woff]==4.68.0'
build/ui-font-tools/bin/python scripts/build_ui_font.py
```

脚本下载固定版本、验证源字体 SHA-256，并生成字体及来源记录。字体构建不属于仓颉服务运行流程。
