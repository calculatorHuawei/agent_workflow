import { describe, it, expect } from '@ohos/hypium'
import { ChineseNumberParser } from '../main/ets/voice/ChineseNumberParser'
import { VoiceExpressionParser } from '../main/ets/voice/VoiceExpressionParser'
import { CalculationCoordinator } from '../main/ets/voice/CalculationCoordinator'
import { VoiceInputController } from '../main/ets/voice/VoiceInputController'
import { FakeSpeechRecognitionGateway } from './FakeSpeechRecognitionGateway'
import { VoicePermissionAdapter, PermissionChecker } from '../main/ets/voice/VoicePermissionAdapter'
import { HarmonySpeechRecognitionGateway, SpeechPlatformDriver } from '../main/ets/voice/HarmonySpeechRecognitionGateway'
import { VoiceEvent } from '../main/ets/voice/VoiceModels'
import { VoiceEventListener } from '../main/ets/voice/SpeechRecognitionGateway'

class DeniedPermissionChecker implements PermissionChecker {
  requestCount: number = 0
  requestMicrophone(): boolean { this.requestCount++; return false }
}

class RecordingPlatformDriver implements SpeechPlatformDriver {
  starts: number = 0
  stops: number = 0
  listener: ((type: string, text: string, error: string) => void) | null = null
  start(listener: (type: string, text: string, error: string) => void): boolean {
    this.starts++; this.listener = listener; listener('listening', '', ''); return true
  }
  stop(): void { this.stops++ }
}

class CapturingListener implements VoiceEventListener {
  events: VoiceEvent[] = []
  onVoiceEvent(event: VoiceEvent): void { this.events.push(event) }
}

export default function voiceFeatureTest(): void {
  describe('VoiceNumberParser', () => {
    it('AC004_integer_forms', 0, (): void => {
      expect(ChineseNumberParser.parse('二十').value).assertEqual('20')
      expect(ChineseNumberParser.parse('一百零二').value).assertEqual('102')
      expect(ChineseNumberParser.parse('二〇二四').value).assertEqual('2024')
      expect(ChineseNumberParser.parse('负二').value).assertEqual('-2')
    })
    it('AC005_decimal_forms', 0, (): void => {
      expect(ChineseNumberParser.parse('十点五').value).assertEqual('10.5')
      expect(ChineseNumberParser.parse('零点零五').value).assertEqual('0.05')
      expect(ChineseNumberParser.parse('一点九五').value).assertEqual('1.95')
    })
    it('AC006_ambiguous_number_fails_closed', 0, (): void => {
      expect(ChineseNumberParser.parse('一百二').ok).assertFalse()
      expect(ChineseNumberParser.parse('一点').ok).assertFalse()
      expect(ChineseNumberParser.parse('一亿').ok).assertFalse()
    })
  })

  describe('VoiceExpressionParser', () => {
    it('AC003_operator_table', 0, (): void => {
      const samples: string[] = ['一加二', '一+二', '三减二', '三-二', '二乘三', '二×三', '六除三', '六÷三']
      const expected: string[] = ['1+2', '1+2', '3-2', '3-2', '2*3', '2*3', '6/3', '6/3']
      for (let i: number = 0; i < samples.length; i++) {
        expect(VoiceExpressionParser.parse(samples[i]).expression).assertEqual(expected[i])
      }
    })
    it('AC004_AC005_AC018_examples', 0, (): void => {
      expect(VoiceExpressionParser.parse('123加456').expression).assertEqual('123+456')
      expect(VoiceExpressionParser.parse('二十乘三').expression).assertEqual('20*3')
      expect(VoiceExpressionParser.parse('十点五减二点五').expression).assertEqual('10.5-2.5')
      expect(VoiceExpressionParser.parse('二〇二四减二千').expression).assertEqual('2024-2000')
      expect(VoiceExpressionParser.parse('负二加五').expression).assertEqual('-2+5')
    })
    it('AC006_invalid_structures', 0, (): void => {
      expect(VoiceExpressionParser.parse('一加').ok).assertFalse()
      expect(VoiceExpressionParser.parse('一加二乘三').ok).assertFalse()
      expect(VoiceExpressionParser.parse('今天加一').ok).assertFalse()
      expect(VoiceExpressionParser.parse('一点二点三加一').ok).assertFalse()
    })
  })

  describe('VoiceCalculation', () => {
    it('AC007_calculates_with_existing_engine', 0, (): void => {
      expect(new CalculationCoordinator().evaluate('123+456', false).result).assertEqual('579')
      expect(new CalculationCoordinator().evaluate('10.5-2.5', false).result).assertEqual('8')
    })
    it('AC009_divide_zero_is_failure', 0, (): void => {
      expect(new CalculationCoordinator().evaluate('10/0', false).ok).assertFalse()
    })
  })

  describe('VoiceController', () => {
    it('AC001_AC007_success_state_and_single_commit', 0, (): void => {
      const gateway: FakeSpeechRecognitionGateway = new FakeSpeechRecognitionGateway()
      const controller: VoiceInputController = new VoiceInputController(gateway)
      controller.start('7*8', '56', false)
      gateway.listening(); gateway.recognizing(); gateway.finalResult('123加456')
      expect(controller.snapshot.state).assertEqual('success')
      expect(controller.snapshot.expression).assertEqual('123+456')
      expect(controller.snapshot.result).assertEqual('579')
      expect(controller.commitCount).assertEqual(1)
      gateway.finalResult('123加456')
      expect(controller.commitCount).assertEqual(1)
    })
    it('AC008_AC010_AC011_failure_preserves_snapshot', 0, (): void => {
      const gateway: FakeSpeechRecognitionGateway = new FakeSpeechRecognitionGateway()
      const controller: VoiceInputController = new VoiceInputController(gateway)
      controller.start('7*8', '56', false); gateway.error('SERVICE_UNAVAILABLE')
      expect(controller.snapshot.expression).assertEqual('7*8')
      expect(controller.snapshot.result).assertEqual('56')
      expect(controller.commitCount).assertEqual(0)
    })
    it('AC012_AC017_cancel_ignores_late_final', 0, (): void => {
      const gateway: FakeSpeechRecognitionGateway = new FakeSpeechRecognitionGateway()
      const controller: VoiceInputController = new VoiceInputController(gateway)
      controller.start('1+1', '2', false); controller.cancel(); gateway.finalResult('123加456')
      expect(controller.snapshot.state).assertEqual('idle')
      expect(controller.snapshot.expression).assertEqual('1+1')
      expect(controller.commitCount).assertEqual(0)
      expect(gateway.cancelCount).assertEqual(1)
    })
  })

  describe('VoicePlatformSeams', () => {
    it('AC002_permission_denial_never_starts_platform', 0, (): void => {
      const checker: DeniedPermissionChecker = new DeniedPermissionChecker()
      const adapter: VoicePermissionAdapter = new VoicePermissionAdapter(checker)
      expect(adapter.ensureMicrophonePermission()).assertFalse()
      expect(checker.requestCount).assertEqual(1)
    })
    it('AC016_gateway_orders_listening_after_driver_start', 0, (): void => {
      const driver: RecordingPlatformDriver = new RecordingPlatformDriver()
      const gateway: HarmonySpeechRecognitionGateway = new HarmonySpeechRecognitionGateway(driver)
      const listener: CapturingListener = new CapturingListener()
      gateway.setListener(listener); gateway.start(8)
      expect(driver.starts).assertEqual(1)
      expect(listener.events[0].type).assertEqual('listening')
      gateway.cancel(8); gateway.dispose()
      expect(driver.stops).assertEqual(1)
    })
  })
}
