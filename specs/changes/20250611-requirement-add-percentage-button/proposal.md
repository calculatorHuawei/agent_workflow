# 需求提案 — 加百分号按钮 (Issue #6)

> **变更**: 20250611-requirement-add-percentage-button
> **作者**: dev-01
> **日期**: 2026-06-11
> **状态**: 🔄 PLANNING

---

## 1. 一句话需求（来自 Issue #6）

> 加一个百分号按钮，输入 `50+10%` 自动算出 `55`

- 分类: **UX 增强**
- 难度: ⭐（1 颗星，简单）
- 演示亮点: **日常高频，立刻感觉实用**

---

## 2. 现状调研

### 2.1 UI 层

`opencalc/entry/src/main/ets/pages/CalculatorPage.ets` 第 278 行：

```typescript
Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
```

百分号按钮**已存在**，但是：

1. **位置不够醒目** — 排在第 2 位（AC 之后），与 `(` `)` `÷` 共享一行，宽度仅 17%
2. **缺乏视觉区分** — 颜色与普通运算符一致 (`#B4D2E4`)，用户难以第一眼识别
3. **没有使用引导** — 新用户不知道 `%` 的语义是 "取基准的百分之几" 而非 "除以 100"
4. **与移动端主流不符** — iOS Calculator 把 `%` 放在数字右侧，而当前布局把它放在顶部

### 2.2 逻辑层

`opencalc/entry/src/main/ets/calculator/Expression.ets` 第 169-255 行 `getPercentString()` 已实现：

| 输入 | 转换结果 | 计算 |
|------|---------|------|
| `10%` | `(10/100)` | 0.1 |
| `50+10%` | `50+50*(10/100)` | 55 |
| `200*10%` | `200*(10/100)` | 20 |
| `(10+5)%` | 递归处理括号 | 0.15 |

**核心算法逻辑已就位**（移植自 Android 原版 OpenCalc），但：
- ❌ **没有单元测试覆盖** — 整个项目搜不到 `*.test.ets` 或 `*.spec.ets`
- ❌ 未来重构时无回归保护

---

## 3. 需求范围

### 3.1 In-Scope（本次必做）

| ID | 描述 | 验收 |
|----|------|------|
| R1 | 百分号按钮更醒目，位置/样式优化 | 用户进入 CalculatorPage 即可一眼看到 `%` 按钮 |
| R2 | 按钮点击行为不变（仍走 `onOp('%')`） | 表达式末尾追加 `%` |
| R3 | 添加单元测试覆盖 `Expression.getPercentString()` | RED → GREEN → REFACTOR 全过；至少 8 个用例 |
| R4 | 在关于/帮助里加一句 "百分号用法" | 用户点击关于页可见 "50+10% = 55" 提示 |

### 3.2 Out-of-Scope（不做）

- 不改变 `getPercentString` 已有行为（iOS-style 50+10%=55 已实现）
- 不新增主题/动画
- 不修改历史记录格式
- 不修改 Calculator 解析器

### 3.3 假设与依赖

- 假设 1：测试框架需要新增。当前 opencalc 项目无测试脚手架，本次需引入轻量级 ArkTS 单测方式（用 Node.js + 自定义 assertion 模拟 `getCleanExpression` 调用，输出至 `apply-report.md` 验证）
- 假设 2：`hvigorw test` 在当前工作树未配置，本次采用"提取核心算法 → 纯函数入口 → Node.js 直跑"的方式验证
- 依赖：`opencalc/entry/src/main/ets/calculator/Expression.ets` 不变

---

## 4. 用户故事

**作为** OpenCalc HarmonyOS 用户  
**我想要** 在键盘上看到一个明显的百分号按钮  
**以便于** 快速计算 "50 加 10%" 这种日常折扣/百分比场景  
**验收**: 输入 `50+10%` 点击 `=`，结果为 `55`

---

## 5. 风险与对策

| 风险 | 等级 | 对策 |
|------|:----:|------|
| 移动按钮后 5 列布局挤 | 🟢 低 | 顶部行从 5 列改为 4 列 (`AC`, `%`, `(`, `)`, `÷` → `AC`, `(`, `)`, `÷` + 单独 `%` 行) |
| 测试覆盖引入编译复杂度 | 🟡 中 | 不用 ArkTS 测试框架，用 Node 脚本直接 import TS 编译后的 JS，或纯算法函数提取 |
| `getPercentString` 边界用例可能不达标 | 🟡 中 | RED 阶段先写 8+ 个用例覆盖常见/边界场景 |

---

## 6. 演示场景

```
1. 用户进入计算器
2. 一眼看到醒目的橙色 % 按钮（在右下数字区附近）
3. 点击 5 0 + 1 0 %
4. 显示屏显示 "50+10%"
5. 点击 =
6. 结果区显示 "55"
7. 历史记录新增 "50+10% = 55"
```

---

## 7. 验收清单

- [x] 需求文案在 Issue #6 找到
- [x] 当前代码状态确认（按钮存在但 UX 弱）
- [x] 范围与边界清晰
- [ ] **PLANNING** 阶段：proposal / delta-spec / info / design
- [ ] **IMPLEMENTING** 阶段：tasks.md
- [ ] **APPLYING** 阶段：TDD 通过 + apply-report.md
