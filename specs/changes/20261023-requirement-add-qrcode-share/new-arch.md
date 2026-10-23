# 二维码分享 - 架构变更说明（new-arch.md）

> 复杂度评估为"复杂（保守判定）"，按 PLANNING Step 7 规则执行完整架构分析。
> **结论先行：无架构级变更**——沿用基线 `2500bf4` 既有架构（单页面 + overlay 面板 + 纯函数逻辑模块），本需求为模块内新增（qrcode/ 纯函数模块 + CalculatorPage 面板扩展），不新增核心交互关系、不新增外部依赖、不改变数据流方向。本文档按模板记录架构前置与变更点细节。

## 1. 变更概述

| 项目 | 内容 |
| ---- | ---- |
| 变更类型 | 新增（模块内新增，非架构变更） |
| 变更日期 | 2026-10-23 |
| 变更人 | dev-01（MigBot PLANNING 阶段） |

---

## 2. 最新架构【架构前置】

### 2.1 架构总览

OpenCalc for HarmonyOS 为单 UIAbility 单页面应用：EntryAbility 启动后经 Index 重定向至 CalculatorPage；CalculatorPage 承载全部计算器交互（显示/按键/历史/设置/关于/绘图），以 Stack overlay 模式管理子面板；业务逻辑沉淀为无 UI 依赖的纯函数模块（calculator/、plot/）；偏好与历史经 PreferencesStore 持久化。目标是继续维持"纯函数可测、UI 薄壳"的分层，二维码分享功能按同一模式增量接入。

### 2.2 分层架构图（变更后）

```
┌─────────────────────────────────────────────────────────────┐
│ 表现层（ArkUI）                                              │
│  EntryAbility → Index → CalculatorPage（@Entry 主页面）       │
│   · DisplayPanel[+二维码入口] ToggleRow ButtonGrid            │
│   · Stack overlay: SettingsPanel/AboutPanel/PlotPanel        │
│                    /QrSharePanel（新增）                      │
├─────────────────────────────────────────────────────────────┤
│ 业务逻辑层（纯函数模块，无 UI 依赖）                           │
│  calculator/Expression · calculator/Calculator(CalcEngine)   │
│  calculator/NumberFormatter · plot/FunctionPlotter           │
│  plot/PlotAxis                                               │
│  qrcode/QrPayload（新增：载荷构造+容量判定）                   │
│  qrcode/QrEncoder（新增：QR byte/EC-M/v1-10/RS/掩模）         │
├─────────────────────────────────────────────────────────────┤
│ 数据层                                                       │
│  preferences/PreferencesStore（@ohos.data.preferences）      │
│  model/Models · model/ErrorFlags（静态标志）                  │
├─────────────────────────────────────────────────────────────┤
│ 基础设施层                                                    │
│  ArkUI Kit(Canvas/promptAction) · BasicServicesKit(pasteboard)│
│  @ohos.data.preferences · @ohos/hypium（测试）                │
│  测试：entry/src/test/List.test.ets                           │
│        → PlotFunction.test.ets · QrShare.test.ets（新增）     │
└─────────────────────────────────────────────────────────────┘
```

### 2.3 组件职责

| 组件 | 类型 | 职责 | 边界 |
| ---- | ---- | ---- | ---- |
| CalculatorPage | 表现层 | 主页面状态与布局；门控判定；overlay 面板编排；Canvas 绘码 | 输入：用户交互；输出：面板渲染/toast；依赖：qrcode/*、calculator/*、preferences/* |
| QrSharePanel（@Builder，新增） | 表现层 | 分享面板：人类可读回显、二维码 Canvas、提示分支、关闭 | 输入：expression/result；输出：二维码画面；依赖：QrPayload/QrEncoder |
| QrPayload（新增） | 业务逻辑层 | 三行固定格式载荷构造、UTF-8 字节计数、容量上限判定 | 纯函数；输入：两字符串；输出：载荷或失败态；零依赖 |
| QrEncoder（新增） | 业务逻辑层 | 文本→QR 模块矩阵（byte 模式/EC-M/版本 1–10/RS 纠错/掩模） | 纯函数；输入：载荷文本；输出：矩阵或失败态；零依赖 |
| CalcEngine/NumberFormatter/Expression | 业务逻辑层 | 计算/格式化/清洗 | 零改动，只读复用 |
| PreferencesStore/Models/ErrorFlags | 数据层 | 持久化/模型/错误标志 | 零改动 |
| QrShare.test.ets（新增） | 测试 | 载荷与编码断言、六类口径、容量边界 | 依赖：qrcode/* 纯函数 |

### 2.4 交互关系

| 交互 | 方向 | 接口/协议 | 说明 |
| ---- | ---- | --------- | ---- |
| 用户 → CalculatorPage | 事件 | onClick（入口/关闭/按键） | 门控通过后置 showQrShare=true |
| CalculatorPage → QrSharePanel | 渲染 | @Builder 条件渲染 | Stack overlay，同 PlotPanel 惯例 |
| QrSharePanel → QrPayload | 调用 | buildQrPayload(expr, res) | 打开时现算，无缓存 |
| QrSharePanel → QrEncoder | 调用 | encodeQr(payload) | 同步纯函数 |
| QrSharePanel → Canvas | 绘制 | CanvasRenderingContext2D | 白底黑模块+4 模块静区 |
| QrShare.test.ets → qrcode/* | 调用 | hypium 断言 | 持久化单测 |

**数据流**：
```
expression/result（页面显示串） ──► buildQrPayload ──► 载荷文本(UTF-8)
──► encodeQr ──► boolean[][] 模块矩阵 ──► Canvas 像素 ──► 外部扫码设备（只读）
```

**控制流**：
```
入口点击 → 门控三分支判定 →[通过] showQrShare=true → 面板挂载 → 载荷现算 → 编码 → 绘制
                          └─[拒绝] 明确提示（不打开面板）
关闭点击 → showQrShare=false（唯一副作用）→ Stack 卸载面板
```

---

## 3. 变更原因

| 原因类型 | 说明 |
| -------- | ---- |
| 业务需求 | Issue #42：计算完成后一键生成"算式+结果"二维码，跨设备扫码读取，替代手工抄写 |
| 技术优化 | 不涉及（无性能/架构债驱动） |
| 历史债务 | 不涉及 |

---

## 4. 变更点【展开细节】

> 每个变更点均可追溯：全部为"新增"，无删除、无既有组件职责改写——这是"无架构级变更"结论的依据。

### 4.1 新增 qrcode/ 纯函数模块

**变更类型**：新增

**影响的组件**：
| 组件 | 变更内容 |
| ---- | -------- |
| qrcode/QrPayload.ets | 新增：载荷构造与容量判定纯函数 |
| qrcode/QrEncoder.ets | 新增：QR 矩阵编码纯函数 |

**变更理由**：业务逻辑层按既有惯例（calculator/、plot/）沉淀为无 UI 依赖纯函数模块，保证可被 hypium 直接测试（AC9）并保持 UI 薄壳。

**实现要点**：
- 零依赖、零网络、全显式类型标注（ArkTS 惯例）；
- 失败以显式失败态/可识别异常表达，禁止静默错误（CM-06/CM-10）；
- 编码器实现 ISO 18004 子集：byte 模式 + UTF-8、EC-M、版本 1–10 自适应、RS 纠错、标准掩模（CM-04/CM-09 消减落点）。

### 4.2 CalculatorPage 扩展（入口 + 面板）

**变更类型**：新增（既有文件内增量）

**影响的组件**：
| 组件 | 变更内容 |
| ---- | -------- |
| pages/CalculatorPage.ets | 新增：showQrShare 状态、DisplayPanel 区入口、QrSharePanel @Builder、Canvas 绘码与提示分支 |

**变更理由**：沿用 Stack overlay 既有扩展点（SettingsPanel/AboutPanel/PlotPanel 三先例），最小侵入；入口置于显示屏区保证横竖屏可用。

**实现要点**：
- 门控三分支判定置于入口回调（CM-03）；不可分享走 toast/文字提示；
- 面板打开即现算载荷，无缓存（CM-02）；关闭仅复位 showQrShare（CM-07）；
- 码区恒定白底黑模块 + 4 模块静区（CM-05）；try/catch 兜底（CM-10）；
- 不改动任何既有函数/手势/布局结构（AC8）。

### 4.3 测试注册扩展

**变更类型**：新增

**影响的组件**：
| 组件 | 变更内容 |
| ---- | -------- |
| entry/src/test/QrShare.test.ets | 新增：载荷/编码/口径断言 |
| entry/src/test/List.test.ets | 追加一行注册调用 |

**变更理由**：AC9 持久化自动化测试；沿用既有测试注册惯例。

**实现要点**：模块级辅助函数（ArkTS 禁止嵌套函数）；六类口径数据驱动；既有 PlotFunction.test.ets 不动。

---

## 5. 兼容性说明

### 5.1 对现有功能的影响

| 功能 | 影响 | 处理方式 |
| ---- | ---- | -------- |
| 基础/科学计算 | 无（不改 calculator/） | AC8 + 既有测试回归 |
| 函数绘图（PR #41） | 无（不改 plot/） | AC8；PlotFunction.test.ets 保持通过 |
| 历史记录 | 无（不读写历史） | AC8；载荷仅取当前显示串 |
| 设置与主题 | 无（不改 preferences/；主题取色函数只读复用） | AC8；码区恒定配色 |
| 显示屏长按复制手势 | 无（入口为独立 onClick 元素） | 布局评审确认无手势冲突 |

### 5.2 对现有接口的影响

| 接口 | 变更 | 兼容策略 |
| ---- | ---- | -------- |
| 既有全部函数签名 | 无变更 | — |
| 新增 buildQrPayload/encodeQr | 纯新增导出 | 无兼容问题；失败态显式 |

### 5.3 对现有数据的影响

不涉及（无数据模型变更；不新增偏好项、不写历史、无持久化结构变化）。

---

## 6. 迁移方案

> 本文档不涉及数据或模块迁移。

### 6.1 迁移范围
不涉及。

### 6.2 迁移步骤
不涉及。（唯一环境级动作：IMPLEMENTING/APPLYING 前将分支对齐基线 `2500bf49d79b08b135059419c422a3d49dfb4a73`——这是版本控制操作而非架构迁移，已列入 todo.md 门禁。）

### 6.3 回滚方案
功能为纯新增：回滚即删除 qrcode/ 两文件、CalculatorPage 内增量段、测试文件与注册行，恢复至基线状态；无数据回滚需求。

### 6.4 验证方法
AC1–AC9 验收（Tester 独立构建安装 + 真实 UI 操作 + 独立解码工具验证）；既有测试套件同批执行通过。

---

## 7. 附录

### 7.1 术语表

| 术语 | 定义 |
| ---- | ---- |
| overlay 面板 | CalculatorPage Stack 内条件渲染的覆盖层（既有扩展点惯例） |
| 纯函数模块 | 无 UI/IO/网络依赖、同输入同输出的逻辑模块（calculator/、plot/ 惯例） |
| EC-M | QR 纠错等级 M（约 15% 码字可纠错） |
| 静区 | 二维码四周 ≥4 模块宽空白边框 |

### 7.2 参考文档

- `specs/changes/20261023-requirement-add-qrcode-share/proposal.md`（§6 系统架构概述）
- `specs/changes/20261023-requirement-add-qrcode-share/info.md`（代码仓理解）
- `specs/changes/20261023-requirement-add-qrcode-share/delta-spec.md`（§3 系统上下文、§8 SR）
- 基线源码：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（2500bf4，overlay/Canvas/主题惯例）
