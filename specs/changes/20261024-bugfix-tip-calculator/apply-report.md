# 应用报告（Tester 反馈迭代 1）

## 应用信息

- 变更类型：缺陷修复（PR #53 / Tester P0）
- 变更名称：修复小费计算器系统 IME 输入后结果不同步
- 关联 Issue：#50
- 目标基线：`84941216afa12ec6fa12c2383a86be2d38976fbb`
- 关联规划：`proposal.md`、`delta-spec.md`、`acceptance-criteria.json`、`delta-design.md`、`tasks.md`
- 应用日期：2026-10-25

## 代码完成情况

| 任务 | 状态 | 完成时间 |
|---|---|---|
| Task 1.1 固化 P0 RED 与快照 oracle | ✅ 完成 | 2026-10-25 |
| Task 2.1 CalculatorPage 唯一输入所有者 | ✅ 完成 | 2026-10-25 |
| Task 2.2 不可变快照与原子派生提交 | ✅ 完成 | 2026-10-25 |
| Task 2.3 四类 ArkUI 事件统一事务 | ✅ 完成 | 2026-10-25 |
| Task 3.1 保持受控 TipPanel 与稳定 ID | ✅ 完成 | 2026-10-25 |
| Task 3.2 清除 TipSession 生产状态职责 | ✅ 完成 | 2026-10-25 |
| Task 4.1 Developer 门禁 | ✅ 完成 | 2026-10-25 |
| Task 4.2 独立 Tester 完整设备复测 | ⏳ 交付 Tester | - |

## 测试结果

- Local Test：通过，63/63，Failure 0，Error 0。
- 构建：通过，`assembleHap` 输出 `BUILD SUCCESSFUL`。
- CodeLinter：通过，退出码 0、0 error、231 条仓库既有 warning；CalculatorPage warning 数与基线同为 74，TipCalculator/TipContract 为 0 finding。
- 静态集成检查：通过；生产及测试源码中无 `TipSession` / `syncTipState`，四类事件均以显式事件后快照求值。
- 设备 UI/E2E：未由 Developer 代签；run-100 保留为 RED，须 Tester 对交付 exact-head 使用真实系统 IME 复测。

## TDD 执行记录

| 任务 | RED | GREEN | REFACTOR |
|---|---|---|---|
| Task 1.1 | run-100：可见 `100/15%/2` 但三结果为 `--` | 增加 `100→101` 精确快照 oracle | 验证首个结果不被第二次求值改变 |
| Task 2.1 | 源码检查命中 `TipSession` 第二状态源 | 页面 `@State` 成为唯一可见输入源 | 每个事件传递显式 post-event 值 |
| Task 2.2 | run-100 证明可见输入与派生结果脱节 | 单快照 `evaluate` 后一次提交错误和三结果 | 提取 `evaluateTipSnapshot`，命名快照参数 |
| Task 2.3 | 四类 handler 均经过镜像回写链 | 账单、人数、预设、自定义均走统一事务 | 提取当前比例解析，避免重复和旧值读取 |
| Task 3.1 | run-100 UI 保持 `--` | TipPanel 继续绑定页面源/派生 `@State` | 稳定 ID 契约移入无状态 `TipContract` |
| Task 3.2 | 全仓检查命中 `TipSession` 生产和测试引用 | 删除 `TipSession` 及误导性的普通类状态测试 | 只保留纯计算与静态 UI 契约测试边界 |
| Task 4.1 | 首次 Local Test 因 Hypium 未解析失败 | `ohpm install --all` 后 test/build/lint 全绿 | 最终重复运行完整门禁与 diff 检查 |

## 测试详情

### Local Test

- 命令：`D:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat test -p module=entry -p coverage=false`
- 结果文件：`opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- 关键 oracle：`100/15%/2 → 15.00/115.00/57.50`；`101/15%/2 → 15.15/116.15/58.08`；四步有序快照、非法输入清空与恢复均通过。

### 构建

- 命令：`opencalc/build-test.bat`
- 结果：`BUILD SUCCESSFUL`。
- 构建仍报告既有 Index、PreferencesStore 和 CalculatorPage API warning；没有新增编译错误。

### Lint

- 命令：`node <DevEco CodeLinter>/index.js -c opencalc/codelinter.json5 -f json -o specs/changes/20261024-bugfix-tip-calculator/lint-result.json -e error opencalc`
- 结果：退出码 0，0 error，231 warning。
- 报告：`specs/changes/20261024-bugfix-tip-calculator/lint-result.json`。

## 代码变更摘要

- CalculatorPage 直接拥有小费输入、选择、touched、错误和结果状态；TextInput 可见值与计算输入不再跨普通类镜像。
- 四类事件使用事件参数与其余页面源状态构造不可变快照，再调用既有纯 `TipCalculator` 并提交完整派生结果。
- 删除可变 `TipSession`；新增无状态 `TipContract` 保存 Tester 使用的稳定 UI ID/入口/呈现契约。
- 增加 `100→101` 独立快照和四步有序输入 oracle；不改变整数分值算法、路由、权限、依赖、Preferences 或历史写入。

## 问题与解决

- 首次 Local Test 因当前 worktree 尚未安装 `@ohos/hypium` 而失败；执行 `ohpm install --all` 后恢复，并完成 GREEN/REFACTOR 重跑。
- Developer 无权用 unit/build 关闭真实系统 IME AC；run-100 失败证据未被覆盖，交付后由 Tester exact-head 重放 AC-001～AC-011。

## 下一步

交付独立 Tester 执行 Task 4.2。仅完成 APPLYING，不归档、不审批。
