# 二维码分享 - 增量设计（delta-design.md）

> mod-design 产出（增量变更：`specs/changes/` 已存在）｜ 输入：info.md / proposal.md / delta-spec.md / new-arch.md
> 变更目录：specs/changes/20261023-requirement-add-qrcode-share/ ｜ 基线：`2500bf49d79b08b135059419c422a3d49dfb4a73`
> 全局 specs/design.md 为归档维护占位（基线 stub），本文对未变更部分标注"见基线源码/无相关实现"，仅展开变更点。

## 1. 概述

### 1.1 应用定位
在 OpenCalc for HarmonyOS（单 UIAbility 单页面计算器）上增量新增"二维码分享"能力：结果有效时一次点击打开面板，离线生成仅含当前算式与当前结果的 UTF-8 文本二维码（对应 delta-spec IR-R1~R5，proposal §7 R1–R6）。

### 1.2 核心交互
用户完成计算（`=`）→ 点击显示屏区"二维码"入口 → 门控判定（AC1/AC4）→ QrSharePanel overlay 弹出（载荷现算→QR 编码→Canvas 绘制 + 人类可读回显）→ 外部设备扫码读取（与页面显示逐字一致，AC2）→ 关闭面板（状态零扰动，AC7）。

### 1.3 技术栈概览
- 框架：ArkTS + Stage 模型 + ArkUI 声明式（SDK 5.0.0(12)，runtimeOS HarmonyOS）
- 状态管理：**V1**（基线 CalculatorPage 全量 @State，本设计沿用 V1，不引入 @ComponentV2）
- Kit：@kit.ArkUI（Canvas/promptAction）、@kit.AbilityKit（UIAbilityContext，既有）、@ohos.data.preferences（既有，不触碰）
- 测试：@ohos/hypium 1.0.15（既有 devDependency）
- Native C++/Rust：无；Hvigor 插件：无；**OHPM 运行时依赖：无（零新增）**

## 2. 功能清单

| 功能名 | 说明 | 入口 Ability/Page | 优先级 |
|--------|------|-------------------|--------|
| 二维码分享入口（门控） | 显示屏区文字入口；三分支有效性判定；拒绝时明确提示 | CalculatorPage（竖屏/横屏） | P0 |
| 二维码分享面板 | overlay 展示二维码图形 + 人类可读算式/结果回显 + 关闭（状态零扰动） | CalculatorPage/QrSharePanel | P0 |
| 二维码载荷构建 | 固定三行 UTF-8 文本载荷；逐字取页面显示值；容量判定 | qrcode/QrPayload（纯函数） | P0 |
| 离线二维码编码器 | QR byte 模式/EC-M/版本 1–10/RS 纠错/掩模 → 模块矩阵 | qrcode/QrEncoder（纯函数） | P0 |
| 三主题可识别渲染 | 码区恒定白底黑模块 + 4 模块静区 + 足够模块尺寸 | QrSharePanel（Canvas） | P0 |
| 持久化自动化测试 | 载荷/编码断言 + 六类口径 + 容量边界；注册进 List.test.ets | entry/src/test/QrShare.test.ets | P0 |

## 3. 实现模型

### 3.1 上下文视图

```plantuml
@startuml
actor User as u
actor "外部扫码设备\n(标准解码器)" as scanner
rectangle "OpenCalc (entry HAP)" as app {
  rectangle "CalculatorPage" as page
  rectangle "QrSharePanel\n(overlay, 新增)" as panel
  rectangle "qrcode/QrPayload\n(新增, 纯函数)" as payload
  rectangle "qrcode/QrEncoder\n(新增, 纯函数)" as encoder
}
cloud "远端服务" as remote #line.dashed
u --> page : 点击入口/按键
page --> panel : showQrShare=true
panel --> payload : buildQrPayload(expr,res)
payload --> encoder : 载荷文本
encoder --> panel : boolean[][] 矩阵
panel --> scanner : 二维码画面(单向只读)
remote ..[noroute].. app : 无任何连接(离线约束)
@enduml
```

### 3.2 总体架构

```plantuml
@startuml
rectangle View as v #E8F0FE
rectangle ViewModel as vm #E8F0FE
rectangle Service as s #DEEBF7
rectangle Data as d #F5F5F5
database PlatformKit as k #EEEEEE
v : CalculatorPage\n(门控/入口/QrSharePanel/Canvas)
vm : @State showQrShare\nexpression/result/errorMsg
s : QrPayload · QrEncoder\n(纯函数, 新增)\nCalcEngine · NumberFormatter (复用)
d : PreferencesStore/Models/ErrorFlags\n(零改动)
k : ArkUI(Canvas,promptAction) · hypium
v --> vm : 状态读写
vm --> s : 现算载荷/编码
s --> d : 不触碰(零改动)
v --> k : Canvas 绘制/toast
@enduml
```

单向数据流：View 事件 → @State → 纯函数计算 → 渲染输出；无反向依赖、无缓存层。

### 3.3 HAP/HAR/HSP 模块划分

| 模块 | 类型 | 说明 |
|------|------|------|
| entry | HAP（唯一模块） | 主入口；新增 qrcode/ 源码目录（源码级模块，非独立 HAR/HSP） |
| HAR/HSP | 无 | 不新增共享包（保持零依赖与最小构建面） |
| OHPM 依赖 | 无新增 | dependencies 保持 `{}`；仅既有 devDependencies（hypium/hamock） |

### 3.4 设计系统规格

#### 3.4.1 色彩系统

| 名称 | Light 模式 | Dark/AMOLED 模式 | 用途 |
|------|-----------|------------------|------|
| 码区背景 QR_BG | #FFFFFF | #FFFFFF（**恒定**） | 二维码白底（CM-05） |
| 码区模块 QR_FG | #000000 | #000000（**恒定**） | 二维码黑模块（CM-05） |
| 面板卡片背景 | 复用 `getPanelBg()` | 复用（#FFFFFF/#323232/#0a0a0a） | 面板容器，随主题 |
| 主文字 | 复用 `getT1()` | 复用 | 回显/标题 |
| 次要文字 | 复用 `getT2()` | 复用 | 提示文案 |
| 错误文字 | #F44B3F（`getErr()`） | 同 | 容量/失败提示 |

> 码区恒定配色是 AC5 的直接实现：三主题下对比度恒为黑白最大值（21:1）。

#### 3.4.2 主题系统
沿用 themeIdx（0 浅色/1 AMOLED/2 暗色）与既有取色函数；二维码内容不参与主题换色，主题切换时码区无需重绘（仅容器取色自动更新）。

#### 3.4.3 排版系统

| 名称 | 字号 | 用途 |
|------|------|------|
| 面板标题 | 18fp Bold | "二维码分享" |
| 回显-算式 | 14fp（getT2） | "算式: …" |
| 回显-结果 | 16fp Bold（getT1） | "结果: …" |
| 提示文案 | 14fp（getErr） | 容量/失败/不可分享提示 |

#### 3.4.4 间距与尺寸系统

| 名称 | 值 | 用途 |
|------|-----|------|
| QR_QUIET_ZONE | 4（模块数） | 静区宽（CM-05，AC5） |
| QR_MODULE_PX | 面板宽按 `(size + 2×4)×modulePx ≤ 宽度-32vp` 反解，`modulePx ≥ 4`，取最大可行整值 | 模块边长（足够尺寸，AC5） |
| 面板内边距 | 16vp（沿用 PlotPanel 惯例） | 面板布局 |
| Canvas 尺寸 | 宽 100%、高按矩阵自适应（正方形码区） | 二维码画布 |

#### 3.4.5 图标与图形资源
无新增资源文件；入口/关闭沿用文字符号（"二维码"/"✕ 返回"），与基线 ToggleRow/PlotPanel 惯例一致。

#### 3.4.6 动画规格
无新增动画（同步一次性渲染，无过渡/循环动画，兼顾功耗 DFX）。

#### 3.4.7 响应式断点与栅格
不引入断点系统；沿用基线 `isLandscape`（onAreaChange 宽高比较）双布局：入口置于 DisplayPanel 区保证横竖屏均渲染（proposal 待定假设 9）。

### 3.5 qrcode 模块实现设计（新增）

#### 3.5.1 模块介绍
entry HAP 内源码目录 `entry/src/main/ets/qrcode/`，两个纯逻辑文件；非 installationFree 变更；无 UI 依赖、无 Kit 依赖、无三方依赖。

#### 3.5.2 功能描述
- QrPayload：`buildQrPayload(expression, result)` 三行固定格式构造；`utf8ByteLength(s)` 字节计数；`isWithinCapacity(s)` 容量判定（≤271 字节，EC-M v10 上限）；超限返回失败态（CM-06）。
- QrEncoder：`encodeQr(text)` → `{ size, modules: boolean[][] }`；ISO 18004 子集：byte 模式 + UTF-8、EC-M、版本 1–10 自适应、RS 纠错、掩模（评分选优）；超限/畸形输入返回失败态，不产出残缺矩阵（CM-10）。

#### 3.5.3 目录结构

```
opencalc/entry/src/main/ets/
├── pages/CalculatorPage.ets      # 修改：入口 + showQrShare + QrSharePanel
├── qrcode/                       # 新增
│   ├── QrPayload.ets             # 载荷构造 + 容量判定（纯函数）
│   └── QrEncoder.ets             # QR 编码（纯函数）
└── （其余目录零改动）
opencalc/entry/src/test/
├── List.test.ets                 # 修改：注册 qrShareTest()
└── QrShare.test.ets              # 新增：持久化单测
```

#### 3.5.4 架构图谱

类图：
```plantuml
@startuml
class QrPayload {
  +{static} buildQrPayload(expression: string, result: string): QrPayloadResult
  +{static} utf8ByteLength(text: string): number
  +{static} isWithinCapacity(text: string): boolean
  +{static} PAYLOAD_PREFIX: string
  +{static} MAX_BYTES: number
}
class QrPayloadResult {
  +ok: boolean
  +payload: string
  +reason: string
}
class QrEncoder {
  +{static} encodeQr(text: string): QrEncodeResult
}
class QrEncodeResult {
  +ok: boolean
  +size: number
  +modules: boolean[][]
  +reason: string
}
QrPayload ..> QrPayloadResult
QrPayload ..> QrEncoder : 无(相互独立, QrSharePanel 编排)
QrEncoder ..> QrEncodeResult
note right of QrPayload : 纯函数/无状态/零依赖\n(CM-01: 载荷单一来源)
@enduml
```

时序图（分享主链路）：
```plantuml
@startuml
actor User
participant "CalculatorPage" as cp
participant "QrSharePanel" as p
participant "QrPayload" as pl
participant "QrEncoder" as en
participant "Canvas" as cv
User -> cp : 点击"二维码"入口
cp -> cp : 门控(expr非空 ∧ res非空 ∧ err空)
alt 拒绝
  cp --> User : toast 明确提示(不打开面板)
else 通过
  cp -> p : showQrShare=true
  p -> pl : buildQrPayload(expr, res)
  alt 超容量
    pl --> p : {ok:false, reason:"过长"}
    p --> User : "内容过长，无法生成二维码"
  else 正常
    pl --> p : {ok:true, payload}
    p -> en : encodeQr(payload)
    alt 编码异常/失败
      en --> p : {ok:false}
      p --> User : "二维码生成失败"(try/catch 兜底)
    else 成功
      en --> p : {ok:true, size, modules}
      p -> cv : 白底黑模块绘制 + 4 模块静区
    end
  end
end
User -> p : 点击"✕ 返回"
p -> cp : showQrShare=false（唯一副作用）
@enduml
```

#### 3.5.5 功能与用例分析

```
用例：SC001-UC001 有效结果打开分享面板（delta-spec §7）
前置条件：expression 非空 ∧ result 非空 ∧ errorMsg 为空
步骤：1.点击入口 2.门控通过 3.面板挂载 4.现算载荷 5.编码 6.Canvas 绘制
后置条件：面板可见且含二维码；计算器状态不变
```

#### 3.5.6 接口设计
见 §4.2（签名级定义）。

#### 3.5.7 状态管理设计
qrcode 模块**无状态**（纯函数，无 @State/无模块级可变变量）——这是 CM-01/CM-02（单一来源、无缓存）的结构性保证。测试可直接同进程调用，无 mock 需求。

#### 3.5.8 核心算法（QR 编码，ISO 18004 子集）

| 步骤 | 算法 | 复杂度 |
|------|------|--------|
| 1 容量/版本选择 | 按 UTF-8 字节数 + 模式指示符 + 长度域选最小版本 v∈[1,10]（EC-M） | O(1)（查表） |
| 2 数据编码 | byte 模式：UTF-8 字节流 → 8bit 码字序列（含模式 0100、字符数指示、终止符、pad 0xEC/0x11） | O(n) |
| 3 RS 纠错 | 按 EC-M 每版本块结构分块，GF(256) 多项式除法生成纠错码字并交错 | O(n·d)（n≤271 数据码字，d≤36） |
| 4 矩阵布置 | (4v+17)² 矩阵：定位图案×3/分隔符/校正图案/时序图案/暗模块/格式信息（BCH(15,5)）/版本信息（v≥7，BCH(18,6)）/数据码字之字形填充 | O(N²)，N≤57 |
| 5 掩模 | 8 个标准掩模条件逐一异或，按 N1–N4 规则评分取最低 | O(8·N²) |
| 6 输出 | `{size: 4v+17, modules}` | O(1) |

总体：v10 规模内同步毫秒级；单次矩阵分配，无放大分配。

#### 3.5.9 错误处理

| 场景 | 处理 | 关联措施 |
|------|------|---------|
| 载荷超 271 字节 | QrPayload 返回 `{ok:false, reason}` → 面板"内容过长，无法生成二维码" | CM-06 |
| 编码内部失败/未知异常 | QrEncoder 返回失败态；面板调用处 try/catch 兜底 →"二维码生成失败" | CM-10 |
| 空串/畸形输入 | 入口前置校验拒绝（编码器同样防御性校验，双保险） | CM-03/CM-10 |

无网络/无 IO，无重试语义；不引入埋点（本地单测即维测手段，SDR-05）。

#### 3.5.10 依赖关系
内部依赖：无（qrcode 不依赖任何其他模块，保证独立可测）；外部依赖：无（零 Kit、零 OHPM）。被依赖方：CalculatorPage（UI 编排）、QrShare.test.ets（断言）。

### 3.6 CalculatorPage 二维码分享扩展实现设计（修改）

#### 3.6.1 模块介绍
既有主页面（~700 行）的增量扩展：1 个 @State、1 个入口、1 个 @Builder 面板；不改动既有函数、手势与布局结构（AC8）。

#### 3.6.2 功能描述
入口门控（AC1/AC4）→ 面板编排（回显 AC6、Canvas 绘码、提示分支、关闭 AC7）。

#### 3.6.3 目录结构
不新增目录；改动集中于 `pages/CalculatorPage.ets`（新增段与新增 @Builder，见 §3.5.3）。

#### 3.6.4 架构图谱
见 §3.5.4 时序图；面板挂载遵循既有 Stack overlay 模式（SettingsPanel/AboutPanel/PlotPanel 三先例）。

#### 3.6.5 功能与用例分析
覆盖 SC-001~SC-004 全部 8 UC（delta-spec §7）；门控三分支对应 SC002-UC001；关闭零扰动对应 SC003-UC001。

#### 3.6.6 接口设计
页面内私有方法：`onOpenQrShare(): void`（门控+提示/置位）、`drawQr(): void`（Canvas 重绘，PlotPanel drawPlot 同款守卫 `size>0`）；无对外导出。

#### 3.6.7 状态管理设计（V1）

| 状态 | 类型 | 变更点 | 说明 |
|------|------|--------|------|
| showQrShare | @State boolean | 新增 | 面板开关；关闭路径唯一副作用 `= false`（CM-07） |
| qrPayloadOk | @State boolean | 新增 | 本次载荷/编码成功与否（提示分支渲染） |
| qrErrorText | @State string | 新增 | 容量/失败提示文案 |

数据流：expression/result（既有 @State，只读消费）→ 打开时现算（无缓存，CM-02）→ qrPayloadOk/qrErrorText → 条件渲染。载荷与矩阵不驻留 @State（临时局部量），杜绝陈旧内容。

#### 3.6.8 核心算法
门控：`expression.length > 0 && result.length > 0 && errorMsg.length === 0`（三分支单测覆盖，CM-03）。Canvas 绘制：模块映射 `px = (col)×modulePx`，静区偏移 `+4×modulePx`，先绘白底矩形再逐模块填黑；守卫与重绘时机沿用 PlotPanel（onReady/onAreaChange）。

#### 3.6.9 错误处理
编码调用包 try/catch → qrErrorText 兜底文案（CM-10）；toast 复用 `promptAction.showToast`（不可分享提示，CM-03）。

#### 3.6.10 依赖关系
内部：qrcode/QrPayload、qrcode/QrEncoder（单向）；既有 calculator/、preferences/ 只读不动。外部：@kit.ArkUI（Canvas/promptAction，API 12）。

### 3.7 持久化测试模块实现设计（新增）

#### 3.7.1 模块介绍
`entry/src/test/QrShare.test.ets`，hypium 本地单测；default 导出注册函数经 `List.test.ets` 挂载（沿用 PlotFunction.test.ets 惯例：模块级辅助函数，禁嵌套）。

#### 3.7.2 功能描述
载荷断言（三行结构/前缀/逐字）、编码断言（尺寸公式 `(4v+17)²`/定位图案×3/时序图案/确定性）、六类口径数据驱动、容量边界（271 通过/272 拒绝）。

#### 3.7.3 用例清单（AC9 口径）

| 口径 | 样例输入 | 断言要点 |
|------|---------|---------|
| 普通算式 | ("1+2","3") | 载荷逐字 `OpenCalc\n算式: 1+2\n结果: 3`；矩阵合法 |
| 科学函数 | ("sin(30)","0.5") | 同上（AC2 主样例） |
| 小数结果 | ("1÷8","0.125") | 小数逐字保留 |
| 负数结果 | ("0-5","-5") | 负号逐字保留 |
| 长表达式 | 构造 ≈200 字节算式 | 版本自适应正确、编码成功 |
| 不可分享状态 | ("", "") / errorMsg 态 | 门控判定函数拒绝（不含 UI 的判定逻辑提为可测纯函数 `isShareable(expr,res,err)`） |
| 容量边界 | 271/272 字节 | 通过/拒绝（CM-06） |
| 多字节 | 含 × ÷ π 的算式 | UTF-8 字节级断言（CM-09） |
| 结构断言 | 任一样例载荷 | 尺寸公式/定位×3/时序/确定性（CM-04） |

#### 3.7.4 错误处理
断言失败即 hvigor 构建失败；断言信息含期望/实际值，定位到载荷或矩阵层。

#### 3.7.5 依赖关系
仅依赖 qrcode/* 纯函数与 `../main/ets/...` 相对导入（既有惯例）；既有 PlotFunction.test.ets 零改动、同批执行（AC8 回归口径，CM-08）。

## 4. 接口设计

### 4.1 内部数据访问 API
无相关实现（不新增偏好/存储访问；PreferencesStore 零改动）。

### 4.2 业务抽象接口

```typescript
// qrcode/QrPayload.ets（纯函数，API 12）
export interface QrPayloadResult { ok: boolean; payload: string; reason: string }
export function buildQrPayload(expression: string, result: string): QrPayloadResult
export function utf8ByteLength(text: string): number
export function isShareable(expression: string, result: string, errorMsg: string): boolean

// qrcode/QrEncoder.ets（纯函数，API 12）
export interface QrMatrix { size: number; modules: boolean[][] }
export interface QrEncodeResult { ok: boolean; matrix: QrMatrix | null; reason: string }
export function encodeQr(text: string): QrEncodeResult
```

同步、无 async、无副作用；失败以 `ok:false + reason` 显式表达（CM-06/CM-10）。

### 4.3 后台任务与 ExtensionAbility 接口
无相关实现。

### 4.4 Want / Action 协议
无相关实现。

### 4.5 URI / Deep Link / AppLinking 协议
无相关实现。

### 4.6 IPC 与 RPC 接口
无相关实现。

### 4.7 Native（C/C++）接口
无相关实现。

### 4.8 文件交换接口（分享载荷契约）

| 项 | 契约 |
|----|------|
| 格式 | UTF-8 纯文本，固定三行：`OpenCalc\n算式: {expression}\n结果: {result}` |
| 取值 | {expression}/{result} 逐字取页面显示串（含千分位逗号/负号/小数，AC2） |
| 容量 | ≤271 UTF-8 字节（EC-M v10）；超限显式失败（CM-06） |
| 字符集 | QR byte 模式 + UTF-8（无 ECI 段，解码端按 UTF-8 约定读取） |
| 消费方 | 任意标准 QR 解码器（ISO 18004）；单向只读，无导入执行语义（"本次不包含"） |

## 5. 数据模型

### 5.1 关系型数据库模型
无相关实现（无 RDB）。

### 5.2 领域模型

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| QrPayloadResult.ok | boolean | 是 | 构造是否成功 |
| QrPayloadResult.payload | string | 是（ok 时） | 三行载荷文本 |
| QrPayloadResult.reason | string | 否 | 失败原因（提示用） |
| QrMatrix.size | number | 是 | 矩阵边长 = 4×version+17 |
| QrMatrix.modules | boolean[][] | 是 | true=深色模块 |
| QrEncodeResult | 同 §4.2 | — | 编码结果封装 |

### 5.3 Preferences 结构
无相关实现（零新增 key；既有 key 零改动）。

### 5.4 分布式数据对象模型
无相关实现。

### 5.5 文件格式 Schema
见 §4.8（载荷即对外交换格式；无文件落盘）。

## 6. UI设计系统

色彩/主题/排版/间距/图形/动画见 §3.4；一多响应式：无断点系统，沿用 `isLandscape` 双布局，入口位于 DisplayPanel 区（横竖屏均渲染），面板 Canvas 宽度自适应（`宽度-32vp` 内反解 modulePx）。

## 7. 页面清单与导航

### 7.1 页面清单总表

| 页面名 | 路径 | 入口 Ability | 传参 | 功能摘要 |
|--------|------|-------------|------|---------|
| Index（既有） | pages/Index | EntryAbility | 无 | 启动重定向 |
| CalculatorPage（既有，修改） | pages/CalculatorPage | EntryAbility | 无 | +二维码入口与 QrSharePanel |
| QrSharePanel（新增 @Builder） | 页面内 overlay（无新路由） | — | 无（读 @State） | 二维码+回显+关闭 |

### 7.2 全局导航图

```plantuml
@startuml
[*] --> Index
Index --> CalculatorPage : router.replaceUrl
CalculatorPage --> CalculatorPage : 二维码入口\n(showQrShare=true, overlay)
CalculatorPage --> CalculatorPage : ✕ 返回\n(showQrShare=false)
note right of CalculatorPage : Settings/About/Plot 面板既有导航零改动
@enduml
```

### 7.3 Deep Link / AppLinking 处理
无相关实现。

### 7.4 Want 跳转矩阵
无相关实现。

## 8. 用户交互规格

### 8.1 手势交互目录

| 手势 | 目标 | 行为 | 关联AC |
|------|------|------|--------|
| onClick | "二维码"入口 | 门控判定 → 打开面板/toast 提示 | AC1/AC4 |
| onClick | 面板"✕ 返回" | 仅 showQrShare=false | AC7 |
| LongPressGesture（既有） | DisplayPanel | 长按复制，零改动 | AC8 |

### 8.2 弹窗/Sheet/Menu 目录

| 组件 | 触发 | 内容 |
|------|------|------|
| QrSharePanel（Stack overlay，非系统弹窗） | 入口门控通过 | 标题/回显/Canvas 码/提示分支/关闭 |
| promptAction.showToast | 门控拒绝 | "请先完成一次有效计算"（文案 §13 待确认项 3） |

### 8.3 剪贴板与反馈行为
不新增剪贴板行为（既有长按复制不动）；反馈仅 toast 与面板内错误文案。

### 8.4 卡片交互
无相关实现。

## 9. 平台集成

### 9.1 构建配置与依赖
零新增依赖：entry 与根 oh-package.json5 `dependencies` 保持 `{}`；build-profile/module.json5 零改动（签名配置沿用仓库现状，Tester 侧本地适配，AC10）。

### 9.2 权限与运行时请求
无新增权限（module.json5 零改动；既有仅 `ohos.permission.VIBRATE` system_grant）——离线约束（TM-02）的可验证证据。

### 9.3 系统能力（Kits）清单

| Kit | 关键 API | 用途 |
|-----|---------|------|
| @kit.ArkUI（API 12） | Canvas/CanvasRenderingContext2D、promptAction.showToast | 码面绘制/提示 |
| @ohos/hypium（测试） | describe/it/expect | 持久化单测 |

### 9.4 后台与 Extension
无相关实现。

### 9.5 备份与恢复
无相关实现（无新增持久化数据）。

### 9.6 分布式与跨端
无相关实现（跨端传递仅经外部扫码器单向读取，无系统分布式能力）。

## 10. 偏好设置目录

| key | 类型 | 默认值 | 说明 | 行为影响 |
|-----|------|--------|------|---------|
| （零新增） | — | — | 本需求不新增任何偏好项；既有 key（vibrateOn/preventSleep/radianMode/theme/scientific 等）零改动 | 无 |

## 自验证（与 delta-spec 交叉校验）

| 校验项 | 结果 |
|--------|------|
| 功能一致性 | IR-R1~R5 ↔ §2 功能清单 6 项一一对应：通过 |
| 页面一致性 | 无新路由页；QrSharePanel 为页面内 overlay ↔ §7.1：通过 |
| 数据一致性 | 零持久化新增 ↔ §5.3/§10：通过 |
| 权限一致性 | 零新增权限 ↔ §9.2：通过 |
| Kit 一致性 | 仅 ArkUI/hypium ↔ §9.3：通过 |
| 措施落点 | CM-01~CM-10 均有 §3.5/§3.6/§3.7 实现落点：通过 |

---
> 本文档由 mod-design skill 生成。
> 标记 [推断] 的内容为基于设计推断，非确定性事实。本文未使用 [推断] 标记：实现参数（入口文案/摆放、编码参数、提示文案）均已在 delta-spec §13 待确认清单以默认值显式记录。
> 生成时间: 2026-10-23
