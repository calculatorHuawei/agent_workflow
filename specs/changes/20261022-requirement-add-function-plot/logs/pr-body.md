## 概述

实现 Issue #40：支持绘制函数图像，输入 `sin(x)` 显示曲线。MigBot Developer 增量（PLANNING → IMPLEMENTING → APPLYING 产物齐备，不归档）。

## 实现

- **CalcEngine**（`calculator/Calculator.ets`）：`evaluate(equation, isDegree, varX?)` 可选变量绑定；parseFactor 在函数参数解析前短路 `x` 分支（裸 x 可直接跟 `^`）；未绑定时 `x` 走既有 syntax_error 路径，既有表达式行为逐位不变
- **Expression**（`calculator/Expression.ets`）：addMultiply 变量 `x` 双向隐式乘法（`2x→2*x`、`x2→x*2`、`2x2→2*x*2`），`xp`（e^x 函数名）保护，不含 x 的输入输出与基线逐字符一致
- **FunctionPlotter**（新增 `plot/FunctionPlotter.ets`）：清洗一次 → [-2π,2π] 等距 401 点弧度制采样 → 逐点 ErrorFlags.reset+有效性判定（flags 全 false && isFinite && |y|≤1e6）→ 单遍分段（无效点断线）→ y 范围（min==max→±1、+10% padding）→ 全程 try/catch 不抛异常
- **CalculatorPage**：全屏 PlotPanel 覆盖层（非新路由页）：标题/返回、TextInput 预填、插入 x/AC/绘制、中文错误提示、Canvas 坐标轴（-2π/-π/0/π/2π 刻度）+ 分段曲线；ToggleRow "绘图"入口；科学区 `x` 按钮；配色经既有主题函数（3 主题适配）
- 不改动：main_pages.json / module.json5 / build-profile.json5 / 既有错误文案

## 测试证据

- 本地 Hypium：`hvigorw --no-daemon --mode module -p module=entry@default test` → **30/30 通过，0 失败**（scaffold 1、CalcEngineVarX 8、ExpressionVarX 13、FunctionPlotterTest 8：sin 单段、1/x 断段两段、sqrt 定义域、tan 渐近线断段、x^2 对称/顶点、常数回退、全无效空结果）
- 构建：`hvigorw --no-daemon assembleHap` → **BUILD SUCCESSFUL**，0 ERROR、41 WARN 全部既有基线、无新增；产物 `entry-default-unsigned.hap`（259,054 字节）
- Lint：`hvigorw lint` 任务在 hvigor 6.24.2 不存在，以 CompileArkTS 诊断为等效门禁（见 logs/verification-log.md V-06）
- 完整证据：`specs/changes/20261022-requirement-add-function-plot/apply-report.md`、`logs/verification-log.md`、`logs/test-final.txt`

## TDD 记录

三轮 RED→GREEN：①3 参 evaluate 编译错×10 → 引擎实现 GREEN；②语义用例失败 → 隐式乘法 GREEN；③FunctionPlotter 模块缺失 → 采样器 GREEN。修正 2 处：测试索引错误（sin 谷值 i=150）、CanvasTextAlign 类型。

## Tester 注意事项

- 设备/UI 验证（sin(x) 曲线+坐标轴、x^2 抛物线、返回无退化、三主题可读）由 Tester 在模拟器上执行，Developer 未做设备端验证
- 本地构建无 signingConfig（与基线一致），Tester 侧需自行签名安装
- hvigor daemon 会导致 Node OOM，构建前先 `hvigorw --stop-daemon`，测试命令用 `--mode module -p module=entry@default test`

Closes #40

🤖 Generated with [Claude Code](https://claude.com/claude-code)
