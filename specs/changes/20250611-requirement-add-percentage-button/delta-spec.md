# 需求规格 Delta — 加百分号按钮

> **变更**: 20250611-requirement-add-percentage-button
> **基线**: opencalc/spec/DESIGN.md (v2026-05-07)
> **类型**: Delta（追加/修改说明，不重写基线）

---

## 1. 需求背景

OpenCalc HarmonyOS 移植版本（基于 Android 3.2.1）已具备百分号逻辑（`Expression.getPercentString`），但 UI 层没有显著的百分号按钮，**用户对核心功能 "50+10%=55" 无感知**。

| 维度 | 当前 | 期望 |
|------|------|------|
| 按钮位置 | 顶部第 2 位（与 `(` `)` `÷` 共享行） | **数字区右下**（与 iOS Calculator 对齐） |
| 按钮颜色 | 与普通运算符同色（浅蓝） | **橙色高亮**（区别于数字/运算符/等号） |
| 按钮尺寸 | 17% 宽度 | 25% 宽度（独立大按钮） |
| 使用引导 | 无 | 关于页追加 "百分号: 50+10%=55" 提示 |
| 单元测试 | 0 个 | ≥ 8 个用例（RED-GREEN-REFACTOR） |

---

## 2. 详细需求规格

### 2.1 FR-1: 百分号按钮 UI 增强

**功能**: 在 CalculatorPage 按钮网格中突出百分号按钮

**接口契约**:
- 组件: `@Builder BtnPct()` 独立方法
- 位置: 科学模式 0 行（与数字 `0` 同行右侧，取代现有 `=` 跨 2 列布局）
- 视觉: 橙色背景（`#FF9500`，iOS 风格），白字，宽度 25%
- 触发: `onOp('%')`（沿用现有事件），与 `(` `)` `÷` 行 `%` 共存（点击效果一致）

**验收**:
- 进入 CalculatorPage（默认竖屏基础模式）→ 立即可见 `%` 按钮
- 点击 → 表达式追加 `%`
- 主题切换（默认/暗色/AMOLED）→ 按钮颜色自适应
- 横屏/竖屏均可见

### 2.2 FR-2: 百分号逻辑测试覆盖

**功能**: 为 `Expression.getPercentString()` 添加单元测试

**测试用例**（至少 8 个）:
| # | 输入 | 期望转换结果 | 期望计算结果 |
|---|------|-------------|------------|
| 1 | `10%` | `(10/100)` | 0.1 |
| 2 | `50+10%` | `50+50*(10/100)` | 55 |
| 3 | `200*10%` | `200*(10/100)` | 20 |
| 4 | `100-20%` | `100-100*(20/100)` | 80 |
| 5 | `5%*200` | `(5/100)*200` | 10 |
| 6 | `(10+5)%` | `((10+5)/100)` | 0.15 |
| 7 | `2*5%+3` | `2*(5/100)+3` | 3.1 |
| 8 | `10/2%` | `10/(2/100)` | 500 |
| 9 | `1+2+3%` | `1+2+(1+2)*(3/100)` | 3.09 |
| 10 | `0%` | `(0/100)` | 0 |

**接口契约**:
- 测试文件: `opencalc/entry/src/test/ExpressionPercent.test.ets`（参考路径）
- 由于 ArkTS 测试框架未配置，本期采用 Node.js 脚本回放：将 `getPercentString` + `Calculator.evaluate` 算法提取为纯 TS 文本，跑 Node 测试
- 输出至 `apply-report.md`

**验收**: 8/8 测试 PASS，回归保护 0 失败

### 2.3 FR-3: 关于页追加百分号提示

**功能**: AboutPanel 显示百分号用法

**位置**: `opencalc/entry/src/main/ets/pages/CalculatorPage.ets` 的 `AboutPanel()` 内部

**内容**:
```
百分号用法：50+10% = 55（10% 等于基准 50 的 10%，再加到基准上）
             200*10% = 20（10% 等于 200 的 10%）
             10%    = 0.1（10% 自身等于 0.1）
```

**验收**: 打开设置 → 关于 OpenCalc → 看到上述 3 行说明

### 2.4 NFR: 不变性约束

- ❌ 不修改 `Expression.getPercentString()` 已有算法
- ❌ 不修改 `Calculator.ets` 解析器
- ❌ 不修改 `NumberFormatter` / `PreferencesStore`
- ❌ 不修改主题色变量名（仅追加新颜色 `getPctBtn()`）
- ✅ 新增的橙色 `#FF9500` 仅在暗色主题调整为 `#FF9F0A`（更柔和）

---

## 3. 接口与数据流

### 3.1 触发链

```
用户点击 %
  └─ onClick()
       └─ onOp('%')                       ← 复用 CalculatorPage.onOp
            └─ this.expression += '%'      ← @State 触发 build()
                 └─ 用户点 = (onEquals)
                      ├─ Expression.getCleanExpression()
                      │    └─ getPercentString() + replaceAll('%', '/100')
                      │         └─ iOS-style: 50+10% → 50+50*(10/100)
                      └─ Calculator.evaluate() → 55
```

### 3.2 错误流

| 场景 | 行为 |
|------|------|
| 输入 `+5%`（无基准） | getPercentString → ErrorFlags.syntax_error → "表达式错误" |
| 输入 `%` 单独 | getPercentString → syntax_error → "表达式错误" |
| 浮点精度 | `0.1+0.2` 已知 IEEE 754 误差，本期不修（与基线一致） |

---

## 4. 验收标准（DoD）

- [ ] 编译: `hvigor assembleHap` BUILD SUCCESSFUL（或因 DevEco 不可用则在 Node 中验证逻辑层 PASS）
- [ ] 功能: `50+10%=55` 真实跑通（Node 端断言 PASS）
- [ ] 单元测试: ≥ 8 个 PASS / 0 失败
- [ ] UI: 关于页可见百分号说明
- [ ] 主题: 3 主题下按钮可见可点
- [ ] 文档: `apply-report.md` 包含 diff + 测试日志

---

## 5. 范围之外

- 不引入新依赖（不装 ArkTS 测试框架）
- 不重构 `getPercentString`（保留 v2026-05-07 算法）
- 不修改 history 格式
- 不支持负数百分比（如 `-10%`）的特殊语义
- 不改 i18n（仍中文）
