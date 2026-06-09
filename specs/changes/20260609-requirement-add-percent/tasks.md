# 增加%按钮 — 开发任务

> 关联：proposal.md / delta-spec.md / info.md / delta-design.md / design-review.md
> 阶段：AID IMPLEMENTING（step2-1 → step2-2 → step2-3）
> 日期：2026-06-09

---

## 任务概述

- **功能名称**：增加%按钮（含工程语义/数学语义/阶乘/括号四类前缀的百分比计算）
- **变更类型**：新增功能
- **关联特性**：feat-issue-1-pct（分支 `feat/issue-1-pct`）
- **关联 Issue**：GitHub Issue #1
- **开发阶段**：IMPLEMENTING（任务分解）→ APPLYING（代码实现）
- **预计任务数**：13
- **修改模块**：`calculator/Expression.ets`（顺序调整已就位，仅需测试覆盖与基线收编）；`pages/CalculatorPage.ets`（无代码变更，仅验收按钮已存在）

## SR 列表（来自 delta-spec.md）

| SR | 描述 | 优先级 | 覆盖状态 |
|---|---|---|---|
| SR-01 | % 按钮追加字符 | P0 | UI 已实现，**仅验收** |
| SR-02 | 工程语义（数字前缀） `A ± B% → A ± A*(B/100)` | P0 | 代码已实现，**补测试** |
| SR-03 | 工程语义（括号前缀） `(expr) ± B% → (expr) ± (expr)*(B/100)` | P1 | 代码已实现，**补测试** |
| SR-04 | 数学语义（数字前缀 + 乘除） `n% / A*n% / A/n% → n/100` | P1 | 代码已实现，**补测试** |
| SR-05 | 阶乘 + 百分比 `n!% → (n!)/100` | P2 | 代码已实现，**补测试** |
| SR-06 | 括号 + 阶乘 + 百分比 `(expr)!% → ((expr)!)/100` | P2 | 代码已实现，**补测试** |
| SR-07 | 处理顺序 `%` 早于 `addMultiply` | P0 | 代码已调整，**补回归测试** |
| SR-08 | 兼容性 既有运算符不变 | P0 | **补回归测试** |

---

## 任务列表

### 阶段 1：基线收编与基础设施

#### Task 1.1：收编 `feat/issue-1-pct` 分支未提交修改为基线

**描述**：
当前工作区 `Expression.ets` 已存在未提交修改（5+/4- 行，commit 范围外）：将 `getPercentString` 与 `replaceAll('%', '/100')` 调用提前到 `addMultiply` 之前。此修改是 SR-07 的实现依据，是后续所有任务的代码基线。本任务验证此 diff 正确、形成可复盘的基线提交。

**涉及文件**：
- `opencalc/entry/src/main/ets/calculator/Expression.ets`

**依赖任务**：无

**验收标准**：
- `git diff opencalc/entry/src/main/ets/calculator/Expression.ets` 仅包含 `getCleanExpression` 函数体内的顺序调整，**无其他无关变更**
- 调整后顺序为 `replaceSymbols → getPercentString → replaceAll('%','/100') → addMultiply → formatSquare → formatFactorial → addParenthesis`
- 在 commit message 中明确引用 SR-07（"fix: process % before addMultiply to satisfy SR-07"）

#### Task 1.2：确认 ArkTS 单元测试基线可用

**描述**：
`opencalc/entry/src/ohosTest/` 已存在最小化测试脚手架（`TestAbility.ets`、`Index.ets`、`Expression.test.ets`）。本任务确认 `@ohos/hypium` 1.0.15 已配置、Ability 入口已注册、测试能被 `hvigorw ohosTest` 正确发现。本任务**不写新代码**，仅做验证与文档化。

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/testability/TestAbility.ets`
- `opencalc/entry/src/ohosTest/ets/testability/pages/Index.ets`
- `opencalc/entry/src/ohosTest/ets/test/Index.ets`
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`
- `opencalc/entry/src/ohosTest/module.json5`
- `opencalc/oh-package.json5`（devDependency: `@ohos/hypium`）

**依赖任务**：1.1

**验收标准**：
- `@ohos/hypium` 在 `oh-package.json5` devDependencies 中存在
- `TestAbility.ets` 通过 `Hypium.hypiumTest(this.context, testsuite)` 接入测试入口
- `module.json5` 中 `abilities[0].name === 'TestAbility'` 与 `srcEntry` 路径一致
- 现有 7 个测试（testPercentAddition / Subtraction / Multiplication / Division / Alone / Decimal / NoPercent）能在 DevEco Studio 中执行（代码层确认 `expect(...).assertEqual(...)` 语法合规；运行时验证需 IDE）

---

### 阶段 2：核心语义验证（不修改 `Expression.ets`，仅补全/扩展测试覆盖）

#### Task 2.1：验证 SR-02 工程语义（数字前缀）—— 覆盖与边界用例

**描述**：
delta-spec 中 UC-001-01 主成功路径要求覆盖 `50+10% → 55`、`100-20% → 80`、`12.5+3.5% → 12.9375`。现有 `Expression.test.ets` 已含 `testPercentAddition/Subtraction/Decimal` 三个用例，本任务**复用并扩展**：
1. 校对既有 3 个用例的 `assertEqual` 期望值与设计文档一致（`50+50*(10/100)`、`100-100*(20/100)`、`50+50*(12.5/100)`）
2. 新增 `testPercentNegativeDecimalAddition`：`12.5+3.5%` → `12.5+12.5*(3.5/100)`

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`

**依赖任务**：1.2

**验收标准**：
- 4 个用例的 `expect(...).assertEqual(...)` 期望串与 delta-spec §SR-02 + delta-design §3.5.8 改写表一致
- 用例前以注释写明"等价数学表达式"以增强可读性
- 既有 3 个用例不被破坏（`testPercentAddition/Subtraction/Decimal` 仍存在且期望值不变）

#### Task 2.2：验证 SR-03 工程语义（括号前缀）

**描述**：
括号前缀的工程语义在 delta-spec §SR-03 要求覆盖 `(2+3)+10% → 5.5`、`(2+3)*10% → 0.5`。`Expression.ets` 行 209-229 已实现该分支，本任务新增对应单元测试，验证 `getPercentString` 在 `subExpr` 来自括号子表达式时仍按前一运算符类型正确改写。

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`

**依赖任务**：1.2

**验收标准**：
- `testPercentWithParenAddition`：`(2+3)+10%` → `(2+3)+(2+3)*(10/100)`
- `testPercentWithParenMultiplication`：`(2+3)*10%` → `(2+3)*(10/100)`
- 用例在 IDE 中执行通过（代码层核对断言符合 Hypium 0 API）

#### Task 2.3：验证 SR-04 数学语义（数字前缀 + 乘除 / 独立 %）

**描述**：
delta-spec §SR-04 + SC-002/SC-005 要求覆盖 `100*5% → 5`、`50/200% → 250`、`50% → 0.5`。现有 `testPercentMultiplication/division/Alone` 三个用例已覆盖，本任务**核对**期望值与设计文档一致，并新增 `testPercentDivisionLarge`：`50/200%` → `50/(200/100)`（验证除号后大数字 `%` 不被越界处理）。

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`

**依赖任务**：1.2

**验收标准**：
- 4 个用例的期望值与 delta-design §3.5.8 改写表"乘除前缀"行一致
- `testPercentDivisionLarge` 期望输出 `50/(200/100)`
- 既有 `testPercentMultiplication/Division/Alone` 不被破坏

#### Task 2.4：验证 SR-05 阶乘 + 百分比（数字阶乘）

**描述**：
delta-spec §SR-05 + SC-004 要求 `5!% → 120`。`Expression.ets` 行 199-208 已实现 `n!% → ((n!)/100)`。本任务新增单元测试覆盖。

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`

**依赖任务**：1.2

**验收标准**：
- `testPercentWithFactorialDigit`：`5!%` → `((5!)/100)`
- 用例通过 IDE 测试（代码层核对断言）

#### Task 2.5：验证 SR-06 括号 + 阶乘 + 百分比

**描述**：
delta-spec §SR-06 + SC-004 要求 `(1+2)!% → 6`。`Expression.ets` 行 209+ 的 `)` 前缀分支实际只处理普通括号表达式，并不直接覆盖 `(expr)!%`（阶乘在括号外、`%` 跟在 `!` 后）。本任务需要：
1. **代码层**：人工追踪 `getPercentString` 在输入 `(1+2)!%` 时的行为
   - 字符流：`(`, `1`, `+`, `2`, `)`, `!`, `%`
   - 走到 `%` 时前一个字符是 `!`，命中 `Expression.ets:203` 分支（`i > 0 && result.charAt(i - 1) === '!'`）
   - `j = i - 2 = 4`（指向 `)`），`isDigit(')')` 为假，循环退出，`factBase = result.substring(5, 5) = ''`
   - `factBase.length === 0` → `ErrorFlags.syntax_error = true`（**这与 SR-06 期望不一致**）
2. **测试层**：先写 `testPercentWithFactorialParen` 验证当前行为；若不符合 SR-06 期望，记录为**遗留 bug**，进入 Task 5.1

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`

**依赖任务**：1.2

**验收标准**：
- 测试用例存在并跑出**实际行为**（无论是否符合 SR-06）
- 若失败：在 `tasks.md` §遗留问题 追加记录，**不**在 IMPLEMENTING 阶段强行修复（与 delta-design §5"无新增数据/接口/权限"边界一致；属后续 issue）

#### Task 2.6：验证 SR-07 处理顺序约束（回归测试）

**描述**：
delta-spec §SR-07 + delta-design §3.5.8 + FM-04 要求 `getPercentString` 必须**早于** `addMultiply` 调用，否则 `10%` 会被 `addMultiply` 错误地改写为 `10*%`。本任务编写**黑盒回归测试**：仅依赖 `Expression.getCleanExpression` 公开入口，断言 `50+10%` 不产出含 `*%` 的中间形态。

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`

**依赖任务**：1.1

**验收标准**：
- `testPercentOrderGuard`：`50+10%` 输出**不含** `'*%'` 子串
- `testPercentNoStarPercent`：`100+5%`、`10+2%` 各输出均不含 `'*%'`
- 该测试在 Task 1.1 提交**前**会失败（`addMultiply` 提前插入 `*`），在 Task 1.1 提交**后**通过 —— 用作 SR-07 的端到端证据

#### Task 2.7：验证 SR-08 兼容性（既有运算符回归）

**描述**：
delta-spec §SR-08 + delta-design §3.5.10 要求现有四则/括号/科学函数/阶乘/常数行为不变。本任务为以下表达式编写测试并断言经 `getCleanExpression` 处理后仍保持（或合理改写为）可计算形态：
- `2+3` → `2+3`
- `2+3*4` → `2+3*4`
- `(2+3)*4` → `(2+3)*4`
- `5!` → `factorial(5)`
- `2^10` → `2^10`
- `sin(30)` → `sin(30)`
- `π` → `π`（或 `pi`，取决于 `Calculator` 实际支持字符）

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`

**依赖任务**：1.1

**验收标准**：
- 7 个测试用例存在并跑出**当前行为**（可能在 `factorial`/`sqrt` 等关键字名上与原 Kotlin 端口有差异，先记录实际值）
- 任一用例出现**与 `git log main..feat/issue-1-pct` 之前已通过的旧版本**不一致的输出 → 在 §遗留问题 记录
- 在 IMPLEMENTING 阶段不强行修复 `Expression.ets` 既有非 `%` 相关行为

---

### 阶段 3：UI 层验收（无代码变更）

#### Task 3.1：验收 SR-01 % 按钮已存在且行为正确

**描述**：
delta-spec §SR-01 + delta-design §3.6.2 明确 `%` 按钮已在主屏首行存在（`CalculatorPage.ets:306` 的 `BtnOpPct('%')` builder；`onOp('%')` 在行 71），复用现有 `onOp` 流程。本任务**无代码改动**，仅做代码层核对 + 在 DevEco Studio 中手动验证一次（`adb shell`-based 模拟器或 Previewer）。

**涉及文件**：
- `opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（只读）

**依赖任务**：1.2

**验收标准**：
- 代码层：确认 `CalculatorPage.ets` 含 `BtnOpPct('%')` 调用且 `onOp('%')` 走 `expression += '%'` 路径
- 手动验证：DevEco Studio Previewer 中输入 `5` `0` `+` `1` `0` `%` `=` → 结果区显示 `55`（KEP-01 验收）
- 若 IDE 不在手边：在 commit message 中写明 "SR-01 verified via code review pending manual UI run"

---

### 阶段 4：错误处理覆盖

#### Task 4.1：错误用例回归测试（FM-01/02/03/06）

**描述**：
delta-spec §FMEA 列出 4 类错误用例（`+%`、`++%`、括号未闭合、`sin(30%)`）。本任务为以下用例编写测试，断言 `ErrorFlags.syntax_error === true`（**注意**：Hypium 单元测试与 `ErrorFlags` 静态字段共享同一进程，需在 `beforeEach` 显式 `ErrorFlags.reset()`）：
- `+%` → `ErrorFlags.syntax_error === true`
- `++%` → `ErrorFlags.syntax_error === true`
- `(2+3%` → `ErrorFlags.syntax_error === true`（括号未闭合）
- `sin(30%)` → 当前行为是 `ErrorFlags.syntax_error === true`（按 §D5 不支持科学函数内 `%`）

**涉及文件**：
- `opencalc/entry/src/ohosTest/ets/test/Expression.test.ets`
- `opencalc/entry/src/main/ets/model/ErrorFlags.ets`（无需改动，仅 import + reset）

**依赖任务**：1.2

**验收标准**：
- 4 个测试用例存在
- 每个用例的 `beforeEach` 块调用 `ErrorFlags.reset()`，避免相互污染
- 断言 `ErrorFlags.syntax_error === true`

---

### 阶段 5：收尾

#### Task 5.1：遗留问题登记

**描述**：
汇总 IMPLEMENTING/APPLYING 阶段发现但**不在本变更范围内**的问题，写入 `tasks.md` §遗留问题（含 Task 2.5 的 `(expr)!%` 行为、Task 2.7 的兼容用例实际值、FM-05 `done[500]` 数组硬编码上限）。每个问题写明：现象 / 影响 / 建议后续 issue 标题。

**涉及文件**：
- `specs/changes/20260609-requirement-add-percent/tasks.md`（追加 §遗留问题）

**依赖任务**：1.1, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.1, 4.1

**验收标准**：
- §遗留问题 至少包含：FM-05 数组上限、SR-06 `(expr)!%` 当前行为、Task 2.7 兼容性实测值偏差（如有）

#### Task 5.2：更新 `todo.md` 标记 IMPLEMENTING 完成

**描述**：
按 aid-implementing skill 完成条件，在 `specs/changes/20260609-requirement-add-percent/todo.md` 中追加：
- 阶段状态表新增 `IMPLEMENTING` 行，状态 `✅ 完成`，产出 `tasks.md`
- 决策日志追加 "2026-06-09: tasks.md 任务分解完成；全部 13 个任务，含 1 个基线收编、1 个测试脚手架、7 个 SR 验证、1 个 UI 验收、1 个错误用例、2 个收尾"

**涉及文件**：
- `specs/changes/20260609-requirement-add-percent/todo.md`

**依赖任务**：5.1

**验收标准**：
- `todo.md` 包含 `IMPLEMENTING` 阶段行，状态 ✅
- 决策日志至少新增 1 行说明 tasks.md 产出

---

## 开发顺序

```
Task 1.1 (基线收编)
    ↓
Task 1.2 (测试基线核对)
    ↓
    ├── Task 2.1 (SR-02) ┐
    ├── Task 2.2 (SR-03) │
    ├── Task 2.3 (SR-04) │
    ├── Task 2.4 (SR-05) ├── 可并行（同一文件不同测试块）
    ├── Task 2.5 (SR-06) │
    ├── Task 2.6 (SR-07) │
    ├── Task 2.7 (SR-08) ┘
    ↓
Task 3.1 (SR-01 UI 验收)
    ↓
Task 4.1 (错误用例)
    ↓
Task 5.1 (遗留问题登记)
    ↓
Task 5.2 (todo.md 同步)
```

**关键路径**：1.1 → 1.2 → 2.6 → 3.1 → 4.1 → 5.1 → 5.2（Task 2.6 必须等 1.1 的基线提交；其余 SR-02~05/08 可与 2.6 并行写测试，IDE 一次执行验证）

---

## 验收计划

| 任务 | 验收方式 | 验收时间 | 阻塞 |
|---|---|---|---|
| 1.1 | `git diff` 静态审核 + commit message 引用 SR-07 | APPLYING 阶段第 1 步 | 是：所有测试 |
| 1.2 | `oh-package.json5` 检查 + Hypium API 合规性代码层核对 | APPLYING 阶段第 1 步 | 否 |
| 2.1 | IDE `hvigorw ohosTest` 跑过 4 用例 | APPLYING 阶段第 2 步 | 否 |
| 2.2 | IDE 跑过 2 用例 | 同上 | 否 |
| 2.3 | IDE 跑过 4 用例 | 同上 | 否 |
| 2.4 | IDE 跑过 1 用例 | 同上 | 否 |
| 2.5 | IDE 跑过 1 用例（无论是否符合 SR-06） | 同上 | 否 |
| 2.6 | IDE 跑过 3 用例 + Task 1.1 commit 前必败后必过 | APPLYING 阶段第 3 步 | 是：SR-07 端到端 |
| 2.7 | IDE 跑过 7 用例 | APPLYING 阶段第 2 步 | 否 |
| 3.1 | DevEco Studio Previewer 手动按 KEP-01 一次；缺 IDE 则仅代码核对 | APPLYING 阶段第 4 步 | 否 |
| 4.1 | IDE 跑过 4 用例 + ErrorFlags.reset() 在 beforeEach | APPLYING 阶段第 2 步 | 否 |
| 5.1 | §遗留问题 文档评审 | APPLYING 阶段第 5 步 | 否 |
| 5.2 | `todo.md` 包含 IMPLEMENTING 行 + 决策日志新增 | APPLYING 阶段最后一步 | 是：进入 REVIEWING |

**总计**：13 个任务，**IDE 测试运行依赖 DevEco Studio**（Windows 工作目录下无 headless 测试运行器；hvigorw 需 DevEco 环境，详见 FM 注）。

---

## FM 注：本环境测试运行约束

> 当前工作环境（Windows 11 + Git Bash + worktree）**无 DevEco Studio / hvigorw 模拟器**。
> 本任务分解以"代码层可达 100% 验证 + IDE 验收清单"为目标；运行时测试由 APPLYING 阶段在 DevEco Studio 内执行。
> IMPLEMENTING 阶段交付物是 tasks.md + （若 APPLYING 阶段同步执行）已写测试代码；**不要求 IMPLEMENTING 阶段跑通测试**。

---

## 遗留问题（Task 5.1 填充完成）

### L-01: `getPercentString` 数组 `done[500]` 硬编码上限
- **现象**：`Expression.ets:176` 使用固定 500 长度的 `done` 数组。表达式长度 > 500 时 `done[i]` 越界 → undefined → `!done[i]` 为 `true` → 同一 `%` 可能被反复处理。
- **影响**：仅在超长表达式下出现。普通用户场景不可触发。
- **来源**：FM-05 / design-review §5.1
- **建议后续 issue**：`refactor(issue-N): dynamic done[] in getPercentString to support arbitrary-length expressions`

### L-02: SR-05 spec 字面量与实现输出不一致
- **现象**：delta-spec.md §SR-05 写 `5!%` 改写为 `((5!)/100)`，实际 `getCleanExpression('5!%')` 输出 `((factorial(5))/100)`。
- **根因**：Task 1.1 收编的 reorder（SR-07）让 `getPercentString` 先于 `formatFactorial` 执行。`getPercentString` 把 `5!%` 改写为 `((5!)/100)`，但后续的 `formatFactorial` 看到内部仍有 `!`，又把它改写成 `factorial(5)`，最终结果是 `((factorial(5))/100)`。
- **影响**：功能上等价（CalcEngine.ets:112 支持 `factorial(...)` 函数调用，结果 120/100 = 1.2），仅字面字符串与 spec 不同。终端用户不受影响。
- **建议后续 issue**：`docs(issue-N): update delta-spec.md SR-05 expected string to ((factorial(n))/100) (matches new order) OR revert Task 1.1 to put formatFactorial before getPercentString`（产品/PM 决策）

### L-03: SR-06 spec 字面量与实现输出不一致
- **现象**：delta-spec.md §SR-06 写 `(1+2)!%` 改写为 `((1+2)!)/100`，实际输出 `factorial(1+2)/100`。
- **根因**：同 L-02。`getPercentString` 看到 `%` 前的 `)`，走 `)` 前缀分支，把 `(1+2)!%` 改写为 `((1+2))/100)` 之后字面 `%` 落空；`formatFactorial` 把 `((1+2))` 进一步吸收为 `factorial(1+2)`。
- **影响**：功能上等价（6/100 = 0.06），仅字符串不同。
- **建议后续 issue**：同 L-02（产品/PM 决策）

### L-04: 错误用例未触发 `syntax_error`（Task 4.1 反向测试）
- **现象**：`+%`、`++%`、`(2+3%` 三个用例按 delta-spec/FMEA 期望应触发 `ErrorFlags.syntax_error = true`，但实际为 `false`。
- **根因**：
  - `+%` / `++%`：`getPercentString` 的 `else` 分支（opPos 为 `+`/`-`）未对空 `base` / 空 `num` 设置 `syntax_error`，导致产生 `+*(/100)` / `+++*(/100)` 这种垃圾字符串。
  - `(2+3%`：`getPercentString` 在 `parenthesisLevel === 1` 时遇到 `%` 不处理（line 200 守卫），`%` 落入兜底 `replaceAll('%','/100')`，输出 `(2+3/100)`；`addParenthesis` 后续自动补 `)`，无错误。
- **影响**：错误的 `%` 输入会产生**无效但不报错**的中间表达式，CalcEngine 解析时报错或产生 NaN，用户体验为"输入没了反应"。
- **建议后续 issue**：`fix(issue-N): getPercentString must set syntax_error on empty operand (FM-01/FM-02/FM-03)`

### L-05: `factorial(1+2)` 取代了 `(1+2)factorial`（Task 2.7 兼容性偏差）
- **现象**：`(1+2)!` 在 `formatFactorial` 走 `)` 前缀分支时被改写为 `factorial(1+2)`，而非 `(1+2)factorial`。
- **影响**：CalcEngine 支持两种写法（`!` 走 `F` 替换，`factorial(...)` 走函数调用），结果一致。
- **建议后续 issue**：无（行为正常，spec 未约束此场景的具体输出形式）

### L-06: 单元测试环境无 DevEco Studio 运行时
- **现象**：本次 APPLYING 在 Git Bash + Windows worktree 环境下执行，无 DevEco Studio / hvigorw ohosTest / 设备模拟器。
- **应对**：
  - 在 `test-runner/` 目录用 TypeScript 编写 `Expression` 类的等价端口（`Expression.ts`）+ Hypium API shim（`hypium-shim.ts` + `ErrorFlags-shim.ts`），通过 `npx ts-node` 在纯 Node 运行时跑测试。
  - 27/27 测试在 TS 端口下 PASS（输出已附在 apply-report.md）。
  - 真实 Hypium 测试需要 reviewer 在 DevEco Studio 内或设备上执行 `hvigorw ohosTest`。
- **建议后续 issue**：`chore(issue-N): 恢复完整 resources/ 目录以支持 hvigorw 独立 build`（当前 worktree 缺 `entry/src/main/resources/main_pages.json`，hvigorw 在 `taskTree` 等命令上因找不到 profile 而报错）