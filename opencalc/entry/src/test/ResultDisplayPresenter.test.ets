import { describe, it, expect } from '@ohos/hypium'
import {
  ResultDisplayMode, ResultDisplayPresenter, ResultDisplaySnapshot, ResultDisplayLifecycle
} from '../main/ets/common/ResultDisplayPresenter'

export default function resultDisplayPresenterTest(): void {
  describe('ResultDisplayPresenter', () => {
    it('toggles only when a successful result is available', 0, (): void => {
      expect(ResultDisplayPresenter.nextMode(ResultDisplayMode.DECIMAL, true))
        .assertEqual(ResultDisplayMode.FRACTION)
      expect(ResultDisplayPresenter.nextMode(ResultDisplayMode.FRACTION, true))
        .assertEqual(ResultDisplayMode.DECIMAL)
      expect(ResultDisplayPresenter.nextMode(ResultDisplayMode.DECIMAL, false))
        .assertEqual(ResultDisplayMode.DECIMAL)
      expect(ResultDisplayPresenter.nextMode(ResultDisplayMode.FRACTION, false))
        .assertEqual(ResultDisplayMode.FRACTION)
    })

    it('keeps the exact decimal snapshot in decimal mode', 0, (): void => {
      expect(ResultDisplayPresenter.selectText(ResultDisplayMode.DECIMAL, 0.5, '0.500'))
        .assertEqual('0.500')
    })

    it('renders fractions for common rational results', 0, (): void => {
      expect(ResultDisplayPresenter.selectText(ResultDisplayMode.FRACTION, 0.5, '0.5')).assertEqual('1/2')
      expect(ResultDisplayPresenter.selectText(ResultDisplayMode.FRACTION, 1 / 3, '0.333333')).assertEqual('1/3')
      expect(ResultDisplayPresenter.selectText(ResultDisplayMode.FRACTION, -0.5, '-0.5')).assertEqual('-1/2')
      expect(ResultDisplayPresenter.selectText(ResultDisplayMode.FRACTION, 2, '2')).assertEqual('2')
    })

    it('falls back to the unmodified decimal snapshot', 0, (): void => {
      expect(ResultDisplayPresenter.selectText(ResultDisplayMode.FRACTION, Math.PI, '3.1415926536'))
        .assertEqual('3.1415926536')
      expect(ResultDisplayPresenter.selectText(ResultDisplayMode.FRACTION, NaN, 'not-a-number'))
        .assertEqual('not-a-number')
    })

    it('preserves result state and external history while toggling', 0, (): void => {
      const initial: ResultDisplaySnapshot = ResultDisplayLifecycle.success(0.5, '0.5')
      const historyBefore: string[] = ['1÷2 = 0.5']
      const expressionBefore: string = '1÷2'
      const fraction: ResultDisplaySnapshot = ResultDisplayLifecycle.toggle(initial, '')
      expect(fraction.mode).assertEqual(ResultDisplayMode.FRACTION)
      expect(fraction.rawValue).assertEqual(initial.rawValue)
      expect(fraction.decimalText).assertEqual(initial.decimalText)
      expect(ResultDisplayLifecycle.visible(fraction)).assertEqual('1/2')
      expect(historyBefore.length).assertEqual(1)
      expect(historyBefore[0]).assertEqual('1÷2 = 0.5')
      expect(expressionBefore).assertEqual('1÷2')
      const decimal: ResultDisplaySnapshot = ResultDisplayLifecycle.toggle(fraction, '')
      expect(ResultDisplayLifecycle.visible(decimal)).assertEqual('0.5')
    })

    it('resets mode on success clear and error and gates invalid toggles', 0, (): void => {
      const successful: ResultDisplaySnapshot = ResultDisplayLifecycle.success(1 / 3, '0.3333333333333333')
      expect(successful.hasResult).assertTrue()
      expect(successful.mode).assertEqual(ResultDisplayMode.DECIMAL)
      const blockedByError: ResultDisplaySnapshot = ResultDisplayLifecycle.toggle(successful, '计算错误')
      expect(blockedByError.mode).assertEqual(ResultDisplayMode.DECIMAL)
      const cleared: ResultDisplaySnapshot = ResultDisplayLifecycle.cleared()
      expect(cleared.hasResult).assertFalse()
      expect(cleared.rawValue).assertEqual(0)
      expect(ResultDisplayLifecycle.toggle(cleared, '').mode).assertEqual(ResultDisplayMode.DECIMAL)
    })

    it('provides accessible current-mode and action labels', 0, (): void => {
      expect(ResultDisplayPresenter.toggleLabel(ResultDisplayMode.DECIMAL)).assertEqual('小数 · 切换为分数')
      expect(ResultDisplayPresenter.toggleLabel(ResultDisplayMode.FRACTION)).assertEqual('分数 · 切换为小数')
      expect(ResultDisplayPresenter.toggleAccessibilityText(ResultDisplayMode.DECIMAL))
        .assertEqual('当前显示小数，切换为分数')
      expect(ResultDisplayPresenter.toggleAccessibilityText(ResultDisplayMode.FRACTION))
        .assertEqual('当前显示分数，切换为小数')
    })
  })
}
