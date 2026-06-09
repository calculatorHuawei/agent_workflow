import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium'
import { CalculatorPage } from '../../main/ets/pages/CalculatorPage'

export default function abilityTest() {
  describe('actsAbilityTest', () => {
    it('preview_state_field_exists', 0, () => {
      // 验证 CalculatorPage 有 @State preview 字段
      const page = new CalculatorPage()
      // 通过检查 preview 属性是否存在来验证
      expect(page.hasOwnProperty('preview')).assertTrue()
      // 验证初始值为空字符串
      expect((page as any).preview === '').assertTrue()
    })

    it('updatePreview_method_exists', 0, () => {
      // 验证 CalculatorPage 有 updatePreview 方法
      const page = new CalculatorPage()
      expect(typeof (page as any).updatePreview === 'function').assertTrue()
    })

    it('updatePreview_empty_expression_returns_empty', 0, () => {
      // 验证空表达式时 preview 为空
      const page = new CalculatorPage()
      ;(page as any).updatePreview()
      expect((page as any).preview === '').assertTrue()
    })

    it('updatePreview_valid_expression_updates_preview', 0, () => {
      // 验证有效表达式更新 preview
      const page = new CalculatorPage()
      ;(page as any).expression = '1+2'
      ;(page as any).updatePreview()
      // 预期 preview 为 '3'
      expect((page as any).preview === '3').assertTrue()
    })
  })
}