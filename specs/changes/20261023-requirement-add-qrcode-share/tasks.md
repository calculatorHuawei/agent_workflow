# 二维码分享（当前算式与结果一键生成二维码）开发任务

> MigBot IMPLEMENTING 产出（Step 2.1 任务分解 / Step 2.2 任务排序 / Step 2.3 tasks.md）。
> 输入：proposal.md §5–§8、delta-spec.md §7–§13、delta-design.md §3.4–§3.7/§4.2、info.md §3–§10。
> 来源：calculatorHuawei/agent_workflow#42 ｜ 基线：`2500bf49d79b08b135059419c422a3d49dfb4a73`（PR #41 合并后）

## 任务概述

- 功能名称：当前算式与结果一键生成二维码（二维码分享）
- 变更类型：新增功能（requirement-add；orchestrator 元数据 refactor 差异已在 proposal §1.1/todo.md 记录备查）
- 关联全局文件：specs/spec.md / specs/arch.md / specs/design.md
- 开发阶段：IMPLEMENTING（任务分解）→ APPLYING（RED → GREEN → REFACTOR 逐任务执行）
- 预计任务数：10（含 1 个环境门禁任务）
- 接口契约：以 delta-design **§4.2 签名级定义为准**（`buildQrPayload/utf8ByteLength/isShareable`、`encodeQr`、`QrPayloadResult/QrMatrix/QrEncodeResult`；§3.5.4 类图为示意，若与 §4.2 冲突按 §4.2 实现，§3.5.6 亦指向 §4.2）
- 载荷契约：UTF-8 文本 `OpenCalc\n算式: {expression}\n结果: {result}`；容量上限 271 字节（EC-M v10）；算式/结果逐字取页面显示串（含千分位逗号，AC2）
- ArkTS 约束（info.md §3.3/§10）：全量显式类型标注；测试辅助函数必须模块级（禁嵌套）；字面量分支赋值规避枚举类型收窄
- 零改动硬约束（AC8）：`plot/`、`calculator/`、`model/`、`preferences/`、`entryability/`、`pages/Index.ets`、`module.json5`、根与 entry 的 `oh-package.json5`（dependencies 保持 `{}`）一律不得改动

## 任务列表

### 阶段 0：环境门禁（APPLYING Step 0 前置）

#### Task 0.1: 基线对齐复核
**描述**：实施任何代码改动前，核对当前分支 HEAD 即基线 merge commit `2500bf49d79b08b135059419c422a3d49dfb4a73`，且工作区除 `specs/changes/20261023-requirement-add-qrcode-share/` 外无未提交改动。IMPLEMENTING 阶段（2026-10-23）已实测 HEAD=`2500bf4`（git log 第一条），PLANNING 期间记录的"分支停留在第一父提交 `672e005`"门禁当前已满足；本任务为 APPLYING 开始时的复核门禁，若不对齐则先对齐再继续。
**涉及文件**：
- 无代码文件（仅 git 状态核对，产物记入 APPLYING 环境检查记录）
**依赖任务**：无
**验收标准**：
- `git log --oneline -1` 输出 `2500bf4 Merge pull request #41 from calculatorHuawei/agent/issue-40-task-1`
- `opencalc/entry/src/main/ets/plot/`（FunctionPlotter.ets、PlotAxis.ets）与 `opencalc/entry/src/test/PlotFunction.test.ets` 存在于工作区
**TDD**：不适用（环境门禁，无代码行为）

### 阶段 1：T0 纯函数模块（qrcode/，纯函数先行，TDD RED→GREEN）

#### Task 1.1: QrPayload 载荷构建、门控判定与容量防护纯函数
**描述**：新建 `qrcode/QrPayload.ets`，零 UI/Kit/三方依赖的纯函数模块。导出：`QrPayloadResult { ok, payload, reason }` 接口；`PAYLOAD_PREFIX`/`MAX_BYTES(=271)` 常量；`buildQrPayload(expression, result)` 按固定三行格式拼接 UTF-8 载荷（逐字取入参，禁止重算/重排，CM-01）；`utf8ByteLength(text)` 按 UTF-8 语义计字节（多字节字符 ×÷π 按字节而非字符数，CM-09）；`isShareable(expression, result, errorMsg)` 三分支门控判定（CM-03）。容量前置判定：载荷 >271 字节返回 `{ok:false, reason}` 且不产出载荷文本（CM-06）。TDD：先在 `QrShare.test.ets` 写 RED（本任务创建该测试文件并在 `List.test.ets` 注册 `qrShareTest()`，保证套件自始可执行，CM-08），再实现转 GREEN。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/qrcode/QrPayload.ets`（新增）
- 测试：`opencalc/entry/src/test/QrShare.test.ets`（新增，本任务起步：载荷逐字/多字节/容量边界/门控三分支用例）
- 测试注册：`opencalc/entry/src/test/List.test.ets`（修改：追加 1 行注册；唯一允许的注册入口）
**依赖任务**：Task 0.1
**验收标准**：
- `buildQrPayload("sin(30)","0.5")` 返回 `{ok:true, payload:"OpenCalc\n算式: sin(30)\n结果: 0.5"}`，三行结构与"算式: ""结果: "前缀逐字正确（AC2）
- 普通（"1+2"/"3"）、科学函数（"sin(30)"/"0.5"）、小数（"1÷8"/"0.125"）、负数（"0-5"/"-5"）、含 ×÷π 多字节算式的载荷断言全部通过（AC9 口径）
- `utf8ByteLength("×")` = 2、`utf8ByteLength("π")` = 2（字节级，CM-09）
- `isShareable` 三分支：空算式/空结果/errorMsg 非空均返回 false，仅三者全通过返回 true（AC4/CM-03）
- 271 字节载荷 `ok:true`、272 字节 `ok:false` 且 payload 为空（CM-06 容量边界）
- 同入参重复调用输出一致（纯函数确定性）；模块无 @State/无模块级可变状态
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.2: QrEncoder 版本选择与数据码字编码
**描述**：新建 `qrcode/QrEncoder.ets`，实现 ISO 18004 子集编码链第 1–2 步（delta-design §3.5.8）：①按 UTF-8 字节数 + 模式指示符（byte 模式 0100）+ 字符数指示，查 EC-M 版本容量表选最小版本 v∈[1,10]；②数据编码：UTF-8 字节流 → 8bit 码字序列，含模式段、长度段、数据段、终止符、0xEC/0x11 填充字节至该版本数据码字容量。TDD：先在 QrShare.test.ets 追加数据段结构 RED 断言（总码字数与版本块表一致），再实现转 GREEN。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/qrcode/QrEncoder.ets`（新增）
- 测试：`opencalc/entry/src/test/QrShare.test.ets`（追加）
**依赖任务**：Task 1.1
**验收标准**：
- 典型载荷（约 40–80 字节）选中版本与 EC-M 容量表一致；边界字节数逐版本选版正确（版本自适应）
- 数据码字序列总长等于该版本 EC-M 数据码字数；含模式指示符 0100 与正确字符数指示
- 填充字节交替 0xEC/0x11；终止符至多 4 bit 且按规范补齐
- 输入超 271 字节不进入编码（前置拒绝，与 CM-06 一致）
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.3: QrEncoder Reed-Solomon 纠错与分块交错
**描述**：实现编码链第 3 步：GF(256) 多项式运算（生成/除法，本原多项式 0x11D）；按 EC-M 各版本块结构将数据码字分块，逐块生成纠错码字；数据码字与纠错码字按规范交错。TDD：先写已知向量 RED（标准 RS 测试向量 + 交错长度断言），再实现转 GREEN。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/qrcode/QrEncoder.ets`（追加）
- 测试：`opencalc/entry/src/test/QrShare.test.ets`（追加）
**依赖任务**：Task 1.2
**验收标准**：
- GF(256) 乘除法对已知测试向量结果正确
- 各版本（1–10）EC-M 块结构（块数/每块数据码字/纠错码字数）与标准表一致
- 交错输出总长 = 数据码字数 + 纠错码字数；多块时交错顺序符合规范
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.4: QrEncoder 矩阵布置
**描述**：实现编码链第 4 步：生成 (4v+17)² 模块矩阵并布置——三个定位图案及分隔符、校正图案（按版本表）、时序图案、暗模块、格式信息（BCH(15,5)，EC-M + 掩模号）、版本信息（v≥7，BCH(18,6)）、数据码字之字形填充（跳过功能模块）。TDD：先写矩阵结构 RED 断言（尺寸公式/定位图案×3/时序交替/暗模块），再实现转 GREEN（CM-04）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/qrcode/QrEncoder.ets`（追加）
- 测试：`opencalc/entry/src/test/QrShare.test.ets`（追加）
**依赖任务**：Task 1.3
**验收标准**：
- 矩阵边长 = 4×版本+17（v1=21 … v10=57），AC9 结构断言基线
- 三个定位图案（左上/右上/左下）形状逐模块正确；时序图案第 6 行/列黑白交替
- 格式信息 BCH(15,5) 位串与规范一致（含掩模号）；v≥7 版本信息 BCH(18,6) 正确
- 之字形填充覆盖全部数据码字且不侵入功能模块；左下角暗模块恒为深色
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.5: QrEncoder 掩模评分与 encodeQr 公共入口封装
**描述**：实现编码链第 5–6 步并封装公共入口：8 个标准掩模条件逐一异或，按 N1–N4 规则评分取最低；`encodeQr(text): QrEncodeResult` 组装全链路（防御性校验：空串/超限输入返回 `{ok:false, matrix:null, reason}`，不产出残缺矩阵，CM-10）；同文本重复编码输出一致（确定性）。测试含长表达式（≈200 字节算式）版本自适应编码成功用例（AC9"长表达式"口径）。TDD：先 RED（掩模评分确定性、失败态、长表达式），再实现转 GREEN。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/qrcode/QrEncoder.ets`（追加收口）
- 测试：`opencalc/entry/src/test/QrShare.test.ets`（追加）
**依赖任务**：Task 1.4
**验收标准**：
- 8 掩模逐一生成合法矩阵，评分函数对已知输入取最低分掩模；结果确定（同输入同掩模同矩阵）
- `encodeQr("OpenCalc\n算式: sin(30)\n结果: 0.5")` 产出 `{ok:true, matrix:{size,modules}}`，矩阵通过 Task 1.4 全部结构断言（CM-04）
- 空串/超 271 字节输入返回失败态，不抛未处理异常、无残缺矩阵（CM-10）
- ≈200 字节长表达式编码成功且版本自适应正确（AC9 长表达式口径）
- 同一文本重复编码输出完全一致（确定性）
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

### 阶段 2：T1 UI 组装（CalculatorPage 扩展）

#### Task 2.1: 二维码分享入口与门控接线
**描述**：扩展 `pages/CalculatorPage.ets`：新增 `@State showQrShare/qrPayloadOk/qrErrorText`（delta-design §3.6.7）；在 DisplayPanel 区新增"二维码"文字入口（横竖屏均渲染，待定假设 9；不与既有长按复制手势冲突）；入口回调调用 `isShareable(this.expression, this.result, this.errorMsg)`：通过置 `showQrShare=true`，拒绝经 `promptAction.showToast` 显示"请先完成一次有效计算"且不置位（CM-03）。最小侵入：不改动任何既有函数、手势与布局结构（AC8）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（修改：+3 状态 + 入口 + 回调）
**依赖任务**：Task 1.1（isShareable）、Task 1.5（面板打开后有可用编码器）
**验收标准**：
- 竖屏与横屏（isLandscape 双布局）均能看到一次明确的"二维码"入口（AC1/F1.1）
- 有效结果（expression 非空 ∧ result 非空 ∧ errorMsg 空）点击 → 面板打开（AC1）
- 空算式/无结果/errorMsg 非空三分支点击 → toast 提示、面板不打开、无任何二维码（AC4/CM-03）
- 长按复制手势行为不变；既有布局元素无位移或功能扰动（AC8）
**TDD**：[x] RED（isShareable 接线行为经 QrShare.test.ets 门控用例守护）/ [x] GREEN / [x] REFACTOR
**UI 验证**：AC1/AC4 的最终验证由 Tester 真实 UI 操作承担（AC10），Developer 侧以代码审查 + 单测口径交付

#### Task 2.2: QrSharePanel 面板、提示分支与关闭零扰动
**描述**：在 CalculatorPage 新增 QrSharePanel `@Builder`（Stack overlay，沿用 SettingsPanel/AboutPanel/PlotPanel 三先例）：打开即现算 `buildQrPayload(this.expression, this.result)`（无载荷级缓存，CM-02），成功则回显人类可读"算式: …""结果: …"（AC6）并进入渲染；容量超限显示"内容过长，无法生成二维码"（CM-06）；编码异常经 try/catch 兜底显示"二维码生成失败"，异常不冒泡（CM-10）；"✕ 返回"仅执行 `showQrShare=false` 单一赋值，不触碰 expression/result 及其他面板开关（CM-07/AC7）。载荷与矩阵为局部量，不驻留 @State（杜绝陈旧内容，delta-design §3.6.7）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（修改：+QrSharePanel @Builder + 提示分支 + 关闭回调）
**依赖任务**：Task 2.1
**验收标准**：
- 面板同时显示二维码区与人类可读算式/结果回显，回显与页面显示串逐字一致（AC6）
- 打开即现算：修改算式重算后再次打开，载荷为新值，无旧内容痕迹（AC3/CM-02）
- 超容量分支显示明确提示且不渲染二维码（AC4 外推/CM-06）
- 编码异常分支显示失败提示，应用不崩溃（CM-10）
- 关闭仅复位 showQrShare；expression/result/主题/历史等状态与打开前一致（AC7/CM-07）
**TDD**：[x] RED（SC003-UC002 载荷现算断言已在 QrShare.test.ets 守护现算语义）/ [x] GREEN / [x] REFACTOR

#### Task 2.3: Canvas 二维码渲染（三主题恒定配色 + 静区）
**描述**：QrSharePanel 内以 Canvas（@kit.ArkUI，API 12）绘制模块矩阵：先绘白色矩形底（#FFFFFF）再逐模块填黑（#000000），配色恒定不随主题变化（CM-05/AC5）；静区 ≥4 模块宽（QR_QUIET_ZONE=4）；模块边长按面板宽度反解：`(size + 2×4)×modulePx ≤ 宽度−32vp` 且 `modulePx ≥ 4` 取最大可行整值（delta-design §3.4.4，足够尺寸）；重绘时机与守卫沿用 PlotPanel 惯例（onReady/onAreaChange 且宽高 >0 才绘制，info.md §3.3）；无动画/无循环重绘（DFX）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`（修改：+Canvas 绘制 `drawQr()`）
**依赖任务**：Task 2.2
**验收标准**：
- 码区恒定白底黑模块：浅色/暗色/AMOLED（themeIdx 0/2/1）三主题下配色与对比度不变（AC5/CM-05）
- 二维码四周存在 ≥4 模块宽白色静区（AC5）
- 模块边长 ≥4 等效 px 且码面完整落于面板宽度内（规格要求，delta-spec SC001 规格表）
- 守卫生效：宽高为 0 时不绘制、不报错；面板尺寸变化（横竖屏切换）后重绘正确
- 无新增动画/定时器（DFX 功耗约束）
**TDD**：[x] RED（渲染参数/静区常量可经渲染函数断言的口径落 QrShare.test.ets）/ [x] GREEN / [x] REFACTOR
**UI 验证**：三主题截图解码（AC5）由 Tester 独立执行（AC10）

### 阶段 3：持久化测试收官与回归

#### Task 3.1: QrShare 测试套件六类口径收官、注册完整性与 AC8 回归
**描述**：对 `QrShare.test.ets` 做 AC9 完整性收官：确认六类口径（普通算式、科学函数、小数结果、负数结果、长表达式、不可分享状态）各 ≥1 条用例，结构断言（尺寸公式/定位图案×3/时序图案/确定性）、容量边界（271/272）、多字节 UTF-8 字节级断言齐备（CM-08/CM-04/CM-09）；辅助函数全部模块级（ArkTS 禁嵌套）；`List.test.ets` 注册唯一入口指向 `qrShareTest()`。执行 hvigor 本地单测全绿，且既有 `PlotFunction.test.ets` 同批执行通过（AC8 回归口径）；`git diff` 审计确认零改动模块（plot/、calculator/、model/、preferences/、module.json5、oh-package.json5）无任何变更（AC8/SDR-07）。
**涉及文件**：
- 测试：`opencalc/entry/src/test/QrShare.test.ets`（收尾完善）
- 测试注册：`opencalc/entry/src/test/List.test.ets`（核对注册行）
**依赖任务**：Task 2.3
**验收标准**：
- hvigor 本地单测：QrShare 套件全部通过，六类 AC9 口径各至少 1 条用例（AC9/SR-04 AC1–AC2）
- 套件持久保存在仓库（非临时脚本）且经 List.test.ets 唯一入口注册（CM-08）
- 同批执行既有 PlotFunction.test.ets 保持通过（AC8/CM-08）
- git diff 审计：plot/、calculator/ 算法、model/、preferences/、EntryAbility/Index、module.json5、oh-package 零改动（AC8）
- 断言失败信息含期望/实际值，可定位到载荷层或矩阵层（SR-04 最小保证）
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR（收官批运行）

## 开发顺序

```
Task 0.1 → Task 1.1 → Task 1.2 → Task 1.3 → Task 1.4 → Task 1.5 → Task 2.1 → Task 2.2 → Task 2.3 → Task 3.1 → 完成
```

- 关键路径：全部任务串行（单 Developer 工作流）；Task 1.2→1.3→1.4→1.5 为同文件（QrEncoder.ets）增量内聚链，不可并行。
- Tier 顺序依据：delta-spec §11"自底向上：SR-00/SR-01（T0 纯函数先行，TDD RED→GREEN）→ SR-02/SR-03（T1 UI 组装）→ SR-04（测试贯穿，RED 先行、收官注册）"。
- 每任务执行节奏（APPLYING 阶段）：RED（先落失败测试）→ GREEN（最小实现转绿）→ REFACTOR（与基线风格对齐：全量显式类型标注、无嵌套函数）。

## 任务 × 需求 × FMEA 追溯

| 任务 | 对应 SR | 对应特性/AC | 消减措施落点 |
|------|---------|------------|-------------|
| Task 0.1 | 全局门禁 | 基线约束（Issue #42 开发基线） | 遗留问题 #2（design-review §4） |
| Task 1.1 | SR-00 | F3/F3.1、AC2/AC3/AC4/AC9 | CM-01/CM-03/CM-06/CM-09 |
| Task 1.2 | SR-01 | F4（数据编码）、AC9 | CM-04 前置 |
| Task 1.3 | SR-01 | F4（RS 纠错）、AC9 | CM-04 |
| Task 1.4 | SR-01 | F4（矩阵布置）、AC5/AC9 | CM-04 |
| Task 1.5 | SR-01 | F4（掩模/入口封装）、AC9 | CM-04/CM-06/CM-10 |
| Task 2.1 | SR-02 | F1/F1.1、AC1/AC4 | CM-03 |
| Task 2.2 | SR-03 | F2/F2.1、AC3/AC4/AC6/AC7 | CM-02/CM-06/CM-07/CM-10 |
| Task 2.3 | SR-03 | F5、AC5 | CM-05 |
| Task 3.1 | SR-04 | F6、AC8/AC9 | CM-08 |

## 验收计划

| 任务 | 验收方式 | 验收时间 |
|------|---------|----------|
| Task 0.1 | git 状态核对（APPLYING 环境检查记录） | APPLYING Step 0（2026-10-23 起） |
| Task 1.1 | hvigor 本地单测（载荷/门控/容量 RED→GREEN）+ 代码审查 | APPLYING Task 执行时 |
| Task 1.2 | hvigor 本地单测（版本/码字结构）+ 代码审查 | APPLYING Task 执行时 |
| Task 1.3 | hvigor 本地单测（RS 已知向量/交错）+ 代码审查 | APPLYING Task 执行时 |
| Task 1.4 | hvigor 本地单测（矩阵结构断言）+ 代码审查 | APPLYING Task 执行时 |
| Task 1.5 | hvigor 本地单测（掩模/失败态/确定性/长表达式）+ 代码审查 | APPLYING Task 执行时 |
| Task 2.1 | 代码审查（门控接线/最小侵入）+ 单测口径；AC1/AC4 终验归 Tester（AC10） | APPLYING Task 执行时 |
| Task 2.2 | 代码审查（现算/提示分支/关闭单赋值）+ 单测口径 | APPLYING Task 执行时 |
| Task 2.3 | 代码审查（恒定配色/静区/守卫）；AC5 三主题终验归 Tester（AC10） | APPLYING Task 执行时 |
| Task 3.1 | hvigor 全量单测批（QrShare + PlotFunction 同批）+ git diff 零改动审计 | APPLYING 收官 |

> AC10/AC11（Tester 独立构建安装 + 真实 UI 操作 + 独立二维码解码验证；Reviewer 双审）不在 Developer 任务范围内，由工作流后续角色承担。
