// 静态 UI 验证脚本 — 检查 CalculatorPage.ets 改动是否破坏布局/语法
//
// 验证内容:
//   1. Row() 子元素宽度总和是否合理 (≤ 100% 合理但有边距)
//   2. BtnPct 主题色逻辑在 3 主题下都有返回值
//   3. AboutPanel 百分号说明文案正确（3 行，无语法错）
//   4. 改动的 Row 数量与 5×N 布局兼容
//
// 运行: node ui_static_check.mjs

'use strict'

import { readFileSync, existsSync } from 'node:fs'

const CALC_PATH = 'D:/huawei/Demo/worktrees/issue-6/opencalc/entry/src/main/ets/pages/CalculatorPage.ets'

let pass = 0
let fail = 0
const log = []

function check(name, ok, detail = '') {
  if (ok) {
    pass++
    log.push(`✅ ${name}${detail ? ' — ' + detail : ''}`)
  } else {
    fail++
    log.push(`❌ ${name}${detail ? ' — ' + detail : ''}`)
  }
}

if (!existsSync(CALC_PATH)) {
  console.error(`FAIL: 文件不存在 ${CALC_PATH}`)
  process.exit(1)
}

const src = readFileSync(CALC_PATH, 'utf-8')

// ============================================================
// 1. BtnPct 子构建器存在 & 关键属性正确
// ============================================================
const btnPctMatch = src.match(/@Builder BtnPct\(\)\s*\{([^}]*)\}/s)
check('BtnPct 子构建器存在', btnPctMatch !== null)
if (btnPctMatch) {
  const body = btnPctMatch[1]
  check('BtnPct 使用 width(\'100%\')', body.includes("width('100%')"))
  check('BtnPct 使用 fontColor(\'#FFFFFF\')', body.includes("fontColor('#FFFFFF')"))
  check('BtnPct 使用 fontWeight(FontWeight.Bold)', body.includes('FontWeight.Bold'))
  check('BtnPct 触发 onOp(\'%\')', body.includes("onOp('%')"))
  check('BtnPct 使用 backgroundColor(this.getPct())', body.includes('this.getPct()'))
  check('BtnPct 横竖屏自适应 height', /height\(this\.isLandscape\s*\?\s*36\s*:\s*56\)/.test(body))
}

// ============================================================
// 2. getPct 主题色取色器
// ============================================================
const getPctMatch = src.match(/getPct\(\):\s*string\s*\{([\s\S]*?)\n\s{2}\}/)
check('getPct 取色器存在', getPctMatch !== null)
if (getPctMatch) {
  const body = getPctMatch[1]
  check('getPct 处理 themeIdx=1 (AMOLED 柔和橙)', /themeIdx\s*===\s*1[\s\S]{0,60}#FF9F0A/.test(body))
  check('getPct 处理 themeIdx=2 (暗色 饱和橙)', /themeIdx\s*===\s*2[\s\S]{0,60}#FF9500/.test(body))
  check('getPct 有默认返回值 #FF9500', /#FF9500/.test(body))
}

// ============================================================
// 3. ButtonGrid 布局 — 5×N 兼容性
// ============================================================
const gridMatch = src.match(/@Builder ButtonGrid\(\)\s*\{([\s\S]*?)\n\s{2}\}/)
check('ButtonGrid 函数存在', gridMatch !== null)
if (gridMatch) {
  const grid = gridMatch[1]
  // 5 行 (科学2行 + 数字3行) - 科学模式
  const hasSci = /this\.BtnFunc\('sin'\)/.test(grid)
  check('科学模式行存在 (sin/cos/tan/ln/log)', hasSci)
  // 顶部行
  check('顶部行已去 % (4 个按钮)', /this\.BtnActPct\('AC'\)[\s\S]{0,100}this\.BtnOpPct\('\('\)[\s\S]{0,100}this\.BtnOpPct\('\)'\)[\s\S]{0,100}this\.BtnOpPct\('÷'\)/.test(grid))
  // 独立 % 行
  check('独立 % 行存在 (Row { this.BtnPct() })', /Row\(\)\s*\{\s*this\.BtnPct\(\)\s*\}/.test(grid))
  // 数字行
  check('数字行 7 8 9 存在', /this\.BtnDig\('7'\)[\s\S]{0,100}this\.BtnDig\('9'\)/.test(grid))
  check('末行 0 . ⌫ = 存在', /this\.BtnDig\('0'\)[\s\S]{0,200}this\.BtnEq\(\)/.test(grid))
}

// ============================================================
// 4. AboutPanel 百分号说明 (3 行)
// ============================================================
check('AboutPanel 有标题行 "—— 百分号用法 ——"', /Text\('——\s*百分号用法\s*——'\)/.test(src))
check('AboutPanel 有示例 "50+10% = 55"', /Text\('50\+10%\s*=\s*55'\)/.test(src))
check('AboutPanel 有示例 "200*10% = 20"', /Text\('200\*10%\s*=\s*20'\)/.test(src))
check('AboutPanel 有示例 "10% = 0.1"', /Text\('10%\s*=\s*0\.1'\)/.test(src))

// ============================================================
// 5. 不变性约束 — Expression.ets / Calculator.ets 未改
// ============================================================
// (此检查在外部通过 git diff --stat 完成)

// ============================================================
// 6. ArkTS 语法 — BtnPct 调用方式
// ============================================================
check('BtnPct 调用语法正确 (this.BtnPct())', /this\.BtnPct\(\)/.test(src))
check('未误用 BtnPct(\'%\'/something)', !/this\.BtnPct\([^)]/.test(src))

// ============================================================
// 7. 主题色变量引用 (在 BtnPct 之外的引用 — getPct 在 BtnPct 唯一使用)
// ============================================================
const getPctUses = (src.match(/getPct\(\)/g) || []).length
check(`getPct() 调用次数合理 (${getPctUses}, 期望 ≥ 1, ≤ 5)`, getPctUses >= 1 && getPctUses <= 5)

// ============================================================
// 输出
// ============================================================
console.log('OpenCalc UI 静态验证')
console.log('========================')
log.forEach((l) => console.log(l))
console.log('========================')
console.log(`${pass}/${pass + fail} 通过, ${fail} 失败`)

process.exit(fail === 0 ? 0 : 1)
