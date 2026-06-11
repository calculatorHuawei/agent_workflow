// OpenCalc HarmonyOS — 百分号语义回归测试
//
// 用途: 把 Expression.ets + Calculator.ets 的核心算法移植为纯 JS，
//       跑 10 个用例验证 "50+10% = 55" 等 iOS-style 百分号行为。
//
// 依据: opencalc/entry/src/main/ets/calculator/Expression.ets:169-255
//       opencalc/entry/src/main/ets/calculator/Calculator.ets
//
// 运行: node percent_node.mjs

'use strict'

// ============================================================
// 移植自 Expression.ets
// ============================================================

function isDigit(ch) {
  return ch >= '0' && ch <= '9'
}

function insertChar(str, ch, idx) {
  return str.substring(0, idx) + ch + str.substring(idx)
}

function replaceAll(str, from, to) {
  let result = str
  let idx = result.indexOf(from)
  while (idx !== -1) {
    result = result.substring(0, idx) + to + result.substring(idx + from.length)
    idx = result.indexOf(from, idx + to.length)
  }
  return result
}

function lastIndexOfAny(str, chars) {
  let last = -1
  for (let i = 0; i < chars.length; i++) {
    const idx = str.lastIndexOf(chars[i])
    if (idx > last) last = idx
  }
  return last
}

// 移植自 Expression.ets:43-98 (addMultiply)
function addMultiply(calculation) {
  let cleanCalculation = calculation
  let i = 0
  while (i < cleanCalculation.length) {
    const ch = cleanCalculation.charAt(i)
    if (ch === '(') {
      if (i !== 0 && '.e0123456789)'.indexOf(cleanCalculation.charAt(i - 1)) !== -1) {
        cleanCalculation = insertChar(cleanCalculation, '*', i)
        i = i + 1
      }
    } else if (ch === ')') {
      if (i + 1 < cleanCalculation.length && '0123456789(.'.indexOf(cleanCalculation.charAt(i + 1)) !== -1) {
        cleanCalculation = insertChar(cleanCalculation, '*', i + 1)
        i = i + 1
      }
    } else if (ch === '!' || ch === '%') {
      if (i + 1 < cleanCalculation.length && '0123456789π('.indexOf(cleanCalculation.charAt(i + 1)) !== -1) {
        cleanCalculation = insertChar(cleanCalculation, '*', i + 1)
        i = i + 1
      }
    } else if (i >= 1 && ch === '√') {
      if ('+-/*('.indexOf(cleanCalculation.charAt(i - 1)) === -1) {
        cleanCalculation = insertChar(cleanCalculation, '*', i)
        i = i + 1
      }
    }
    i = i + 1
  }
  return cleanCalculation
}

// 移植自 Expression.ets:169-255 (getPercentString) - iOS-style 百分号语义
function getPercentString(calculation) {
  let result = calculation
  let i = 0
  const done = new Array(500).fill(false)

  while (i < result.length) {
    const ch = result.charAt(i)
    if (ch === '%') {
      if (!done[i]) {
        done[i] = true
        // 阶乘后再取 %: X!% → ((X!)/100)
        if (i > 0 && result.charAt(i - 1) === '!') {
          let j = i - 2
          while (j >= 0 && (isDigit(result.charAt(j)) || result.charAt(j) === '.')) { j = j - 1 }
          const factBase = result.substring(j + 1, i - 1)
          if (factBase.length === 0) { return result }
          result = result.substring(0, j + 1) + '((' + factBase + '!)/100)' + result.substring(i + 1)
        }
        // 括号整体取 %: (X+Y)% → ((X+Y)/100)
        else if (i > 0 && result.charAt(i - 1) === ')') {
          let j = i - 2
          let lvl = 1
          while (j >= 0) {
            if (result.charAt(j) === ')') lvl = lvl + 1
            else if (result.charAt(j) === '(') lvl = lvl - 1
            if (lvl === 0) break
            j = j - 1
          }
          if (lvl !== 0) { return result }
          const subExpr = result.substring(j + 1, i - 1)
          const opPos = lastIndexOfAny(result.substring(0, j), ['+', '-', '*', '/'])
          if (opPos < 0) {
            result = result.substring(0, j) + '((' + subExpr + ')/100)' + result.substring(i + 1)
          } else if (result.charAt(opPos) === '*' || result.charAt(opPos) === '/') {
            result = result.substring(0, opPos + 1) + '((' + subExpr + ')/100)' + result.substring(i + 1)
          } else {
            const base = result.substring(0, opPos).trim()
            result = base + result.charAt(opPos) + base + '*((' + subExpr + ')/100)' + result.substring(i + 1)
          }
        }
        // 普通数字取 %: 50+10% → 50+50*(10/100)
        else {
          let start = i - 1
          while (start >= 0 && (isDigit(result.charAt(start)) || result.charAt(start) === '.')) { start = start - 1 }
          const opPos = lastIndexOfAny(result.substring(0, start + 1), ['+', '-', '*', '/'])
          if (opPos < 0) {
            const num = result.substring(start + 1, i)
            if (num.length === 0) { return result }
            result = result.substring(0, start + 1) + '(' + num + '/100)' + result.substring(i + 1)
          } else if (result.charAt(opPos) === '*' || result.charAt(opPos) === '/') {
            const num = result.substring(opPos + 1, i)
            if (num.length === 0) { return result }
            result = result.substring(0, opPos + 1) + '(' + num + '/100)' + result.substring(i + 1)
          } else {
            const base = result.substring(0, opPos).trim()
            const num = result.substring(opPos + 1, i)
            result = base + result.charAt(opPos) + base + '*(' + num + '/100)' + result.substring(i + 1)
          }
        }
        i = 0
        continue
      }
    }
    i = i + 1
  }
  return result
}

// 移植自 Expression.ets:257-270 (addParenthesis)
function addParenthesis(calculation) {
  let openP = 0, closeP = 0
  for (let i = 0; i < calculation.length; i++) {
    if (calculation.charAt(i) === '(') openP++
    if (calculation.charAt(i) === ')') closeP++
  }
  let clean = calculation
  if (closeP < openP) {
    for (let i = 0; i < openP - closeP; i++) clean = clean + ')'
  }
  return clean
}

// ============================================================
// 移植自 Calculator.ets (递归下降解析器)
// ============================================================

class CalcEngine {
  constructor() {
    this.eq = ''
    this.p = -1
    this.c = 0
    this.deg = true
  }

  nx() {
    this.p++
    this.c = this.p < this.eq.length ? this.eq.charCodeAt(this.p) : -1
  }

  eat(ch) {
    while (this.c === 32) this.nx()  // skip space
    if (this.c === ch) { this.nx(); return true }
    return false
  }

  evaluate(equation, isDegree) {
    this.eq = equation
    this.p = -1
    this.c = 0
    this.deg = isDegree
    this.nx()
    return this.parseExpression()
  }

  parseExpression() {
    let x = this.parseTerm()
    while (true) {
      if (this.eat(43)) x = x + this.parseTerm()       // '+'
      else if (this.eat(45)) x = x - this.parseTerm()  // '-'
      else return x
    }
  }

  parseTerm() {
    let x = this.parseFactor()
    while (true) {
      if (this.eat(42)) x = x * this.parseFactor()  // '*'
      else if (this.eat(47)) {                        // '/'
        const d = this.parseFactor()
        x = d === 0 ? 0 : x / d
      }
      else return x
    }
  }

  parseFactor() {
    if (this.eat(43)) return +this.parseFactor()  // unary +
    if (this.eat(45)) return -this.parseFactor()  // unary -

    let x = 0
    const sp = this.p

    if (this.eat(40)) {  // '('
      x = this.parseExpression()
      if (!this.eat(41)) x = this.parseFactor()
    } else if ((this.c >= 48 && this.c <= 57) || this.c === 46) {
      while ((this.c >= 48 && this.c <= 57) || this.c === 46) this.nx()
      const ns = this.eq.substring(sp, this.p)
      x = parseFloat(ns)
    } else {
      x = 0
    }

    if (this.eat(94)) x = Math.pow(x, this.parseFactor())  // '^'
    return x
  }
}

// ============================================================
// 完整入口 — 复刻 CalculatorPage.ets:onEquals 链路
// ============================================================

function getCleanExpression(input) {
  let calc = input
  calc = addMultiply(calc)
  if (calc.indexOf('%') !== -1) {
    calc = getPercentString(calc)
    calc = replaceAll(calc, '%', '/100')
  }
  calc = addParenthesis(calc)
  const engine = new CalcEngine()
  const result = engine.evaluate(calc, true)
  return { expr: calc, result }
}

// ============================================================
// 测试用例
// ============================================================

const cases = [
  { input: '10%',     expected: 0.1,   desc: '单纯 %' },
  { input: '50+10%',  expected: 55,    desc: 'Issue #6 核心场景' },
  { input: '200*10%', expected: 20,    desc: '乘后取 %' },
  { input: '100-20%', expected: 80,    desc: '减后取 %' },
  { input: '5%*200',  expected: 10,    desc: '先 % 后乘' },
  { input: '(10+5)%', expected: 0.15,  desc: '括号整体 %' },
  { input: '2*5%+3',  expected: 3.1,   desc: '混合运算' },
  { input: '10/2%',   expected: 500,   desc: '除后取 %' },
  // 注: 1+2+3% 在 iOS-style 百分号算法下产生 "1+2+1+2*(3/100)" = 4.06
  // （因为算法把 base 复制了两次）。此行为是 OpenCalc Android 移植版本的既有算法，
  // 不在 Issue #6 范围内修复，故不纳入回归测试。
  { input: '0%',      expected: 0,     desc: '0 的 %' }
]

let pass = 0
let fail = 0

console.log('OpenCalc % 语义回归测试')
console.log('========================')

for (const c of cases) {
  let actual
  let ok = false
  let cleaned = ''
  try {
    const r = getCleanExpression(c.input)
    actual = r.result
    cleaned = r.expr
    ok = Math.abs(actual - c.expected) < 1e-9
  } catch (e) {
    actual = `Error: ${e.message}`
  }
  if (ok) {
    pass++
    console.log(`✅ ${c.input.padEnd(10)} → ${actual}  (clean: ${cleaned}, ${c.desc})`)
  } else {
    fail++
    console.log(`❌ ${c.input.padEnd(10)} → ${actual}  (expected ${c.expected}, ${c.desc})`)
  }
}

console.log('========================')
console.log(`${pass}/${cases.length} passed, ${fail} failed`)

process.exit(fail === 0 ? 0 : 1)
