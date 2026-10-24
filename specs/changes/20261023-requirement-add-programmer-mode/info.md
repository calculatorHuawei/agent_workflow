# 程序员模式与四进制转换 - 代码仓理解

## 1. 基本信息
- **需求类别**：新增功能；当前产品不存在程序员模式，Issue #45 要求新增独立能力。
- **需求名称**：程序员模式与 BIN/OCT/DEC/HEX 转换。
- **分析时间**：2026-10-24（Task 33 PLANNING 复核）。
- **分析范围**：`opencalc/entry` 主页面、计算逻辑、模型、偏好、构建与本地测试。
- **重点分析类别**：架构与约束、公共组件、接口契约、影响范围、构建集成、风险与测试。
- **约束边界**：仅规划；未修改产品源码、构建配置或测试源码。

## 2. 模块架构

### 2.1 当前模块结构
```text
OpenCalc (single entry HAP)
├── entryability/EntryAbility.ets
│   └── loads pages/Index
├── pages/Index.ets
│   └── router.replaceUrl('pages/CalculatorPage')
├── pages/CalculatorPage.ets
│   ├── UI + @State + event routing
│   ├── Expression → CalcEngine → NumberFormatter
│   ├── PreferencesStore → preferences (history/settings)
│   └── FunctionPlotter/PlotAxis → Canvas
├── calculator/
├── model/
├── plot/
├── programmer/ProgrammerConverter.ets
└── preferences/
```

项目只有一个 `entry` HAP，无 HAR/HSP/feature HAP。`CalculatorPage` 是实际主页面，当前承担 UI、页面状态和事件编排；业务算法按 `calculator/` 与 `plot/` 子目录拆分。

### 2.2 核心模块职责
| 模块 | 位置 | 当前职责 | 与本需求关系 |
|------|------|----------|--------------|
| `CalculatorPage` | `entry/src/main/ets/pages/CalculatorPage.ets` | 普通/科学计算 UI、历史、设置、绘图，以及已集成的模式切换和程序员面板 | 规划边界：程序员状态继续与普通状态隔离 |
| `CalcEngine` | `calculator/Calculator.ets` | 基于 `number` 的递归下降表达式求值 | 保持不变；不适合作为 U64 转换核心 |
| `Expression` | `calculator/Expression.ets` | 普通表达式清理/转换 | 保持不变；本期不支持程序员表达式 |
| `NumberFormatter` | `calculator/NumberFormatter.ets` | 十进制结果分组/格式化 | 保持不变；它服务浮点/十进制显示，不承担多进制 U64 |
| `Models` | `model/Models.ets` | 错误、编号体系、科学模式、历史、偏好及程序员模式类型 | 规划边界：既有字段和程序员契约保持兼容 |
| `PreferencesStore` | `preferences/PreferencesStore.ets` | 主题、振动、历史等 Preferences 读写 | 不修改 schema；模式切换不得触发历史清空 |
| `FunctionPlotter/PlotAxis` | `plot/` | 函数采样、分段、坐标轴布局 | 不涉及；回归范围 |

### 2.3 扩展点与推荐落点
现有目录惯例按领域拆分纯业务代码；当前 HEAD 已将精确校验/转换落在 `entry/src/main/ets/programmer/ProgrammerConverter.ets`，与页面和浮点引擎隔离。该落点符合规划约束，页面只负责状态和呈现，无需新模块或新路由。

## 3. 接口与契约

### 3.1 现有关键接口
| 接口 | 位置 | 功能 | 参数/返回 |
|------|------|------|-----------|
| `CalcEngine.evaluate` | `calculator/Calculator.ets` | 普通/科学表达式求值 | `(equation: string, isDegree: boolean, varX?: number): number` |
| `Expression.getCleanExpression` | `calculator/Expression.ets` | UI 表达式转求值表达式 | string → string |
| `NumberFormatter.format` | `calculator/NumberFormatter.ets` | 现有十进制格式化 | string + separator/system → string |
| `PreferencesStore.getHistory/setHistory` | `preferences/PreferencesStore.ets` | JSON 历史持久化与按上限裁剪 | `Promise<HistoryItem[]>` / `Promise<void>` |
| 页面事件方法 | `pages/CalculatorPage.ets` | `onDigit/onOp/onBS/onAC/onEquals` 等 | 直接修改 `@State` |

### 3.2 现有状态与事件机制
| 状态/事件 | 当前行为 | 规划约束 |
|-----------|----------|----------|
| `expression/result/errorMsg` | 普通计算状态 | 程序员模式不得复用或清空 |
| `history` | 启动加载，等号成功时保存 | 模式切换只读保留，不新增程序员历史 |
| `scientific/radianMode/themeIdx` | 页面内状态，部分来自偏好 | 程序员模式往返后保持 |
| `isLandscape` | 根 Stack 的 `onAreaChange` 更新；横屏强制 `scientific=true` | 新面板需适配但不改变该既有规则 |
| `showPlot/showSettings/showAbout` | 同页覆盖层 | 程序员模式入口不应重建页面或路由 |

### 3.3 新接口建议（设计输入）
| 接口 | 所属元素 | 契约 |
|------|----------|------|
| `convert(text, radix)` | `ProgrammerConverter` | 返回完整 `ConversionResult` 或 `ProgrammerError`，不得抛出到 UI |
| `isDigitAllowed(digit, radix)` | `ProgrammerConverter` | UI 键启停与业务校验共用同一规则 |
| `appendDigit(state, digit)` | 状态操作层 | 成功返回新状态；失败返回原状态 + 错误 |
| `changeRadix(state, target)` | 状态操作层 | 有值时保持数值并重写草稿；空值只变 radix |

调用约束：converter 必须纯同步、无 IO、无 ArkUI/Preferences 依赖；成功前完成字符、范围和精度验证；失败不得部分更新多个页面字段。

## 4. 构建与集成
- **项目类型**：HarmonyOS Stage 模型、ArkTS、ArkUI 声明式 UI。
- **兼容/目标 SDK**：HarmonyOS 5.0.0(12)，API 12。
- **构建入口**：`opencalc/build-profile.json5`、`opencalc/hvigorfile.ts`、`entry/build-profile.json5`。
- **模块**：仅 `entry`，类型 `entry`，支持 phone/tablet，自动旋转。
- **OHPM 依赖**：产品依赖为空；本地测试使用 `@ohos/hypium 1.0.15`，根 devDependency 另有 `@ohos/hamock`。
- **权限**：仅既有 `ohos.permission.VIBRATE`；本需求不新增权限。
- **规划后验证命令**：构建使用仓库约定 `opencalc/build-test.bat` 或等价 `hvigorw assembleHap`；本地 Hypium 使用 worker 约定 `hvigorw --mode module -p module=entry@default test`，不是旧文档中的 `test@entry`。
- **测试聚合**：`entry/src/test/List.test.ets` 同时注册 `PlotFunction.test` 与 `ProgrammerConverter.test`，沿用单一 Hypium 聚合入口。

## 5. 影响范围
| 模块/文件 | 影响内容 | 风险 |
|-----------|----------|------|
| `pages/CalculatorPage.ets` | 新增模式、程序员状态、Builders 与动画 | 文件已较大（约 32KB），需限制新增职责，防止状态交叉 |
| `model/Models.ets` | 新增枚举/接口，不改既有类型字段 | 命名冲突或对现有 import 造成非预期影响 |
| `programmer/ProgrammerConverter.ets` | U64 字符串精确算法与状态操作 | 需保持边界精度、错误原子性和纯同步契约 |
| `entry/src/test` | 新套件与聚合注册 | 测试任务/ArkTS 语法与产品编译差异 |
| `PreferencesStore.ets` | 原则上不修改 | 若错误复用会导致不必要持久化或历史覆盖 |
| `calculator/`、`plot/` | 不修改，仅回归 | 模式条件若包裹错误会隐藏或破坏既有入口 |

调用链规划：
```text
Programmer key/radix event
  → CalculatorPage handler
  → ProgrammerConverter / state operation
  → success: atomically replace programmer state
    failure: retain valid data + replace feedback
  → ArkUI rerender programmer panel only
```

## 6. 约束清单
| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| 仅执行 PLANNING，不修改产品源码 | 用户指令 | 只写 `specs/changes/...` 制品 |
| 不创建或修改 `tasks.md` | 用户指令 | 保留精确 PR HEAD 中的既有文件；本次 todo 单独记录 PLANNING 复核 |
| 保持向后兼容 | Issue/worker workflow | 隔离普通和程序员状态，不改既有接口/schema |
| 安全可逆默认 | GitHub assignment | 采用 U64 非负、页面内草稿、不含位运算并记录 rationale |
| 精确转换 | Issue 的错算/边界 AC | 禁止浮点 `number` 处理 U64；边界单测门禁 |
| 最小权限 | workflow | 无新权限、依赖、网络、后台任务或持久化 |
| 现有工作树保护 | workspace 规则 | 仅更新指定 change 目录中的 Planning 制品；不触碰产品、任务拆解或无关改动 |

## 7. 可复用组件
| 组件 | 位置 | 复用方式 |
|------|------|----------|
| 主题颜色 getters | `CalculatorPage.ets` | 程序员标签、键盘、反馈沿用 `getBg/getBtnBg/getOp/getErr/getT1/getT2` |
| 响应式 `isLandscape` | `CalculatorPage.ets` | 程序员面板复用现有横竖屏状态，不新增监听器 |
| Builder 按钮惯例 | `CalculatorPage.ets` | 沿用 `Text(...).onClick`、统一尺寸/圆角模式，新增受限 digit builder |
| Hypium 套件惯例 | `entry/src/test/PlotFunction.test.ets` | `describe/it/expect`，模块级函数，避免 ArkTS 禁止的嵌套函数 |
| Models 集中定义 | `model/Models.ets` | 公共枚举/接口保持显式类型 |

不建议复用：`CalcEngine`、`Expression` 和 `NumberFormatter` 的 `number` 路径，因为其语义是十进制浮点表达式而非 U64 进制转换。

## 8. 关键实现现状
- `CalculatorPage` 同时持有 `calculatorMode` 与既有 `scientific`；前者控制普通/程序员分支，后者仍只控制普通计算的附加科学按键，两者职责分离。
- 普通输入仍由 `onDigit/onOp/...` 直接拼接 `expression`；等号后调用 `Expression → CalcEngine → NumberFormatter` 并写入历史，程序员链路不复用或重置这些字段。
- 历史保存在 Preferences 的单个 JSON 字符串 `history` 中；损坏时返回空数组。模式切换无需触碰它。
- 横屏在 `onAreaChange` 中自动开启科学模式；程序员模式设计必须明确与此既有行为隔离。
- 页面已有函数绘图全屏覆盖层；程序员模式使用显式 `CalculatorMode` 和同页分支，避免路由生命周期重建。
- `ProgrammerConverter` 采用十进制字符串乘加、比较和长除法，不依赖 `bigint` 源语法，也不经浮点 `number` 中转；这是当前仓库已验证且最小风险的精确路径。

### 边界条件
- 十六进制大小写：UI 仅大写，防御入口可规范化小写。
- 空字符串与 `0` 不同；空值不应产生数值结果。
- U64 最大长度随进制为 BIN 64、OCT 22、DEC 20、HEX 16 位，但仅长度不能独立判断上界（如 OCT/DEC 最大首位）。
- 换进制必须先基于旧 radix 解析，再按新 radix 格式化，不能直接重解释相同文本。
- 非法/越界不能覆盖最后有效结果；清空与退格必须能恢复。

## 9. 风险与测试
| 风险 | 缓解 | 测试策略 |
|------|------|----------|
| U64 被 `number` 舍入 | 独立精确算法与代码评审禁则 | MAX、MAX-1、MAX+1，跨进制往返 |
| 精确字符串算法被误改为浮点路径 | 保持算法禁则与 U64 契约 | MAX、MAX+1、四进制往返与受控回归测试 |
| UI 禁用规则与业务规则漂移 | 共用 `isDigitAllowed` | 各 radix 合法/非法字符矩阵 |
| 多个 `@State` 部分更新 | 操作返回单一状态对象或严格原子赋值顺序 | 失败前后状态深度比较 |
| 快速动画重入 | 同步幂等 mode 状态，动画不提交业务 | 180ms 内连续切换序列 |
| 普通状态丢失 | 模式分支不调用 `onAC`/历史写入 | 普通状态快照往返测试 |
| 横屏布局拥挤 | 复用响应式标志、限制键盘行高 | phone/tablet 横竖屏 UI 验证（Tester 阶段） |

回归范围：`CalculatorPage` 普通基础/科学输入、等号、错误、历史加载/删除/点击、主题/角度、绘图入口与已有 PlotFunction 本地测试。

## 10. 关键发现

### 可复用组件
- 主题、响应式布局与 Builder 风格可直接沿用。
- Hypium 本地测试框架和聚合入口已存在。
- 单 entry HAP 足以承载本功能，无需模块化扩张。

### 风险提示
- 最大技术风险不是算法复杂度，而是精度模型和页面状态交叉。
- 现有 `CalculatorPage` 体积较大；业务算法必须移出页面。
- 初始化标记里的旧测试命令已被 worker workflow 的新命令覆盖，后续执行应采用后者。

### 建议
- 先实现/编译/单测 T0 converter，再接状态与 UI。
- 不修改 PreferencesStore，模式只保存页面内草稿。
- UI 自动化由 Tester 阶段在设备/模拟器上完成；Developer 不应声称未运行的设备覆盖。

---
> 本文件由 rq-codebase 工作流产出，仅包含代码仓理解与设计输入，不包含产品源码修改。

## 11. 2026-10-24 精确 HEAD 复核

本次在 PR #49 的精确 HEAD `17b7145dcbbc418580d2370008dba6c2f5b6d19c` 上重新执行 `rq-codebase`。该 HEAD 已包含上一轮实现，现状检查仅作为设计一致性证据，不授权或产生产品源码改动：

| 规划约束 | 当前代码证据 | 结论 |
|----------|--------------|------|
| 精确 U64 且不得经浮点 `number` 中转 | `programmer/ProgrammerConverter.ets` 使用十进制字符串乘加/长除与 `U64_MAX_DEC` 比较 | 符合设计允许的精确字符串回退 |
| UI 与业务共用合法键规则 | `programmerKeyEnabled` 委托 `ProgrammerConverter.isDigitAllowed` | 符合 |
| 普通状态与程序员状态隔离 | `CalculatorPage` 分别持有既有普通字段和 `programmerState`；mode handler 不调用 AC/历史/偏好方法 | 符合 |
| 180ms opacity + 4vp translation | `animateTo({ duration: 180 })` 与 `TransitionEffect.OPACITY.combine(translate({ y: 4 }))` | 符合 |
| 最小权限与兼容 | 无新增网络、权限、Preferences key、路由或 HAP/HAR/HSP | 符合 |

复核结论：原 `info.md` 对架构、约束、风险和推荐落点的理解仍有效；本次没有读取结果后反向扩大需求或修改设计边界。

## 12. Task 39 rq-codebase 复核

- **复核上下文**：分支 `agent/pull_request-49-task-39`，只读基线 HEAD `9b3629c473317b22781ad3cb415b2dcc7346a86c`。
- **结构结论**：仓库仍为单 `entry` HAP；`CalculatorPage` 使用 ArkUI V1 `@State` 编排普通与程序员两条状态链；`ProgrammerConverter` 是 UI 无关的纯本地业务边界；`PreferencesStore` 仍只服务既有普通状态。
- **契约结论**：`Models.ets` 的 `CalculatorMode`、`Radix`、`ProgrammerError`、`ProgrammerState` 与 `ProgrammerOperationResult(state + error)` 和设计一致；无公开 API、权限、网络或持久化 schema 变更。
- **实现约定**：转换路径使用字符串精确算法而非浮点 `number`；页面模式切换使用同步单值状态，`UIContext.animateTo` 与 `TransitionEffect` 均为 180ms，内容位移为 y=4vp。
- **测试约定**：`entry/src/test/List.test.ets` 聚合既有绘图和程序员转换套件。Task 39 不运行测试，只把现有注册方式作为后续验证层级设计输入。
- **影响与风险**：继续约束 U64 精度、非法输入原子性、快速切换、重复点击区域、响应式状态刷新以及普通历史兼容；无需新增模块、依赖或权限。

## 13. Task 42 rq-codebase 只读复核

- **基线**：分支 `agent/pull_request-49-task-42`，精确 HEAD `49054a10f21f83f1f46a538df6d097dd32f87681`；工作树在复核前干净。
- **架构与状态**：项目仍为单 `entry` HAP、单 `CalculatorPage`；ArkUI V1 `@State` 分别保存普通字段和 `ProgrammerState`，条件渲染不复用或清空普通表达式、结果、历史、主题、角度或绘图状态。
- **业务契约**：`ProgrammerConverter` 继续采用十进制字符串乘加/比较/长除，不经浮点 `number` 承担 U64；`ProgrammerOperationResult` 使用 `state + error`，非法追加保留最后有效 input/result。
- **交互约定**：键盘启停委托 `ProgrammerConverter.isDigitAllowed`；模式切换为同步单值状态，UI 使用 180ms `EaseInOut`、opacity 和 y=4vp transition；不新增路由或持久化。
- **构建与权限**：API 12、phone/tablet、auto rotation、既有 VIBRATE 权限和既有 Hypium devDependency 均不变。本仓库含既有本机签名配置路径，但本需求不读取、修改或扩展签名凭据；签名可用性不影响本地规划。
- **风险与验证责任**：精度、边界、状态原子性可由本地单元/集成层覆盖；设备动画流畅度、触控目标和横竖屏由后续 Tester 负责。Task 42 不运行产品测试或构建。

## 14. Task 45 rq-codebase 只读复核

- **基线与范围**：分支 `agent/pull_request-49-task-45`，精确 HEAD `aeb8f4e8a60bda04651c9c69af034cac28606d17`；本次仅阅读需求相关 ArkTS、模块配置和测试聚合，不改产品或测试源码。
- **模块架构**：仍为单 `entry` HAP、单 `CalculatorPage`。页面使用 ArkUI V1 `@State` 分别保存普通计算字段与 `ProgrammerState`；`ProgrammerConverter` 是不依赖 ArkUI、Preferences、网络或外部服务的纯本地业务边界。
- **接口与状态契约**：`ProgrammerOperationResult` 保持 `state + error` 单一结果契约；非法追加保留最后有效 input/result；键盘启停委托与业务校验共享的 `isDigitAllowed`，避免双重规则漂移。
- **精度与交互约定**：U64 转换继续采用十进制字符串乘加、比较和长除，不经浮点 `number`；模式切换使用同步单值状态、180ms `EaseInOut`、opacity 与 y=4vp transition，条件渲染只保留一个可交互面板。
- **构建与集成**：API 12、phone/tablet、auto rotation、既有 VIBRATE 权限、Hypium devDependency 与 `List.test.ets` 聚合约定不变；本需求无需新增权限、Kit、依赖、路由、Preferences key、HAR/HSP 或部署单元。
- **设计输入结论**：现有代码与 proposal/spec/design 的最小架构一致；实现存在不改变本次正向 Planning 的产品边界。设备动画流畅度、触控目标和横竖屏仍保留为后续 Tester 验证责任。

## 15. Task 48 rq-codebase 只读复核

- **基线与范围**：在 `agent/pull_request-49-task-48` 的 assigned HEAD `4224f027f05b93a4900c68c31700897c07dcfafe` 上，只读检查需求相关页面、模型、converter、模块配置与测试聚合；未修改任何产品/测试源码或构建配置。
- **架构约定**：仓库仍是 API 12 的单 `entry` HAP；`CalculatorPage` 使用 ArkUI V1 `@State` 隔离普通字段和 `ProgrammerState`，`ProgrammerConverter` 保持无 ArkUI/Preferences/网络依赖的纯同步业务边界。
- **行为契约**：页面键启停与业务防御校验共用 `programmerKeyEnabled/isDigitAllowed`；操作结果保持 `state + error`；字符串乘加/比较/长除承担 U64 精度，不经浮点 `number`。
- **交互与兼容**：模式切换使用同步单值状态、180ms `EaseInOut`、opacity 与 y=4vp transition；不新增路由、Preferences key、权限、Kit、HAR/HSP 或外部依赖，普通表达式/历史/设置/绘图链路保持原契约。
- **测试与风险输入**：`List.test.ets` 继续聚合 PlotFunction 与 ProgrammerConverter 套件；设备动画流畅度、触控目标及 phone/tablet 横竖屏仍属于后续 Tester 层，不构成 Planning blocker。
