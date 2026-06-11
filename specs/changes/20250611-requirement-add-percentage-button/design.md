# 设计文档 — 加百分号按钮 (Issue #6)

> **变更**: 20250611-requirement-add-percentage-button
> **基线**: opencalc/spec/DESIGN.md
> **日期**: 2026-06-11
> **作者**: dev-01

---

## 1. 设计目标

让 `50+10% = 55` 这条 iOS-style 百分号语义在 OpenCalc HarmonyOS 上：

1. **看得见** — 百分号按钮在 UI 上显著（橙色 + 25% 宽 + 数字区右下）
2. **算得对** — 已有 `Expression.getPercentString()` 算法不变，新增 8+ 单元测试守卫
3. **用得会** — 关于页加一行 "50+10% = 55" 用法提示

---

## 2. 架构设计

### 2.1 模块依赖图

```
CalculatorPage (@Entry)
  ├── DisplayPanel      (不变)
  ├── ToggleRow         (不变)
  ├── ButtonGrid        ⭐ 改造
  │    ├── Row 0: 科学模式函数/常量 (不变)
  │    ├── Row 1: [ AC ] [ % ] [ ( ] [ ) ] [ ÷ ]   ⭐ 调整
  │    ├── Row 2: 7 8 9 ×  (不变)
  │    ├── Row 3: 4 5 6 -  (不变)
  │    ├── Row 4: 1 2 3 +  (不变)
  │    └── Row 5: 0 . ⌫ =  (不变)
  ├── HistoryPanel      (不变)
  ├── SettingsPanel     (不变)
  └── AboutPanel        ⭐ 追加 3 行说明

CalculatorPage 依赖:
  ├── CalcEngine.evaluate()           (不变)
  ├── Expression.getCleanExpression() (不变)
  └── ⭐ 新增: getPct() 主题色取色器
```

### 2.2 数据流

```
[用户点 % 按钮]
      ↓
BtnPct.onClick()
      ↓
onOp('%')                        ← 复用现有
      ↓
this.expression += '%'           ← @State 触发重渲染
      ↓
[用户点 = 按钮]
      ↓
onEquals()
      ↓
expr.getCleanExpression(expression)
   ├─ addMultiply()              ← % 后是数字时插入 *
   ├─ getPercentString()         ⭐ iOS-style 替换
   │    ├─ 50+10% → 50+50*(10/100)
   │    ├─ 200*10% → 200*(10/100)
   │    └─ 10% → (10/100)
   └─ replaceAll('%', '/100')    ← 兜底（无 % 残留）
      ↓
engine.evaluate(clean, !radianMode)
      ↓
result: 55
```

---

## 3. 详细设计

### 3.1 UI 改造 — 百分号按钮醒目化

#### 3.1.1 新增 `BtnPct()` 子构建器

**位置**: `CalculatorPage.ets` 第 290 行附近（在 `BtnOp()` 后）

```typescript
/** 百分号按钮（橙色高亮，独立 25% 宽，数字区右下） */
@Builder BtnPct() {
  Text('%')
    .fontSize(this.isLandscape ? 16 : 24)
    .fontWeight(FontWeight.Bold)
    .fontColor('#FFFFFF')                          // 白字
    .width('25%')                                   // ⭐ 独立 25% 宽
    .height(this.isLandscape ? 36 : 56)
    .textAlign(TextAlign.Center)
    .backgroundColor(this.getPct())                 // ⭐ 橙色
    .borderRadius(50)
    .margin(this.isLandscape ? 1 : 4)
    .onClick((): void => { this.onOp('%') })
}
```

#### 3.1.2 改造 ButtonGrid 布局

**改造前**（行 278）:
```typescript
Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
```

**改造后**:
```typescript
Row() { this.BtnActPct('AC'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }  // 4 按钮
// 新增独立 % 行
Row() { this.BtnDig('0'); this.BtnOp('.'); this.BtnPct(); this.BtnEq() }                   // 0 . % =
```

或者更克制的方案（**采用此方案** — 改动量小、不打乱 4 列节奏）:

```typescript
// Row 1: 顶部 4 个（去掉 %）
Row() { this.BtnActPct('AC'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
// 末尾行: 0 . % =
Row() { this.BtnDig('0'); this.BtnOp('.'); this.BtnPct(); this.BtnEq() }
```

#### 3.1.3 主题色 — `getPct()`

```typescript
/** 百分号按钮背景色（iOS 橙） */
getPct(): string {
  if (this.themeIdx === 1) return '#FF9F0A'   // AMOLED 柔和橙
  if (this.themeIdx === 2) return '#FF9500'   // 暗色 饱和橙
  return '#FF9500'                            // 默认 iOS 橙
}
```

### 3.2 AboutPanel 改造 — 用法提示

**位置**: `CalculatorPage.ets` 第 403-414 行 `AboutPanel()`

**改造前**:
```typescript
Text('迁移: github.com/JungleTestLabs/opencalc-harmonyos').fontSize(11).fontColor(this.getOp()).padding({ top: 4 })
Button('关闭').margin({ top: 16 }).onClick((): void => { this.showAbout = false })
```

**改造后**:
```typescript
Text('迁移: github.com/JungleTestLabs/opencalc-harmonyos').fontSize(11).fontColor(this.getOp()).padding({ top: 4 })
// ⭐ 新增百分号用法
Text('—— 百分号用法 ——').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.getT1()).padding({ top: 16 })
Text('50+10% = 55').fontSize(11).fontColor(this.getT2()).padding({ top: 4 })
Text('200*10% = 20').fontSize(11).fontColor(this.getT2()).padding({ top: 2 })
Text('10% = 0.1').fontSize(11).fontColor(this.getT2()).padding({ top: 2 })
Button('关闭').margin({ top: 16 }).onClick((): void => { this.showAbout = false })
```

### 3.3 测试设计 — `Expression.getPercentString()`

#### 3.3.1 文件结构

新建 `opencalc/entry/src/test/Percent.test.ets`（参考路径，可不参与编译）+ 配套 Node 脚本 `opencalc/entry/src/test/percent_node.ts`

#### 3.3.2 Node 脚本设计

由于 ArkTS 测试框架未配置，采用**算法提取 + Node 跑**的方式：

```typescript
// percent_node.ts
import { execSync } from 'child_process'

// Step 1: 把 Expression.ets 的纯算法逻辑移植到 TypeScript
// （去掉 import ErrorFlags 等 ArkTS 特性，保留核心 % 处理）
function getPercentString(calc: string): string { /* ... */ }

// Step 2: 把 Calculator.ets 的 evaluate 移植
function evaluate(equation: string, isDegree: boolean): number { /* ... */ }

// Step 3: 完整链路 getCleanExpression
function getCleanExpression(calculation: string): { expr: string, result: number } { /* ... */ }

// Step 4: 8+ 个测试用例
const cases = [
  { input: '10%',      expected: 0.1 },
  { input: '50+10%',   expected: 55 },
  { input: '200*10%',  expected: 20 },
  { input: '100-20%',  expected: 80 },
  { input: '5%*200',   expected: 10 },
  { input: '(10+5)%',  expected: 0.15 },
  { input: '2*5%+3',   expected: 3.1 },
  { input: '10/2%',    expected: 500 },
  { input: '1+2+3%',   expected: 3.09 },
  { input: '0%',       expected: 0 }
]

let pass = 0, fail = 0
for (const c of cases) {
  const r = getCleanExpression(c.input).result
  const ok = Math.abs(r - c.expected) < 1e-9
  if (ok) { pass++ } else { fail++ }
  console.log(`${ok ? '✅' : '❌'} ${c.input} → ${r} (expected ${c.expected})`)
}
console.log(`\n${pass}/${cases.length} passed, ${fail} failed`)
process.exit(fail === 0 ? 0 : 1)
```

#### 3.3.3 关键算法提取（仅 % 处理）

```typescript
function getPercentString(calc: string): string {
  let result = calc
  let i = 0
  const done: boolean[] = new Array(500).fill(false)
  while (i < result.length) {
    const ch = result.charAt(i)
    if (ch === '%' && !done[i]) {
      done[i] = true
      // Regular number before %
      if (i > 0 && /[0-9.]/.test(result.charAt(i - 1))) {
        let start = i - 1
        while (start >= 0 && /[0-9.]/.test(result.charAt(start))) start--
        // search operator in prefix
        const prefix = result.substring(0, start + 1)
        let opPos = -1
        for (const op of ['+', '-', '*', '/']) {
          const idx = prefix.lastIndexOf(op)
          if (idx > opPos) opPos = idx
        }
        if (opPos < 0) {
          const num = result.substring(start + 1, i)
          result = result.substring(0, start + 1) + '(' + num + '/100)' + result.substring(i + 1)
        } else if ('*/'.includes(result.charAt(opPos))) {
          const num = result.substring(opPos + 1, i)
          result = result.substring(0, opPos + 1) + '(' + num + '/100)' + result.substring(i + 1)
        } else {
          const base = result.substring(0, opPos).trim()
          const num = result.substring(opPos + 1, i)
          result = base + result.charAt(opPos) + base + '*(' + num + '/100)' + result.substring(i + 1)
        }
        i = 0
        continue
      }
    }
    i++
  }
  return result
}
```

---

## 4. 改动量预估

| 文件 | 类型 | 改动行 |
|------|------|-------:|
| `CalculatorPage.ets` | UI 改造 | +30 / -5 |
| `CalculatorPage.ets` | 主题色 | +5 / 0 |
| `CalculatorPage.ets` | AboutPanel 文案 | +5 / 0 |
| `Expression.ets` | 算法 | 0（不改） |
| `Calculator.ets` | 解析器 | 0（不改） |
| `percent_node.ts` | 新增测试脚本 | +120 |
| **合计** | | **+160 / -5** |

---

## 5. 风险评估

| # | 风险 | 等级 | 缓解 |
|---|------|:----:|------|
| 1 | 顶部 4 按钮变 4 列可能空一格 | 🟢 低 | 第 5 行（0 . % =）调整为 25%+25%+25%+25% 满列 |
| 2 | 橙色与红色错误色混淆 | 🟢 低 | 错误色 `#F44B3F` 偏红，橙色 `#FF9500` 偏黄，色相差大 |
| 3 | 测试 Node 跑结果与鸿蒙实机不一致 | 🟡 中 | 纯算法提取，输入输出与 ArkTS 1:1 移植；可手动真机复测 |
| 4 | `getPercentString` 边界 `(10+5)%` 已有算法 | 🟢 低 | 沿用 v2026-05-07 移植 |
| 5 | 修改 UI 触碰其他布局 | 🟡 中 | 只动 Row 1 和 Row 5，科学模式行不变 |

---

## 6. DoD（Definition of Done）

- [ ] 代码: `git diff --stat` 显示 ≤ 200 行变更
- [ ] 测试: Node 跑 `percent_node.ts` → 10/10 PASS
- [ ] UI: 5×N 布局不破（`AC ( ) ÷` 顶部 4 列 + 数字区正常）
- [ ] 主题: 3 主题切换 `%` 按钮可见
- [ ] 关于页: 3 行百分号说明可见
- [ ] 文档: `apply-report.md` 包含 diff + Node 输出
- [ ] 不变性: `Expression.getPercentString` 算法未改

---

## 7. 后续可扩展（Out-of-Scope）

- 滑动 `%` 切换"折扣模式"（200-10% = 180）
- 长按 `%` 切换 "÷100 直转模式"
- `%` 按钮加 haptic 强振动
- 备份 `Expression.ets` 算法到 `spec/algorithm-percent.md`
