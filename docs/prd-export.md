# PRD：`export` 命令 — 导出带证据的可运行示例包

> 版本：v1.0 · 2026-10-06 · 状态：交 Codex 实现
> 目标里程碑：R02，随初赛版本提交（截止 2026-10-07 23:59:59）
> 基线：分支 `codex/cj-docguard`，HEAD `f369030`（R01 已完成命令参数严格校验）
> 执行约束：本功能凌晨 01:00 前测试未全绿则整体砍掉，按 R01 版本提交，不得带病合并。

---

## 1. 背景与目标

CJ-DocGuard 当前能把「示例在哪个 SDK 真实运行过、证据是否仍有效」查出来（`query`/`evidence`），但开发者或 AI 助手拿到证据后，仍要手工拼装示例、包装模板和库源码才能本地复现。

`export` 命令把这个闭环补上：**仅当指定示例的证据当前有效（eligible）时，把冻结快照中的示例、包装、库源码和证据清单一并导出为独立目录，可直接用真实 `cjc` 编译运行。**

对应产品主张：「AI 读取带证据的示例」→ 升级为「AI 拿到带证据出生证明的可运行工程骨架」。

### 成功标准

- 健康样本 14 例中任一 `eligible=true` 的格可导出，导出目录用对应真实 SDK 编译运行，stdout 与登记断言一致。
- 全部拒绝路径与 `query` 的 `rejected` 口径完全一致，拒绝时不产生任何文件副作用。
- 现有测试与 28 格矩阵全绿，无回归。

## 2. 命令规格

```bash
cj-docguard export --config /path/docguard.toml --example arithmetic \
  --sdk 1.1.3 --platform Darwin-arm64 --out ./exported/arithmetic
```

| 参数 | 必填 | 说明 |
|---|---|---|
| `--config` | 是 | 项目配置（沿用现有约定） |
| `--example` | 是 | 登记的示例 ID；首版只支持单例，不支持批量 |
| `--sdk` | 是 | 确切 SDK 版本，必须在 `[[sdks]]` 中已声明；不跨版本回退 |
| `--platform` | 是 | 实际平台（如 `Darwin-arm64`） |
| `--out` | 是 | 导出目录。**不存在则创建；已存在且非空则拒绝（退出码 2），与 `init` 的拒覆盖哲学一致** |

**退出码**（沿用现有语义）：`0` 导出成功；`1` 证据不满足准入（质量失败）；`2` 配置/参数/路径/环境错误。

**参数校验**（对接 R01 机制，必须改的两处）：
- `src/main.cj` `options()` 的已知选项数组加入 `"--out"`；
- `validateOptions()` 的 match 加入 `case "export" => ["--config", "--example", "--sdk", "--platform", "--out"]`，其他命令传入 `--out` 必须照旧拒绝；`--help`/HELP 文案同步更新。

## 3. 行为规则

### 3.1 准入判定（零新逻辑，必须复用）

在 `operate()` 现有项目命令路径内实现（与 `query` 同级）：加载 `Project` → 检查 `writer.lock` → 计算 `projectManifest` / `inspectEnvironments` → `readAttempts` → 对目标 `(example_id, sdk, platform)` 取 `latestAttempt`，用 `src/evidence.cj` 现有函数判定：

- `freshness(record, projectFp, envFp, closure)` 必须为 `"CURRENT"`；
- `eligible(record, projectFp, envFp, sdk, platform, closure)` 必须为 `true`。

不满足时：打印 JSON `{"error": "...", "example_id", "status", "freshness", "reason", "exit_code": 1}`（reason 与 `query` 的 rejected 条目同口径），返回 1，**不创建 `--out` 或已创建则删除自己创建的空目录**——拒绝路径零文件副作用。

### 3.2 导出内容（全部来自冻结快照，不读工作区现文件）

快照根：`<output>/snapshots/<project_fingerprint>/`（`engine.cj freezeProject` 已保证其与证据同源）。导出目录结构：

```
<out>/
├── src/                     # 冻结的库源码，保持原相对路径
├── examples/<原路径>         # 冻结的登记示例源文件
├── wrapper.cj               # kind="snippet" 时的原始包装模板（含 {{code}} 占位）
├── main_wrapped.cj          # 实际编译单元（模板已代入示例代码，与 attempts 记录中 code 字段一致）
├── build.sh                 # 复现脚本：编译 + 运行（见 3.3）
├── manifest.json            # 证据清单（见 3.4）
└── README.md                # 自动生成：这是什么、怎么跑、证据边界
```

`kind="program"` 的示例无包装，`main_wrapped.cj` 即冻结示例源码本身，结构保持一致。

### 3.3 build.sh 生成

从该尝试记录的 `compile.argv` / `run.argv` 重建命令，但：

- 把所有快照内绝对路径重写为导出目录内的相对路径（`./src/...`、`./main_wrapped.cj`）；
- SDK 路径写成环境变量占位 `${CJ_SDK_HOME}`，README 说明如何指向真实 SDK 根；
- 路径映射必须走 `engine.cj` 现有 `publicValue()`/`sanitizeStage()` 的脱敏口径，不得泄露私有绝对路径；
- 文件头注释注明生成时间与来源尝试序号。

### 3.4 manifest.json 模式

```json
{
  "schema_version": 1,
  "tool": "cj-docguard",
  "tool_version": "<ENGINE_VERSION>",
  "project": "<项目名>",
  "example_id": "arithmetic",
  "symbol": "add",
  "sdk_version": "1.1.3",
  "platform": "Darwin-arm64",
  "project_fingerprint": "<sha256>",
  "environment_fingerprint": "<sha256>",
  "attempt_sequence": 137,
  "snapshot_manifest_sha256": "<sha256>",
  "status": "RUN_VERIFIED",
  "freshness_at_export": "CURRENT",
  "assertions": [{"kind": "stdout", "required": true, "passed": true}],
  "evidence_boundary": "证据冻结于导出时刻；输入或环境变化后当前性必须重新查询。运行通过仅证明登记断言在记录环境下通过，不证明 API 全部行为正确。"
}
```

### 3.5 路径安全（沿用配置校验同级严格度）

- `--out` 解析为绝对路径后：不得位于项目 `sources` 任一目录内、不得与 `output` 目录互相包含、不得逃逸为配置根之外的相对陷阱（复用 `util.cj resolved()` 与现有重叠检查的思路）；
- 违反 → 退出码 2，零副作用。

## 4. 与现有代码的对接点

| 文件 | 改动 |
|---|---|
| `src/main.cj` | HELP 文案；`options()` 加 `--out`；`validateOptions()` 加 `export` 允许列表；`operate()` 项目命令 known 列表加 `"export"`，在 `query` 分支同级实现分发 |
| `src/export.cj` | **新建**（≤250 行）：`exportExample(project, manifest, environments, attempts, options): Int64`，含准入复用、快照读取、目录写出、build.sh/manifest/README 生成 |
| `src/evidence.cj` | 不改，仅调用 `eligible()` / `freshness()` / `latestAttempt()` |
| `src/engine.cj` | 不改；`freezeProject` 的快照布局、`publicValue()` 脱敏直接复用 |

## 5. 测试要求（全部必须真实，不得替身冒充真实编译器）

### 5.1 仓颉原生测试（新增 `tests/native_export.cj`，两个 SDK 各跑一遍）

1. 正例：verified 健康项目上导出成功，目录结构完整、manifest 字段齐全、指纹与报告一致；
2. 负例·过期：verify 后修改源文件 → export 返回 1，freshness=STALE，`--out` 不存在；
3. 负例·仅编译：`COMPILE_ONLY` 例 → 返回 1，reason 与 query 口径一致；
4. 负例·未知：未登记/未验证的 example ID → 返回 1（UNKNOWN_CURRENT）；
5. 参数：缺 `--out`/`--sdk`/`--platform`、export 传 `--tool`、其他命令传 `--out` → 均退出码 2；
6. 路径：`--out` 位于 sources 内、已存在非空 → 退出码 2 且原目录内容未被触碰。

### 5.2 Python CLI 集成（追加进 `tests/test_cli.py`）

- 真实 CLI 跑健康样本：导出 → 用 `${CJ_SDK_HOME}` 指向真实 1.1.3 执行导出目录的编译运行 → stdout 断言一致（SDK 缺失时按现有惯例显式标记跳过，不得静默）；
- 修改-拒绝-恢复三段：改源码 → export 拒绝 → 重验 → export 恢复成功。

### 5.3 回归

`python3 scripts/test.py` 全量 + 健康样本 `--matrix` 28 格重验全绿；结果记入 `docs/optimization-log.md` 的 R02 节（保留退出码与二进制身份）。

## 6. 文档更新清单（随功能一起交付）

- [ ] `README.md`：命令表加 `export` 行 + 一小节「导出可运行示例包」（含证据边界一句话）
- [ ] `CHANGELOG.md`：R02 条目
- [ ] `docs/optimization-log.md`：R02 验证记录
- [ ] `docs/acceptance.md`：新增 F17/A24 映射行
- [ ] `docs/submission.md`：演示脚本第 5 段后加 30 秒 export 镜头（导出 → 编译 → 运行 → 指向 manifest 的「出生证明」）
- [ ] `skills/cj-docguard/SKILL.md`：补一句「可用 export 把 eligible 示例落地为可运行骨架」

## 7. 非目标（明确不做）

- 批量导出、`--all`、按 symbol 批量；
- FROZEN/history 记录导出（归档只读语义不变）；
- MCP 增加写工具（MCP 仍只读三工具）；
- 修改 verify/准入/失效任何现有判定逻辑；
- 跨包依赖解析、cjpm 依赖下载（导出包仅限单包自包含场景，与首版支持范围一致）。

## 8. 诚实口径（写代码和文档时同样遵守）

- 不宣称导出的示例「保证正确」——只能说「登记断言在记录环境下通过」；
- manifest 与 README 必须带 `evidence_boundary` 声明；
- 未做模型行为对照实验，不得宣称提升 AI 生成代码通过率。

## 9. 验收命令（Codex 完成后按序执行并留存输出）

```bash
python3 scripts/dev.py build
python3 scripts/test.py
python3 scripts/dev.py run -- verify --config examples/healthy/docguard.toml --matrix
python3 scripts/dev.py run -- check --config examples/healthy/docguard.toml --strict
python3 scripts/dev.py run -- export --config examples/healthy/docguard.toml \
  --example arithmetic --sdk 1.1.3 --platform Darwin-arm64 --out build/export-smoke/arithmetic
cd build/export-smoke/arithmetic && CJ_SDK_HOME=<真实SDK根> bash build.sh
```
