# 函数图像绘制（Issue #40） - 架构变更

## 1. 变更概述

| 项目 | 内容 |
| ---- | ---- |
| 变更类型 | 新增（plot 模块层 + 绘图面板），扩展（CalcEngine/Expression） |
| 变更日期 | 2026-10-22 |
| 变更人 | MigBot Developer（Issue #40 指派） |

---

## 2. 最新架构【架构前置】

### 2.1 架构总览

OpenCalc HarmonyOS 为单 @Entry 页面应用：CalculatorPage 以 Stack 叠放主界面与全屏面板（Settings/About 条件渲染、History 内嵌）。数学逻辑集中于 calculator/（CalcEngine 递归下降解析器 + Expression 预处理），错误经全局静态 ErrorFlags 报告。本变更在该架构内新增"绘图"能力层，不改变既有交互关系。

### 2.2 分层架构图

```
┌─────────────────────────────────────────────────────────────┐
│ 表现层                                                       │
│ CalculatorPage (@Entry)                                     │
│  ├── DisplayPanel / ToggleRow(+绘图入口) / ButtonGrid(+x)   │
│  ├── HistoryPanel / SettingsPanel / AboutPanel（既有）      │
│  └── PlotPanel（新增，全屏条件渲染 Builder：输入+Canvas+返回）│
├─────────────────────────────────────────────────────────────┤
│ 业务逻辑层                                                   │
│ FunctionPlotter（新增：采样/有效性/分段，纯逻辑）             │
│ CalcEngine（扩展：evaluate 可选 varX 绑定）                   │
│ Expression（扩展：x 隐式乘法，xp 保护）                       │
├─────────────────────────────────────────────────────────────┤
│ 数据层                                                       │
│ ErrorFlags（复用，不改动）；PreferencesStore（不涉及）        │
├─────────────────────────────────────────────────────────────┤
│ 基础设施层                                                   │
│ ArkUI Canvas 2D / TextInput / Stack 面板模式；hypium 本地单测 │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 组件职责

| 组件 | 类型 | 职责 | 边界 |
| ---- | ---- | ---- | ---- |
| PlotPanel | 表现层（新增 Builder） | 绘图 UI：表达式输入（预填）、x 插入、触发绘制、Canvas 渲染坐标轴/刻度/分段曲线、返回、错误提示 | 输入：表达式字符串；输出：用户可见图形；不持有业务逻辑 |
| FunctionPlotter | 业务逻辑层（新增纯逻辑类） | 清洗表达式一次，[-2π,2π] 401 点弧度制采样，逐点有效性判定（isFinite+ErrorFlags+幅值夹持），输出分段数据与 y 轴范围 | 输入：表达式字符串；输出：PlotSegment[]；不做任何 UI/Canvas 操作 |
| CalcEngine | 业务逻辑层（扩展） | 表达式数值求值；新增可选变量 x 绑定 | 第三参缺省时行为与基线完全一致 |
| Expression | 业务逻辑层（扩展） | 预处理；新增 x 隐式乘法规则 | 不含变量语义，仅字符级变换 |
| ErrorFlags | 数据层（复用） | 采样点错误检测 | 不改动其定义 |

### 2.4 交互关系

| 交互 | 方向 | 接口/协议 | 说明 |
| ---- | ---- | --------- | ---- |
| PlotPanel → FunctionPlotter | 调用 | plot(cleanExpr, xMin, xMax, n) | 点"绘制"时一次性执行 |
| FunctionPlotter → Expression | 调用 | getCleanExpression | 采样前清洗一次 |
| FunctionPlotter → CalcEngine | 调用 | evaluate(clean, false, xᵢ) | 每采样点一次，弧度制 |
| FunctionPlotter → ErrorFlags | 调用 | reset()/字段读取 | 每点求值前后 |
| PlotPanel → CalculatorPage 状态 | 事件 | @State showPlot、themeIdx | 面板开关与主题适配 |

**数据流**：
```
用户表达式 → Expression 清洗（一次）→ FunctionPlotter 逐点求值（CalcEngine+ErrorFlags）
          → PlotSegment[]（连续有效段）→ Canvas 坐标映射 → 折线渲染
```

**控制流**：
```
ToggleRow"绘图"点击 → showPlot=true → PlotPanel 呈现（预填表达式）
"绘制"点击 → FunctionPlotter.plot() → 渲染或中文错误提示
"返回"点击 → showPlot=false → 主界面（状态保留）
```

---

## 3. 变更原因

| 原因类型 | 说明 |
| -------- | ---- |
| 业务需求 | Issue #40：从数值计算进入函数可视化；验收要求 sin(x)/x^2 曲线、坐标轴、无效点断线、返回不退化 |
| 技术优化 | 采样器独立为纯逻辑类，使核心数学可本地单测（TDD），UI 与数学解耦 |
| 历史债务 | 无（纯增量） |

---

## 4. 变更点【展开细节】

### 4.1 新增 plot/FunctionPlotter.ets 模块

**变更类型**：新增

**影响的组件**：
| 组件 | 变更内容 |
| ---- | -------- |
| entry/src/main/ets/plot/ | 新目录；FunctionPlotter 类（采样、有效性、分段、y 范围估算） |

**变更理由**：Issue 核心能力；纯逻辑独立便于 hvigorw test@entry 本地单测（采样正确性是验收关键）。

**实现要点**：
- `plot(cleanExpr: string, xMin: number, xMax: number, n: number): PlotResult`；等距采样含双端点
- 每点：ErrorFlags.reset() → evaluate(cleanExpr, false, xᵢ) → 有效 = flags 全 false 且 isFinite(y) 且 |y| ≤ 夹持阈值
- 分段：相邻有效点归同段；无效点断段（moveTo 语义由渲染端执行）
- PlotResult 含段列表与有限样本 yMin/yMax（min==max → ±1；+10% padding）

### 4.2 扩展 CalcEngine 变量绑定

**变更类型**：修改（向后兼容）

**影响的组件**：
| 组件 | 变更内容 |
| ---- | -------- |
| calculator/Calculator.ets | evaluate 增加可选第三参 varX?: number 与实例字段 varXEnabled/varXValue；parseFactor 函数名分支 fn==='x' 且启用绑定时返回变量值 |

**变更理由**：变量语义属于解析器；可选参数保证既有调用点零改动。

**实现要点**：
- 函数名按连续小写字母段解析，`xp`（2 字符）天然优先于单字符 `x`，无新增歧义
- 未启用绑定时 fn==='x' 维持既有 syntax_error 路径

### 4.3 扩展 Expression 隐式乘法

**变更类型**：修改

**影响的组件**：
| 组件 | 变更内容 |
| ---- | -------- |
| calculator/Expression.ets | addMultiply 增加 'x' 字符规则（前邻/后邻隐式乘法），'xp' 序列跳过保护 |

**变更理由**：用户自然输入 `2x`、`x(x+1)`、`πx` 需与既有隐式乘法惯例一致。

**实现要点**：
- 扫描到 'x' 时先判 `substring(i, i+2) === 'xp'` → 跳过（由既有 functionsList 分支处理）
- 前邻 ∈ '.%πex0123456789)' 或数字 → 前插 '*'；后邻 ∈ '0123456789π(ex' 或函数首字母 → 后插 '*'

### 4.4 CalculatorPage 增加绘图入口与 PlotPanel

**变更类型**：修改（UI）

**影响的组件**：
| 组件 | 变更内容 |
| ---- | -------- |
| pages/CalculatorPage.ets | @State showPlot/plotInput/plotError/plotResult；ToggleRow 增加"绘图"；科学区新增 'x' 常量按钮；Stack 增加条件渲染 PlotPanel Builder；Canvas 绘制（坐标轴、π 刻度、分段折线） |

**变更理由**：独立清晰图像区域 + 显式返回；面板模式与 Settings/About 一致，回归面最小。

**实现要点**：
- PlotPanel 为全屏 Column（表达式 TextInput + 按钮行 + Canvas + 错误提示），背景 getPanelBg()，全部取色经既有主题函数
- Canvas 尺寸经 onAreaChange 记录后映射；绘制在触发时执行一次
- 返回按钮固定可点；绘制流程 try/catch → plotError 中文提示

---

## 5. 兼容性说明

### 5.1 对现有功能的影响

| 功能 | 影响 | 处理方式 |
| ---- | ---- | -------- |
| 基础/科学计算 | 理论无影响（varX 默认关闭） | 单测守护：常数表达式结果与基线一致；未绑定 x 仍报"表达式错误" |
| 历史/设置 | 无影响（不触碰 PreferencesStore/HistoryPanel） | 回归由 Tester UI 证据覆盖 |
| 'xp'/exp 函数 | 预处理改动可能误伤 | 'xp' 序列保护 + 单测 AC 守护 |

### 5.2 对现有接口的影响

| 接口 | 变更 | 兼容策略 |
| ---- | ---- | -------- |
| CalcEngine.evaluate | 追加可选第三参 | 可选参数，既有两参调用语义不变 |
| Expression.getCleanExpression | 无签名变化，行为扩展 | 对不含 'x' 的表达式输出与基线逐字符一致 |

### 5.3 对现有数据的影响

无数据模型/持久化变更。

---

## 6. 迁移方案

> 本文档不涉及数据或模块迁移。

### 6.3 回滚方案

变更以单 commit 序列落在 agent/issue-40-task-1 分支；回滚 = revert 该 commit 序列，无数据/配置残留（不改 main_pages.json、module.json5、oh-package 依赖）。

### 6.4 验证方法

`hvigorw assembleHap` BUILD SUCCESSFUL + `hvigorw test@entry` 全部通过 + Tester 模拟器 UI 证据。

---

## 7. 附录

### 7.1 术语表

| 术语 | 定义 |
| ---- | ---- |
| PlotSegment | 连续有效采样点构成的折线段序列 |
| 夹持阈值 | 判定采样点无效的 |y| 上界（tan 发散点为有限大数，需幅值判据） |
| xp | 预处理映射后的 e^x 函数名（源自 'exp'） |

### 7.2 参考文档

- proposal.md / delta-spec.md / info.md（本变更目录）
- opencalc/README.md（架构图与模块清单）
