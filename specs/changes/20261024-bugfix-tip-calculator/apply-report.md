# 应用报告

## 应用信息
- 变更类型：编排类型 bugfix；产品语义为新增功能
- 变更名称：小费计算器与多人账单分摊
- 关联 Issue：#50
- 关联规划：`proposal.md`、`delta-spec.md`、`delta-design.md`、`tasks.md`
- 应用日期：2026-10-24

## 代码完成情况
| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 TipCalculator RED 契约 | ✅ 完成 | 2026-10-24 |
| Task 2.1 纯逻辑计算 | ✅ 完成 | 2026-10-24 |
| Task 3.1 会话状态与原子重算 | ✅ 完成 | 2026-10-24 |
| Task 3.2 TipPanel UI | ✅ 完成 | 2026-10-24 |
| Task 3.3 横竖屏入口与隔离覆盖层 | ✅ 完成 | 2026-10-24 |
| Task 4.1 Developer 门禁 | ✅ 完成 | 2026-10-24 |
| Task 4.2 独立 Tester 设备验证 | ⏳ 待 Tester | - |

## 测试结果
- 单元测试：通过，64/64，Failure 0，Error 0
- 构建：通过，`assembleHap` 输出 `BUILD SUCCESSFUL`
- Lint：通过，DevEco CodeLinter 退出码 0、0 error；仓库基线仍有 231 条 warn，不包含新增 TipCalculator/TipSession 告警
- 集成检查：通过编译和依赖写路径审查；设备 UI/E2E 不由 Developer 代签

## TDD 执行记录
| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| Task 1.1/2.1 核心契约与实现 | ✅ 缺少 TipCalculator 模块失败 | ✅ 59/59 | ✅ 59/59 |
| Task 3.1 响应式会话 | ✅ 缺少 TipSession 模块失败 | ✅ 62/62 | ✅ 62/62 |
| Task 3.2 面板与稳定标识 | ✅ 缺少 TIP_UI_IDS 失败 | ✅ 63/63 | ✅ 构建成功 |
| Task 3.3 双入口与覆盖层 | ✅ 缺少入口/呈现契约失败 | ✅ 64/64 | ✅ 64/64 + 构建成功 |
| Task 4.1 门禁 | ✅ 门禁前先固定预期命令与 oracle | ✅ test/build/lint 全绿 | ✅ diff/依赖审查后复跑全绿 |

## 测试详情
### 单元测试
- 命令：`hvigorw test -p module=entry -p coverage=false`
- 结果文件：`opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`
- 覆盖核心示例、0% 边界、half-up 舍入、金额/人数/比例校验、恢复、即时更新、互斥选择和 UI 定位契约。

### 构建
- 命令：`opencalc/build-test.bat`
- 结果：`BUILD SUCCESSFUL`。
- 构建输出仍含既有 `Index.ets`、`PreferencesStore.ets` 和既有 CalculatorPage API 的基线 warning；没有本变更新增编译错误。

### Lint
- 命令：`node <DevEco CodeLinter>/index.js -c opencalc/codelinter.json5 -f json -o specs/changes/20261024-bugfix-tip-calculator/lint-result.json -e error opencalc`
- 结果：退出码 0，0 error；JSON 报告保存于 `lint-result.json`。

## 代码变更摘要
- 新增无副作用、整数分值计算的 `TipCalculator`，统一校验与固定两位格式化。
- 新增可单测的 `TipSession`，负责输入事件、预设/自定义互斥和原子派生状态。
- CalculatorPage 新增横竖屏入口、同页覆盖 TipPanel、字段错误和稳定 UI 标识；不写 History/Preferences，不调用 router 或主 CalcEngine。
- 注册小费专属 Local Test；全套回归由 59 增至 64 个用例。

## 问题与解决
- 首次 Local Test 因 `@ohos/hypium` 未安装而无法解析；执行仓库依赖安装后恢复。
- CodeLinter 报告含既有文件的风格 warning；本次新增纯逻辑模块告警已在重构阶段清零，门禁按 error 级别通过。
- 横竖屏实际可达、设备 UI 文本和历史前后相等必须由后续独立 Tester 留证，不在本报告中提前关闭。

## 下一步
交付 Tester 执行 Task 4.2；不归档、不审批。
