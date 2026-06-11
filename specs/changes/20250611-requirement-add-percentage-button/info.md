# 代码仓理解 — info.md

> **变更**: 20250611-requirement-add-percentage-button
> **基线**: opencalc (HarmonyOS ArkTS 移植)
> **生成时间**: 2026-06-11

---

## 1. 项目身份

| 维度 | 值 |
|------|-----|
| 项目 | OpenCalc HarmonyOS (ArkTS 移植) |
| 原项目 | clementwzk/OpenCalc Android 3.2.1 |
| 语言 | ArkTS（TypeScript 超集，鸿蒙专用） |
| 文件数 | 9 个 .ets，~1,800 行 |
| 编译 | Hvigor 6.0.2 + HarmonyOS SDK 12 |
| 入口 | `@Entry CalculatorPage` (`pages/CalculatorPage.ets`) |
| 测试 | ⚠️ **无**（无 .test.ets / .spec.ets / 测试目录） |

---

## 2. 目录结构

```
D:\huawei\Demo\worktrees\issue-6\
├── .git/
├── agents/                              # 数字员工配置
│   └── (SOUL.md 等)
├── opencalc/                            # ⭐ 主项目
│   ├── AppScope/app.json5
│   ├── build-profile.json5              # 根构建
│   ├── oh-package.json5                 # 依赖
│   ├── hvigorfile.ts
│   ├── hvigor/hvigor-config.json5
│   ├── entry/
│   │   ├── build-profile.json5
│   │   ├── hvigorfile.ts
│   │   ├── oh-package.json5
│   │   └── src/main/
│   │       ├── module.json5
│   │       ├── ets/
│   │       │   ├── entryability/EntryAbility.ets
│   │       │   ├── pages/
│   │       │   │   ├── Index.ets
│   │       │   │   └── CalculatorPage.ets   ⭐ 主 UI
│   │       │   ├── calculator/
│   │       │   │   ├── Calculator.ets        ⭐ 解析器
│   │       │   │   ├── Expression.ets        ⭐ 预处理 + %
│   │       │   │   └── NumberFormatter.ets
│   │       │   ├── model/
│   │       │   │   ├── Models.ets
│   │       │   │   └── ErrorFlags.ets
│   │       │   └── preferences/
│   │       │       └── PreferencesStore.ets
│   │       └── resources/base/
│   │           ├── profile/main_pages.json
│   │           ├── element/{string,color}.json
│   │           └── media/app_icon.png
│   ├── docs/                              # 业务文档
│   │   ├── 增强需求-修改分析.md
│   │   └── 增强需求-一句话需求列表.md       ⭐ Issue #6 源
│   ├── spec/
│   │   ├── ARCH_ANALYSIS.md
│   │   ├── DESIGN.md                      # ⭐ 架构基线
│   │   └── TASK_BOARD.md                  # 任务看板
│   └── progress/2026-05-07.md
├── handoff.yaml                          # 团队配置
├── INVITE_AGENTS.md
├── rules.md                              # 协作铁律
└── README.md
```

---

## 3. 关键文件画像

### 3.1 `pages/CalculatorPage.ets` (415 行)

| 区块 | 行 | 角色 |
|------|-----|------|
| 状态声明 | 16-37 | `@State` 与私有字段 |
| 生命周期 | 39-58 | `aboutToAppear / loadPrefs / loadHistory` |
| 事件处理 | 70-113 | `onDigit / onOp / onFunc / onConst / onBS / onAC / onEquals / onCopy` |
| 主题颜色 | 115-185 | 9 个 `getXxx()` 取色器 |
| 布局 | 188-222 | `build()` Stack（横竖屏自适应） |
| 显示屏 | 225-253 | `@Builder DisplayPanel()` |
| 切换栏 | 256-269 | `@Builder ToggleRow()` |
| 按钮网格 | 272-309 | `@Builder ButtonGrid()` + 7 个 BtnXxx 子构建器 |
| 历史面板 | 311-351 | `@Builder HistoryPanel()` |
| 设置面板 | 354-400 | `@Builder SettingsPanel()` |
| 关于面板 | 403-414 | `@Builder AboutPanel()` |

**百分号按钮定位**: 第 278 行
```typescript
Row() { this.BtnActPct('AC'); this.BtnOpPct('%'); this.BtnOpPct('('); this.BtnOpPct(')'); this.BtnOpPct('÷') }
```
使用 `BtnOpPct()` 子构建器（306 行），与 `(`/`)`/`÷` 共享 17% 宽度行。

### 3.2 `calculator/Expression.ets` (299 行)

| 方法 | 行 | 功能 |
|------|-----|------|
| `getCleanExpression()` | 8-23 | 入口：replaceSymbols → addMultiply → %处理 → !处理 → addParenthesis |
| `replaceSymbols()` | 25-41 | `×÷√log` 符号替换 |
| `addMultiply()` | 43-98 | 隐式乘法 (`2π`→`2*π`, `5(3+2)`→`5*(3+2)`) |
| `formatSquare()` | 100-120 | `√x` → `sqrt(x)` |
| **`getPercentString()`** | **169-255** | **iOS-style 百分号语义（50+10%→55）** |
| `formatFactorial()` | 122-167 | `5!` → `factorial(5)` |
| `addParenthesis()` | 257-270 | 补齐 `)` |

**`getPercentString` 关键算法**（Issue #6 关注点）:
```typescript
// 50+10%  →  50+50*(10/100)
if (result.charAt(opPos) === '+' || result.charAt(opPos) === '-') {
  const base = result.substring(0, opPos).trim()       // "50"
  const num  = result.substring(opPos + 1, i)          // "10"
  result = base + op + base + '*(' + num + '/100)' + tail
}

// 200*10%  →  200*(10/100)
if (result.charAt(opPos) === '*' || result.charAt(opPos) === '/') {
  const num  = result.substring(opPos + 1, i)          // "10"
  result = prefix + '(' + num + '/100)' + tail
}

// 10%  →  (10/100)
if (opPos < 0) {
  const num = result.substring(start + 1, i)           // "10"
  result = '(' + num + '/100)' + tail
}
```

### 3.3 `calculator/Calculator.ets` (181 行)

递归下降解析器：
- `evaluate()` → `parseExpression()` → `parseTerm()` → `parseFactor()`
- 支持 `+ - × ÷ # ^ ! sin cos tan arcsin arccos arctan ln log logtwo exp π e`
- ASCII 码匹配（43=`+`, 45=`-`, 42=`*`, 47=`/`, 35=`#`, 94=`^`, 40=`(`, 41=`)`）
- 错误通过 `ErrorFlags` 静态类传递

### 3.4 `model/ErrorFlags.ets`

```typescript
export class ErrorFlags {
  static division_by_0: boolean = false
  static domain_error: boolean = false
  static syntax_error: boolean = false
  static is_infinity: boolean = false
  static require_real_number: boolean = false
  static reset(): void { /* 全部置 false */ }
}
```

---

## 4. 编译/构建能力

| 能力 | 状态 |
|------|------|
| `hvigorw assembleHap` | ✅ DevEco Studio 可用时执行（本期未跑） |
| `ohpm test` | ❌ 未配置测试框架 |
| `node --test` | ✅ 可用（提取纯算法跑） |
| 设备安装 `hdc` | ⚠️ 需要真机/模拟器 |

**本期策略**: 由于环境无 DevEco Studio / 真机，APPLYING 阶段采用 **Node.js 算法回放**：
- 将 `Expression.ets` 中 `%` 相关纯算法逻辑提取为 TypeScript 文本
- 写 Node 脚本调用 `Calculator.evaluate` 模拟完整链路
- 输出 PASS/FAIL 列表到 `apply-report.md`

---

## 5. 复用清单（Issue #6 可复用资源）

| 资源 | 路径 | 复用方式 |
|------|------|---------|
| `%` 算法 | `Expression.ets:169-255` | ✅ 直接复用，不改 |
| `onOp` 事件 | `CalculatorPage.ets:71` | ✅ 复用 `onOp('%')` |
| `BtnOpPct` 构建器 | `CalculatorPage.ets:306` | ✅ 改造为独立 `BtnPct()` |
| `getOp()` 主题色 | `CalculatorPage.ets:149-152` | ✅ 参照追加 `getPct()` |
| 错误提示体系 | `CalculatorPage.ets:83-87` | ✅ 沿用 |
| 历史记录 | `CalculatorPage.ets:91-96` | ✅ 沿用 |

---

## 6. 风险点

| # | 风险 | 影响 | 缓解 |
|---|------|------|------|
| 1 | ArkTS 测试框架缺失 | 单元测试无法跑 | Node 算法回放 + 输出报告 |
| 2 | 5 列布局变 4 列影响其他按钮 | UX 抖动 | 仅顶部行调整，下面 4 列保持 |
| 3 | 主题适配不周 | AMOLED 下橙色失真 | AMOLED 主题用 `#FF9F0A` 替代 |
| 4 | `addMultiply` 与 `%` 交互 | 隐式乘插入位置错 | 已实测：`50%` 不需要 `*` |

---

## 7. 关键发现总结

1. **核心算法已就位** — `getPercentString` 完整实现 iOS-style 语义，本次主要工作不是"修 bug"
2. **主要工作是 UX 增强** — 让用户**看得到** `%` 按钮
3. **缺少测试** — 整个项目 0 个测试文件，本次需补 ≥ 8 个
4. **环境约束** — 无 ArkTS 测试框架，用 Node 跑算法验证
5. **改动量小** — 预计 ≤ 80 行代码变更（UI ~50 行 + 测试 ~30 行 + about 文案 ~5 行）
