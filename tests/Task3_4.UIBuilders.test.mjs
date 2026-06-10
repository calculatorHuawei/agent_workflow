// Task 3.x + 4.x — CalculatorPage.ets UI 组件 + 集成
// 弱 TDD: 源代码层面断言所有新增 @Builder / 方法 / 状态字段存在
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { loadEts } from './loader.mjs'

const modelsCtx = loadEts('opencalc/entry/src/main/ets/model/Models.ets')
const NumberBase = modelsCtx.NumberBase
const CalculatorMode = modelsCtx.CalculatorMode

const P = fileURLToPath(new URL('../opencalc/entry/src/main/ets/pages/CalculatorPage.ets', import.meta.url))
const SRC = readFileSync(P, 'utf8')

// ============ Task 4.1: aboutToAppear 读取偏好 ============
test('Task 4.1: aboutToAppear 读取 currentMode + currentBase', () => {
  assert.ok(SRC.includes('getProgrammerModeDefault'), 'loadPrefs 必须调用 getProgrammerModeDefault')
  assert.ok(SRC.includes('getDefaultBase'), 'loadPrefs 必须调用 getDefaultBase')
  assert.ok(SRC.includes('@State currentMode: CalculatorMode'), '必须有 @State currentMode 字段')
  assert.ok(SRC.includes('@State currentBase: NumberBase'), '必须有 @State currentBase 字段')
})

// ============ Task 3.3: ToggleRow 三态化 ============
test('Task 3.3: ToggleRow 三态化（BASIC → SCIENTIFIC → PROGRAMMER → BASIC）', () => {
  // 点击触发 onModeChange
  assert.ok(SRC.includes('onModeChange'), 'ToggleRow 必须调用 onModeChange')
  // 文字按 currentMode 查表
  assert.ok(SRC.includes("'基础'"), '必须有基础模式文字')
  assert.ok(SRC.includes("'科学'"), '必须有科学模式文字')
  assert.ok(SRC.includes("'程序员'"), '必须有程序员模式文字')
  // 取模逻辑
  assert.ok(/\(this\.currentMode\s*\+\s*1\)\s*%\s*3/.test(SRC), 'onModeChange 必须有 (currentMode+1)%3 逻辑')
})

// ============ Task 3.4: BaseSwitcher ============
test('Task 3.4: BaseSwitcher 渲染 4 个按钮 + 调用 onBaseChange', () => {
  assert.ok(SRC.includes('onBaseChange'), 'BaseSwitcher 必须调用 onBaseChange')
  assert.ok(SRC.includes('NumberBase.DEC'), '必须引用 NumberBase.DEC')
  assert.ok(SRC.includes('NumberBase.BIN'), '必须引用 NumberBase.BIN')
  assert.ok(SRC.includes('NumberBase.OCT'), '必须引用 NumberBase.OCT')
  assert.ok(SRC.includes('NumberBase.HEX'), '必须引用 NumberBase.HEX')
})

// ============ Task 3.1: BaseConversionPanel ============
test('Task 3.1: BaseConversionPanel 显示 4 行（DEC/BIN/OCT/HEX）', () => {
  assert.ok(SRC.includes('BaseConversionPanel') || SRC.includes('@Builder BaseConversionPanel'),
    '必须定义 BaseConversionPanel')
  assert.ok(SRC.includes('getDecDisplay'), '必须实现 getDecDisplay')
  assert.ok(SRC.includes('getBinDisplay'), '必须实现 getBinDisplay')
  assert.ok(SRC.includes('getOctDisplay'), '必须实现 getOctDisplay')
  assert.ok(SRC.includes('getHexDisplay'), '必须实现 getHexDisplay')
})

// ============ Task 3.2: ProgrammerKeypad ============
test('Task 3.2: ProgrammerKeypad 程序员键盘（@Builder + isCharValid）', () => {
  assert.ok(SRC.includes('ProgrammerKeypad'), '必须定义 ProgrammerKeypad')
  assert.ok(SRC.includes('isCharValid'), '必须实现 isCharValid')
  assert.ok(SRC.includes('onLetter'), '必须实现 onLetter')
  assert.ok(SRC.includes('BtnAlpha') || SRC.includes('BtnHex'), '必须有 A-F 按钮构建器')
})

// ============ Task 4.4: onModeChange 节流 + 动画 + 持久化 ============
test('Task 4.4: onModeChange 200ms 节流 + 持久化', () => {
  assert.ok(SRC.includes('setProgrammerModeDefault'), 'onModeChange 必须持久化')
  // 节流
  assert.ok(SRC.includes('lastModeChangeTime') || SRC.includes('throttle') || /\b200\b/.test(SRC),
    'onModeChange 必须有节流机制')
  // 动画
  assert.ok(SRC.includes('animation') || SRC.includes('Curve.EaseInOut'),
    '必须有动画配置')
})

// ============ Task 4.5: onBaseChange + 表达式校验 ============
test('Task 4.5: onBaseChange 校验 + 重解读 + 持久化', () => {
  assert.ok(SRC.includes('setDefaultBase'), 'onBaseChange 必须持久化')
  assert.ok(SRC.includes('isValidExpression') || SRC.includes('当前进制不支持该表达式'),
    '必须有表达式校验逻辑')
})

// ============ Task 4.2 + 4.3: DisplayPanel + ButtonGrid 分支 ============
test('Task 4.2 + 4.3: DisplayPanel + ButtonGrid 按 currentMode 分支', () => {
  assert.ok(SRC.includes('CalculatorMode.PROGRAMMER'), 'DisplayPanel/ButtonGrid 必须按 PROGRAMMER 分支')
  // 切换基础/科学 模式保留原行为
  assert.ok(SRC.includes('CalculatorMode.BASIC') || SRC.includes('CalculatorMode.SCIENTIFIC'),
    '必须保留 BASIC/SCIENTIFIC 分支')
})

// ============ Task 4.6: 辅助方法 ============
test('Task 4.6: 辅助方法（isCharValid/getXxxDisplay/isCurrentBase 等）', () => {
  assert.ok(SRC.includes('isCurrentBase'), '必须实现 isCurrentBase')
  assert.ok(SRC.includes('getBaseHighlightBg'), '必须实现 getBaseHighlightBg')
})

// ============ Task 3.5: SettingsPanel 扩展 ============
test('Task 3.5: SettingsPanel 新增默认模式 + 默认进制', () => {
  // 检查 SettingsPanel 内出现程序员/进制相关
  assert.ok(SRC.includes('默认模式') || SRC.includes('默认模式：') || SRC.includes("'默认模式'"),
    'SettingsPanel 需有"默认模式"文字')
  assert.ok(SRC.includes('默认进制') || SRC.includes("'默认进制'"),
    'SettingsPanel 需有"默认进制"文字')
})

// ============ Task 5.1: 集成场景 ============
test('Task 5.1: CalculatorPage 包含所有 task 关键标识', () => {
  // 12 个 task 的关键 token 都应出现
  const tokens = [
    'currentMode', 'currentBase', 'onModeChange', 'onBaseChange',
    'BaseConversionPanel', 'ProgrammerKeypad', 'BaseSwitcher',
    'getDecDisplay', 'getBinDisplay', 'getOctDisplay', 'getHexDisplay',
    'isCharValid', 'onLetter', 'isCurrentBase'
  ]
  for (const t of tokens) {
    assert.ok(SRC.includes(t), `CalculatorPage.ets 必须包含 "${t}"`)
  }
})
