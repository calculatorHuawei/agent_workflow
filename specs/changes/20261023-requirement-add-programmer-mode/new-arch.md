# 程序员模式与四进制转换 - 架构变更

## 1. 变更概述
| 项目 | 内容 |
| ---- | ---- |
| 变更类型 | 新增（entry HAP 内部业务组件） |
| 变更日期 | 2026-10-23 |
| 变更人 | Developer Agent |
| 关联需求 | Issue #45 / IR-45 |

---

## 2. 最新架构【架构前置】

### 2.1 架构总览
OpenCalc 继续采用单 entry HAP、单主页面的 ArkUI 声明式架构。本变更不改变部署模型、模块边界或外部依赖，只在 entry 内增加“程序员转换”业务组件，并在 `CalculatorPage` 增加与普通计算隔离的模式状态和 UI 分支。

### 2.2 分层架构图
```text
┌──────────────────────────────────────────────────────────┐
│ 表现层：CalculatorPage                                   │
│  ModeSwitch ── NormalPanel / ProgrammerPanel             │
│  ├─ 普通 @State：expression/result/history/...           │
│  └─ 程序员 @State：radix/input/results/error             │
├──────────────────────────────────────────────────────────┤
│ 业务逻辑层                                                │
│  既有：Expression → CalcEngine → NumberFormatter         │
│  新增：ProgrammerConverter / ProgrammerState operations  │
├──────────────────────────────────────────────────────────┤
│ 数据层                                                    │
│  PreferencesStore（既有偏好与普通历史；本变更不扩展）     │
├──────────────────────────────────────────────────────────┤
│ 基础设施层                                                │
│  ArkUI / ArkData / Hypium（均为既有依赖）                 │
└──────────────────────────────────────────────────────────┘
```

### 2.3 组件职责
| 组件 | 类型 | 职责 | 边界 |
| ---- | ---- | ---- | ---- |
| `CalculatorPage` | 表现/编排 | 持有应用模式与两侧页面状态，路由事件并渲染过渡 | 不实现 U64 解析算法；不因切换写历史 |
| `NormalPanel`（现有 Builders） | 表现 | 普通/科学计算、历史、设置、绘图 | 行为和数据契约保持不变 |
| `ProgrammerPanel`（新 Builders） | 表现 | 进制标签、输入、四行结果、键盘、反馈 | 仅消费结构化状态/操作结果 |
| `ProgrammerConverter` | 业务 | 字符校验、精确解析、U64 范围、四进制格式化 | 纯同步、无 UI/IO/Preferences 依赖 |
| `ProgrammerState operations` | 业务/状态 | append/backspace/clear/changeRadix 的原子状态转换 | 失败保留最后有效数据 |
| `PreferencesStore` | 数据 | 既有普通历史与设置持久化 | 不新增程序员字段或迁移 |

### 2.4 交互关系
| 交互 | 方向 | 接口/协议 | 说明 |
| ---- | ---- | --------- | ---- |
| 用户 → CalculatorPage | 事件 | click | 选择模式、进制或按键 |
| CalculatorPage → state operations | 调用 | typed ArkTS method | 传入当前状态与操作 |
| state operations → ProgrammerConverter | 调用 | `convert/isDigitAllowed` | 完成精确校验和转换 |
| state operations → CalculatorPage | 数据 | `ProgrammerOperationResult` | 成功新状态或失败原状态+错误 |
| CalculatorPage → ArkUI | 状态 | `@State` | 原子呈现结果和 180ms 过渡 |
| NormalPanel → PreferencesStore | 调用 | 既有 Promise API | 仅普通历史/偏好继续使用 |

**数据流**：
```text
digit/radix event → validate → exact parse → U64 gate → format 4 bases
                  → one operation result → programmer state → UI rerender
```

**控制流**：
```text
mode event → synchronous CalculatorMode update → ArkUI transition
（无计时器提交、无路由重建、无持久化副作用）
```

---

## 3. 变更原因
| 原因类型 | 说明 |
| -------- | ---- |
| 业务需求 | Issue #45 要求独立程序员模式与四进制同步转换 |
| 精度隔离 | 既有 `CalcEngine` 以浮点 `number` 求表达式，不能保证 U64 全范围精确 |
| 兼容性 | 独立组件可避免改变普通表达式语法、历史和设置契约 |
| 可测试性 | 纯业务 converter 可脱离 ArkUI 使用 Hypium 覆盖边界与非法输入 |

---

## 4. 变更点【展开细节】

### 4.1 新增精确转换业务组件
**变更类型**：新增

| 组件 | 变更内容 |
| ---- | -------- |
| `ProgrammerConverter` | 新增合法字符、精确解析、U64 上界和四进制格式化 |
| 程序员模型 | 新增 `CalculatorMode/Radix/ConversionResult/ProgrammerError/ProgrammerState` |

**变更理由**：隔离浮点引擎，保证 U64 精度并形成稳定测试边界。

**实现要点**：
- 成功返回四行完整结果，失败返回结构化错误，不把异常抛给 UI。
- 禁止用 `number` 中转 U64；采用十进制字符串乘加、比较和长除法，避免 SDK 源语法依赖并保证 U64 全范围精确。
- 输出大写、无前缀、无多余前导零。

### 4.2 扩展主页面模式与程序员 UI
**变更类型**：修改

| 组件 | 变更内容 |
| ---- | -------- |
| `CalculatorPage` | 新增单一应用模式状态、程序员状态与事件路由 |
| `ProgrammerPanel` | 新增结果列表、进制选择器、受限键盘和反馈 |

**变更理由**：保持当前单页面/响应式/主题惯例，减少导航与生命周期变化。

**实现要点**：
- 普通状态字段继续原样存在；模式切换不调用 `onAC` 或历史写入。
- 180ms 动画只作用于呈现；业务状态同步更新、同模式选择幂等。
- 共用一份 digit 合法性规则，避免 UI 与业务层漂移。

### 4.3 扩展本地测试聚合
**变更类型**：修改/新增

| 组件 | 变更内容 |
| ---- | -------- |
| `ProgrammerConverter.test.ets` | 新增转换、边界、错误与状态操作测试 |
| `List.test.ets` | 注册新套件，不删除既有 plot 套件 |

**变更理由**：为精确边界和可靠性措施提供自动化门禁。

---

## 5. 兼容性说明

### 5.1 对现有功能的影响
| 功能 | 影响 | 处理方式 |
| ---- | ---- | -------- |
| 普通/科学计算 | 页面增加外层模式分支 | 原 Builders、事件与状态字段不改语义；回归测试 |
| 历史记录 | 不应受模式切换影响 | 不改 schema/key；切换不调用 setHistory |
| 函数绘图 | 入口可见性随普通模式分支呈现 | `FunctionPlotter/PlotAxis` 不修改；回归入口与状态 |
| 主题/横竖屏 | 程序员面板复用颜色与 `isLandscape` | 不新增全局主题或旋转监听 |

### 5.2 对现有接口的影响
既有接口无签名变更。所有程序员接口为新增内部接口，不对外导出跨模块协议。

### 5.3 对现有数据的影响
无持久化数据变更、迁移、清理或重解释。程序员草稿仅页面内存态。

---

## 6. 迁移方案

本文档不涉及数据或模块迁移。

### 6.1 迁移范围
无。

### 6.2 迁移步骤
不适用；按 T0 converter → T1 state → T2 UI → T3 regression 增量集成。

### 6.3 回滚方案
变更仅为新增文件与主页面条件分支；若实施失败，可在独立分支撤销该变更而不处理数据迁移。不得使用破坏性工作树命令。

### 6.4 验证方法
本地 Hypium 边界测试、产品构建、普通功能回归、Tester 阶段设备/模拟器横竖屏与动画验证。

---

## 7. 附录

### 7.1 术语表
| 术语 | 定义 |
| ---- | ---- |
| U64 | 无符号 64 位整数 |
| 原子状态更新 | 一次操作成功后一起提交 radix/input/results/error，失败不提交部分字段 |
| 页面内存态 | 页面实例存活期间保存，应用重启不保证 |

### 7.2 参考文档
- `proposal.md`
- `delta-spec.md`
- `info.md`
- Issue #45

### 7.3 Task 33 架构复核

在精确 HEAD `17b7145dcbbc418580d2370008dba6c2f5b6d19c` 上复核后，架构仍为单 entry HAP、单主页面、独立纯业务 converter。无需新增模块、权限、依赖、路由、持久化或迁移；本次仅修正规划文字中的精确算法默认值，不改变组件边界。

### 7.4 Task 39 架构复核

在 HEAD `9b3629c473317b22781ad3cb415b2dcc7346a86c` 上再次检查后，§2 的目标架构仍是最小且兼容的常规方案：单 `entry` HAP、单 `CalculatorPage`、普通与程序员内存态隔离、独立 `ProgrammerConverter`、既有 Preferences schema 不变。Task 39 不提出新的模块、接口、权限、依赖、路由、部署或迁移；`acceptance-criteria.json` 仅补强验收契约，不改变架构。

### 7.5 Task 42 架构复核

在精确 HEAD `49054a10f21f83f1f46a538df6d097dd32f87681` 上按 Planning Step 7 重新检查：§2 的单 entry HAP 分层、独立 converter、页面内双状态与既有 Preferences 边界仍是满足 Issue 的最小架构。没有新的外部实体、部署单元、权限、依赖、接口版本、持久化 schema 或迁移需求；因此保留本 `new-arch.md`，不提出架构扩张。

### 7.6 Task 45 架构复核

在精确 HEAD `aeb8f4e8a60bda04651c9c69af034cac28606d17` 上按 Planning Step 7 复核后，§2 的单 `entry` HAP、单主页面、独立纯业务 converter、普通/程序员页面内状态隔离及既有 Preferences 边界仍是满足 Issue #45 的最小架构。无需新增外部实体、部署单元、权限、依赖、路由、接口版本或持久化迁移；本次保留 `new-arch.md` 作为内部架构增量说明，不扩大产品或平台范围。

### 7.7 Task 48 架构复核

在 assigned PR HEAD `4224f027f05b93a4900c68c31700897c07dcfafe` 上按 Planning Step 7 复核，§2 的单 `entry` HAP、同页条件分支、普通/程序员内存态隔离和独立纯业务 converter 仍是满足 IR-45-R1~R5 的最小架构。当前实现存在不改变正向设计结论；无需新增外部实体、部署单元、权限、依赖、路由、接口版本、持久化 schema 或迁移。Task 48 保留本架构增量并拒绝任何 Issue 外扩张。
