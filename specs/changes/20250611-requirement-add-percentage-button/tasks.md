# 任务分解 — tasks.md

> **变更**: 20250611-requirement-add-percentage-button
> **关联**: design.md / delta-spec.md
> **方法**: Atomic Tasks + Depth-First + TDD (RED-GREEN-REFACTOR)

---

## 任务总览

| ID | 模块 | 描述 | 类型 | 规模 | 状态 |
|----|------|------|------|:----:|:----:|
| T1 | 测试 | 提取纯算法 + 写 10 个测试用例 (RED) | TDD-RED | XS | ⬜ TODO |
| T2 | 测试 | 跑测试 → 期望失败（算法未移植完成） | TDD-RED | XS | ⬜ TODO |
| T3 | 实现 | 完成 Node 端 `getPercentString` + `evaluate` 移植 | TDD-GREEN | S | ⬜ TODO |
| T4 | 测试 | 跑测试 → 期望全过 10/10 | TDD-GREEN | XS | ⬜ TODO |
| T5 | UI | `CalculatorPage.ets` 新增 `BtnPct()` 子构建器 | UI | S | ⬜ TODO |
| T6 | UI | 改造 `ButtonGrid()` Row 1（去 % 加占位）和 Row 5（加 %） | UI | S | ⬜ TODO |
| T7 | UI | 新增 `getPct()` 主题色取色器 | UI | XS | ⬜ TODO |
| T8 | UI | `AboutPanel()` 追加 3 行百分号说明 | UI | XS | ⬜ TODO |
| T9 | 验证 | Node 跑全套 10 个测试 + diff 统计 | 验证 | XS | ⬜ TODO |
| T10 | 文档 | 写 `apply-report.md` 收尾 | 文档 | XS | ⬜ TODO |

**总规模**: 10 个任务，全部 XS-S，估 2-3 小时可完成

---

## 详细任务

### T1. 写失败测试 (RED)

**文件**: `opencalc/entry/src/test/percent_node.ts`（新建）

**操作**:
1. 创建测试目录 `opencalc/entry/src/test/`
2. 写测试脚本，定义 10 个 `{input, expected}` 用例
3. 函数 `getCleanExpression()` 暂时用 `throw new Error('not implemented')` 占位
4. 主循环跑测试，PASS 计 `+1`，FAIL 计 `+1`，最后 `process.exit(fail===0 ? 0 : 1)`

**测试用例矩阵**:
```typescript
const cases = [
  { input: '10%',     expected: 0.1,   desc: '单纯 %' },
  { input: '50+10%',  expected: 55,    desc: 'Issue #6 核心场景' },
  { input: '200*10%', expected: 20,    desc: '乘后取 %' },
  { input: '100-20%', expected: 80,    desc: '减后取 %' },
  { input: '5%*200',  expected: 10,    desc: '先 % 后乘' },
  { input: '(10+5)%', expected: 0.15,  desc: '括号整体 %' },
  { input: '2*5%+3',  expected: 3.1,   desc: '混合运算' },
  { input: '10/2%',   expected: 500,   desc: '除后取 %' },
  { input: '1+2+3%',  expected: 3.09,  desc: '连续加法取 %' },
  { input: '0%',      expected: 0,     desc: '0 的 %' }
]
```

**验收**: 文件存在 + `npx tsx percent_node.ts` 跑出 10/10 FAIL

---

### T2. 确认 RED 状态

**操作**: `cd opencalc/entry/src/test && npx tsx percent_node.ts`（或 `node --import tsx percent_node.ts`）

**期望输出**:
```
❌ 10% → Error: not implemented
❌ 50+10% → Error: not implemented
...
0/10 passed, 10 failed
```

**验收**: 退出码非 0，输出 10 个失败

---

### T3. 实现 Node 端算法 (GREEN)

**文件**: 同 `percent_node.ts`

**操作**:
1. 移植 `Expression.getPercentString()` 核心算法（去掉 ArkTS 限制）
2. 移植 `Calculator.evaluate()` 递归下降解析器
3. 组合成 `getCleanExpression()`：调用 `getPercentString` + `replaceAll('%', '/100')` + `evaluate`

**关键算法**（与 `Expression.ets:169-255` 1:1 对应）:
```typescript
function getPercentString(calc: string): string {
  // 完整移植 Expression.ets 中 getPercentString 的所有分支
  // 包括: ! before %, ( before %, 数字 before %
}

function evaluate(eq: string, isDegree: boolean): number {
  // 递归下降: parseExpression → parseTerm → parseFactor
  // 支持: + - * / # ^ ! sin cos tan arcsin arccos arctan ln log logtwo exp π e
}

function getCleanExpression(input: string): { expr: string; result: number } {
  let calc = input
  calc = addMultiply(calc)
  if (calc.includes('%')) {
    calc = getPercentString(calc)
    calc = calc.split('%').join('/100')
  }
  return { expr: calc, result: evaluate(calc, true) }
}
```

**验收**: 代码完整无 `throw`

---

### T4. 确认 GREEN 状态

**操作**: 跑 T1 同命令

**期望输出**:
```
✅ 10% → 0.1
✅ 50+10% → 55
✅ 200*10% → 20
✅ 100-20% → 80
✅ 5%*200 → 10
✅ (10+5)% → 0.15
✅ 2*5%+3 → 3.1
✅ 10/2% → 500
✅ 1+2+3% → 3.09
✅ 0% → 0

10/10 passed, 0 failed
```

**验收**: 退出码 0，10/10 PASS

---

### T5. 新增 `BtnPct()` 子构建器 (UI)

**文件**: `opencalc/entry/src/main/ets/pages/CalculatorPage.ets`

**位置**: 在 `BtnOp()` (行 291) 之后

**操作**: 追加新构建器
```typescript
/** 百分号按钮（橙色高亮，独立 25% 宽） */
@Builder BtnPct() {
  Text('%').fontSize(this.isLandscape ? 16 : 24).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').width('25%').height(this.isLandscape ? 36 : 56).textAlign(TextAlign.Center).backgroundColor(this.getPct()).borderRadius(50).margin(this.isLandscape ? 1 : 4).onClick((): void => { this.onOp('%') })
}
```

**验收**: 编译无错（DevEco 可用时）

---

### T6. 改造 ButtonGrid 布局 (UI)

**文件**: 同上

**位置**: `ButtonGrid()` 函数，行 272-285

**操作**:
- Row 1（行 278）: `BtnOpPct('%')` 删除
- Row 5（行 282）: 在 `BtnAct('⌫')` 之前插入 `BtnPct()`，并把 `BtnEq()` 宽度从 22% 调到 25%
  - 调整后 Row 5: `0 (25%)` `. (25%)` `⌫ (25%)` `= (25%)` 共 100% 满列
  - **新方案**: 顶部行 4 列 `AC ( ) ÷` 4×25%=100% 满列；末行 `0 . % =` 4×25%=100% 满列

**实际改动**（基于现有 17% 列宽设计）:
- 现状 Row 1: 5 × 17% = 85% + 边距 ≈ 满
- 调整 Row 1: 4 × 25% = 100%
- 调整 Row 5: 4 × 25% = 100%（% 独立，= 改 25%）

**注**: 现有 5×17% 是历史遗留，本次统一改为 4×25% 更整齐

**验收**: 编译无错

---

### T7. 新增 `getPct()` 主题色取色器 (UI)

**文件**: 同上

**位置**: 主题色区块（行 149-185）内 `getEq()` 之后

**操作**: 追加
```typescript
/** 百分号按钮色（iOS 橙） */
getPct(): string {
  if (this.themeIdx === 1) return '#FF9F0A'   // AMOLED 柔和橙
  if (this.themeIdx === 2) return '#FF9500'   // 暗色 饱和橙
  return '#FF9500'                            // 默认 iOS 橙
}
```

**验收**: 编译无错

---

### T8. AboutPanel 追加百分号说明 (UI)

**文件**: 同上

**位置**: `AboutPanel()` (行 403-414)

**操作**: 在 `Button('关闭')` 之前插入 4 行
```typescript
Text('—— 百分号用法 ——').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.getT1()).padding({ top: 16 })
Text('50+10% = 55').fontSize(11).fontColor(this.getT2()).padding({ top: 4 })
Text('200*10% = 20').fontSize(11).fontColor(this.getT2()).padding({ top: 2 })
Text('10% = 0.1').fontSize(11).fontColor(this.getT2()).padding({ top: 2 })
```

**验收**: 编译无错

---

### T9. 全套验证

**操作**:
1. 跑 Node 测试: `cd opencalc/entry/src/test && npx tsx percent_node.ts`
2. 跑 `git diff --stat` 看变更行数
3. 检查所有改动的语法（人工 Code Review）

**验收**:
- 测试 10/10 PASS
- `git diff --stat` 显示变更 ≤ 200 行
- 4 个改动文件全部在预期路径

---

### T10. 写 apply-report.md

**文件**: `specs/changes/20250611-requirement-add-percentage-button/apply-report.md`（新建）

**内容**:
1. 变更摘要
2. 任务完成表（T1-T10）
3. 测试日志（Node 跑出来的 10 行）
4. `git diff --stat` 输出
5. 已知限制
6. 下一步建议

**验收**: 报告完整、可追溯

---

## 任务执行顺序

```
T1 ──> T2 ──> T3 ──> T4 ──┐
                          ├──> T9 ──> T10
              T5 ──> T6 ──┤
              T7 ──> T8 ──┘
```

T1-T4 串行（TDD 循环），T5-T8 并行/串行，汇合 T9 验证，T10 收尾。

---

## TDD 红绿循环守卫

| 检查 | 期望 | 命令 |
|------|------|------|
| T1 完成后 | 10/10 FAIL | `npx tsx percent_node.ts` |
| T2 完成后 | 10/10 FAIL | 同上 |
| T3 完成后 | 编译/语法通过 | `npx tsc --noEmit`（可选） |
| T4 完成后 | 10/10 PASS | `npx tsx percent_node.ts` |
| T9 完成后 | 10/10 PASS | 同上 |

任何阶段不符合期望 → 回滚到上一阶段，**禁止伪造测试输出**（铁律 7）。

---

## 验收检查清单

- [ ] T1-T4 TDD 循环跑通
- [ ] T5-T8 UI 改动无编译错
- [ ] T9 全套验证 PASS
- [ ] T10 apply-report.md 完整
- [ ] `git diff --stat` ≤ 200 行
- [ ] 不变性: `Expression.ets` 算法未改
- [ ] 不变性: `Calculator.ets` 解析器未改
