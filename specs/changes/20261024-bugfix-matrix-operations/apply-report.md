# 应用报告

## 应用信息

- 变更类型：缺陷修复（PR #54 Tester-feedback iteration 1）
- 变更名称：2×2 / 3×3 矩阵设备输入修复
- Issue：calculatorHuawei/agent_workflow#51
- 目标基线：`6e76305e8d3df57378314d78f30f4b53b0dc4690`
- 分支：`agent/pull_request-54-task-61`
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 应用日期：2026-10-25
- 执行范围：仅 MigBot APPLYING；未归档、未审批

## 前置制品核验

- Planning checkpoint 的 `proposal.md`、`delta-spec.md`、`acceptance-criteria.json`、`delta-design.md`、`todo.md`、`info.md`、`design-review.md` 及其引用的 `new-arch.md` 均存在、非空并已核验。
- `design-review.md` 结论为“通过。PLANNING 可完成”。
- AC 校验器通过：`VALID: 12 source requirement(s), 15 acceptance criterion/criteria`。
- Implementing checkpoint 的 `tasks.md` 存在，包含 5 项有序任务及 15/15 AC 的 Developer/Tester 验证责任。

## 根因诊断

精确基线 HAP（SHA-256 `7265C60B1F6E8E34443A40DC6B66DA7154935DB5E0F2EC8E9904FFEAD3ADE489`）安装到模拟器 `127.0.0.1:5555`（OpenHarmony 6.1.1.125）后：

1. 矩阵 A[1,1] 在 UI 树中 `focused=true`，但 `uitest uiInput text 1` 后 `text`/`originalText` 仍为空。
2. 同一设备、同一命令对绘图面板的顶层 `@State` TextInput 正常写入 `1`。
3. Tester 旧证据还显示坐标命令在键盘重布局后可能命中 B[2,2]；因此 exit 0 不能作为输入成功 oracle。

结论：驱动与全局 IME 路径可用；主要产品缺陷位于矩阵嵌套 Builder 参数/响应式状态绑定链，且缺少稳定的 matrix-row-column 节点 identity。

## 代码完成情况

| 任务 | 状态 | 完成时间 |
|---|---|---|
| Task 1.1 精确 head 设备输入诊断 | ✅ 完成 | 2026-10-25 |
| Task 1.2 建立最小失败回归 | ✅ 完成 | 2026-10-25 |
| Task 2.1 修复 TextInput identity 与状态所有权 | ✅ 完成 | 2026-10-25 |
| Task 3.1 Developer 全量回归与范围审计 | ✅ 完成 | 2026-10-25 |
| Task 3.2 AC-015 优先 Tester 交接 | ✅ 完成 | 2026-10-25 |

## TDD 执行记录

| 任务 | RED | GREEN | REFACTOR |
|---|---|---|---|
| Task 1.1 | 精确基线 A[1,1] 聚焦后输入仍为空；Plot 控制组通过 | 根因分类完成 | 四时点证据及命令成功≠语义成功规则固化 |
| Task 1.2 | 基线设备行为 RED；identity-only HAP 仍 RED | 顶层状态直接绑定后输入为 `1` | 失焦保持、计算消费、3×3 identity 复验 |
| Task 2.1 | `.id()` 单独不足，证明状态链也需修复 | A/B 八格标准 uitest 输入均可见 | A+B 得 `[[6,8],[10,12]]`，18/18 IDs 唯一 |
| Task 3.1 | 首次全量测试因缺失 Hypium 依赖失败（环境分类） | `ohpm install` 后 68/68 | CodeLinter `[]`、最终 HAP 构建、diff 审计通过 |
| Task 3.2 | Tester 旧 head AC-015 失败证据保留 | 精确新 head 交接字段齐备 | UI/E2E 结论继续由 Tester 独立执行 |

## 代码变更摘要

- `MatrixGrid` 不再接收非响应式 `string[][]` Builder 参数；每个 TextInput 直接读取页面顶层 `matrixAText` / `matrixBText` `@State`。
- 每个矩阵单元格增加稳定唯一 ID：`matrix-cell-{A|B}-{row}-{column}`。
- 未修改矩阵算法、数字语法、精度策略、MatrixSession、依赖、权限、Preferences schema、路由或持久化。

## 测试结果

- 单元测试：通过，68/68，Failure 0，Error 0。
- 设备集成回归：通过（Developer 观察）；输入即时可见、失焦保持、A+B 消费正确，2×2 为 8/8 唯一 ID，3×3 为 18/18 唯一 ID。
- CodeLinter：通过，`@typescript-eslint/recommended` + `@security/recommended`，结果 `[]`，exit 0。
- HAP 构建：通过，`BUILD SUCCESSFUL`；最终 unsigned HAP SHA-256 `43F6FEF52B355955197869FE1ACE6506477E74BF2C009CE8201985CEEA67F737`。
- Git diff 检查：通过；仅计划制品、任务/报告及 `CalculatorPage.ets` 的最小产品修复进入变更。

## 执行命令

```text
opencalc\run-build-wt.bat
ohpm install
hvigorw test -p module=entry -p coverage=false --no-daemon
node <DevEco>/plugins/codelinter/run/index.js -c opencalc/codelinter.json5 -f json -o specs/changes/20261024-bugfix-matrix-operations/codelinter-result.json -e error,warn opencalc
hdc -t 127.0.0.1:5555 install -r opencalc/entry/build/default/outputs/default/entry-default-unsigned.hap
hdc ... uitest dumpLayout / screenCap / uiInput click / uiInput text / keyEvent Back
git diff --check
```

## 证据位置

- 单测：`opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- Lint：`specs/changes/20261024-bugfix-matrix-operations/codelinter-result.json`
- HAP：`opencalc/entry/build/default/outputs/default/entry-default-unsigned.hap`
- 设备 RED/GREEN UI trees：`D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-61\run-111\device\ui-trees`
- 设备 RED/GREEN screenshots：`D:\huawei\Demo\calculatorHuawei\.agent-runtime\evidence\task-61\run-111\device\screenshots`

## 验收覆盖与边界

- AC-001..013：既有 68 个 unit/integration tests 保持全绿；Developer 设备回归额外证明 AC-001、AC-002 和修复相关的 AC-007/008/010/015 核心链路未回归。
- AC-014：Developer 不宣告完成；必须由 Tester 在精确 PR head 上独立生成并执行算法、边界和 UI 证据。
- AC-015：Developer RED→GREEN 已完成；Tester 必须优先复测手工触摸+系统 IME与标准 uitest，并保存输入前、输入后、失焦/重绘后、计算后的 focus/text/UI tree/screenshot。

## 已知风险

- `assembleHap` 仍输出仓库既有的 ArkTS exception/deprecation warnings，并因未配置 signingConfig 生成 unsigned HAP；本次未新增对应告警。
- Developer 设备证据不能替代 Tester 的 AC-014/015 独立结论。
- Tester 应使用稳定 ID 或每步重新读取节点 bounds，避免键盘重布局后的陈旧坐标。

## 下一步

Tester 在 PR #54 的精确新 head 上先执行 AC-015；通过后重跑 AC-002..012 输入依赖 UI 场景，并汇总 AC-014。归档命令仅供后续阶段使用，本次未执行归档或审批。
