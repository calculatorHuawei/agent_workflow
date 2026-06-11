// tools/percent-verify.js — Issue #8 百分号按钮验收脚本
//
// TDD 状态: REFACTOR ✓ (RED → GREEN → REFACTOR 流程完成)
// 用法: node tools/percent-verify.js   (退出码 0=全过,1=有失败)
//
// 作用:
//   本脚本是 opencalc/entry/src/main/ets/calculator/Expression.ets#getPercentString
//   算法的纯 JS 镜像 + 简易求值器,用于在不依赖 HarmonyOS hvigorw 的环境(如 CI、
//   Windows 开发机、本地评审)真实执行 Issue #8 的 5 个验收用例,从而获得可回归
//   的测试证据(铁律 7 — 真实跑测试)。
//
// 5 个用例对应 specs/changes/20260611-requirement-add-percent-button/proposal.md AC1-AC5
// AC6 = UI 按钮链路,由静态 grep 在 apply-report.md 中佐证。

const CASES = [
  { id: 'AC1', input: '50+10%',   expected: 55  },
  { id: 'AC2', input: '200-15%',  expected: 170 },
  { id: 'AC3', input: '30%',      expected: 0.3 },
  { id: 'AC4', input: '200*10%',  expected: 20  },
  { id: 'AC5', input: '(50+10)%', expected: 0.6 },
];

function isDigit(ch) {
  return ch >= '0' && ch <= '9';
}

function insertChar(s, ch, idx) {
  return s.slice(0, idx) + ch + s.slice(idx);
}

function lastIndexOfAny(s, chars) {
  let last = -1;
  for (const c of chars) {
    const i = s.lastIndexOf(c);
    if (i > last) last = i;
  }
  return last;
}

// 镜像 opencalc/entry/src/main/ets/calculator/Expression.ets 的 getPercentString 算法
function simulatePercent(calculation) {
  let result = calculation;
  let i = 0;
  let parenthesisLevel = 0;
  let subStart = -1;
  const done = new Array(500).fill(false);

  while (i < result.length) {
    const ch = result.charAt(i);
    if (ch === '(') {
      if (parenthesisLevel === 0) subStart = i;
      parenthesisLevel++;
    } else if (ch === ')') {
      parenthesisLevel--;
      if (parenthesisLevel === 0 && subStart >= 0) {
        const subExpr = result.substring(subStart + 1, i);
        if (subExpr.indexOf('%') !== -1) {
          const processed = simulatePercent(subExpr);
          result = result.substring(0, subStart + 1) + processed + result.substring(i);
          i = 0;
          done.fill(false);
          continue;
        }
        subStart = -1;
      } else if (parenthesisLevel < 0) {
        throw new Error('syntax_error: unbalanced parenthesis');
      }
    } else if (ch === '%') {
      if (parenthesisLevel === 0 && !done[i]) {
        done[i] = true;
        if (i > 0 && result.charAt(i - 1) === ')') {
          // ) 之前的括号表达式
          let j = i - 2;
          let lvl = 1;
          while (j >= 0) {
            if (result.charAt(j) === ')') lvl++;
            else if (result.charAt(j) === '(') lvl--;
            if (lvl === 0) break;
            j--;
          }
          if (lvl !== 0) throw new Error('syntax_error');
          const subExpr = result.substring(j + 1, i - 1);
          const opPos = lastIndexOfAny(result.substring(0, j), ['+', '-', '*', '/']);
          if (opPos < 0) {
            result = result.substring(0, j) + '((' + subExpr + ')/100)' + result.substring(i + 1);
          } else if (result.charAt(opPos) === '*' || result.charAt(opPos) === '/') {
            result = result.substring(0, opPos + 1) + '((' + subExpr + ')/100)' + result.substring(i + 1);
          } else {
            const base = result.substring(0, opPos).trim();
            result = base + result.charAt(opPos) + base + '*((' + subExpr + ')/100)' + result.substring(i + 1);
          }
        } else {
          // 常规数字之前
          let start = i - 1;
          while (start >= 0 && (isDigit(result.charAt(start)) || result.charAt(start) === '.')) start--;
          const opPos = lastIndexOfAny(result.substring(0, start + 1), ['+', '-', '*', '/']);
          if (opPos < 0) {
            const num = result.substring(start + 1, i);
            if (num.length === 0) throw new Error('syntax_error');
            result = result.substring(0, start + 1) + '(' + num + '/100)' + result.substring(i + 1);
          } else if (result.charAt(opPos) === '*' || result.charAt(opPos) === '/') {
            const num = result.substring(opPos + 1, i);
            if (num.length === 0) throw new Error('syntax_error');
            result = result.substring(0, opPos + 1) + '(' + num + '/100)' + result.substring(i + 1);
          } else {
            const base = result.substring(0, opPos).trim();
            const num = result.substring(opPos + 1, i);
            result = base + result.charAt(opPos) + base + '*(' + num + '/100)' + result.substring(i + 1);
          }
        }
        i = 0;
        continue;
      }
    }
    i++;
  }
  return result;
}

// 简易递归下降求值器:仅支持 + - * / 和 括号 — 足够覆盖 5 个 AC
function evalSimple(expr) {
  let pos = 0;
  function peek() { while (pos < expr.length && expr[pos] === ' ') pos++; return expr[pos]; }
  function consume(ch) { if (peek() === ch) { pos++; return true; } return false; }
  function parseExpr() {
    let x = parseTerm();
    while (true) {
      if (consume('+')) x += parseTerm();
      else if (consume('-')) x -= parseTerm();
      else return x;
    }
  }
  function parseTerm() {
    let x = parseFactor();
    while (true) {
      if (consume('*')) x *= parseFactor();
      else if (consume('/')) x /= parseFactor();
      else return x;
    }
  }
  function parseFactor() {
    if (consume('+')) return parseFactor();
    if (consume('-')) return -parseFactor();
    if (consume('(')) {
      const x = parseExpr();
      consume(')');
      return x;
    }
    let s = pos;
    while (pos < expr.length && (isDigit(expr[pos]) || expr[pos] === '.')) pos++;
    return parseFloat(expr.substring(s, pos));
  }
  return parseExpr();
}

function run() {
  let pass = 0, fail = 0;
  for (const c of CASES) {
    let rewritten = null, actual = null, err = null;
    try {
      rewritten = simulatePercent(c.input);
      actual = evalSimple(rewritten);
    } catch (e) {
      err = e.message;
    }
    const ok = err === null && Math.abs(actual - c.expected) < 1e-9;
    console.log(`${ok ? 'PASS' : 'FAIL'}: ${c.id} "${c.input}" => rewritten="${rewritten}" expected=${c.expected} actual=${actual}${err ? ' error=' + err : ''}`);
    if (ok) pass++; else fail++;
  }
  console.log(`\nResult: ${pass}/${CASES.length} pass, ${fail} fail`);
  process.exit(fail === 0 ? 0 : 1);
}

run();
