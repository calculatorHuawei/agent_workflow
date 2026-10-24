import { Expression } from '../calculator/Expression'
import { CalcEngine } from '../calculator/Calculator'
import { NumberFormatter } from '../calculator/NumberFormatter'
import { ErrorFlags } from '../model/ErrorFlags'
import { NumberingSystem } from '../model/Models'
import { CalculationOutcome } from './VoiceModels'

export class CalculationCoordinator {
  private expression: Expression = new Expression()
  private engine: CalcEngine = new CalcEngine()

  evaluate(candidate: string, radianMode: boolean): CalculationOutcome {
    const out: CalculationOutcome = new CalculationOutcome()
    out.expression = candidate
    ErrorFlags.reset()
    try {
      const clean: string = this.expression.getCleanExpression(candidate, '.', ',')
      const raw: number = this.engine.evaluate(clean, !radianMode)
      if (ErrorFlags.division_by_0) out.error = '除数不能为零'
      else if (ErrorFlags.domain_error) out.error = '定义域错误'
      else if (ErrorFlags.syntax_error) out.error = '表达式错误'
      else if (ErrorFlags.is_infinity) out.error = '结果无穷大'
      else if (ErrorFlags.require_real_number) out.error = '需要实数'
      else {
        out.ok = true
        out.result = NumberFormatter.format(raw.toString(), '.', ',', NumberingSystem.INTERNATIONAL)
      }
    } catch (_e) { out.error = '计算错误' }
    return out
  }
}
