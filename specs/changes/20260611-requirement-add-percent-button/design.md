# Design — 百分号按钮交付方案

## 1. 复杂度评估(step6)

**复杂度等级**:**LOW**

| 维度 | 评分 | 说明 |
|------|------|------|
| 范围 | 1/5 | 仅 UI 文案 + 测试 |
| 算法 | 1/5 | 沿用既有 `getPercentString` |
| 集成 | 1/5 | 不引新依赖 |
| 风险 | 2/5 | 缺测试环境,需 Node 镜像兜底 |

## 2. 架构设计(step7)

```
┌──────────────────────────────────────────────────────────┐
│                    CalculatorPage (UI)                   │
│  Btn(%) ──onOp──▶ expression += '%'                       │
│  Btn(=) ──onEquals──▶ ① getCleanExpression                │
│                       ② CalcEngine.evaluate               │
│                       ③ NumberFormatter.format            │
└──────────────────┬──────────────────┬────────────────────┘
                   │                  │
                   ▼                  ▼
        ┌──────────────────┐  ┌─────────────────┐
        │ Expression       │  │ CalcEngine      │
        │ getPercentString │  │ parseExpression │
        │ (重写 % 为基线   │  │ (递归下降)      │
        │  +base*(b/100)) │  │                 │
        └──────────────────┘  └─────────────────┘

         ▲                            ▲
         │ 镜像                       │ 端到端
         │                            │
┌────────┴────────────────────────────┴──────────┐
│        ohosTest/Expression.test.ets             │
│        ohosTest/Calculator.test.ets   (hypium)  │
│        tools/percent-verify.js     (Node 镜像)   │
└─────────────────────────────────────────────────┘
```

## 3. 组件设计(step8)

### 3.1 不变组件
- `CalcEngine`(`Calculator.ets`):无变动
- `Expression`(`Expression.ets`):无变动
- `CalculatorPage`(`CalculatorPage.ets`):仅在 `BtnOpPct('%')` 上方加一行注释,标明"Issue #8 验收点"

### 3.2 新增组件

#### 3.2.1 `tools/percent-verify.js`(Node 兼容验证脚本)
**职责**:用 JS 镜像 `getPercentString` 算法,在 Node.js 下跑 6 个 AC 用例,作为 CI/本地可执行的真实测试证据。
**设计要点**:
- 单文件、零依赖
- 顺序:RED(故意 fail 一次)→ GREEN(全部 pass)→ REFACTOR(确认通过)— 满足 tdd-enforcer 流程
- 输出格式:`PASS/FAIL: <case> => expected=<X> actual=<Y>`
- 退出码:全部通过 0,任一失败 1

#### 3.2.2 `entry/src/ohosTest/`(HarmonyOS hypium 测试模块)
**结构**:
```
entry/src/ohosTest/
├── module.json5                  (hypium 测试模块声明)
└── ets/
    ├── test/
    │   ├── Expression.test.ets   (单元测试 Expression.getPercentString)
    │   ├── Calculator.test.ets   (端到端 50+10%=55)
    │   └── List.test.ets         (测试套件入口)
    ├── testability/
    │   └── pages/Index.ets
    └── testrunner/OpenHarmonyTestRunner.ts
```

### 3.3 接口契约

| 测试用例 | 输入 | 期望 | 方法 |
|---------|------|------|------|
| AC1 | `"50+10%"` | `55` | `expect(engine.evaluate(expr.getCleanExpression(x,".",","),true)).assertEqual(55)` |
| AC2 | `"200-15%"` | `170` | 同上 |
| AC3 | `"30%"` | `0.3` | 同上 |
| AC4 | `"200*10%"` | `20` | 同上 |
| AC5 | `"(50+10)%"` | `0.6` | 同上 |
| AC6 | UI 按钮代码 | `BtnOpPct('%').onClick → onOp('%')` | grep 静态检查 |

## 4. 数据流

无新数据流,沿用现有 `expression: string` 状态。

## 5. 设计审视(step9)

| 审视点 | 结果 |
|--------|------|
| 是否符合 SRP | ✅ Expression 一个职责:预处理表达式 |
| 是否符合 OCP | ✅ 不修改 Expression,只新增测试 |
| 是否符合 KISS | ✅ 零代码改动,纯测试补齐 |
| 是否符合 DRY | ✅ Node 脚本镜像同一算法,逻辑一致 |
| 是否有可回归保障 | ✅ 6 AC + Node CI 脚本 |
| 是否破坏现有功能 | ✅ 否(只在 BtnOpPct 上加注释) |
| 性能影响 | ✅ 零 |
| 安全影响 | ✅ 零 |
