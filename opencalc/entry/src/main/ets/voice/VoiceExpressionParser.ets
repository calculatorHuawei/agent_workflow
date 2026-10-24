import { ChineseNumberParser } from './ChineseNumberParser'
import { NumberParseResult, VoiceParseResult } from './VoiceModels'

export class VoiceExpressionParser {
  static parse(input: string): VoiceParseResult {
    const out: VoiceParseResult = new VoiceParseResult()
    let text: string = input.trim()
    const ignored: string[] = [' ', '，', ',', '。', '？', '?']
    for (let i: number = 0; i < ignored.length; i++) text = VoiceExpressionParser.replaceAll(text, ignored[i], '')
    let operatorIndex: number = -1
    let operatorLength: number = 0
    let mapped: string = ''
    const words: string[] = ['加', '+', '减', '-', '乘', '×', '除', '÷']
    const maps: string[] = ['+', '+', '-', '-', '*', '*', '/', '/']
    let count: number = 0
    for (let i: number = 0; i < text.length; i++) {
      for (let j: number = 0; j < words.length; j++) {
        if (text.substring(i, i + words[j].length) === words[j]) {
          if ((words[j] === '-' && i === 0) || (words[j] === '减' && i === 0)) continue
          count++
          if (count === 1) { operatorIndex = i; operatorLength = words[j].length; mapped = maps[j] }
        }
      }
    }
    if (count !== 1 || operatorIndex <= 0 || operatorIndex + operatorLength >= text.length) {
      out.error = 'INVALID_EXPRESSION'; return out
    }
    const left: NumberParseResult = ChineseNumberParser.parse(text.substring(0, operatorIndex))
    const right: NumberParseResult = ChineseNumberParser.parse(text.substring(operatorIndex + operatorLength))
    if (!left.ok || !right.ok) { out.error = 'INVALID_OPERAND'; return out }
    out.ok = true; out.expression = left.value + mapped + right.value
    return out
  }

  private static replaceAll(text: string, from: string, to: string): string {
    let out: string = text
    let index: number = out.indexOf(from)
    while (index >= 0) { out = out.substring(0, index) + to + out.substring(index + from.length); index = out.indexOf(from) }
    return out
  }
}
