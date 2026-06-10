// Shared test harness: load .ets files via vm-based transformer
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

export function transformEtsToJs(src) {
  src = src.replace(/@\w+(?:\([^)]*\))?\s*\n?/g, '')
  // Strip TypeScript access modifiers (private/public/protected/readonly) in class fields
  src = src.replace(/\b(private|public|protected|readonly)\s+/g, '')
  src = src.replace(/\bstruct\s+(\w+)/g, 'class $1')
  src = src.replace(/^import\s+.*$/gm, '')
  src = src.replace(/interface\s+\w+\s*\{[^}]*\}/g, '')
  src = src.replace(/type\s+\w+\s*=\s*[^;\n]+[;\n]/g, '')
  src = src.replace(/^export\s+default\s+/gm, 'globalThis.default = ')
  src = src.replace(/^export\s+/gm, '')
  src = src.replace(/(\b(?:const|let|var)\s+\w+)\s*:\s*[A-Za-z_$][\w$<>,\[\]|&]*(?=\s*=)/g, '$1')
  // Strip type annotations on class fields: `static X: Type = ...` or `x: Type = ...`
  src = src.replace(/(\b(?:static\s+)?\w+)\s*:\s*[A-Za-z_$][\w$<>,\[\]|&]*(?=\s*=)/g, '$1')
  // Strip types INSIDE function parameter lists only (between matched parens).
  // Walk through the source and only modify text inside the outermost parens of parameter lists.
  src = src.replace(/(\([^()]*\))(\s*[:][^=;(){]*)?\s*(?=\{|=>)/g, (m, parenPart) => {
    // Strip types inside parenPart: (a: T, b: U) → (a, b)
    const stripped = parenPart.replace(/(\s*\w+)\s*:\s*[A-Za-z_$][\w$<>,\[\]|&]*(?=\s*[,)])/g, '$1')
    return stripped
  })
  src = src.replace(/\)\s*:\s*[A-Za-z_$][\w$<>,\[\]|&]*(?=\s*\{)/g, ')')
  src = src.replace(/\)\s*:\s*[A-Za-z_$][\w$<>,\[\]|&]*(?=\s*\{)/g, ')')
  src = src.replace(/\)\s*:\s*[A-Za-z_$][\w$<>,\[\]|&]*(?=\s*=>)/g, ')')
  src = src.replace(/\s+as\s+[A-Za-z_$][\w$<>,\[\]|&]*/g, '')
  src = src.replace(/(\w)!(?![=])/g, '$1')
  src = src.replace(/enum\s+(\w+)\s*\{([\s\S]*?)\n\}/g, (_, name, body) => {
    const members = []
    let auto = 0
    body.split(/[,\n]/).map(s => s.trim()).filter(Boolean).forEach(member => {
      if (member.startsWith('//') || member.startsWith('/*') || member.startsWith('*')) return
      member = member.replace(/\/\/.*$/, '').trim()
      if (!member) return
      const m = member.match(/^(\w+)\s*(?:=\s*(.+?))?(?:\s*\/\/.*)?$/)
      if (!m) return
      const [, k, v] = m
      let value
      if (v !== undefined && v.length > 0) {
        value = v.trim()
        if (/^-?\d+(\.\d+)?$/.test(value)) auto = parseFloat(value) + 1
      } else {
        value = String(auto); auto++
      }
      members.push(`  ${k}: ${value}`)
    })
    return `globalThis.${name} = Object.freeze({\n${members.join(',\n')}\n})`
  })
  src = src.replace(/^const\s+(\w+)\s*=/gm, 'globalThis.$1 =')
  src = src.replace(/^let\s+(\w+)\s*=/gm, 'globalThis.$1 =')
  src = src.replace(/^class\s+(\w+)/gm, 'globalThis.$1 = class $1')
  return src
}

export function loadEts(relPath, extraGlobals = {}) {
  const path = new URL('../' + relPath, import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')
  const src = readFileSync(path, 'utf8')
  const js = transformEtsToJs(src)
  const ctx = {
    console, Object, Math, parseInt, parseFloat, isNaN, isFinite,
    Number, String, Array, Boolean, JSON, Date, Promise, Error,
    RegExp, Map, Set, Symbol, BigInt,
    ...extraGlobals
  }
  ctx.globalThis = ctx
  vm.createContext(ctx)
  vm.runInContext(js, ctx)
  return ctx
}
