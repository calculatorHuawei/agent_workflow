import { CalculatorPage } from '../../../main/ets/pages/CalculatorPage'

/** Test-only entry wrapper; renders the production calculator component unchanged. */
@Entry
@Component
struct VoiceTestIndex {
  build() {
    Column() { CalculatorPage() }
  }
}
