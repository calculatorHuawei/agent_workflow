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
（补救轮）Task 4.1 → Task 4.2 → Task 4.3 → Task 4.4 → 完成
（补救轮 R5）Task 5.1 → Task 5.2 → Task 5.3 → Task 5.4 → Task 5.5 → 完成
```

## 补救轮任务（R4 可读坐标系，PR #41 changes_requested，2026-10-22 追加）

#### Task 4.1: PlotAxis 纯逻辑 TDD（RED→GREEN）
**描述**：先在 `entry/src/test/PlotFunction.test.ets` 新增 PlotAxisTest 套件（刻度计算 + 边缘安全标签布局 + 主题色/字号契约），运行确认失败（RED，模块未实现编译错）；再实现 `plot/PlotAxis.ets`（AxisTick/xAxisTicks/yTicks nice-number/hLabelLayout/vLabelLayout/PLOT_LABEL_FONT_PX≥14/plotGridColor/plotLabelColor，退化输入返回空数组）使全部用例通过（GREEN）。
**涉及文件**：
- 测试：`opencalc/entry/src/test/PlotFunction.test.ets`（套件 PlotAxisTest，先写）
- 实现：`opencalc/entry/src/main/ets/plot/PlotAxis.ets`（后写）
**依赖任务**：Task 3.3（首轮绿线基线）
**验收标准**（delta-spec SR-03 AC1-6）：
- RED：套件因 PlotAxis 缺失编译失败，证据留存 logs/test-red.txt
- GREEN：X 刻度 [-2π,2π] 恰 5 条（-2π/-π/0/π/2π 及标签）；Y 刻度 [-1.2,1.2] ≥5 条含 -1/-0.5/0/0.5/1；[0.8,3.2] ≥5 条；退化输入空数组不抛异常；四角+中部标签布局不越界；三主题网格色/标签色/背景两两不同；字号常量 ≥14
**TDD**：[x] RED（logs/test-red.txt，`Cannot find module '../main/ets/plot/PlotAxis'`）/ [x] GREEN（logs/test-green.txt，PlotAxisTest 10/10，全量 40/40；本会话恢复后复跑复核 40/40）/ [x] REFACTOR（不适用——纯函数）

#### Task 4.2: CalculatorPage 坐标系渲染重写
**描述**：drawPlot 固化绘制顺序 clear→drawGrid→drawAxes→drawTickLabels→drawAxisNames→drawRangeText→drawCurve；drawGrid 以 PlotAxis 刻度画 1px 低对比网格；drawAxes/drawTickLabels 以 14px+plotLabelColor 绘制并经 hLabelLayout/vLabelLayout 夹持；新增轴名 'x'/'y' 与范围文本 `x∈[-2π, 2π] y∈[-1.2, 1.2]`；不做缩放/平移/自定义范围。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 4.1
**验收标准**：
- CompileArkTS 0 ERROR；既有 30 用例不回归
- 绘制顺序保证网格不遮挡曲线（代码审查 + Tester UI 三主题截图）
**TDD**：[x] N/A（渲染层，由 Task 4.1 纯逻辑单测 + Tester UI 证据覆盖）

#### Task 4.3: 全量绿线验证
**描述**：`hvigorw --mode module -p module=entry@default test` 全部通过（30+新增）且 `hvigorw assembleHap` BUILD SUCCESSFUL；证据写入 logs/。
**涉及文件**：无新增（验证任务）
**依赖任务**：Task 4.2
**验收标准**：test 退出码 0、0 失败；assembleHap 退出码 0；无新增 ERROR/WARN 扩大
**TDD**：[x] N/A（验证任务）

#### Task 4.4: 补救轮 APPLYING 与 PR 推进
**描述**：更新 apply-report.md（补救轮章节）与 logs/verification-log.md；提交 HEAD 并显式推送到 PR #41 头分支 agent/issue-40-task-1；校验 PR head SHA 与本地 HEAD 一致；产出 developer→tester 移交。
**涉及文件**：`specs/changes/20261022-requirement-add-function-plot/apply-report.md`、`logs/*`
**依赖任务**：Task 4.3
**验收标准**：
- apply-report.md 含补救轮验收对照与验证命令退出码
- 远端 agent/issue-40-task-1 HEAD == 本地提交 SHA == PR #41 head SHA
- 不归档（用户明确要求）
**TDD**：[x] N/A（过程任务）

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

## 补救轮任务（R5 渐近线视觉分离，PR #41 user_feedback，2026-10-22 追加）

#### Task 5.1: 渐近线分离回归测试 TDD（RED）
**描述**：先在 `entry/src/test/PlotFunction.test.ets` 新增 AsymptoteSeparationTest 套件（引用尚不存在的 PLOT_VIEW_INSET_RATIO 常量触发编译失败=RED），断言：1/x ≥2 段/全点在 [yMin+inset,yMax−inset] 窗内/最小 \|x\|≥2 步长/无跨正负号段；log(x) 全 x>0/最小 x≥2 步长/最低点≥yMin+inset−ε/单段；tan(x) 每段同一 π/2 区间/距最近渐近线 ≥2 步长；sin(x) 单段 401 点 maxY≥0.999 零回归；x² 单段 401 点含 (0,0) 零回归；sqrt(x) 绘制 x≥1 步长。运行留存 logs/test-red-r5.txt。
**涉及文件**：
- 测试：`opencalc/entry/src/test/PlotFunction.test.ets`（套件 AsymptoteSeparationTest，先写）
**依赖任务**：Task 4.3（R4 绿线基线）
**验收标准**：
- RED：套件编译失败（Cannot find module/导出缺失），证据留存 logs/test-red-r5.txt
**TDD**：[x] RED（logs/test-red-r5.txt：`has no exported member 'PLOT_VIEW_INSET_RATIO'`，BUILD FAILED）/ [x] GREEN（logs/test-green-r5.txt）/ [x] REFACTOR（不适用）

#### Task 5.2: FunctionPlotter 视窗裁剪+断口阴影（GREEN）
**描述**：实现 delta-design §12.2.3：导出 PLOT_VIEW_INSET_RATIO=1/20；buildSegments 单遍构建中 drawable = valid ∧ y∈[yMin+inset, yMax−inset]，断口（无效或窗外）后首个可绘制点若为发散尾部（\|y\|>span/2）阴影化（每断口 1 点）；可绘制总数为 0 且 totalValid>0 时回退绘制全部有效点。plot() 签名/返回/totalValid 语义不变。实现中发现并修复同源缺陷：yRange 稳健修剪对 tan 的对称成对极值失效，修剪比例改 2%→5%→10% 逐级（见偏差记录）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/plot/FunctionPlotter.ets`
**依赖任务**：Task 5.1
**验收标准**（delta-spec SR-04 AC1-AC5）：
- 1/x：≥2 段、绘制点全在窗内、最小 \|x\|≥2 步长（实测 9 步长）
- log(x)：单段、起点 x≥2 步长、不贴底边
- tan(x)：各段同一 π/2 区间、距渐近线 ≥2 步长（实测 5 步长，范围 ±7.6）
- sin(x)/x²：绘制集合零变化（401 点单段、峰值/顶点保留）
- AsymptoteSeparationTest 全过 + 既有套件零回归，证据 logs/test-green-r5.txt
**TDD**：[x] RED / [x] GREEN（51/51，0 失败）/ [x] REFACTOR（不适用——单遍纯函数）

#### Task 5.3: 轴线可辨与像素防御夹持
**描述**：drawAxes 轴线色 plotLabelColor→getT1（主文字色）、lineWidth 1→2（保持绘制于曲线之后）；drawCurve 对 mathToPx 结果做 [−2,w+2]×[−2,h+2] 超扫夹持（delta-design §12.3）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 5.2
**验收标准**（delta-spec SR-04 AC6）：
- CompileArkTS 0 ERROR；绘制顺序不回归（曲线→轴覆盖）
- 三主题可辨由 Tester 截图终验（SC006-UC002 分工）
**TDD**：[x] N/A（渲染层，由 Task 5.1 纯逻辑单测 + 构建 + Tester UI 证据覆盖）

#### Task 5.4: 全量绿线验证（R5）
**描述**：`hvigorw --no-daemon --mode module -p module=entry@default test` 全部通过（40+新增）且 `hvigorw --no-daemon assembleHap` BUILD SUCCESSFUL；先 ohpm install（新检出工作树）；证据写入 logs/。
**涉及文件**：无新增（验证任务）
**依赖任务**：Task 5.3
**验收标准**：test 退出码 0、0 失败；assembleHap 退出码 0；无新增 ERROR/WARN 扩大
**TDD**：[x] N/A（验证任务）——test 51/51（0 失败）+ assembleHap BUILD SUCCESSFUL（0 ERROR，WARN 全部既有基线），证据 logs/test-green-r5.txt

#### Task 5.5: 补救轮 R5 APPLYING 与 PR 推进
**描述**：更新 apply-report.md（R5 章节）与 logs/verification-log.md；提交 HEAD 并显式推送到 PR #41 头分支 agent/issue-40-task-1；校验 PR head SHA 与本地 HEAD 一致；产出 developer→tester 移交。
**涉及文件**：`specs/changes/20261022-requirement-add-function-plot/apply-report.md`、`logs/*`
**依赖任务**：Task 5.4
**验收标准**：
- apply-report.md 含 R5 验收对照与验证命令退出码
- 远端 agent/issue-40-task-1 HEAD == 本地提交 SHA == PR #41 head SHA
- 不归档（用户明确要求）
**TDD**：[x] N/A（过程任务）
