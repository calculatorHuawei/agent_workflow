# 计算结果小数/分数切换 - 代码仓理解

## 1. 基本信息
- **需求类别**：缺陷修复（重发历史 Issue #27）
- **需求名称**：结果小数/最简分数显示切换
- **分析时间**：2026-10-23
- **分析范围**：`opencalc/entry/src/main/ets/{pages,calculator,model,preferences,common}`、`entry/src/test`
- **约束边界**：仅规划；不修改产品源码；不创建 `tasks.md`

## 2. 模块架构
```
CalculatorPage（ArkUI View + 页面状态）
  ├─ Expression.getCleanExpression
  ├─ CalcEngine.evaluate -> number
  ├─ NumberFormatter.format -> 小数字符串
  ├─ HistoryItem[] -> PreferencesStore
  └─ [拟新增] FractionUtil -> FractionResult|null
```

| 模块 | 当前位置 | 职责 |
|------|---------|------|
| 页面/状态 | `pages/CalculatorPage.ets` | 输入、求值编排、结果显示、历史写入 |
| 计算引擎 | `calculator/Calculator.ets` | 递归下降求值，返回 `number` |
| 数字格式化 | `calculator/NumberFormatter.ets` | 小数/分组符号显示 |
| 数据模型 | `model/Models.ets` | `HistoryItem`、偏好接口、枚举 |
| 偏好存储 | `preferences/PreferencesStore.ets` | 历史和设置持久化 |
| 测试入口 | `entry/src/test/List.test.ets` | 注册 Hypium 本地测试套件 |

无需新增 HAP/HAR/HSP、外部依赖、权限或系统 Kit。

## 3. 接口与契约

### 3.1 外部接口
| 接口 | 位置 | 功能 | 参数格式 |
|------|------|------|----------|
| `CalcEngine.evaluate` | `Calculator.ets:33` | 表达式求值 | `(equation: string, isDegree: boolean, varX?: number) => number` |
| `NumberFormatter.format` | `NumberFormatter.ets` | 小数显示 | `(text, decimalSep, groupingSep, numberingSystem) => string` |
| `PreferencesStore.setHistory` | `PreferencesStore.ets:127` | 裁剪并持久化历史 | `(HistoryItem[]) => Promise<void>` |

### 3.2 事件机制
| 事件 | 触发条件 | 消费者 | 格式 |
|------|---------|--------|------|
| 等号点击 | 表达式非空 | `CalculatorPage.onEquals` | UI click |
| 模式切换（拟新增） | 成功结果存在且无错误 | `CalculatorPage` | UI click |
| 清空 | AC 点击 | `CalculatorPage.onAC` | UI click |

### 3.3 调用约束
- `onEquals` 在错误标志均未设置后才可更新 raw result、小数快照和历史。
- 模式切换不得调用 `CalcEngine.evaluate` 或 `PreferencesStore.setHistory`。
- 分数工具仅接收有限 `number`；不可靠时返回 `null`，不得抛出到 UI。

## 4. 构建与集成
- **构建入口**：`opencalc/hvigorfile.ts`、`opencalc/build-profile.json5`、`entry/hvigorfile.ts`
- **集成方式**：单一 entry HAP 内静态 ArkTS 源码
- **测试入口**：`opencalc/entry/src/test/List.test.ets`
- **初始化证据**：`specs/initialized.flag` 记录 hvigorw 6.24.2 基线构建成功与 `entry/src/test` 可用
- **裁剪机制**：不涉及

## 5. 影响范围
| 模块/文件 | 影响内容 | 风险 |
|-----------|---------|------|
| `common/FractionUtil.ets`（新增） | 有界连分数、GCD、格式化 | 浮点近似被错误接受 |
| `pages/CalculatorPage.ets` | raw result、display mode、派生展示、切换入口 | 历史副作用、复制语义、布局拥挤 |
| `entry/src/test/*` | 注册纯逻辑及关键交互测试 | 测试入口漏注册 |
| `Models.ets` | 无持久 schema 变更；可选页面本地 enum 或导出 enum | 避免扩大兼容面 |

不修改 `Calculator.ets`、`Expression.ets`、`PreferencesStore.ets`、`HistoryItem` 或 plot 目录。

## 6. 约束清单
| 约束 | 来源 | 遵守方式 |
|------|------|----------|
| `1÷3` 必须显示 `1/3` | Issue #44 AC | 不采用历史十进制定标算法；用有界逼近 |
| 小数遵循现有精度策略 | Issue #44 | 小数和降级直接复用当前 `result` 快照/NumberFormatter |
| 历史一致 | Issue #44 | 切换路径不调用 `setHistory`，不改数组或条目 |
| 不伪造分数 | Issue #44 | 分母上限 + 误差门禁；失败返回 `null` |
| ArkTS 静态约束 | 项目技术栈 | 显式类型、无动态对象形状、纯函数可测试 |
| 本 phase 不实现 | 用户指令 | 只写 `specs/changes/...` 文档 |

## 7. 可复用组件
| 组件 | 位置 | 复用方式 |
|------|------|----------|
| `NumberFormatter` | `calculator/NumberFormatter.ets` | 小数模式和分数失败降级 |
| `ErrorFlags` | `model/ErrorFlags.ets` | 只在成功求值时建立可切换结果 |
| `DisplayPanel` 主题方法 | `CalculatorPage.ets` | 沿用 `getT1/getT2/getOp` 与 border 风格 |
| Hypium 入口 | `entry/src/test/List.test.ets` | 注册新增测试套件 |

## 8. 关键实现

### 8.1 当前结果链路
`onEquals` 在 `CalculatorPage.ets:94-116` 中获得 `raw`，立即格式化为 `fmt`，然后把相同 `fmt` 同时写入 `this.result` 和新 `HistoryItem.result`。当前页面没有保留 raw result，因此不能从带分组符号的字符串可靠反推。

### 8.2 当前展示与历史
- `DisplayPanel` 在 `CalculatorPage.ets:468-496` 直接渲染 `this.result`。
- `HistoryPanel` 在 `553-586` 直接渲染 `item.result`。
- `onHistoryTap` 只回填表达式，不重算结果。

### 8.3 历史 #27 发现
Git 提交 `525b442` 曾新增 `FractionUtil`，但其测试把 `toFraction(1/3)` 明确期望为 `null`。Issue #44 将 `1/3` 规定为必须行为，因此只能借鉴状态分离和安全降级，不能照搬算法或测试。

### 8.4 推荐边界
成功求值时保存 `lastRawResult` 与 `decimalResult`；展示函数按模式派生文本。分数转换采用有界连分数，候选必须满足：有限值、分母不超过设计上限、绝对/相对误差门禁、整数安全范围。失败返回 `null`。

## 9. 风险与测试
| 风险 | 缓解 | 测试策略 |
|------|------|----------|
| 把 π/√2 误显示为简单分数 | 严格误差门禁和最大分母 | 非有理近似降级样例 |
| `1/3` 无法识别 | 连分数而非十进制定标 | `1/3 -> 1/3` |
| 符号或约分错误 | 正分母 + GCD | `-1/2`、`2/4` |
| 切换重复写历史 | 切换函数纯状态变更 | 记录数组长度/内容前后相等 |
| 清空后陈旧结果复现 | AC 同步清除 raw/快照 | AC 后按钮不可用/结果为 0 |
| 横竖屏空间冲突 | 入口位于结果区域并允许紧凑布局 | 两种方向 UI 验证在后续 APPLYING/Tester 阶段 |

## 10. 关键发现
### 可复用组件
`NumberFormatter`、`ErrorFlags`、`DisplayPanel` 样式与 Hypium 测试入口均可复用。

### 风险提示
历史实现不是可直接恢复的正确实现；复制行为应复制当前可见结果还是既有小数快照属于交互细节。本设计选择复制当前可见结果，使 UI 所见即所得，但不影响历史存储。

### 建议
优先以纯 `FractionUtil` 测试锁定数学契约，再接入页面。页面切换逻辑提取为可测试的纯展示选择函数，减少 ArkUI 组件级测试依赖。
