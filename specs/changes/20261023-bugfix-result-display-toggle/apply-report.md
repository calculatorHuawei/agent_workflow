# 应用报告

## 应用信息
- 变更类型：缺陷修复（Tester feedback）
- 变更名称：result-display-toggle canonical UI suite
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 应用日期：2026-10-23
- 关联 Issue / PR：#44 / #47
- 变更基线：`dd3f053a1a4fe04987f27f5b3f502db253dde5e0`

## 代码完成情况
| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 持久化已执行的结果显示 UI 套件 | ✅ 完成 | 2026-10-23 |
| Task 2.1 验证 loader 契约、覆盖集合与最小变更范围 | ✅ 完成 | 2026-10-23 |

## 测试结果
- 单元测试：通过，HarmonyOS Local Test 62/62；Python driver tests 4/4
- 集成测试：通过，真实 `load_cases()` 加载 5 个 case，并与 run-59 JSON 结构化相等
- Lint 检查：通过，CodeLinter 0 error；222 个既有 warning
- 构建：通过，`entry-default-unsigned.hap` 已生成

## TDD 执行记录
| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| Task 1.1 | ✅ `load_cases()` 对缺失 canonical 路径抛出 `FileNotFoundError` | ✅ 新增 version-1 JSON 后加载 5 个唯一 case | ✅ 复用 run-59 原始结构，无附加运行时字段；哈希相等 |
| Task 2.1 | ✅ 缺失资产使 loader/语义契约无法成立 | ✅ ID、表达式、assertions、整数正/负断言与结构化相等检查通过 | ✅ driver 4/4、范围审查与全量复验保持绿色 |

## 测试详情
### Canonical loader 与语义验证
- 使用共享 `orchestrator.harmony_ui_driver.load_cases()` 加载 PR 工作树中的 canonical 文件。
- 精确加载 5 个唯一 ID：`half-toggle`、`third-toggle`、`reduced-half`、`negative-half`、`integer-fraction-mode`。
- expression 映射精确覆盖 `1÷2`、`1÷3`、`2÷4`、`-1÷2`、`4÷2`。
- integer case 同时包含 `text_present: 2` 与 `text_absent: 2/1`。
- PR 文件、共享 canonical 文件和 run-59 evidence 的 SHA-256 均为 `3579E7CCD9AA087117835C77E53EDBF9D111CAF10E638AF88224D4759C5FD2D0`。

### 单元测试
- `hvigorw --no-daemon test -p module=entry -p coverage=false`
- 结果：`Tests run: 62, Failure: 0, Error: 0, Pass: 62, Ignore: 0`。
- `python -m pytest orchestrator/tests/test_harmony_ui_driver.py -q`
- 结果：`4 passed`；仅出现 Python requests 的可选字符检测依赖 warning，与测试结果无关。

### Lint 检查
DevEco CodeLinter 以 error 为退出门禁：0 error、222 个基线 warning。变更仅新增 JSON 和工作流文档，不修改 ArkTS 产品源码。

### 构建
`opencalc/run-build-wt.bat` 完成 `BUILD SUCCESSFUL`；产物为 `opencalc/entry/build/default/outputs/default/entry-default-unsigned.hap`。

## 代码变更摘要
- 在 PR 仓库路径新增 `orchestrator/ui_cases/result_display_toggle.json`，使 canonical suite 随 PR 交付。
- 同步共享编排器路径，供当前 orchestrator/tester 直接读取。
- JSON 内容逐字段复用 Tester run-59 已执行基线，不携带设备 ID、HEAD、时间戳、截图/evidence 绝对路径、坐标或凭据。
- 未修改 `opencalc/` 产品源码、loader、`function_plot.json`、历史 evidence 或归档内容。

## 问题与解决
- 新工作树首次 Local Test 因 `@ohos/hypium` 未安装而编译失败；使用现有 lockfile 执行 `ohpm install --all` 后，真实测试 62/62 通过。该失败属于环境准备，不作为 TDD RED。
- 共享 orchestrator 目录不在 PR 基线 Git 树中；为确保 PR 可交付，canonical 文件同时位于 assigned branch 的仓库相对路径，并验证两份文件与 run-59 基线哈希完全一致。

## 下一步
交由 Tester 从 canonical 路径复验。当前禁止归档或批准。
