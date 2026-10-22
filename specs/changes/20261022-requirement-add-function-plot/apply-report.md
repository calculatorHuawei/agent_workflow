# 应用报告（apply-report）

## 应用信息
- 变更类型：新增功能
- 变更名称：function-plot（函数图像绘制 sin(x)，Issue #40）
- 关联全局文件：specs/spec.md / specs/arch.md / specs/design.md
- 关联 Issue：calculatorHuawei/agent_workflow#40
- 应用日期：2026-10-22
- 分支：`agent/issue-40-task-1`（worktree `.agent-runtime/worktrees/developer-issue-40-task-1`）

## 代码完成情况

| 任务 | 状态 | 完成时间 | 证据 |
|------|------|----------|------|
| Task 1.1: hypium 本地测试脚手架 | ✅ 完成 | 2026-10-22 | 空/最小套件 BUILD SUCCESSFUL（logs/verification-log.md V-01）；hypium 1.0.15 入 entry devDependencies + ohpm lock |
| Task 2.1: CalcEngine 变量 x 绑定 | ✅ 完成 | 2026-10-22 | RED（3 参编译错 ×10）→ GREEN；CalcEngineVarX 8/8 |
| Task 2.2: Expression 隐式乘法 x 规则（xp 保护） | ✅ 完成 | 2026-10-22 | ExpressionVarX 13/13（含 2x2→2*x*2、2xp3→2*e^3、基线逐字符不变） |
| Task 2.3: FunctionPlotter 采样与分段 | ✅ 完成 | 2026-10-22 | RED（模块缺失）→ GREEN；FunctionPlotterTest 8/8（sin 单段 / 1/x 两段 / sqrt 定义域 / tan 断段 / x^2 对称 / 常数回退 / 全无效空结果） |
| Task 3.1: CalculatorPage 绘图入口与 PlotPanel 状态 | ✅ 完成 | 2026-10-22 | ToggleRow"绘图"、科学区 'x' 按钮（onConst('x')）、Stack `if (this.showPlot)` 条件渲染、onOpenPlot/onPlot try/catch |
| Task 3.2: PlotPanel 面板与 Canvas 渲染 | ✅ 完成 | 2026-10-22 | TextInput 预填/插入 x/AC/绘制、drawAxes（-2π/-π/0/π/2π 刻度）、drawCurve 分段折线（仅有效点）、取色经既有主题函数 |
| Task 3.3: 构建与测试绿线 | ✅ 完成 | 2026-10-22 | assembleHap BUILD SUCCESSFUL（0 ERROR）；test 30/30 0 失败（logs/verification-log.md V-06/V-07） |

## 变更文件清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `opencalc/entry/src/main/ets/calculator/Calculator.ets` | 修改 | evaluate 追加可选 varX；parseFactor 变量分支（参数解析前短路，未绑定走既有 syntax_error 路径） |
| `opencalc/entry/src/main/ets/calculator/Expression.ets` | 修改 | addMultiply 新增 'x' 双向隐式乘法分支（'xp' 保护，前/后插互不冲突） |
| `opencalc/entry/src/main/ets/plot/FunctionPlotter.ets` | 新增 | PlotPoint/PlotSegment/PlotResult + plot()：清洗一次 → [-2π,2π] 等距 401 点弧度采样 → 逐点 ErrorFlags.reset+判定（全 flags false && isFinite && |y|≤1e6）→ 单遍分段 → y 范围（min==max→±1，+10% padding）→ 全程 try/catch |
| `opencalc/entry/src/main/ets/pages/CalculatorPage.ets` | 修改 | 绘图 @State ×8、PlotPanel @Builder（全屏覆盖层）、drawAxes/drawCurve/mathToPx、绘图入口、科学区 x 按钮；无新路由页（main_pages.json/module.json5 未动） |
| `opencalc/entry/src/test/List.test.ets`、`PlotFunction.test.ets` | 新增 | hypium 本地单测：scaffold 1 + CalcEngineVarX 8 + ExpressionVarX 13 + FunctionPlotterTest 8 |
| `opencalc/entry/oh-package.json5`、`oh-package-lock.json5` | 修改/新增 | 测试依赖 @ohos/hypium 1.0.15 |
| `opencalc/.gitignore` | 修改 | 忽略 `entry/.test/`（本地测试产物目录） |

不改动（约束遵守）：main_pages.json、module.json5、build-profile.json5、根 oh-package.json5、既有错误文案与面板。

## 测试结果
- 单元测试：**通过**（30/30，0 失败 0 错误——`hvigorw --no-daemon --mode module -p module=entry@default test`，exit 0）
- 集成测试：不涉及（无既有集成测试套件）
- Lint 检查：**通过（等效口径）**——`hvigorw lint` 任务在本机 hvigor 6.24.2 不存在（AdaptorError 00306054），以 CompileArkTS 诊断为 lint 门禁：0 ERROR、41 WARN 全部为既有基线告警、无新增（logs/verification-log.md V-06）

## 测试详情

### 单元测试（SR-00 / SR-01 覆盖，对应 delta-spec §8 AC）

- SR-00（CalcEngineVarX）：sin(x)@x=1≈0.8414709848（±1e-9）✓；x^2@2=4、@-3=9 ✓；2*x+1@2=5 ✓；x=0 正确绑定为 0（区别于未定义）✓；未绑定 sin(x) 置 syntax_error ✓；xp(1)≈e 且绑定 x=5 不影响 ✓；既有常数表达式 sin(0)=0、2+3*4=14 不回归 ✓
- SR-00（ExpressionVarX）：2x→2*x、x2→x*2、x(x+1)→x*(x+1)、πx→π*x、ex→e*x、xx→x*x、xln(2)→x*ln(2)、2x2→2*x*2 ✓；'xp' 不拆分（2xp3→2*xp3，求值 2·e³）✓；不含 x 输出逐字符不变（2(3)、2π）✓；语义端到端 2x+1=5、x(x+1)=6 ✓
- SR-01（FunctionPlotterTest）：sin(x) 401 点全有效单段、|y|≤1+1e-9、峰谷四点（i=50/150/250/350）±1 ✓；y 轴范围 ±1.2（10% padding）✓；1/x 在 x=0 无效、两段不相连（400 有效，段=2，负段末点 x<0、正段首点 x>0）✓；sqrt(x) 仅 x≥0 有效（200/201，浮点边界容差）、单段 ✓；tan(x) 渐近线断段（段数>1 且 ≤6，有效点 390~400）✓；x^2 全有效、顶点 (0,0)、对称 y(x)=y(-x)、单调 ✓；常数 2 → y 范围回退 [0.8,3.2] ✓；非法表达式 qq(x) → 全无效空段 ✓
- 工具生成结果：`opencalc/entry/.test/default/intermediates/test/coverage_data/test_result.txt`（副本 `logs/test-final.txt`）；HTML 报告 `opencalc/entry/.test/default/outputs/test/reports/index.html`

### Lint 检查
见上文"测试结果"第三条。新增代码无任何 ERROR/WARN 级诊断。

## 实现要点与偏差记录

1. **测试命令修正**：init flag 记载 `hvigorw test@entry`，实际该任务名在本机 hvigor 6.24.2 无效；本会话使用 `hvigorw --mode module -p module=entry@default test`（工作流入口门禁亦如此要求）。
2. **环境限制**：hvigor daemon 存在时编译会触发 Node "Zone Allocation failed" OOM——每次构建前 `hvigorw --stop-daemon` 后以 `--no-daemon` 运行。
3. **TDD 修正 2 处**：①测试索引错误（sin 谷值应为 i=150），实现无错；②`ctx.textAlign` 类型（TextAlign→CanvasTextAlign 字面量 'center'），HAP 构建期 stricter 检查发现，单测编译不报。
4. **lint 任务缺失**：以 CompileArkTS 诊断替代（详见验证日志）。
5. **签名**：本地无 signingConfig，产物为未签名 HAP（与基线一致）；Tester 侧签名安装流程不在 Developer 范围。

## 下一步

- Developer 产物就绪，等待独立 Tester 在连接的 HarmonyOS 模拟器上安装**准确 PR SHA** 构建的 HAP 并执行真实 UI 操作（sin(x) 曲线+坐标轴、x^2 抛物线、返回无退化、三主题可读）。
- 按工作流约束，本阶段**不执行归档**（migbot-increment-archiving 留待 Tester 证据与双 Reviewer 闸门通过后）。
