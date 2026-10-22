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

---

# 补救轮应用报告（R4 可读坐标系，PR #41 changes_requested，2026-10-22 追加）

> 来源：用户 changes_requested（Issue #40 评论 + PR #41 评论，2026-10-22）。Tester 实测判定首轮坐标系"不可用/不可读"。
> 本轮继续使用本变更目录（用户明确要求**不归档、不新建目录**）；PLANNING 9 步补救轮产物见 proposal §11 / delta-spec R4+SC-005+SR-03+CM-07~10 / info §11 / delta-design §11 / design-review 补救轮（结论=通过）。

## 补救轮代码完成情况

| 任务 | 状态 | 完成时间 | 证据 |
|------|------|----------|------|
| Task 4.1: PlotAxis 纯逻辑 TDD（RED→GREEN） | ✅ 完成 | 2026-10-22 | RED：logs/test-red.txt（`Cannot find module '../main/ets/plot/PlotAxis'`，BUILD FAILED）；GREEN：logs/test-green.txt（PlotAxisTest 10/10，全量 40/40）；恢复会话独立复跑复核 40/40（logs/test-final-r4.txt、verification-log.md V-R4-03） |
| Task 4.2: CalculatorPage 坐标系渲染重写 | ✅ 完成 | 2026-10-22 | drawPlot 顺序固化 clear→drawGrid→drawAxes→drawTickLabels→drawAxisNames→drawRangeText→drawCurve（曲线恒最后，CM-10）；14px 标签 + hLabelLayout/vLabelLayout 边缘夹持（CM-07）；轴名 x/y + 范围文本 `x∈[-2π, 2π] y∈[-1.2, 1.2]`；三主题经 plotGridColor/plotLabelColor；CompileArkTS 0 ERROR（V-R4-04） |
| Task 4.3: 全量绿线验证 | ✅ 完成 | 2026-10-22 | test 40/40、0 失败（exit 0）；assembleHap BUILD SUCCESSFUL（exit 0，未签名与基线一致）；0 ERROR、既有 WARN 不扩大（logs/test-final-r4.txt） |
| Task 4.4: 补救轮 APPLYING 与 PR 推进 | ✅ 完成 | 2026-10-22 | 本节 + logs/verification-log.md V-R4-01~04 + logs/test-final-r4.txt；HEAD 显式推送 PR #41 头分支 `agent/issue-40-task-1` 并校验 PR head SHA 一致；**不归档** |

## 补救轮变更文件清单

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `opencalc/entry/src/main/ets/plot/PlotAxis.ets` | 新增 | 纯逻辑（无 UI 依赖，SDR-04 惯例）：AxisTick/TickLabelLayout、xAxisTicks（π 倍数步长，[-2π,2π]→-2π/-π/0/π/2π）、yTicks（nice-number {1,2,5}×10^k，≥minCount，[-1.2,1.2]×5→-1/-0.5/0/0.5/1）、hLabelLayout/vLabelLayout（边缘夹持+对齐）、plotGridColor（浅 #E0E0E0/AMOLED #1E1E1E/暗 #474747，暗色自 #2A2A2A 修正——面板 #323232 上不可见）、plotLabelColor、PLOT_LABEL_FONT_PX=14；退化输入返回空数组不抛异常 |
| `opencalc/entry/src/main/ets/pages/CalculatorPage.ets` | 修改 | drawPlot 重写（绘制顺序固化，曲线恒最后）；新增 drawGrid/drawTickLabels/drawAxisNames/drawRangeText/formatPi/applyHAlign/applyVBaseline；刻度与布局全部来自 PlotAxis 纯函数；不新增 @State、不做缩放/平移/自定义范围（用户排除项） |
| `opencalc/entry/src/test/PlotFunction.test.ets` | 修改 | 新增 PlotAxisTest 套件 10 用例（X π 刻度值+标签 / Y ≥5 条含 ±1、±0.5、0 / 常函数范围 / 退化空数组 / 左右中水平夹持 / 上下中垂直夹持 / 三主题色两两不同+字号≥14） |
| `specs/changes/20261022-requirement-add-function-plot/*` | 修改 | proposal §11、delta-spec R4/SC-005/SR-03/CM-07~10、info §11、delta-design §11、design-review 补救轮、tasks.md 补救轮 Task 4.1-4.4、todo.md、logs/test-red.txt、logs/test-green.txt、logs/test-final-r4.txt、logs/verification-log.md V-R4 |

## 补救轮测试结果

- 单元测试：**通过**（40/40，0 失败 0 错误——`hvigorw --no-daemon --mode module -p module=entry@default test`，exit 0；SR-03 新增 10 + 既有 30 零回归）
- 集成测试：不涉及（无既有集成测试套件）
- Lint 检查：**通过（等效口径）**——`hvigorw lint` 任务在本机 hvigor 6.24.2 不存在（同首轮 AdaptorError 00306054），以 CompileArkTS 诊断为 lint 门禁：0 ERROR、WARN 全部既有基线告警、无新增（V-R4-04）

## 用户 changes_requested 逐条对照

| # | 用户要求 | 处置 | 证据 |
|---|---------|------|------|
| 1 | X 刻度 -2π/-π/0/π/2π 可读、边缘不裁切 | xAxisTicks 恰产 5 条 π 刻度；标签经 hLabelLayout 水平 + vLabelLayout 垂直双轴夹持（左缘左对齐/右缘右对齐，间距 ≥4px） | PlotAxisTest xaxis_default_range_five_pi_ticks、hlabel_*_clamped；Tester UI 截图终验 |
| 2 | ≥5 条自动 Y 刻度，sin(x) 含 -1/-0.5/0/0.5/1 | yTicks nice-number（{1,2,5,10}×10^k 候选取满足条数最大步长）；sin(x) y 范围 ±1.2 → 步长 0.5 → 恰含五值 | PlotAxisTest yaxis_sin_range_five_ticks_include_half_steps、yaxis_constant_expr_range_still_five |
| 3 | 低对比水平+垂直网格线，位于曲线之后方 | drawGrid 1px plotGridColor 先于曲线绘制（顺序固化 网格→轴→标签→轴名→范围→曲线） | delta-design §11.3.1（CM-10）；Tester UI 截图终验 |
| 4 | 轴名标签 + 当前 X/Y 范围显示 | drawAxisNames（'x' 轴右端上方、'y' 轴顶端右侧，均经夹持）；drawRangeText（`x∈[-2π, 2π]  y∈[-1.2, 1.2]`，左上角） | delta-design §11.3.3；Tester UI 截图终验 |
| 5 | 标签 ≥14px 且浅色/暗色/AMOLED 三主题可读 | PLOT_LABEL_FONT_PX=14 常量（单测断言 ≥14）；plotLabelColor 浅 #595959/深 #BDBDBD、plotGridColor 三主题两两不同于背景（单测断言） | PlotAxisTest theme_colors_and_font_contract；Tester 三主题截图终验 |
| 6 | 刻度计算与边缘安全标签布局 TDD 先行 | PlotAxisTest 10 用例先写，RED 编译失败证据留存（test-red.txt），后实现转 GREEN | logs/test-red.txt → logs/test-green.txt → V-R4-03 复跑 40/40 |
| 7 | 不做缩放/平移/自定义范围 | 未实现任何对应交互/状态；delta-spec §5 约束 7 明确排除 | 代码审查（CalculatorPage 无对应分支） |
| 8 | 更新既有变更目录、不归档 | 全部产物追加于 20261022-requirement-add-function-plot/；未调用 migbot-increment-archiving | 本报告；git 历史 |
| 9 | 推送最终 HEAD 至 agent/issue-40-task-1 并校验 PR #41 head | HEAD 显式推送该分支（fast-forward 自 39b7661）；`gh api` 校验 PR head.sha == 本地 HEAD | 见 verification-log.md V-R4-05 |

## 补救轮实现要点与偏差记录

1. **暗色网格色修正**：proposal §11.2 初定暗色 #2A2A2A，设计阶段发现其与暗色面板背景 #323232 近似不可见，修正为 #474747（delta-design §11.2.2 已记录），单测按修正值断言。
2. **TDD 环境事项**：R4 前序会话 RED 首跑暴露新检出工作树缺 oh_modules（`Failed to resolve OhmUrl for "@ohos/hypium"`），按门禁补 `ohpm install` 后取得有效 RED；本恢复会话同样先 ohpm install（V-R4-01）再复跑。
3. **hvigor daemon OOM 规避**：延续首轮做法，统一 `--no-daemon` 运行。
4. **签名**：本地无 signingConfig，产物为未签名 HAP（与基线一致）；Tester 侧签名安装流程不在 Developer 范围。
5. **UI 视觉项边界**：网格不遮挡曲线、三主题对比度、边缘不裁切的**实际视觉效果**需真机/模拟器确认，Developer 仅提供纯逻辑单测 + 构建证据（SC005-UC002 分工），已在 delta-spec 标注 Tester 责任。

## 补救轮下一步

- Developer 产物就绪（ready_for_test）：等待独立 Tester 在模拟器验证 PR head SHA 构建的 HAP——重点：X 刻度五标签无裁切、Y ≥5 刻度、网格不遮挡曲线、轴名与范围文本、三主题 14px 可读；既有验收（sin(x) 曲线、x^2、返回无退化）不豁免。
- **不归档**（用户明确要求；归档留待 Tester 证据与双 Reviewer 闸门通过后）。

---

# 缺陷修复轮应用报告（R5 渐近线与 Y 轴可读性，2026-10-22 追加）

## 修复内容

- `FunctionPlotter` 使用 2%~98% 中心样本估算稳健可视范围；仅当原始范围超过中心范围 3 倍时启用，避免影响 `sin(x)`、`x^2` 等正常函数。
- 当相邻有效点跨过零值且跳变超过可视跨度 1.5 倍时断段，覆盖偶数采样没有恰好命中渐近线的 `1/x`。
- 绘制顺序改为网格→曲线→坐标轴→标签，使渐近线曲线不再覆盖 Y 轴。
- 持久化 `1/x`、`log(x)`、`tan(x)` UI 回归用例到 `ui-tests/asymptote-regression.md`。

## TDD 与验证

- RED：偶数 400 点采样的 `1/x` 原实现得到 1 段而非 2 段；原 Y 范围不满足主体可读性阈值。
- GREEN：新增 4 条回归单测后完整 Hypium 套件通过，无失败输出。
- 构建：`assembleHap` BUILD SUCCESSFUL。
- 模拟器：hdc 3.2.0d，`127.0.0.1:5555`；`1/x`、`log(x)`、`tan(x)` 三条 UI 用例全部通过。
- 运行证据：`.agent-runtime/evidence/plot-asymptote-remediation/`。
