# 函数图像绘制（Issue #40） 开发任务

## 任务概述

- 功能名称：函数图像绘制（sin(x) 显示曲线）
- 变更类型：新增功能
- 关联全局文件：specs/spec.md / specs/arch.md / specs/design.md
- 开发阶段：IMPLEMENTING → APPLYING（TDD：先测后码）
- 预计任务数：7

## 任务列表

### 阶段 1：基础设施与测试脚手架

#### Task 1.1: hypium 本地测试脚手架
**描述**：创建 `entry/src/test/` 本地单测入口与聚合文件（hypium 已在根 devDependencies）。首建后先运行一次空套件验证 `hvigorw test@entry` 可用（测试框架首次搭建风险消解）。
**涉及文件**：
- 测试：`opencalc/entry/src/test/List.test.ets`（testsuite 聚合）
- 测试：`opencalc/entry/test/`（如 test@entry 要求本地测试运行配置则按 hvigor 报错补齐）
**依赖任务**：无
**验收标准**：
- `hvigorw test@entry` 以空/最小套件退出码 0（或给出明确的可修复配置缺口并修复）
- 既有 `hvigorw assembleHap` 不受影响
**TDD**：[x] RED（空套件先行） / [x] GREEN（框架跑通） / [x] REFACTOR（不适用）

### 阶段 2：核心逻辑（SR-00 → SR-01）

#### Task 2.1: CalcEngine 变量 x 绑定
**描述**：`evaluate(equation, isDegree, varX?)` 追加可选参数；私有字段 varXEnabled/varXValue（evaluate 入口设置）；parseFactor 函数名分支增加 `fn==='x' && varXEnabled → 返回 varXValue`（其后 `^` 幂处理沿用既有尾部逻辑）；未启用绑定时行为与基线逐位一致（fn==='x' → 既有 syntax_error 路径）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/calculator/Calculator.ets`
- 测试：`opencalc/entry/src/test/PlotFunction.test.ets`（套件 CalcEngineVarX）
**依赖任务**：Task 1.1
**验收标准**：
- x=1 时 sin(x)≈0.8414709848（±1e-9，弧度）
- x=2 时 x^2=4；未绑定 sin(x) 置 syntax_error；xp(1)≈e
- 既有常数表达式结果不变（如 sin(0)=0、2+3*4=14）
**TDD**：[x] RED（3 参 evaluate 编译错，Expected 2 arguments but got 3 ×10）/ [x] GREEN（CalcEngineVarX 8/8）/ [x] REFACTOR（不适用）

#### Task 2.2: Expression 隐式乘法 x 规则（xp 保护）
**描述**：addMultiply 扫描到 'x'（且 `substring(i,i+2)!=='xp'`）时执行双向隐式乘法：前邻 ∈ "0123456789)πex"（或为数字）→ 前插 '*'；后邻 ∈ "0123456789π(ex" 或小写字母（函数名首字符）→ 后插 '*'。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/calculator/Expression.ets`
- 测试：`opencalc/entry/src/test/PlotFunction.test.ets`（套件 ExpressionVarX）
**依赖任务**：Task 2.1（用其验证语义正确性）
**验收标准**：
- getCleanExpression 输出：2x→2*x、x2→x*2、x(x+1)→x*(x+1)、πx→π*x、ex→e*x、xx→x*x、xln(2)→x*ln(2)
- 不含 x 的输入输出与基线逐字符一致；'xp' 不被拆分（2xp3 清洗后为 2*xp3 形态且求值 2*e^3）
**TDD**：[x] RED（ExpressionVarX 语义用例随 RED 轮失败）/ [x] GREEN（ExpressionVarX 13/13）/ [x] REFACTOR（不适用）

#### Task 2.3: FunctionPlotter 采样与分段
**描述**：新建 `plot/FunctionPlotter.ets`：PlotPoint/PlotSegment/PlotResult 接口 + FunctionPlotter.plot(expr, xMin, xMax, n)。内部：清洗一次 → n 点等距采样（含双端点）→ 每点 ErrorFlags.reset()+evaluate(clean,false,xᵢ) → valid = 全 flags false && isFinite(y) && |y|≤1e6 → 单遍分段 → y 范围（有限样本，min==max→±1，+10% padding）。全程 try/catch 不抛异常。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/plot/FunctionPlotter.ets`
- 测试：`opencalc/entry/src/test/PlotFunction.test.ets`（套件 FunctionPlotterTest）
**依赖任务**：Task 2.1、Task 2.2
**验收标准**（对应 delta-spec SR-01 AC1-5）：
- sin(x)：401 点全有效、单段、|y|≤1+ε
- 1/x：x=0 无效，两侧分段且不相连（段数=2）
- sqrt(x)：仅 x≥0 有效
- tan(x)：±π/2 邻域断段（段数>1）
- x^2：全有效、对称、顶点 (0,0)
**TDD**：[x] RED（Cannot find module '../main/ets/plot/FunctionPlotter'）/ [x] GREEN（FunctionPlotterTest 8/8；含 1 处测试索引修正：sin 谷值在 i=150 即 x≈-π/2）/ [x] REFACTOR（测试显式 PlotPoint[] 类型）

### 阶段 3：UI 表现层（SR-02）

#### Task 3.1: CalculatorPage 绘图入口与 PlotPanel 状态
**描述**：新增 @State showPlot/plotInput/plotError/plotSegments/plotYMin/plotYMax/canvasW/canvasH；私有方法 onOpenPlot()/onPlot()/mathToPx()；ToggleRow 增加"绘图"入口；科学区新增 'x' 按钮（onConst('x')）；Stack 增加 `if (this.showPlot) this.PlotPanel()`。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 2.3
**验收标准**：
- 入口可见、面板全屏条件渲染、返回后主界面状态保留（代码审查 + Tester UI）
- 空表达式/全无效有中文提示；绘制流程 try/catch 不崩溃
**TDD**：[ ] RED（逻辑层经 Task 2.3 覆盖） / [ ] GREEN / [ ] REFACTOR

#### Task 3.2: PlotPanel 面板与 Canvas 渲染
**描述**：@Builder PlotPanel()：标题行（"函数绘图"+✕ 返回）、TextInput（预填）、按钮行（插入 x/AC/绘制）、plotError 文本、Canvas（layoutWeight(1)，onReady/onAreaChange 记录尺寸）；drawAxes（横纵轴+x 轴 π 刻度标签）与 drawCurve（分段 moveTo/lineTo，仅绘制 PlotSegment 有效点）；全部取色经既有主题函数。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 3.1
**验收标准**：
- sin(x) 呈现坐标轴+连续正弦曲线；x^2 呈现抛物线（UI 由 Tester 模拟器验证）
- 3 主题下可读（轴线/曲线/文字对比度）
**TDD**：[x] N/A（渲染层，由构建 + Tester UI 证据覆盖）

#### Task 3.3: 构建与测试绿线
**描述**：全量验证：`hvigorw assembleHap` BUILD SUCCESSFUL 且 `hvigorw test@entry` 全部用例通过；修复任一回归。
**涉及文件**：无新增（验证任务）
**依赖任务**：Task 3.2
**验收标准**：
- assembleHap 退出码 0；test@entry 退出码 0、0 失败
- 无新增 ArkTS ERROR 级告警（既有 WARN 不扩大）
**TDD**：[x] N/A（验证任务）

## 开发顺序

```
Task 1.1 → Task 2.1 → Task 2.2 → Task 2.3 → Task 3.1 → Task 3.2 → Task 3.3 → 完成
```

## 验收计划

| 任务 | 验收方式 | 验收时间 |
|------|---------|----------|
| Task 1.1 | hvigorw test@entry 退出码 | 2026-10-22 |
| Task 2.1 | 单元测试（CalcEngineVarX 套件） | 2026-10-22 |
| Task 2.2 | 单元测试（ExpressionVarX 套件） | 2026-10-22 |
| Task 2.3 | 单元测试（FunctionPlotterTest 套件） | 2026-10-22 |
| Task 3.1 | 代码审查 + 构建 | 2026-10-22 |
| Task 3.2 | 代码审查 + 构建（UI 证据归 Tester） | 2026-10-22 |
| Task 3.3 | 全量构建+测试绿线 | 2026-10-22 |
