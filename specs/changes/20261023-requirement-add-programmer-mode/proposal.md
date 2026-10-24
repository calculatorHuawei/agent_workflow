# 程序员模式与四进制转换需求提案

## 1. 需求概述

### 1.1 基本信息
- **功能名称**：程序员模式与 BIN/OCT/DEC/HEX 转换
- **需求类型**：新增功能
- **关联 Issue**：#45（历史 Issue：#4、#12、#22，均已关闭）
- **关联全局文件**：specs/spec.md / specs/arch.md / specs/design.md

### 1.2 需求描述
在 OpenCalc 现有普通/科学计算界面之外增加独立程序员模式。用户可在 BIN（2）、OCT（8）、DEC（10）、HEX（16）中选择输入进制，通过受约束键盘输入一个非负整数，并同步查看四种进制表示。模式切换采用轻量动画，普通计算器表达式、结果和历史记录不被重置。

### 1.3 使用场景
程序员或计算机专业学生需要快速核对整数的二、八、十、十六进制表示；使用结束后返回普通计算器继续原有计算，不需要重新输入此前表达式或恢复历史。

### 1.4 预期效果
- DEC `10` 同步显示 BIN `1010`、OCT `12`、DEC `10`、HEX `A`。
- HEX `FF` 同步显示 DEC `255`。
- 当前输入进制不支持的键被禁用，业务入口仍进行防御性校验。
- 空输入、非法输入、超过无符号 64 位范围均显示明确、可恢复的反馈。
- 普通模式与程序员模式的内存态相互隔离，双向切换无崩溃、错算、闪烁或历史丢失。

### 1.5 背景与价值

#### 问题背景
当前应用提供基础/科学计算、历史记录和函数绘图，但没有面向计算机学习与开发场景的精确整数进制转换能力。现有 `CalcEngine` 与 `NumberFormatter` 以浮点 `number` 为核心，不适合直接承诺 64 位整数精确转换。

#### 需求价值
减少用户在不同工具间切换或手工换算的成本，并让 OpenCalc 覆盖常见编程学习场景。

#### 核心问题
缺少独立程序员模式、按输入进制约束字符的交互、精确四进制同步转换，以及异常输入的稳定反馈。

#### 不做什么（边界）
本期不做位运算、程序员模式算术表达式、浮点进制转换、有符号数/补码、字长切换、进制前缀输入、分组显示、程序员转换历史，也不改变普通计算器历史结构。

## 2. 竞品/参考方案分析

本需求范围和验收标准已明确，按最小权限与最小范围原则未执行可选外部竞品调研。采用通行的“切换进制保持数值语义、重新格式化当前输入”交互，但不引入竞品特有能力。

## 3. 需求解析报告

### 3.1 意图分类
- **类型**：新增功能
- **一句话概括**：为 OpenCalc 增加与普通计算器相互切换的四进制非负整数转换模式。
- **分类依据**：Issue 标题使用“新增”，正文要求当前产品不存在的独立模式。当前 orchestrator 的 `change_type=bugfix` 描述 Reviewer 反馈触发的流程补正，不改变产品意图分类。

### 3.2 领域映射
- **UI/交互**：模式入口、进制选择器、按进制启停的键盘、四行结果区、动画和错误反馈。
- **业务逻辑**：字符合法性校验、无符号 64 位范围校验、精确整数转换和大写格式化。
- **状态管理**：应用模式、输入进制、程序员草稿、转换结果和错误状态；普通计算状态保持原有职责。
- **可靠性**：错误输入不污染最后有效状态，快速切换不重入，超范围不发生截断或舍入。

### 3.3 影响层次
| 层次 | 变更类型 | 说明 |
|------|---------|------|
| 表现层 | modify/new | `CalculatorPage` 增加模式入口和程序员面板构件 |
| 业务层 | new | 新增独立 `ProgrammerConverter`，不接入浮点表达式解析链 |
| 数据层 | extend | 新增页面内模式/进制/草稿状态；不新增持久化数据 |
| 基础设施 | 无 | 不新增权限、网络、后台任务、外部依赖或 Kit |

### 3.4 关键实体
- **数据实体**：`CalculatorMode`、`Radix`、`ProgrammerState`、`ConversionResult`、`ProgrammerError`。
- **页面实体**：模式切换入口、进制选择器、结果列表、程序员键盘、内联反馈。
- **接口实体**：`appendDigit`、`removeLast`、`clear`、`changeRadix`、`convert`。
- **事件实体**：模式切换、进制切换、字符输入、退格、清空、转换结果更新。

### 3.5 模糊点
| # | 类别 | 描述 | 严重程度 | 处理结果 |
|---|------|------|---------|---------|
| 1 | 约束 | 支持范围、符号与负数表示未定义 | important | 采用无符号 64 位 `[0, 2^64-1]`；见 §4 |
| 2 | 状态 | 模式切换时是否保留两侧草稿未定义 | important | 两模式内存态分别保留；见 §4 |
| 3 | 行为 | 切换输入进制是重解释文本还是保持数值 | important | 保持数值并改写为目标进制文本；见 §4 |
| 4 | 范围 | 历史草案含位运算，而当前 Issue 未要求 | nice-to-have | 以当前 Issue 为准，明确排除 |

### 3.6 复杂度评估
- **等级**：M（中等）
- **理由**：涉及页面、状态模型、独立转换服务和测试四个关注点；不增加外部依赖或持久化迁移，但需保证 64 位精度和现有普通模式回归。

## 4. 需求澄清

### 4.1 已澄清的关键决策
| # | 问题 | 决策 | 来源 |
|---|------|------|------|
| 1 | 整数范围 | 仅支持无符号 64 位整数：`0` 至 `18446744073709551615` | 自动澄清：最小范围且与“程序员模式/超范围反馈”一致；BigInt 在当前 SDK 类型中可用 |
| 2 | 负数规则 | 不支持负号、补码或有符号解释 | 自动澄清：避免在未提供字长规则时产生歧义 |
| 3 | 模式状态 | 普通模式和程序员模式分别保留内存态；切回普通模式恢复原表达式/结果，历史数组不变 | Issue 的“界面状态稳定/无关历史不丢失”与向后兼容要求 |
| 4 | 进制切换 | 有有效输入时保持数值语义，并把输入草稿转换为目标进制；空输入保持空 | 自动澄清：符合常规进制转换器行为且可逆 |
| 5 | 默认状态 | 首次进入程序员模式默认为 DEC、空输入 | 自动澄清：十进制最熟悉，且不凭空制造业务值 |
| 6 | 字母与前缀 | HEX 仅显示/录入大写 `A-F`；不接受 `0x/0b/0o` 前缀 | 自动澄清：收窄输入语法、降低误解与解析风险 |
| 7 | 动画 | 180ms ease-in-out 的内容淡入/轻微位移；状态先更新再呈现，不依赖动画完成回调 | 自动澄清：轻量、可逆、无外部依赖 |

### 4.2 待定假设
- 精确转换实现不得经浮点 `number` 中转。规划默认采用仓库已验证、无 SDK 语法依赖的十进制字符串乘加/长除算法；如后续等价替换为 `bigint`，必须保持接口与 U64 边界测试不变。
- 程序员草稿只在当前页面生命周期内保留，不跨应用重启持久化；Issue 未要求持久化，避免新增设置和迁移。
- 空输入显示四行占位符和“请输入数值”，属于中性引导；只有非法或超范围状态使用错误色。
- 横竖屏沿用单页面响应式布局；不新增路由页，减少旋转时的状态重建风险。

### 4.3 功能边界
- **包含**：普通/程序员模式双向切换；BIN/OCT/DEC/HEX 输入与结果；合法键约束；同步转换；空/非法/超范围反馈；轻量动画；普通表达式、结果、历史和程序员草稿稳定保留；单元/状态/布局回归测试。
- **不包含**：位运算、算术表达式、负数/补码、位宽选择、浮点数、前缀、持久化程序员草稿、程序员转换历史、复制/粘贴增强、外部键盘专项适配。

## 5. 特性清单

- **F1：模式切换与状态隔离**
  - 功能描述：普通/程序员模式可双向切换，使用轻量动画并保留各自页面内状态。
  - 用户价值：在两类任务间连续工作，不丢失上下文。
  - 技术要点：单一 `CalculatorMode` 状态控制显示；不清空 `expression/result/history`；动画不承担业务提交。
- **F2：按进制受限输入**
  - 功能描述：选择 BIN/OCT/DEC/HEX 后，仅对应合法数字键可用；业务层再次校验。
  - 用户价值：在输入源头避免错值。
  - 技术要点：UI 禁用 + converter 防御性验证双层约束。
- **F3：精确同步转换**
  - 功能描述：输入变化后同步展示四种大写、无前缀表示；进制切换保持数值。
  - 用户价值：一眼对照四种表示。
  - 技术要点：无符号 64 位精确整数路径，不复用浮点 `CalcEngine`。
- **F4：明确错误与恢复**
  - 功能描述：空、非法、超范围分别给出可辨识反馈，退格/清空后可恢复。
  - 用户价值：用户知道为何没有结果以及如何继续。
  - 技术要点：结构化错误枚举；失败不产生部分或舍入结果。
- **F5：兼容与验证**
  - 功能描述：不改变普通/科学/绘图/历史行为，覆盖边界、非法输入和快速切换测试。
  - 用户价值：新增能力不破坏已有工作流。

## 6. 系统架构概述

### 6.1 概念架构图
```text
用户输入
   │
   ▼
CalculatorPage（模式状态、普通状态、程序员状态、动画）
   ├── 普通模式 ──> Expression / CalcEngine / NumberFormatter
   │                         └──> PreferencesStore（既有历史）
   └── 程序员模式 ──> ProgrammerConverter（校验/解析/范围/格式化）
                              └──> ConversionResult（BIN/OCT/DEC/HEX）
```

### 6.2 核心模块职责
| 模块 | 职责 | 备注 |
|------|------|------|
| `CalculatorPage` | 路由交互事件、维护两模式页面状态、渲染动画与反馈 | 修改 |
| `ProgrammerConverter` | 纯函数式校验、64 位范围判断、四进制格式化 | 新增 |
| `Models` | 提供模式、进制、结果和错误类型 | 扩展 |
| `CalcEngine`/`Expression` | 继续处理普通/科学计算 | 复用且不修改转换语义 |
| `PreferencesStore` | 继续保存普通历史和偏好 | 复用，不新增 key |

### 6.3 模块交互简述
页面把当前进制与字符事件交给 converter；converter 返回完整结果或结构化错误；页面原子更新程序员状态。普通模式数据流保持不变，模式切换只改变可见分支。

### 6.4 明确不涉及的模块
不新增 HAP/HAR/HSP，不更改 `EntryAbility`、权限、网络、数据库、Preferences schema、普通表达式语法和函数绘图算法。

## 7. 需求规格

- **R1：模式双向切换**（P0，关联 F1/F5）
  - AC1：普通→程序员→普通后，原普通表达式、结果和历史数量/内容不变。
  - AC2：切换采用 180ms 轻量动画，无明显空白帧或重复触发导致的错态。
- **R2：四进制合法输入**（P0，关联 F2）
  - AC1：BIN 禁用 `2-9/A-F`，OCT 禁用 `8-9/A-F`，DEC 禁用 `A-F`，HEX 开放 `0-9/A-F`。
  - AC2：任何绕过 UI 到达业务层的非法字符返回 `INVALID_DIGIT`，不改变最后有效输入。
- **R3：同步精确转换**（P0，关联 F3）
  - AC1：DEC `10` → BIN `1010`、OCT `12`、DEC `10`、HEX `A`。
  - AC2：HEX `FF` → DEC `255`；HEX 字母统一大写且所有输出无前缀/前导零（值 `0` 除外）。
  - AC3：切换输入进制保持数值，例如 DEC `10` 切到 BIN 后输入显示 `1010`。
- **R4：范围与反馈**（P0，关联 F4）
  - AC1：`0` 和 `18446744073709551615` 成功转换且精确。
  - AC2：`18446744073709551616` 返回 `OUT_OF_RANGE`，不显示截断、舍入或部分结果。
  - AC3：空输入显示“请输入数值”和结果占位符；退格/清空后可从错误态恢复。
- **R5：兼容与测试**（P0，关联 F5）
  - AC1：普通/科学计算、历史读取删除、绘图入口和主题状态不因模式切换改变。
  - AC2：单测覆盖四进制典型值、0/最大值/越界、非法字符、前导零规范化和模式/进制切换状态。

## 8. 影响范围分析

### 8.1 涉及的模块
| 模块 | 现有功能 | 新增/修改 |
|------|---------|-----------|
| `entry/src/main/ets/pages/CalculatorPage.ets` | 普通/科学 UI、历史、设置、绘图 | 增加应用模式状态与程序员面板 |
| `entry/src/main/ets/model/Models.ets` | 错误、偏好、历史模型 | 增加程序员模式类型；不改既有字段 |
| `entry/src/main/ets/programmer/ProgrammerConverter.ets` | 不存在 | 新增纯业务转换组件 |
| `entry/src/test/ProgrammerConverter.test.ets` | 不存在 | 新增核心边界与校验测试 |
| `entry/src/test/List.test.ets` | Hypium 测试聚合入口 | 注册新测试套件（按既有约定） |

### 8.2 代码依赖分析
`CalculatorPage → ProgrammerConverter → Models` 为新增单向依赖；converter 不依赖 ArkUI、Preferences 或 `CalcEngine`，可在本地 Hypium 中测试。普通链路 `CalculatorPage → Expression/CalcEngine/NumberFormatter` 与历史存储链路保持兼容。

## 9. 复杂度评估

### 9.1 评估结果
- **复杂度等级**：复杂（工作量等级 M）
- **影响模块数**：4 个关注模块（页面、模型、转换器、测试）
- **架构变更**：是（entry HAP 内新增独立业务组件和数据流，不改变部署架构）
- **数据模型变更**：是（新增内存态类型；无持久化迁移）

### 9.2 跳过策略
| 制品 | 是否产出 |
|------|---------|
| proposal.md | 必须，产出 |
| delta-spec.md | 必须，产出 |
| info.md | 必须，产出 |
| new-arch.md | 复杂需求且新增业务组件，产出 |
| delta-design.md | 必须，产出 |
| tasks.md | 本次复核明确禁止创建或修改；保留精确 PR HEAD 中的既有文件 |

## 10. 待解决问题

### 10.1 已定决策
无符号 64 位、无负数/前缀、两模式分别保留页面内状态、进制切换保持数值、DEC 空草稿为初始状态、独立 converter、180ms 轻量动画。

### 10.2 待解决问题
无阻塞项。精度策略已经收敛为实现无关的“不得经浮点 `number` 中转”，当前仓库的精确字符串算法是最安全、已验证且不扩权限的默认实现。

---
> 本提案中的自动澄清均依据 Issue 授权，选择安全、可逆、最小范围且向后兼容的默认值。

## 11. 2026-10-24 PLANNING 复核记录

- **初始化确认**：复用有效的 `specs/initialized.flag`；`PROJECT_ROOT=opencalc`、`CHANGES_ROOT=specs/changes`、`TEST_ROOT=opencalc/entry/src/test` 均存在。本次不重新初始化、不改初始化配置。
- **意图分类确认**：Issue #45 的产品意图仍为“新增功能”；orchestrator 的 `change_type=bugfix` 仅描述本次因 Reviewer 过程证据缺失而进行的流程补正，不改变产品范围，也不迁移既有 change 目录。
- **澄清方式**：Issue、既有验收证据和授权足以消除 important 级歧义；按 `rq-clarify` 的“用户授权代理决定”路径保留 U64、页面内状态、数值保持换进制、无位运算等安全默认，无需人工确认。
- **范围结论**：本次仅重新执行并留痕 PLANNING；既有 `tasks.md`、产品实现与测试属于已存在的精确 PR HEAD，本次不创建或修改它们，不进入 IMPLEMENTING/APPLYING/ARCHIVING。
- **复核结果**：原提案的功能边界、假设和 rationale 仍与 Issue 及当前代码约定一致，无需扩大权限、依赖或持久化范围。

## 12. Task 33 PLANNING 证据补正记录

- **执行上下文**：在独立分支 `agent/pull_request-49-task-33`、精确基线 HEAD `17b7145dcbbc418580d2370008dba6c2f5b6d19c` 上重新执行 PLANNING；该 HEAD 已包含先前实现，本次仅把它作为代码仓现状与设计一致性输入。
- **顺序与边界**：依次完成初始化/意图确认、`rq-parse`、授权式 `rq-clarify`、spec/场景/追溯、`rq-codebase`、复杂度、架构、`mod-design` 和设计审视；未进入 IMPLEMENTING/APPLYING/ARCHIVING。
- **安全默认**：继续采用 U64 非负、无前缀/补码/位运算、页面内状态隔离、数值保持换进制、180ms/4vp 轻量过渡和无新增权限/依赖/持久化；这些选择均可逆、局部且向后兼容。

## 13. Task 39 PLANNING 独立复核

- **初始化确认**：复用有效的 `specs/initialized.flag`。`PROJECT_ROOT=opencalc`、`CHANGES_ROOT=specs/changes`、`TEST_ROOT=opencalc/entry/src/test` 及全局 spec/arch/design 均存在；按 init 的已初始化路径只复核 Git 与会话，不重写初始化标记或 README。
- **Git 确认**：当前为非 main/master 的独立分支 `agent/pull_request-49-task-39`，规划输入基线 HEAD 为 `9b3629c473317b22781ad3cb415b2dcc7346a86c`。既有产品实现只作为 `rq-codebase` 的只读现状，不授权源代码修改。
- **意图分类**：Issue #45 的产品意图是“新增功能”；payload 的 `change_type=bugfix` 与 `run_reason=reviewer_feedback` 仅描述证据补正原因，不改变功能分类、目录名或产品范围。
- **rq-parse 结果**：领域为 UI/交互、精确整数业务逻辑、页面状态和可靠性；影响表现层、业务层及内存态模型，不涉及网络、权限、后台或持久化迁移。原始要求稳定归一为 IR-45-R1~R5。
- **rq-clarify 结果**：U64 范围、页面内双状态、数值保持换进制、大写无前缀、180ms/4vp 过渡均属安全、可逆且 Issue 内的普通歧义，依据 assignment 自主采用并在 `acceptance-criteria.json.assumptions` 记录理由；无须人工确认。
- **AC 门禁补正**：新增 `acceptance-criteria.json`，定义 5 条原始 IR、10 条 feature-level AC 及逐 IR 七维覆盖；相同 AC 编号和语义已镜像到 `delta-spec.md` §7/§8/§10/§11。
- **范围与兼容性**：继续排除位运算、负数/补码、浮点、多字长、持久化和新增权限/依赖；普通计算、历史、设置和绘图保持向后兼容。
- **阶段边界**：Task 39 只执行 PLANNING，不创建或修改 `tasks.md`，不修改产品源码，不实施、测试产品、提交、推送、审批或归档。

## 14. Task 42 PLANNING 过程证据补正

- **初始化确认**：复用有效的 `specs/initialized.flag`；`PROJECT_ROOT=opencalc`、`CHANGES_ROOT=specs/changes`、`TEST_ROOT=opencalc/entry/src/test` 及全局 spec/arch/design 均存在。按已初始化路径仅复核 Git 与会话，不重写初始化标记或产品 README。
- **Git 与基线**：当前分支为独立非主分支 `agent/pull_request-49-task-42`，只读规划基线为 PR #49 精确 HEAD `49054a10f21f83f1f46a538df6d097dd32f87681`。
- **意图分类**：Issue #45 仍是“新增功能”；orchestrator 的 `change_type=bugfix`、`run_reason=reviewer_feedback` 只描述“补齐可认证 PLANNING/IMPLEMENTING 阶段证据”的流程修复，不改变产品需求、change 目录或验收范围。
- **rq-parse / rq-clarify 结论**：IR-45-R1~R5、UI/交互、精确整数业务、页面状态及可靠性范围保持不变。U64、页面内状态隔离、数值保持换进制、大写无前缀、180ms/4vp 过渡等均是安全、可逆、局部且向后兼容的默认值，已在 `acceptance-criteria.json.assumptions` 记录 rationale，无需人工确认。
- **范围约束**：本次只重新执行 PLANNING 并刷新规划制品；既有实现和测试仅作为 `rq-codebase` 的只读现状。未创建或修改 `tasks.md`，未修改产品/测试源码，未运行 IMPLEMENTING/APPLYING/ARCHIVING，未提交、推送、审批或归档。

## 15. Task 45 PLANNING 独立执行记录

- **初始化确认**：复用有效的 `specs/initialized.flag`；`PROJECT_ROOT=opencalc`、`CHANGES_ROOT=specs/changes`、`TEST_ROOT=opencalc/entry/src/test` 以及全局 spec/arch/design 均存在。按已初始化恢复路径仅检查 Git 与现有会话，不重写初始化标记或 README。
- **Git 确认**：当前为独立非主分支 `agent/pull_request-49-task-45`，只读规划基线为 PR #49 精确 HEAD `aeb8f4e8a60bda04651c9c69af034cac28606d17`。
- **意图分类**：Issue #45 的产品意图为“新增功能”；payload 中 `change_type=bugfix` 与 `run_reason=reviewer_feedback` 描述的是补齐可认证阶段证据的流程修复，不改变产品需求、既有 change 目录或验收边界。
- **rq-parse 结果**：需求稳定归一为 IR-45-R1~R5，领域覆盖 UI/交互、精确整数转换、ArkUI 页面状态与可靠性；影响表现层、业务层和内存态模型，不涉及网络、后台、隐私、权限或持久化迁移。
- **rq-clarify 结果**：U64 非负范围、页面内状态隔离、换进制保持数值、大写无前缀、180ms/4vp 轻量过渡均属于 Issue 内安全、可逆、常规且向后兼容的默认值。依据 assignment 的自治授权直接采用，并继续以 `acceptance-criteria.json.assumptions` 记录决策与 rationale，无需人工确认。
- **阶段边界**：Task 45 仅执行 PLANNING。既有实现与测试只作为 `rq-codebase` 的只读仓库现状；不创建或修改 `tasks.md`，不修改产品/测试源码，不进入 IMPLEMENTING/APPLYING/ARCHIVING，不提交、推送、审批或归档。

## 16. Task 48 PLANNING 独立执行记录

- **初始化确认**：复用有效的 `specs/initialized.flag`；`PROJECT_ROOT=opencalc`、`CHANGES_ROOT=specs/changes`、`TEST_ROOT=opencalc/entry/src/test` 及全局 spec/arch/design 均存在。按 worker entry gate 不重跑初始化、不改标记或 README。
- **Git 与输入基线**：当前分支为独立非主分支 `agent/pull_request-49-task-48`，只读规划基线是 assigned PR #49 HEAD `4224f027f05b93a4900c68c31700897c07dcfafe`；工作树进入本阶段时无未提交变更。
- **意图分类（rq-parse）**：Issue #45 的产品意图继续判定为“新增功能”；payload 的 `change_type=bugfix` 与 `run_reason=reviewer_feedback` 只表示修复缺失的可认证阶段证据，不改变功能范围、change 目录、IR 或 AC。
- **授权式澄清（rq-clarify）**：U64 非负范围、页面内双状态、换进制保持数值、大写无前缀、180ms/4vp 轻量过渡均为 Issue 内安全、可逆、常规且向后兼容的默认。依据 assignment 授权自主确认，继续以 `acceptance-criteria.json.assumptions` 保存决策与 rationale。
- **范围与权限**：保持单 entry HAP、ArkUI V1、纯本地精确字符串转换；不新增权限、网络、后台、第三方服务、依赖、持久化或路由。既有实现仅供代码仓理解，不反向扩大需求。
- **阶段边界**：Task 48 只执行 PLANNING。既有 `tasks.md`、产品/测试源码、构建配置与 APPLYING 证据均不修改；不执行 IMPLEMENTING/APPLYING/ARCHIVING，不提交、推送、审批或归档。

## 17. Task 54 PLANNING 独立执行记录

- **初始化确认**：复用有效的 `specs/initialized.flag`；已验证 `PROJECT_ROOT=opencalc`、`CHANGES_ROOT=specs/changes`、`TEST_ROOT=opencalc/entry/src/test` 及全局 spec/arch/design 均存在。按初始化 skill 的已初始化路径，仅复核 Git 与会话恢复状态，不重写初始化标记或 README。
- **Git 与原始需求**：当前为独立非主分支 `agent/pull_request-49-task-54`，只读规划基线为 PR #49 HEAD `091c3a46e21c127d41b82cbf388e4e7b7acb800f`。通过 `gh issue view 45 --comments` 直接复核 Issue 原文；Issue 无补充评论，因此 payload 与 GitHub 原文不存在需求冲突。
- **意图分类（rq-parse）**：产品意图仍为“新增功能”，稳定映射到 IR-45-R1~R5；orchestrator 的 `change_type=bugfix`、`run_reason=reviewer_feedback` 仅描述补齐可认证 PLANNING 过程证据的流程修复，不改变 change 目录、产品范围或验收语义。
- **授权式澄清（rq-clarify）**：U64 非负范围、页面内双状态、换进制保持数值、HEX 大写且不接受前缀、180ms/4vp 轻量过渡均为安全、可逆、Issue 内且向后兼容的默认值；依据 assignment 授权自主采用，并由 `acceptance-criteria.json.assumptions` 保存每项 rationale。
- **最小范围**：保持单 `entry` HAP、ArkUI V1 `@State`、纯本地精确字符串转换；不新增权限、网络、后台、第三方服务、依赖、路由、持久化或迁移。现有实现仅作为 `rq-codebase` 的只读事实输入，不反向扩大需求。
- **阶段边界**：Task 54 仅执行 PLANNING；不创建或修改 `tasks.md`，不修改产品/测试源码，不执行 IMPLEMENTING/APPLYING/ARCHIVING，不提交、推送、审批或归档。
