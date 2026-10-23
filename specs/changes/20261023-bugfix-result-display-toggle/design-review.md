# 设计审视报告

> 变更目录：`specs/changes/20261023-bugfix-result-display-toggle/`  
> 关联 Issue：#44（历史 #27）  
> 审视日期：2026-10-23
> 本次审视范围：Tester run-59 feedback replan；产品行为已通过，仅审视 canonical UI 用例持久化增量。

## 1. 完整性评估

### 1.1 制品齐全性
- [x] `proposal.md`：需求提案、rq-parse 结果与澄清结论
- [x] `delta-spec.md`：完整 §1–§13、STAGE、Given-When-Then、SR 追溯
- [x] `info.md`：rq-codebase 代码仓理解
- [x] `delta-design.md`：mod-design D1–D10 增量设计与自验证
- [x] `design-review.md`：本报告
- [x] `todo.md`：PLANNING 子步骤状态
- [x] `new-arch.md`：不适用；无模块边界、部署、外部依赖或主数据流变化
- [x] `tasks.md`：目录中已有上一轮 IMPLEMENTING 制品；本次 PLANNING 未创建、删除或修改

**制品齐全性：通过。**

### 1.2 需求覆盖度
| Issue #44 要求 | proposal | delta-spec | delta-design | 覆盖 |
|----------------|----------|------------|--------------|------|
| 结果区域切换入口 | §1/§5 | SR-01 | §3.7/§8 | ✅ |
| `1÷2`：`0.5 ↔ 1/2` | §1.4/R1 | SC001-UC001 | §3.8 | ✅ |
| `1÷3`：小数 ↔ `1/3` | §4.1/R1 | SC001-UC002/SR-00 | §3.5/§3.8 | ✅ |
| `2÷4` 约分为 `1/2` | R1 | SC001-UC002 | §3.8 | ✅ |
| 负数符号 | R1 | SC001-UC003 | §3.5/§3.8 | ✅ |
| 整数不显示 `/1` | §1.4/R1 | SC001-UC003 | §3.5 | ✅ |
| 切换保持算式/结果/历史一致 | F2/R2 | SC003-UC001/SR-01 | §3.7 | ✅ |
| 不可靠转换合理降级 | F3/R3 | SC002-UC001 | §3.5/§3.6 | ✅ |
| 自动化测试 | R4 | SR-02 | §3.8 | ✅ |
| canonical UI 套件来源 | F4/R5 | SC004-UC001/SR-03 | §3.9/§4.8/§9.1 | ✅ |

**需求覆盖度：100%。**

## 2. 一致性评估

### 2.1 proposal → delta-spec
- [x] 工作流意图统一为 `bugfix`，并保留 Issue 标题 `feat` 的产品语义说明。
- [x] 功能边界一致：只切换当前结果，不做分数输入、历史重格式化或偏好持久化。
- [x] 历史 #27 的关键反例一致：旧测试把 `1/3` 期望为 `null`，新规格必须修复。
- [x] R1–R4 均分解到 SR-00–SR-02 与用例。
- [x] Tester run-59 唯一失败门禁已分解为 R5/F4、SC004-UC001 与 SR-03；未重开已通过的产品要求。

**proposal → delta-spec：通过。**

### 2.2 delta-spec → delta-design
| SR | 设计分配 | 接口/状态 | 测试 | 结论 |
|----|----------|-----------|------|------|
| SR-00 | `FractionUtil` | `toFraction/gcd/format` | `FractionUtil.test.ets` | 通过 |
| SR-01 | `ResultDisplayPresenter` + `CalculatorPage` | mode/raw/decimal/hasResult | presenter + 后续 UI | 通过 |
| SR-02 | 测试模块 | `List.test.ets` 注册 | 核心与交互矩阵 | 通过 |
| SR-03 | canonical UI 测试资产 | version-1 JSON / 既有 `load_cases()` | 解析、唯一 ID、五类覆盖与来源复验 | 通过 |

- [x] 最大分母、误差门禁和迭代上限在 spec 与 design 一致。
- [x] `null → decimalText` 降级契约一致。
- [x] 新计算回到 DECIMAL、AC/错误清理、切换零历史写入的状态规则一致。
- [x] History schema、Preferences、CalcEngine 和 NumberFormatter 均保持兼容。

**delta-spec → delta-design：通过。**

### 2.3 内部自洽性
- [x] `1/3` 由连分数识别，不再使用历史十进制定标算法。
- [x] π/√2 等候选仍需严格误差门禁，避免“最大分母”被误解为无条件近似。
- [x] 小数模式和降级复用同一 `decimalText`，保证现有精度策略不漂移。
- [x] 复制当前可见文本，但不覆盖历史小数快照。
- [x] 所有 Markdown 代码围栏成对闭合。
- [x] canonical 文件与 evidence 分工明确：前者保存测试意图，后者保存设备/HEAD/截图/日志。

**内部自洽性：通过。**

## 3. 规范性评估

### 3.1 格式规范
- [x] proposal 使用 1–10 章模板结构。
- [x] delta-spec 保留 1–13 章结构，包含 3 个场景、5 个完整 UC、STAGE 与 Given-When-Then。
- [x] delta-design 覆盖 D1–D10，并附追溯与自验证。
- [x] info.md 使用 rq-codebase 1–10 章结构。
- [x] todo.md 与规划步骤标签一致。

### 3.2 命名规范
- [x] 变更目录符合 `YYYYMMDD-bugfix-name`。
- [x] IR/SR/SC/UC 编号唯一且追溯关系明确。
- [x] ArkTS 标识符使用英文 PascalCase/camelCase。

### 3.3 范围门禁
- [x] 未修改 `opencalc/` 产品源码。
- [x] 未创建或修改 `tasks.md`、测试代码、canonical JSON 或应用报告；这些既有文件保持原状。
- [x] 未 commit、push 或 archive。
- [x] 未运行实现/测试阶段命令。

**规范性：通过。**

## 4. 关键设计决策
| 决策 | 依据 | 影响 |
|------|------|------|
| 使用 raw number，而非从 `result` 字符串反解析 | 当前 result 已格式化且同时作为历史快照 | 避免分组符和精度丢失 |
| 使用有界连分数 + 误差门禁 | `1/3` AC 与旧算法冲突 | 支持循环小数，同时拒绝粗糙近似 |
| 模式为会话内状态，不持久化 | Issue 未要求 | 不改 Preferences schema |
| 新计算重置为小数 | 确保每个新结果先遵循现有显示策略 | 行为确定、便于验收 |
| 历史始终保留计算时小数快照 | “结果区域”范围与历史一致性 AC | 切换无持久副作用 |
| 横竖屏均提供入口 | 功能范围未排除横屏 | 避免历史方案横屏隐藏造成能力缺失 |
| canonical 用例采用 run-59 已执行套件 | Tester 已完成真实模拟器验证 | 最小化反馈修复，避免新增未经执行的产品场景 |
| 文件名采用 `result_display_toggle.json` | 现有 `function_plot.json` 使用蛇形命名 | 保持编排器目录约定；suite ID 保持 kebab-case |
| 不修改 `load_cases()` | 现有 version-1 契约已能解析目标内容 | 保持向后兼容与最小权限 |

## 5. 风险与遗留问题

### 5.1 已闭环风险
| 风险 | 设计闭环 |
|------|----------|
| 浮点噪声导致巨大分母 | 连分数 + 最大分母 + 误差门禁 |
| `1/3` 被错误降级 | 明确 AC 和回归测试 |
| 无理数被显示为“精确”分数 | 严格误差门禁，失败返回 null |
| 切换污染历史 | 切换路径无求值、无 `setHistory`，测试状态不变量 |
| 错误后复用陈旧 raw | ERROR/AC 清理 hasResult/raw/mode |
| UI 覆盖结果文本 | 预留间距、≥32vp 触控目标、双方向验证 |
| 临时 evidence 套件不被视为 canonical | 新增 SR-03，固定 `orchestrator/ui_cases/result_display_toggle.json` 并要求 loader 解析/来源复验 |

### 5.2 遗留问题
无 PLANNING blocker/important 遗留问题。共享编排器路径存在，新增单个静态 JSON 可逆且不需要凭据、付费服务、隐私/合规决策或产品范围扩张。以下仍为范围外未来项：分数输入、混合分数、历史条目跟随模式、跨启动记忆。

## 6. 审视结论
| 维度 | 结果 |
|------|------|
| 完整性 | ✅ 通过 |
| 一致性 | ✅ 通过 |
| 规范性 | ✅ 通过 |
| 可实施性 | ✅ 通过 |
| 范围门禁 | ✅ 通过 |

**PLANNING 阶段结论：通过。反馈增量已完整映射到 R5/SC004/SR-03 与 §3.9；本次停在 PLANNING，不进入 IMPLEMENTING/APPLYING。**
