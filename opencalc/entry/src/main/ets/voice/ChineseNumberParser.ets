import { NumberParseResult } from './VoiceModels'

export class ChineseNumberParser {
  static parse(input: string): NumberParseResult {
    const out: NumberParseResult = new NumberParseResult()
    let text: string = input.trim()
    let negative: boolean = false
    if (text.startsWith('负') || text.startsWith('-')) { negative = true; text = text.substring(1) }
    if (text.length === 0) { out.error = 'EMPTY_NUMBER'; return out }
    const parts: string[] = text.split('点')
    if (parts.length > 2 || parts[0].length === 0 || (parts.length === 2 && parts[1].length === 0)) {
      out.error = 'INVALID_DECIMAL'; return out
    }
    const integerText: string = ChineseNumberParser.parseInteger(parts[0])
    if (integerText.length === 0) { out.error = 'INVALID_NUMBER'; return out }
    let value: string = integerText
    if (parts.length === 2) {
      let fraction: string = ''
      for (let i: number = 0; i < parts[1].length; i++) {
        const digit: number = ChineseNumberParser.digit(parts[1].charAt(i))
        if (digit < 0) { out.error = 'INVALID_FRACTION'; return out }
        fraction += digit.toString()
      }
      value += '.' + fraction
    }
    out.ok = true
    out.value = (negative ? '-' : '') + value
    return out
  }

  private static parseInteger(text: string): string {
    let arabic: boolean = true
    for (let i: number = 0; i < text.length; i++) {
      const ch: string = text.charAt(i)
      if (ch < '0' || ch > '9') { arabic = false; break }
    }
    if (arabic) return text
    let hasUnit: boolean = false
    for (let i: number = 0; i < text.length; i++) {
      if (ChineseNumberParser.unit(text.charAt(i)) > 0) { hasUnit = true; break }
    }
    if (!hasUnit) {
      let digits: string = ''
      for (let i: number = 0; i < text.length; i++) {
        const d: number = ChineseNumberParser.digit(text.charAt(i))
        if (d < 0) return ''
        digits += d.toString()
      }
      return digits
    }
    const last: string = text.charAt(text.length - 1)
    if (ChineseNumberParser.digit(last) > 0 && text.indexOf('零') < 0 && text.indexOf('〇') < 0) return ''
    let total: number = 0
    let section: number = 0
    let pending: number = -1
    for (let i: number = 0; i < text.length; i++) {
      const ch: string = text.charAt(i)
      const d: number = ChineseNumberParser.digit(ch)
      if (d >= 0) { pending = d; continue }
      const u: number = ChineseNumberParser.unit(ch)
      if (u === 0) return ''
      if (u === 10000) {
        if (pending >= 0) section += pending
        total += section * 10000
        section = 0; pending = -1
      } else {
        section += (pending < 0 ? 1 : pending) * u
        pending = -1
      }
    }
    if (pending >= 0) section += pending
    return (total + section).toString()
  }

  private static digit(ch: string): number {
    if (ch >= '0' && ch <= '9') return parseInt(ch)
    const chars: string = '零一二三四五六七八九'
    if (ch === '〇') return 0
    if (ch === '两') return 2
    return chars.indexOf(ch)
  }

  private static unit(ch: string): number {
    if (ch === '十') return 10
    if (ch === '百') return 100
    if (ch === '千') return 1000
    if (ch === '万') return 10000
    return 0
  }
}
