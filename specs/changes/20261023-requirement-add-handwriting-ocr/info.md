# 拍照识别手写算式并自动填入 - 代码仓理解

## 1. 基本信息

- **产品需求类别**：新增功能
- **本次任务类别**：缺陷修复（既有实现交付门禁纠偏）
- **分析时间**：2026-10-24
- **分析范围**：`opencalc/entry/src/main`、构建配置、现有测试与全局 specs
- **重点**：架构/公共组件/接口与契约/权限约束/影响范围/测试策略

## 2. 模块架构

```text
Index (@Entry, replaceUrl)
  └─ CalculatorPage (@Entry, 单页聚合 UI/状态)
      ├─ calculator/Expression + Calculator + ErrorFlags
      ├─ preferences/PreferencesStore
      ├─ plot/FunctionPlotter + PlotAxis
      ├─ recognition/：model / platform / service / view
      └─ Stack 条件覆盖层：Settings / About / Plot / RecognitionPanel
```

- 单 `entry` HAP，phone/tablet，Stage 模型，ArkUI V1 状态管理（`@State`）。
- `CalculatorPage` 持有 `expression`，输入按钮只拼接字符；`onEquals()` 才调用 `Expression.getCleanExpression` 与 `CalcEngine.evaluate`。
- 识别确认沿用 `Stack` 条件覆盖层惯例；拍照通过系统 `cameraPicker`，应用不自建相机预览页。
- 当前已使用 `@kit.CameraKit`、`@kit.CoreVisionKit`、`@kit.ImageKit`；无网络运行时依赖。

## 3. 接口与契约

| 接口/事件 | 位置 | 契约 |
|-----------|------|------|
| `onDigit/onOp/onFunc/onConst` | CalculatorPage | 直接追加到 `expression` 并清错误 |
| `onEquals` | CalculatorPage | 非空时清 ErrorFlags、清洗并求值；成功后写历史 |
| `Expression.getCleanExpression` | calculator/Expression.ets | 做符号替换、隐式乘法、特殊运算格式化与括号补全；它不是不可信文本的完整白名单验证器 |
| `CalcEngine.evaluate` | calculator/Calculator.ets | 求值入口；通过 ErrorFlags 表达语法/定义域错误 |
| `PreferencesStore` | preferences/PreferencesStore.ets | 主题、模式、历史等持久化；识别链路未接入此存储 |
| `RecognitionCoordinator` | recognition/service | 会话 ID、状态转换、重试/取消、迟到回调隔离、确认门禁 |
| `ExpressionValidator` | recognition/service | 归一化、128 长度、字符白名单与基础四则 grammar |
| `HarmonyCaptureGateway` | recognition/platform | `cameraPicker.pick` 获取单张照片 URI |
| `OnDeviceHandwritingOcrProvider` | recognition/platform | CoreVisionKit 初始化、PixelMap 创建、端侧识别与资源释放 |

关键约束：安全边界必须位于 `Expression.getCleanExpression/evaluate` 之前。识别确认不得复用 `onEquals()`，只能受控更新 `expression`。

## 4. 构建与集成

- 构建根：`opencalc/`；单 entry 模块；compatible/target SDK `5.0.0(12)`。
- 运行时依赖仍无第三方网络包；端侧 OCR 由系统 Kit 提供，不得引入网络、账号、密钥、付费服务或新的远端数据处理方。
- `module.json5` 已声明 `ohos.permission.CAMERA` 的 user_grant 配置并由权限网关运行时申请。
- 页面清单仍只有 Index 与 CalculatorPage；系统相机 picker + 覆盖层未增加路由。
- 本地测试：`entry/src/test` 已有 Hypium；worker 规则指定 `hvigorw --mode module -p module=entry@default test`，初始化标记中的旧命令 `hvigorw test@entry` 不应继续沿用。

## 5. 影响范围

| 模块/文件 | 影响 | 风险 |
|-----------|------|------|
| CalculatorPage.ets | 入口、会话状态、面板、确认写入 | 单文件已较大；状态耦合与布局回归 |
| module.json5 | 相机权限声明 | reason/usedScene/API 版本错误会构建或审核失败 |
| recognition/model | 新增会话/错误/校验模型 | 状态遗漏导致原输入被覆盖 |
| recognition/service | 已有协调器、校验器、OCR 抽象 | 真机 OCR 行为待 Tester 验证 |
| recognition/platform | 权限/拍照适配 | 永久拒绝判定及设备差异 |
| resources | 权限理由与错误文案 | 多语言/资源引用一致性 |
| tests | 纯逻辑 + UI/设备场景 | OCR 准确率测试需固定数据集与真值 |

## 6. 约束清单

| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| 不自动执行识别文本 | Issue | 确认仅写 `expression`，不调用 `onEquals/evaluate` |
| 失败不覆盖原输入 | Issue | 会话内快照；仅 `CONFIRMED_VALID` 提交 |
| 不可信输入 | Issue | 归一化 → 字符白名单 → Token/语法验证 → 才可提交 |
| 权限拒绝可恢复 | Issue | 显式状态与设置引导；不进入拍摄调用 |
| 自主歧义处理 | Issue assignment | 采用端侧离线、基础四则、可量化 NFR，并完整记录假设与理由 |
| 不改产品源 | 本轮用户指令 | 仅写 `specs/changes/...` 规划制品 |

## 7. 可复用组件

| 组件 | 位置 | 复用方式 |
|------|------|----------|
| 覆盖层模式 | CalculatorPage Settings/About/Plot | 识别确认 UI 的呈现惯例 |
| 主题函数 | CalculatorPage `getBg/getPanelBg/getT*` | 新面板视觉一致性 |
| `Expression` | calculator/Expression.ets | 在安全校验后做既有规范化；不能代替白名单校验 |
| Hypium | entry/src/test | 纯逻辑状态机、验证器、fake gateway/provider 测试 |

## 8. 关键实现分析

- 建议把平台依赖隔离在 gateway/provider，协调器只处理可枚举事件，避免在 UI 回调中散落权限/OCR 分支。
- 建议状态：IDLE → REQUESTING_PERMISSION → CAPTURING → RECOGNIZING → REVIEWING；任意阶段可到 ERROR/CANCELLED，重试返回 CAPTURING；只有 REVIEWING 且 validation.valid 才允许 CONFIRMED。
- 会话创建时保存 `originalExpression`。关闭、拒绝、失败、空结果、不支持字符、重拍均不写页面 `expression`。
- `Expression.addParenthesis()` 会自动补右括号，不适合作为严格的识别语法校验；验证器应拒绝不平衡括号，避免悄悄修复 OCR 错误。

## 9. 风险与测试

| 风险 | 缓解 | 测试策略 |
|------|------|----------|
| 权限永久拒绝/重复申请 | 权限状态网关 + 设置引导 | fake 权限矩阵 + 真机 UI |
| OCR 把 `×`/`x`、`÷`/`/`、`1`/`l` 混淆 | 仅映射 `×/x/X→*`、`÷→/`、Unicode 减号→`-`；`l` 等其余字符提示编辑 | 表驱动字符测试 + 固定图片集 |
| 恶意/异常字符串进入求值器 | 长度上限、白名单、完整 token/语法检查 | fuzz/边界输入，不调用 evaluate 的 spy |
| 异步回调晚到覆盖新会话 | session id/取消令牌，丢弃过期结果 | 两次会话乱序 fake 测试 |
| 图像/结果泄漏 | 默认内存临时数据，离开即释放；云路线需另审 | 生命周期测试与隐私评审 |
| 页面状态膨胀 | coordinator 与 UI 状态分离 | 单测状态转换，CalculatorPage 只消费 view state |

## 10. 关键发现

1. 现有计算核心可复用，但必须在其前新增严格安全验证层。
2. 现有应用没有任何 OCR 能力；以 provider 隔离端侧实现是新增架构边界，云端路径明确不在首期范围。
3. 当前 SDK 基线是 API 12；CoreVisionKit/CameraKit/ImageKit 已在精确 head 编译通过。设备可用性、真实拍摄与识别质量仍需 Tester 在支持设备验证，失败不得自动改用云端。
4. 产品需求是复杂新增功能；本次规划复核仍保留 new-arch.md 和 delta-design.md，以准确描述现有 PR 架构与阶段门禁。
5. 当前 worktree HEAD、任务载荷 PR head 与 Developer evidence head 均为 `19f7c3d146dc30574738dd2187dd99ec6877610d`，可作为追溯基线。

## 11. 自主澄清结论与依据

| 决策 | 默认值 | 代码仓/范围依据 |
|------|--------|-----------------|
| OCR 路线 | 端侧离线、单 provider | 当前无 NetworkKit/网络权限/账号能力；最小权限且满足离线目标 |
| 字符范围 | 数字、小数点、四则、圆括号 | Issue 示例 + 既有引擎稳定支持；不扩展求值语法 |
| 填入语义 | 预览确认后替换 expression | `CalculatorPage` 对 expression 单一所有权；追加会产生不可预期拼接 |
| 性能/准确率 | 100 图固定集完全识别率 ≥90%，P95 ≤2 s，5 s 超时 | 演示重点、可自动复验、异常可恢复 |
| 数据生命周期 | 会话内临时，退出即释放 | 现有 Preferences 只用于偏好/历史，无保存照片的产品需求 |

## 12. Developer evidence 与下游风险

| 项目 | 观察结果 |
|------|----------|
| Evidence | `D:\\huawei\\Demo\\calculatorHuawei\\.agent-runtime\\evidence\\task-23\\run-61.json` |
| 已完成 | API 12 HAP build、57/57 Local Test、CodeLinter 0 error、模拟器权限拒绝/永久拒绝/相机失败恢复 |
| 尚不可在 Developer 环境完成 | 真实相机拍摄、真实手写 OCR 成功、100 图/≥5 书写者准确率、P95、飞行模式、持久文件隐私扫描 |
| 规划结论 | 上述缺口是 Tester 风险/门禁，不是 Developer blocker；最终验收标准保持不变 |
