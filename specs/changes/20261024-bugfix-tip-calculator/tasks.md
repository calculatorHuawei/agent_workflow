# 小费计算器与多人账单分摊开发任务（Tester 反馈迭代 1）

## 任务概述

- 功能名称：小费计算器与多人账单分摊
- 变更类型：编排器 `bugfix`；产品语义为既有新增功能的 P0 纠正
- 目标基线：PR #53 / `84941216afa12ec6fa12c2383a86be2d38976fbb`
- 规划输入：`proposal.md`、`delta-spec.md`、`acceptance-criteria.json`、`info.md`、`delta-design.md`、`design-review.md`
- 开发阶段：收敛 CalculatorPage 的小费输入状态所有权，修复真实系统键盘输入后可见值与结果脱节
- 预计任务数：8
- 范围守卫：保留纯分值算法、同页覆盖层、现有入口和稳定 ID；不新增路由、权限、依赖、持久化、历史写入、程序员模式或 `ohosTest` target
- 完成边界：Developer 的 unit/build/lint 通过不等于 feature AC 关闭；AC-001～AC-011 最终状态以独立 Tester 的 exact-head 设备证据为准

## 规划制品验证结论

| 制品 | 验证结果 |
|---|---|
| `proposal.md` | 通过；IR-001～IR-014、Tester P0 反馈、范围与安全默认完整 |
| `delta-spec.md` | 通过；SR-00～SR-05、场景、FMEA 和 IR→SR→AC 追溯一致 |
| `acceptance-criteria.json` | 通过；JSON 可解析，14 IR、11 个 feature AC、14 条覆盖记录，无重复/悬空 ID，均声明验证层级 |
| `info.md` | 通过；代码现状、三源状态风险、影响文件和设备证据边界明确 |
| `delta-design.md` | 通过；页面 `@State` 单一事实源、不可变快照、原子派生提交和真实 IME 门禁可实施 |
| `design-review.md` | 通过；记录 AC 校验器最终退出 0，结论为 PLANNING 完成且无 blocker |
| `todo.md` | 通过；PLANNING 子步骤已完成，本阶段可开始任务分解 |

## 任务列表

### 阶段 1：回归契约

#### Task 1.1: 固化 Tester P0 RED 与快照 oracle

**描述**：把 run-100 的真实设备失败作为本轮不可弱化的 RED：可见 `100/15%/2` 时结果为 `--/--/--`。在既有 Hypium 契约中补充 `101/15%/2 → 15.15/116.15/58.08` 和连续不可变快照断言。unit oracle 在基线可能已通过，不能替代或冒充 UI 缺陷的 RED。

**涉及文件**：
- 测试：`opencalc/entry/src/test/TipCalculator.test.ets`
- 测试注册（仅在确需调整时）：`opencalc/entry/src/test/List.test.ets`
- 外部 RED 证据（只读）：`.agent-runtime/evidence/task-55/run-100/`

**依赖任务**：无

**预计用时**：1 小时

**输入/输出**：输入 AC-002/004/011 与 run-100 证据；输出绑定 AC ID 的快照回归契约和 device RED 说明。

**验收标准**：
- 精确断言 `100/15%/2`、`101/15%/2`，且一次求值不读取或改变前一快照。
- run-100 的 `100/15%/2 => --` 明确保留为 RED，后续必须由同类真实 IME 步骤转绿。
- 不修改纯计算舍入契约，不把 Local Test 通过写成设备缺陷已修复。

**需求追溯**：IR-004、IR-005、IR-008、IR-014 → AC-002、AC-004、AC-011

**Developer 验证**：Hypium unit；精确 oracle 为 `15.00/115.00/57.50` 与 `15.15/116.15/58.08`。

**Tester 验证请求**：保留 run-100 为 RED；修复后在真实 HarmonyOS 设备使用系统 IME 重放 AC-011。

**TDD**：[x] RED（run-100 设备证据复核） / [x] GREEN（快照 oracle） / [x] REFACTOR（独立快照保持）

### 阶段 2：单一源状态纠正

#### Task 2.1: 将 CalculatorPage 设为唯一小费输入所有者

**描述**：移除生产 UI 对可变 `TipSession` 输入镜像的依赖。由 CalculatorPage 的 `@State` 标量唯一持有账单、人数、预设比例、自定义模式、自定义文本和 touched 状态；TextInput 可见值与计算输入均绑定这些字段。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 参考契约：`opencalc/entry/src/main/ets/tip/TipCalculator.ets`

**依赖任务**：Task 1.1

**预计用时**：1–2 小时

**输入/输出**：输入 delta-design §3.2/§3.6.1 和当前镜像链；输出页面级唯一源状态。

**验收标准**：
- `CalculatorPage` 不再通过 `TipSession.change*()` 或从 `TipSession` 回写输入字段。
- 初值保持账单空、15%、1 人；未触碰空账单不报错，页面生命周期内关闭/重开保留输入。
- 不改变表达式、结果、历史、模式、Preferences 或路由状态。

**需求追溯**：IR-002、IR-003、IR-012、IR-014 → AC-001、AC-002、AC-004、AC-009、AC-011

**Developer 验证**：生产引用静态审查；确认 UI 输入只读写页面 `@State`，无 Tip→History/Preferences/router/CalcEngine 写路径。

**Tester 验证请求**：设备核对输入框可见文本、比例选中态与 UI 树来自同一交互状态。

**TDD**：[x] RED（生产引用检查命中第二状态源） / [x] GREEN（页面 @State 唯一所有） / [x] REFACTOR（显式事件快照）

#### Task 2.2: 实现不可变快照求值与原子派生提交

**描述**：建立统一重算路径：事件先更新页面源状态，再构造该事件后的完整不可变快照，调用 `TipCalculator.evaluate`，最后在同一处理路径提交三个字段错误及 tip/total/perPerson。非法输入时一次清为 `--`，不得混用上次派生值。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
- 纯逻辑（原则上保持算法不变）：`opencalc/entry/src/main/ets/tip/TipCalculator.ets`
- 测试：`opencalc/entry/src/test/TipCalculator.test.ets`

**依赖任务**：Task 2.1

**预计用时**：1–2 小时

**输入/输出**：输入 delta-design §3.5/§3.6.2/§3.6.4；输出单入口、同快照、全量覆盖派生字段的求值函数。

**验收标准**：
- 每次求值只使用本事件后的 bill/people/percent 快照，不读取普通类镜像或旧派生结果。
- 有效快照全量提交三项两位结果；无效快照全量提交字段错误和三个 `--`，校验先于除法。
- `TipCalculator` 继续按整数分值/basis point 计算，无必要不得改变公共算法契约。

**需求追溯**：IR-004、IR-005、IR-006、IR-007、IR-008、IR-009、IR-010、IR-011、IR-014 → AC-002～AC-008、AC-011

**Developer 验证**：Hypium unit + 代码审查；覆盖有效→非法→有效和 100→101，不出现 NaN/Infinity/部分旧结果。

**Tester 验证请求**：设备执行 AC-002～AC-008、AC-011，逐状态核对输入、错误和三结果。

**TDD**：[x] RED（run-100 可见值与派生值脱节） / [x] GREEN（单次快照求值/提交） / [x] REFACTOR（命名快照参数）

#### Task 2.3: 重接四类 ArkUI 事件到同一事务

**描述**：将账单 onChange、人数 onChange、四个预设 click 和自定义比例 onChange 全部接到“写源状态→快照求值→提交派生状态”事务。保证预设/自定义互斥、每个预设使用自身值且无计算按钮。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 2.2

**预计用时**：1–2 小时

**输入/输出**：输入 delta-design §3.6.3 与 AC-004；输出四类交互共享的求值事务。

**验收标准**：
- `200|10%|2`、`200|20%|2`、`200|20%|4`、`200|custom:12.5|4` 依次得到 `20.00/220.00/110.00`、`40.00/240.00/120.00`、`40.00/240.00/60.00`、`25.00/225.00/56.25`。
- 点击预设清除自定义错误并退出 custom；编辑自定义值立即进入 custom，且选择态唯一。
- 不存在 `syncTipState` 式普通对象镜像回写。

**需求追溯**：IR-002、IR-003、IR-004、IR-014 → AC-002、AC-003、AC-004、AC-008、AC-011

**Developer 验证**：事件处理代码审查 + 可执行状态/逻辑测试；逐一检查四个预设参数。

**Tester 验证请求**：真实系统 IME + 点击执行 AC-004 有序 UI/E2E，用同帧 UI 树留证。

**TDD**：[x] RED（四类 handler 仍走镜像链） / [x] GREEN（四类事件统一事务） / [x] REFACTOR（共享快照求值）

### 阶段 3：UI 契约与遗留状态清理

#### Task 3.1: 保持受控 TipPanel、稳定 ID 与兼容隔离

**描述**：复核并最小调整 TipPanel，使输入、错误、结果和选择态全部由 Task 2 的页面状态驱动，同时保持横竖屏入口、返回、主题、滚动布局和稳定 ID；不通过重做 UI 扩大范围。

**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 2.3

**预计用时**：1 小时

**输入/输出**：输入 delta-design §3.4/§3.6.5/§6～§8；输出保持外观和可达性、绑定单一源的 TipPanel。

**验收标准**：
- 保留账单、人数、自定义比例、四预设、三个结果、返回和错误的稳定 UI ID。
- 横竖屏入口及返回不回归；结果始终为两位或 `--`，错误有文本表达。
- 成功分摊并返回后，主表达式、结果、历史和现有模式不变，小费不新增历史。

**需求追溯**：IR-001～IR-004、IR-008～IR-012、IR-014 → AC-001～AC-009、AC-011

**Developer 验证**：构建/静态检查 + UI 绑定与依赖审查；不以此关闭设备 AC。

**Tester 验证请求**：横竖屏、错误/恢复、历史/模式前后相等及稳定 ID 的 UI/E2E。

**TDD**：[x] RED（run-100 UI 结果为 `--`） / [x] GREEN（受控 UI 绑定页面状态） / [x] REFACTOR（稳定 ID 契约分离）

#### Task 3.2: 清除 TipSession 生产状态职责并校正测试边界

**描述**：生产 UI 脱离后处理 `TipSession`：无消费者则删除；因兼容暂留时不得保存/回写页面输入或派生显示状态。同步删除会给出“普通类状态测试即可证明 ArkUI 同步”的误导性测试。

**涉及文件**：
- 候选删除/收缩：`opencalc/entry/src/main/ets/tip/TipSession.ets`
- 测试：`opencalc/entry/src/test/TipCalculator.test.ets`
- 测试注册（仅在需要时）：`opencalc/entry/src/test/List.test.ets`
- 生产引用：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**依赖任务**：Task 3.1

**预计用时**：1 小时

**输入/输出**：输入 delta-design §3.2 保留条件和全仓引用；输出无第二份可变 UI 状态源且测试层级准确。

**验收标准**：
- 全仓不存在生产 UI 对 `TipSession` 的实例化、`change*` 调用或 `syncTipState` 回写链。
- 单元测试只证明纯计算/静态契约，不宣称证明 ArkUI/IME state_sync。
- 删除或保留均不改变稳定 UI ID、TipCalculator API 或 feature-level AC。

**需求追溯**：IR-004、IR-013、IR-014 → AC-004、AC-010、AC-011

**Developer 验证**：全仓引用检查 + Hypium unit；在 Apply 报告记录删除/保留决策。

**Tester 验证请求**：继续以真实设备 UI/E2E 作为状态同步结论，不接受普通类 unit 代签。

**TDD**：[x] RED（全仓引用检查命中 TipSession） / [x] GREEN（生产/测试引用清零） / [x] REFACTOR（TipContract 只保留静态契约）

### 阶段 4：验证与独立交付

#### Task 4.1: 执行 Developer 门禁并形成可复现交付

**描述**：在后续 APPLYING 完成代码后执行 Local Test、entry 构建、CodeLinter 和 diff/依赖审查，记录命令、退出码、revision 与风险；不得在本 IMPLEMENTING 阶段执行。

**涉及文件**：
- 实现/测试：Tasks 1.1～3.2 涉及文件
- 后续报告：`specs/changes/20261024-bugfix-tip-calculator/apply-report.md`
- 后续 lint：`specs/changes/20261024-bugfix-tip-calculator/lint-result.json`

**依赖任务**：Task 3.2

**预计用时**：1 小时

**输入/输出**：输入完成的实现和仓库验证命令；输出绑定修复 revision 的 Developer 结果及 Tester 输入清单。

**验收标准**：
- Local Test 全通过、entry 构建成功、CodeLinter 0 error；既有 warning 与新增 finding 分开报告。
- diff 仅含授权实现/测试/阶段制品；无路由、权限、依赖、Preferences key 或历史写入扩张。
- UI/E2E/真实 IME 仍标待 Tester；不因 `ohosTest` target 缺失把未执行项记为通过。

**需求追溯**：IR-001～IR-014 → AC-001～AC-011

**Developer 验证**：unit / build / lint / diff review，记录真实结果。

**Tester 验证请求**：接收 exact-head HAP、SHA、稳定 ID、AC oracle 和 Developer 日志索引。

**TDD**：[x] RED（首次 Local Test 缺失 Hypium） / [x] GREEN（恢复依赖并全量通过） / [x] REFACTOR（重复执行完整门禁）

#### Task 4.2: 请求独立 Tester 完整设备复测与证据审计

**描述**：由独立 Tester 对修复后的 exact-head 构建执行 AC-001～AC-011。P0 主路径必须在真实设备用系统 IME 完成，并在同一证据点采集输入值、选中态和三结果；Developer 不代签。

**涉及文件**：
- 验收契约：`specs/changes/20261024-bugfix-tip-calculator/acceptance-criteria.json`
- 任务追溯：`specs/changes/20261024-bugfix-tip-calculator/tasks.md`
- Tester 报告与证据：由后续 Tester 工作流确定路径

**依赖任务**：Task 4.1

**预计用时**：1–2 小时（Tester 执行窗口）

**输入/输出**：输入 exact-head HAP、SHA 和 AC；输出逐 AC 的状态、环境、命令、截图/UI 树/hilog 与 revision 证据。

**验收标准**：
- AC-011 依次观察 `100|15%|2=>15.00|115.00|57.50`、`101|15%|2=>15.15|116.15|58.08`，不得用未触发用户事件的文本注入代替系统 IME。
- AC-003～AC-009 补齐 run-100 未完整执行项；AC-009 含成功分摊后的主状态、模式和历史前后相等。
- 每条 AC 含 status、expected、actual、environment、revision 和存在的证据路径；未执行/部分执行不得通过。

**需求追溯**：IR-001～IR-014 → AC-001～AC-011

**Developer 验证**：仅审计 AC ID 集合、revision 和路径完整性，不替代 Tester 判断。

**Tester 验证请求**：integration / ui / e2e / real-device IME / orientation / history isolation；机器权威 oracle 为 `acceptance-criteria.json`。

**TDD**：不适用（独立验收任务）

## 开发顺序

```text
Task 1.1 → Task 2.1 → Task 2.2 → Task 2.3 → Task 3.1 → Task 3.2 → Task 4.1 → Task 4.2 → 完成
```

## 依赖与关键路径

| 任务 | 前置 | 可并行项 | 关键路径原因 |
|---|---|---|---|
| Task 1.1 | 无 | Tester 可预备 AC-011 脚本但不执行候选构建 | 固化不能被 unit 弱化的 RED 与 oracle |
| Task 2.1 | 1.1 | 无 | 先确立唯一输入所有者 |
| Task 2.2 | 2.1 | 无 | 事件接线依赖统一求值事务 |
| Task 2.3 | 2.2 | 无 | 全部用户事件必须使用同一事务 |
| Task 3.1 | 2.3 | 无 | 受控 UI 依赖稳定状态/事件接口 |
| Task 3.2 | 3.1 | 无 | 生产脱离后才能清理遗留会话职责 |
| Task 4.1 | 3.2 | Tester 可完成用例设计 | 汇总 Developer 门禁并产出候选构建 |
| Task 4.2 | 4.1 | 无 | 真实设备 exact-head 证据是最终门禁 |

关键路径为八项顺序链。Tester 用例设计可提前，设备结论只能针对 Task 4.1 的 exact-head 构建。

## 验收计划

| 任务 | 验收方式 | 验收时点 |
|---|---|---|
| Task 1.1 | run-100 RED 审计 + Hypium exact oracle | 修改生产代码前 |
| Task 2.1 | 状态所有权/依赖静态审查 | 单一源建立时 |
| Task 2.2 | unit + 有效/非法/恢复快照审查 | 统一求值完成时 |
| Task 2.3 | 四步有序状态与预设参数审查 | 事件重接完成时 |
| Task 3.1 | build/lint + UI 绑定/兼容性审查 | 面板接入完成时 |
| Task 3.2 | 全仓引用 + unit + 测试层级审查 | 遗留清理完成时 |
| Task 4.1 | Local Test、build、lint、diff review | Developer 交付前 |
| Task 4.2 | 独立 Tester UI/E2E 与证据审计 | exact-head 构建交付后 |

## AC 覆盖自检

| AC | 实现/交付任务 | Developer 验证责任 | Tester 验证责任 | 结论 |
|---|---|---|---|---|
| AC-001 | 2.1, 3.1, 4.2 | 覆盖层/无路由审查 | 横竖屏进入、标题、返回 | 完整；需设备 |
| AC-002 | 1.1, 2.1～2.3, 3.1, 4.2 | exact unit + 同源审查 | 系统 IME 的精确 UI | 完整；P0 |
| AC-003 | 2.2～2.3, 3.1, 4.2 | exact unit | 88.80/10%/3 精确 UI | 完整 |
| AC-004 | 1.1, 2.1～2.3, 4.2 | 有序快照/handler 审查 | 四步同帧 UI/E2E | 完整；需 IME |
| AC-005 | 2.2～2.3, 3.1, 4.2 | 0%/舍入 unit | 0% 选中态和两位 UI | 完整 |
| AC-006 | 2.2～2.3, 3.1, 4.2 | 账单错误/全 `--`/恢复 unit | 完整非法表与恢复 UI | 完整 |
| AC-007 | 2.2～2.3, 3.1, 4.2 | 人数校验先于除法 unit | 无 Infinity/NaN 与恢复 UI | 完整 |
| AC-008 | 2.2～2.3, 3.1, 4.2 | 比例边界/互斥 unit | 边界、拒绝、预设恢复 UI | 完整 |
| AC-009 | 2.1, 3.1, 4.1～4.2 | 无写路径/既有回归 | 成功分摊前后主状态/历史/模式相等 | 完整；需设备 |
| AC-010 | 1.1, 3.2, 4.1～4.2 | 提供 SHA、日志、AC 清单 | 独立执行与证据语义 | 完整；Tester 所有 |
| AC-011 | 1.1, 2.1～2.3, 3.2, 4.2 | 保留 RED、同源实现和 exact oracle | 真机 IME 的 100→101 同帧证据 | 完整；最终 P0 门禁 |

自检结论：IR-001～IR-014 均由至少一个任务追溯；AC-001～AC-011 的 unit、integration、ui、e2e 和环境责任均已接收；没有用 unit/build 关闭 UI/E2E，也没有新增或弱化 Planning AC。
