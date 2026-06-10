# 程序员模式 + 进制转换 — 开发任务

> **Issue**: #4
> **类型**: 新增功能（type:feature）
> **关联特性**: feat-calculator
> **生成时间**: 2026-06-10
> **生成者**: dev-01 (aid-implementing step2-3)
> **上游文档**: `proposal.md` / `delta-spec.md` / `delta-design.md` / `info.md` / `design-review.md`

---

## 任务概述

- 功能名称：程序员模式 + 进制转换（DEC/BIN/OCT/HEX）
- 变更类型：requirement-add
- 关联特性：feat-calculator
- 开发阶段：IMPLEMENTING → APPLYING
- 预计任务数：**15**（基础设施 4 + 持久化 2 + UI 组件 5 + 集成 3 + 验收 1）

## 任务依赖图

```
基础设施 (1.x)              持久化 (2.x)               UI 组件 (3.x)              集成 (4.x)
─────────────              ──────────                 ──────────                  ──────────
Task 1.1 (Models 枚举) ─┐
Task 1.2 (BaseConverter)─┤
Task 1.3 (BaseConverter 扩展)─┤
Task 1.4 (string.json 资源)──┤
                          ├─→ Task 2.1 (PreferencesStore 4 方法)
                          │       └─→ Task 2.2 (getAllPreferences)
                          │              └─→ Task 4.1 (aboutToAppear 读取)
                          ├─→ Task 3.1 (BaseConversionPanel)
                          │       └─→ Task 4.2 (DisplayPanel 分支)
                          ├─→ Task 3.2 (ProgrammerKeypad)
                          │       └─→ Task 4.3 (ButtonGrid 分支)
                          ├─→ Task 3.3 (ToggleRow 三态化)
                          │       └─→ Task 4.4 (onModeChange + 节流 + 动画)
                          ├─→ Task 3.4 (BaseSwitcher 进制切换器)
                          │       └─→ Task 4.5 (onBaseChange + 键盘过滤)
                          └─→ Task 3.5 (SettingsPanel 默认模式/进制)
                                 └─→ Task 4.6 (Settings 集成)
                                                                                └─→ Task 5.1 (集成测试 + 验收)
```

---

## 任务列表

### 阶段 1：基础设施

#### Task 1.1: 在 Models.ets 中新增 CalculatorMode 与 NumberBase 枚举
**描述**：在 `model/Models.ets` 中追加两个枚举：`CalculatorMode`（BASIC=0 / SCIENTIFIC=1 / PROGRAMMER=2）和 `NumberBase`（BIN=2 / OCT=8 / DEC=10 / HEX=16）。这是后续所有模块的契约基础，必须最先完成。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/model/Models.ets`
**依赖任务**：无
**验收标准**：
- 编译通过（hvigor 0 错误）
- `CalculatorMode.PROGRAMMER === 2`
- `NumberBase.DEC === 10`
- 现有 4 个枚举（CalculatorError / NumberingSystem / ScientificModeType / HistoryItem / CalculatorPreferences）不受影响
- 导出语句 `export enum` 保留
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR （N/A，无运行期逻辑）

#### Task 1.2: 创建 BaseConverter.ets 工具类（toBase / fromBase）
**描述**：在 `calculator/` 目录新建 `BaseConverter.ets`，实现最核心的两个静态方法：`toBase(value, base)` 和 `fromBase(str, base)`。纯函数，无 UI 依赖。先实现正常路径，再处理边界。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/calculator/BaseConverter.ets`
- 测试：`opencalc/entry/src/test/ets/calculator/BaseConverter.test.ets`（如项目无单元测试目录，则仅做手动冒烟）
**依赖任务**：Task 1.1
**验收标准**：
- `BaseConverter.toBase(255, NumberBase.BIN) === "11111111"`
- `BaseConverter.toBase(255, NumberBase.OCT) === "377"`
- `BaseConverter.toBase(255, NumberBase.HEX) === "FF"`（大写）
- `BaseConverter.toBase(0, NumberBase.HEX) === "0"`
- `BaseConverter.toBase(-10, NumberBase.BIN) === "-1010"`
- `BaseConverter.fromBase("FF", NumberBase.HEX) === 255`
- `BaseConverter.fromBase("ff", NumberBase.HEX) === 255`（小写可解析）
- 0 边界 / 负数 / 正常正数三类测试通过
**TDD**：[x] RED（先写测试用例断言） / [x] GREEN（实现后断言通过） / [ ] REFACTOR

#### Task 1.3: 扩展 BaseConverter.ets（isValidChar / formatHex / convert / isOverflow / isValidExpression）
**描述**：在 Task 1.2 基础上继续追加 5 个静态方法，覆盖 UI 调用所需的全部辅助函数。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/calculator/BaseConverter.ets`
- 测试：`opencalc/entry/src/test/ets/calculator/BaseConverter.test.ets`
**依赖任务**：Task 1.2
**验收标准**：
- `isValidChar("0", BIN) === true`；`isValidChar("2", BIN) === false`
- `isValidChar("7", OCT) === true`；`isValidChar("8", OCT) === false`
- `isValidChar("9", DEC) === true`；`isValidChar("A", DEC) === false`
- `isValidChar("F", HEX) === true`；`isValidChar("G", HEX) === false`
- `formatHex("ff00ab") === "FF00AB"`（大写化）
- `convert("ff", HEX, BIN) === "11111111"`
- `isOverflow(2 ** 54) === true`；`isOverflow(2 ** 53) === false`
- `isValidExpression("FF+1", HEX) === true`；`isValidExpression("FF+1", BIN) === false`（含非法字符 `F`）
- 溢出场景 `toBase(2 ** 54, BIN)` 返回 `"Overflow"`
- `toBase(NaN, DEC)` 返回 `"Invalid"`
**TDD**：[x] RED / [x] GREEN / [x] REFACTOR

#### Task 1.4: 追加字符串资源（string.json）
**描述**：在 `resources/base/element/string.json`（如不存在则在 en_US 目录）中追加："基础" / "科学" / "程序员" / "DEC" / "BIN" / "OCT" / "HEX" / "A" / "B" / ... / "F" / "Overflow" / "Invalid" / "不支持小数" / "当前进制不支持该表达式" 等键值。
**涉及文件**：
- `opencalc/entry/src/main/resources/base/element/string.json`
- `opencalc/entry/src/main/resources/en_US/element/string.json`（如有）
- `opencalc/entry/src/main/resources/zh_CN/element/string.json`（如有）
**依赖任务**：无（纯资源准备，可与 1.1~1.3 并行）
**验收标准**：
- 所有新增 key 写入 string.json
- 现有 key 不受影响
- 占位符可被 `getString($r('app.string.xxx'))` 引用

---

### 阶段 2：持久化层

#### Task 2.1: 在 PreferencesStore.ets 追加 4 个偏好方法
**描述**：仿照现有 `getScientificModeDefault / setScientificModeDefault` 模式，新增 4 个方法：`getProgrammerModeDefault` / `setProgrammerModeDefault` / `getDefaultBase` / `setDefaultBase`，键名分别为 `programmerModeDefault` 和 `defaultBase`，默认值参见 §3.7.4。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/preferences/PreferencesStore.ets`
**依赖任务**：Task 1.1（依赖 NumberBase / CalculatorMode 枚举）
**验收标准**：
- `getProgrammerModeDefault()` 在首次启动时返回 0（BASIC）
- `setProgrammerModeDefault(2)` 后立即 flush，再 `get` 返回 2
- `getDefaultBase()` 默认返回 10
- `setDefaultBase(16)` 后 `get` 返回 16
- `this.store === null` 情况下兜底返回默认值（不抛异常）
**TDD**：[x] RED（手动测试） / [x] GREEN / [ ] REFACTOR

#### Task 2.2: 扩展 getAllPreferences 返回结构
**描述**：在 `getAllPreferences()` 中追加 `programmerModeDefault` 和 `defaultBase` 两个字段读取；同时更新 `DEFAULT_PREFERENCES` 常量（来自 Models.ets 扩展）以包含新字段。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/preferences/PreferencesStore.ets`
- 实现：`opencalc/entry/src/main/ets/model/Models.ets`（同步扩展 `CalculatorPreferences` 接口 + `DEFAULT_PREFERENCES`）
**依赖任务**：Task 2.1
**验收标准**：
- `CalculatorPreferences` 接口新增 2 个字段
- `DEFAULT_PREFERENCES` 同步填入默认值（0 / 10）
- `getAllPreferences()` 返回的对象包含 12 个字段（原 10 + 新 2）
- 编译通过
**TDD**：[x] RED / [x] GREEN / [ ] REFACTOR

---

### 阶段 3：UI 组件（@Builder）

#### Task 3.1: 实现 BaseConversionPanel（4 行进制显示）
**描述**：在 CalculatorPage.ets 内新增 `@Builder BaseConversionPanel()`，按 DEC / BIN / OCT / HEX 顺序展示 4 行，行格式 `LABEL: value`。当前进制行用 `getOp()` 背景色高亮。复用现有 `getT1()` / `getT2()` / `getBg()` 主题色方法。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 1.3（依赖 BaseConverter.toBase）
**验收标准**：
- 4 行按固定顺序渲染（DEC → BIN → OCT → HEX）
- DEC 行 28pt Bold、BIN/OCT/HEX 行 18pt Normal
- 当前进制行有 `getOp()` 背景色，非当前行透明
- 表达式为空时 4 行均显示 `0`
- 表达式非空时 4 行实时同步（基于 expression 解析 + BaseConverter.toBase）
- 任一行溢出时该行显示 `Overflow`
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR（UI 单元测试代价高，仅冒烟）

#### Task 3.2: 实现 ProgrammerKeypad（程序员键盘）
**描述**：在 CalculatorPage.ets 内新增 `@Builder ProgrammerKeypad()`，按以下布局：
```
行 1: [DEC][BIN][OCT][HEX]   ← 进制切换器
行 2: [A][B][C][D][E][F][(][)]  ← HEX 模式专属
行 3: [7][8][9][÷]
行 4: [4][5][6][×]
行 5: [1][2][3][-]
行 6: [0][.][⌫][=]
```
当前进制非法字符的按钮置灰（透明度 0.3）；BIN 模式隐藏 A-F、OCT 模式隐藏 8/9/A-F、DEC 模式隐藏 A-F、HEX 显示全部。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 1.3（依赖 BaseConverter.isValidChar）+ Task 3.4（依赖 BaseSwitcher 事件）
**验收标准**：
- BIN 模式：0/1 可用，其他数字 + A-F 全部置灰
- OCT 模式：0-7 可用，8/9/A-F 置灰
- DEC 模式：0-9 可用，A-F 隐藏
- HEX 模式：0-9 + A-F 全部可用，共 16 个字符
- 小数点按钮始终置灰（程序员模式仅整数）
- 复用现有 BtnDig / BtnOp / BtnAct / BtnEq 组件
- 新增 BtnAlpha（HEX 字母按钮，单独样式：getFuncBg 背景 + getOp 文字色）
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 3.3: 重构 ToggleRow 支持三态循环
**描述**：将现有 `@Builder ToggleRow()` 的二态逻辑（基于 `this.scientific` boolean）改为三态（基于 `this.currentMode: CalculatorMode`）。点击时 `(currentMode + 1) % 3` 循环，显示文字从 `this.scientific ? '科学' : '基础'` 改为按 currentMode 查表显示「基础 / 科学 / 程序员」。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 1.1（依赖 CalculatorMode 枚举）
**验收标准**：
- 点击按钮：BASIC → SCIENTIFIC → PROGRAMMER → BASIC 循环
- 按钮文字正确反映当前模式
- 原有"历史"和"⚙"按钮不受影响
- 横屏自动开 scientific 行为不变（科学模式额外按钮独立字段）
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 3.4: 实现 BaseSwitcher（DEC/BIN/OCT/HEX 切换器）
**描述**：在 CalculatorPage.ets 内新增 `@Builder BaseSwitcher()`，渲染 4 个 23% 宽、32dp 高的切换按钮。点击触发 `onBaseChange(newBase)` 方法（Task 4.5 实现）。当前进制按钮高亮（背景色 `getOp()`）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 1.1（依赖 NumberBase 枚举）
**验收标准**：
- 4 个按钮等宽，文字分别为 DEC / BIN / OCT / HEX
- 当前 currentBase 按钮高亮，其他透明
- 点击事件绑定到 `onBaseChange`
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 3.5: 扩展 SettingsPanel（默认模式 + 默认进制）
**描述**：在现有 `@Builder SettingsPanel()` 中追加两个设置项：「默认模式」三选一开关（基础/科学/程序员）、「默认进制」四选一开关（DEC/BIN/OCT/HEX）。复用现有 `ToggleItem` 组件或新增 `RadioItem` 组件。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 2.2（依赖 getAllPreferences）+ Task 1.1（依赖枚举）
**验收标准**：
- 两个设置项显示在 SettingsPanel 内
- 启动时从 PreferencesStore 读取默认值
- 用户修改后立即调用对应 set 方法持久化
- 关闭重开 APP 后设置保持
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

---

### 阶段 4：集成

#### Task 4.1: aboutToAppear 读取偏好初始化 currentMode / currentBase
**描述**：在 CalculatorPage 的 `aboutToAppear()` 中（已有 `initPreferences()` 调用）追加：从 `PreferencesStore.getProgrammerModeDefault()` 读 → 赋给 `this.currentMode`；从 `getDefaultBase()` 读 → 赋给 `this.currentBase`。若 store 不可用，使用默认值（0 / 10）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 2.2
**验收标准**：
- 首次启动 currentMode = 0 (BASIC)、currentBase = 10 (DEC)
- 关闭重开 APP 后 currentMode 恢复为上次退出时模式
- store 为 null 时不抛异常
- 编译通过
**TDD**：[x] RED（手动启动验证） / [x] GREEN / [ ] REFACTOR

#### Task 4.2: DisplayPanel 按 currentMode 分支渲染
**描述**：在 `@Builder DisplayPanel()` 中根据 `this.currentMode` 分支：`BASIC` / `SCIENTIFIC` 保持现有单行布局；`PROGRAMMER` 切换为 `@Builder BaseConversionPanel()`（Task 3.1）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 3.1
**验收标准**：
- BASIC 模式：原有单行显示行为完全不变
- SCIENTIFIC 模式：原有单行显示行为完全不变
- PROGRAMMER 模式：4 行 BaseConversionPanel
- 切换时整个 DisplayPanel 触发 200ms 淡入淡出 + 8dp 上移动画
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 4.3: ButtonGrid 按 currentMode 分支渲染
**描述**：在 `@Builder ButtonGrid()` 中根据 `this.currentMode` 分支：`BASIC` / `SCIENTIFIC` 保持现有 5×N 网格；`PROGRAMMER` 切换为 `@Builder ProgrammerKeypad()`（Task 3.2）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 3.2
**验收标准**：
- BASIC 模式：原 4×5 网格不变
- SCIENTIFIC 模式：原 4×5 网格 + sin/cos/tan 等额外行不变
- PROGRAMMER 模式：6 行 ProgrammerKeypad
- 切换时 200ms 动画
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 4.4: 实现 onModeChange + 节流 + 模式切换动画
**描述**：在 CalculatorPage 中新增 `onModeChange()` 方法：
- 节流：200ms 内连续点击忽略
- 状态更新：`currentMode = (currentMode + 1) % 3`
- 动画：通过 `.animation({ duration: 200, curve: Curve.EaseInOut })` 在 DisplayPanel + ButtonGrid 根节点
- 持久化：调用 `PreferencesStore.setProgrammerModeDefault(currentMode)`
- console.log `modeChanged: X → Y`
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 3.3（ToggleRow 改造）+ Task 2.1（setProgrammerModeDefault）
**验收标准**：
- 200ms 内多次点击仅响应一次
- 模式切换有 200ms 淡入淡出 + 8dp 上移（视觉验证）
- 切换后立即 flush 到 PreferencesStore
- 偏好保存失败 console.warn 不阻塞 UI
- 编译通过
**TDD**：[ ] RED / [ ] GREEN / [ ] REFACTOR

#### Task 4.5: 实现 onBaseChange + 键盘过滤 + 表达式重解读
**描述**：在 CalculatorPage 中新增 `onBaseChange(newBase: NumberBase)` 方法：
- 状态更新：`currentBase = newBase`
- 表达式校验：检查当前 expression 在 newBase 下是否合法
  - 合法 → 直接切换
  - 非法 → Toast「当前进制不支持该表达式」+ 不切换（保持原 currentBase）
- 持久化：调用 `PreferencesStore.setDefaultBase(currentBase)`
- console.log `baseChanged: X → Y`

同时改造 `onEquals()`：当 `currentMode === PROGRAMMER` 时，按 `currentBase` 解读 expression，结果仅显示 DEC（不进行二次进制转换）。
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 1.3（isValidExpression）+ Task 3.4（BaseSwitcher 触发）+ Task 2.1（setDefaultBase）
**验收标准**：
- DEC 模式输入 `255` → 切到 BIN → expression 仍为 `255`，BaseConversionPanel 重新计算 4 行
- BIN 模式输入 `1010` → 切到 OCT → expression 不变，OCT 行显示 `12`
- HEX 模式输入 `FF` → 切到 BIN → 触发 Toast「当前进制不支持该表达式」，currentBase 保持 HEX
- onEquals 改造后程序员模式按 currentBase 解读（如 BIN 模式 `1010 + 1` → DEC 结果 `5`）
- 编译通过
**TDD**：[x] RED（手动 + 单元） / [x] GREEN / [ ] REFACTOR

#### Task 4.6: 实现 onLetter + isCharValid + getXxxDisplay 辅助方法
**描述**：在 CalculatorPage 中实现剩余辅助方法：
- `onLetter(ch: string)` — 处理 A-F 字母按钮点击
- `onDigit(d: string)` 改造 — 调用 `BaseConverter.isValidChar` 校验，非法字符忽略
- `isCharValid(ch: string): boolean` — 程序员模式用，非程序员模式返回 true
- `getDecDisplay() / getBinDisplay() / getOctDisplay() / getHexDisplay(): string` — 4 行数据源
- `isCurrentBase(base: NumberBase): boolean` — 高亮判断
- `getBaseHighlightBg(): string` — 高亮色（复用 getOp）
- `shouldThrottle(): boolean` — 节流判断
- 同时改造 `onAC()` 在程序员模式下同步清空 4 行（实际仅清 expression，4 行通过 expression 派生）
**涉及文件**：
- 实现：`opencalc/entry/src/main/ets/pages/CalculatorPage.ets`
**依赖任务**：Task 1.3（BaseConverter 全套）
**验收标准**：
- BIN 模式点击 "2" → 无反应（isValidChar 返回 false）
- HEX 模式点击 "A" → 追加到 expression，4 行同步更新
- onAC → expression 清空 → 4 行显示 `0` / `0` / `0` / `0`
- 4 行显示辅助方法返回值正确
- 编译通过
**TDD**：[x] RED（单元测试 isCharValid + getXxxDisplay） / [x] GREEN / [ ] REFACTOR

---

### 阶段 5：验收

#### Task 5.1: 集成测试 + 回归测试 + 验收
**描述**：执行以下验证：
1. **集成测试**（6 个场景，参见 design-review §6）：
   - 基础 → 程序员 → 输入 255 → 看到 4 进制
   - 程序员 → HEX → 输入 FF → 4 行同步
   - DEC 输入 10 → 切到 BIN → 显示 1010
   - 程序员 → 科学 → 基础（3 次点击回到起点）
   - BIN 模式点击按钮 "2" → 置灰无反应
   - 关闭重开 APP → 模式与进制保持
2. **回归测试**（参见 design-review §6）：
   - 基础模式四则运算
   - 科学模式 sin/cos/tan
   - 横屏自动开科学模式
   - 历史记录
   - 主题切换
3. **DFR/FMEA 验证**（参见 design-review §5.1 + info.md §6）：
   - 溢出显示 "Overflow"
   - 小数输入 Toast「不支持小数」
   - 200ms 节流保护
4. **编译验证**：`hvigor assembleHap` 0 错误
5. **覆盖率**（如启用）：BaseConverter 单测覆盖率 ≥90%
**涉及文件**：
- 测试：`opencalc/entry/src/test/ets/calculator/BaseConverter.test.ets`
- 冒烟：手动 UI 录屏
**依赖任务**：Task 4.1 ~ 4.6 + Task 3.1 ~ 3.5
**验收标准**：
- 集成测试 6 个场景全部通过
- 回归测试 5 项全部通过
- 编译 0 错误
- 100 个随机整数 4 进制转换正确率 100%
- 模式切换响应 ≤200ms
- 动画流畅度 ≥55fps（目视）
**TDD**：[x] RED（缺陷） / [x] GREEN（修复） / [x] REFACTOR

---

## 开发顺序

```
基础设施（可部分并行）：
  Task 1.1 (Models 枚举) ─┬─→ Task 1.2 (BaseConverter 核心) ─→ Task 1.3 (BaseConverter 扩展)
                          │
                          └─→ Task 1.4 (string.json 资源) ──────────────────────┐
                                                                                │
持久化：                                                                                │
  Task 1.1 ─→ Task 2.1 (PreferencesStore 4 方法) ─→ Task 2.2 (getAllPreferences)│
                                                                                │
UI 组件（可部分并行）：                                                                 │
  Task 1.1 + 1.3 ─→ Task 3.1 (BaseConversionPanel)                              │
  Task 1.1 + 1.3 + 3.4 ─→ Task 3.2 (ProgrammerKeypad)                          │
  Task 1.1 ─→ Task 3.3 (ToggleRow 三态化)                                       │
  Task 1.1 ─→ Task 3.4 (BaseSwitcher)                                           │
  Task 1.1 + 2.2 ─→ Task 3.5 (SettingsPanel) ──────────────────────────────────┘
                                                                                │
集成：                                                                                │
  Task 2.2 ─→ Task 4.1 (aboutToAppear)                                          │
  Task 3.1 ─→ Task 4.2 (DisplayPanel 分支)                                      │
  Task 3.2 ─→ Task 4.3 (ButtonGrid 分支)                                       │
  Task 3.3 + 2.1 ─→ Task 4.4 (onModeChange + 动画)                             │
  Task 1.3 + 3.4 + 2.1 ─→ Task 4.5 (onBaseChange + 重解读)                     │
  Task 1.3 ─→ Task 4.6 (辅助方法)                                               │
                                                                                │
验收：                                                                                │
  Task 4.1 ~ 4.6 + 3.1 ~ 3.5 ─→ Task 5.1 (集成 + 回归 + 验收)                   │
```

**简化关键路径**：
```
Task 1.1 → Task 1.2 → Task 1.3 → Task 2.1 → Task 2.2
   → Task 3.1 → Task 3.2 → Task 3.3 → Task 3.4 → Task 3.5
   → Task 4.1 → Task 4.2 → Task 4.3 → Task 4.4 → Task 4.5 → Task 4.6
   → Task 5.1
```

**可并行机会**：
- Task 1.4（string.json 资源）与 Task 1.1~1.3（基础设施）完全独立，可最早并行
- Task 3.1（BaseConversionPanel）与 Task 3.3（ToggleRow）独立，可并行
- Task 3.2（ProgrammerKeypad）依赖 Task 3.4（BaseSwitcher），需串行
- Task 3.5（SettingsPanel）独立，可与 3.1~3.4 并行

---

## 验收计划

| 任务 | 验收方式 | 验收时间 | 负责人 |
|------|---------|----------|--------|
| Task 1.1 | 编译 + grep 枚举值 | 任务完成后立即 | dev-01 |
| Task 1.2 | 单元测试 + 控制台冒烟 | RED 阶段：~30min | dev-01 |
| Task 1.3 | 单元测试 + 边界用例 | GREEN 阶段：~1h | dev-01 |
| Task 1.4 | 资源加载验证 | 任务完成后立即 | dev-01 |
| Task 2.1 | 手动 + 持久化测试 | 任务完成后立即 | dev-01 |
| Task 2.2 | 编译 + 字段断言 | 任务完成后立即 | dev-01 |
| Task 3.1 | 视觉 + 4 行同步 | dev 完成后冒烟 | dev-01 |
| Task 3.2 | 视觉 + 字符过滤 | dev 完成后冒烟 | dev-01 |
| Task 3.3 | 视觉 + 三态循环 | dev 完成后冒烟 | dev-01 |
| Task 3.4 | 视觉 + 高亮 | dev 完成后冒烟 | dev-01 |
| Task 3.5 | 设置持久化测试 | dev 完成后冒烟 | dev-01 |
| Task 4.1 | 重启验证 | dev 完成后冒烟 | dev-01 |
| Task 4.2 | 视觉 + 模式切换 | dev 完成后冒烟 | dev-01 |
| Task 4.3 | 视觉 + 模式切换 | dev 完成后冒烟 | dev-01 |
| Task 4.4 | 节流 + 动画 + 持久化 | dev 完成后冒烟 | dev-01 |
| Task 4.5 | 6 个集成场景 | dev 完成后冒烟 | dev-01 |
| Task 4.6 | 字符过滤 + AC + 4 行 | dev 完成后冒烟 | dev-01 |
| Task 5.1 | 6 集成 + 5 回归 + 编译 | IMPLEMENTING 收尾 | dev-01 + reviewer |

---

## IMPLEMENTING 阶段完成

**产出物位置**：`specs/changes/20250604-requirement-add-programmer-mode/tasks.md`

**任务列表**（15 个）：
- **基础设施（4）**：Task 1.1 (Models 枚举) / Task 1.2 (BaseConverter 核心) / Task 1.3 (BaseConverter 扩展) / Task 1.4 (string.json 资源)
- **持久化（2）**：Task 2.1 (PreferencesStore 4 方法) / Task 2.2 (getAllPreferences)
- **UI 组件（5）**：Task 3.1 (BaseConversionPanel) / Task 3.2 (ProgrammerKeypad) / Task 3.3 (ToggleRow 三态化) / Task 3.4 (BaseSwitcher) / Task 3.5 (SettingsPanel)
- **集成（6）**：Task 4.1 (aboutToAppear) / Task 4.2 (DisplayPanel 分支) / Task 4.3 (ButtonGrid 分支) / Task 4.4 (onModeChange) / Task 4.5 (onBaseChange) / Task 4.6 (辅助方法)
- **验收（1）**：Task 5.1 (集成 + 回归 + 验收)

**开发顺序（关键路径）**：
```
Task 1.1 → Task 1.2 → Task 1.3 → Task 2.1 → Task 2.2
→ Task 3.1 / 3.2 / 3.3 / 3.4 / 3.5（可部分并行）
→ Task 4.1 → Task 4.2 → Task 4.3 → Task 4.4 → Task 4.5 → Task 4.6
→ Task 5.1
```

**TDD 适用性**：
- **强 TDD**：Task 1.2 / 1.3 / 2.1 / 2.2 / 4.1 / 4.5 / 4.6（逻辑/状态可断言）
- **弱 TDD / 冒烟**：Task 1.1 / 3.1 / 3.2 / 3.3 / 3.4 / 3.5 / 4.2 / 4.3 / 4.4（UI 渲染需目视）

**请确认**：
- 任务分解是否符合您的预期？
- 是否需要调整任务数量/粒度/依赖关系？

选项：
1. 接受，继续进入 APPLYING 阶段
2. 调整（请说明需要调整的内容）

---

> **文档生成说明**
> 本文档由 aid-implementing skill step2-1（任务分解） + step2-2（任务排序） + step2-3（产出 tasks.md）产出。
> 上游：`proposal.md` / `delta-spec.md` / `delta-design.md` / `info.md` / `design-review.md`
> 下一步：等待用户确认后进入 APPLYING 阶段（aid-applying skill）
