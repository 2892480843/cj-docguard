# 实施计划与进度

依据：上级目录 PRD v1.0；2026-10-06 用户已要求按需求文档完成项目。

## 全局约束

- 核心提取、验证、输入指纹、状态判定与CLI使用仓颉原生实现；平台子进程管理使用随项目提供的Unix C小组件，构建/集成测试脚本使用Python标准库，透明披露语言构成。
- 不用模拟编译成功代替真实SDK。SDK按官方下载校验值安装到项目外 `.toolchains`，不修改用户已有1.0.5 SDK。
- 最新登记尝试优先；只有完整断言通过、输入与环境匹配才可返回当前有证据示例。历史成功不能掩盖较新失败/取消/进行中。
- 明确未知/未支持/未检查；静态报告是快照，不能在线证明当前仓库状态。
- 执行仅限显式审核项目；不继承敏感环境；进程组超时清理不等于安全沙箱。
- 不自动发送邮件、联系第三方、发布远程仓库或参赛提交。完成可审核本地工程与材料。
- 可选AI对照实验没有实测时标为未测；不捏造真实项目采用数。

## 工程契约

项目目录为当前文件的上级目录。`src/*.cj`统一使用`package docguard`，由cjc直接构建本地可执行文件；同时提供cjpm配置。原生基础JSON类型：`class J`，`kind:String`、`text:String`、`items:ArrayList<J>`、`fields:HashMap<String,J>`；`J.str(String)`、`J.num(Int64)`、`J.boolean(Bool)`、`J.arr()`、`J.obj()`、`J.nil()`；`get(String):J`缺字段返回null；`s():String`、`i():Int64`、`b():Bool`严格读取；`add(J):J`与`put(String,J):J`支持链式；`dump():String`；`parseJson(String):J`；`parseToml(String):J`限定并拒绝未支持语法；`sha256(Array<Byte>):String`。

AST入口：`extractSource(source:String,path:String):J`返回`symbols`数组、`diagnostics`数组、`imports`数组、`package`、`status`。符号字段：`name`、`kind`、`package`、`owner`、`declaration`、`parameters`（name/type字符串对象）、`returns`、`line`、`column`、`source`、`comment`、`status`；ID由主引擎统一以来源/签名摘要补齐。仅显式公共接口作为已支持公共符号，未支持/解析失败透明报告。

配置契约：`[project] name, sources=["src"], documents=["README.md"], output=".docguard", trusted=true, closed_inputs=true, exclude=[]`；`[[sdks]] version, home`（home可省略，使用显式CLI注册或`CJ_DOCGUARD_SDK_1_1_3`类环境值）；`[[examples]] id, file, symbol, mode="run"|"compile", kind="program"|"snippet", wrapper, sdks=[...], stdout, expected_exit=0, timeout_ms=10000, skip_reason, required=true`；`[[links]] from,target`。配置及示例文件都绑定快照。运行例无输出/退出码断言登记时不得生成RUN_VERIFIED。

## 顺序与验收

| 任务 | 文件范围 | 验收证据 | 状态 |
|---|---|---|---|
| 1. SDK/AST/执行探针 | scripts、工具链记录、probes | 1.1.3和1.2.0版本；最小程序及AST真实运行 | 已完成 |
| 2. 原生JSON/TOML/SHA基础 | src/primitives.cj、tests/native_primitives.cj | 标准SHA向量、JSON转义/错误、TOML重复与子集限制 | 已实现，详见验收记录 |
| 3. 原生API提取 | src/extractor.cj、tests/native_extractor.cj | 顶层/成员/泛型重载、位置、中文注释、错误与未支持 | 已实现，详见验收记录 |
| 4. 执行器与证据引擎 | src/engine.cj、scripts/runner.c | 固定快照、真实SDK、失败分类、超时/中断、完整历史/最新尝试、变更拒绝 | 已实现，详见验收记录 |
| 5. 文档报告与查询 | src/report.cj、src/main.cj、静态资源 | 离线搜索、API/示例/SDK/链接报告、严格退出码、只读协议 | 已实现，详见验收记录 |
| 6. 完整样本与复验 | examples、tests/test_cli.py、scripts/test.py、scripts | 至少30符号/12类示例、两个SDK10例、干净目录复验；第三方复用按实际结果 | 已实现，详见验收记录 |
| 7. 开源与参赛材料 | README、LICENSE、CHANGELOG、docs | 安装、限制、验收映射、演示脚本、模板填写素材与实际未提交项 | 已实现，详见验收记录 |

探针属于探索性验证，保留实际日志；核心行为采用测试先失败再实现。没有现有Git工程，已在独立`cj-docguard`目录初始化开发分支，原有文档保持原位。


## 集成状态

0.1.0 基线的核心、双 SDK 模块、39 项集成测试和干净目录复验通过；当时健康矩阵 28 格当前匹配，其中 26 格运行验证、2 格明确仅编译，严格检查退出 0。报告遍历和搜索问题已修复并回归，原失败记录仍保留。详见 [基线验证归档](verification.md)、[持续优化](optimization-log.md)、[验收映射](acceptance.md) 与 [已知边界](TODO-OPT.md)。未来赛事版本迭代、真实样例 60 例扩展、AI 研究和人工提交不冒充已完成。

## R03 当前收尾（2026-10-07）

上段为0.1.0历史边界。现已完成真实60调用/双SDK120格、受控128MB长历史修复、Ubuntu22.04 Linux aarch64原生双SDK、30对AI实验及本地三分半演示/官方Word。AI未见提升、上游失败/未知保留；完整Markdown、多包、其他平台及本人信息/公开链接/签字/任务9最新明细/提交仍待。当前数字、冻结身份与对应验证范围见 [最新验收](acceptance.md)，原始历史均保留。
