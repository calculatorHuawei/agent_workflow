// OpenCalc — 二维码载荷构建（Issue #42，纯函数模块）
// 契约：delta-design §4.2 ｜ 措施：CM-01 载荷单一来源 / CM-03 门控判定 / CM-06 容量防护 / CM-09 字节计数
// 约束：零 UI/Kit/三方依赖、无模块级可变状态（结构上保证确定性）

/** 三行固定格式：第一行标识 + 算式行前缀 */
export const PAYLOAD_PREFIX: string = 'OpenCalc\n算式: '

/** 结果行前缀（模块内私有常量，载荷格式单一来源） */
const PAYLOAD_RESULT_PREFIX: string = '\n结果: '

/** 容量上限：271 UTF-8 字节（QR EC-M v10 byte 模式，CM-06） */
export const MAX_BYTES: number = 271

/** 载荷构造结果：失败时 payload 为空串、reason 给出提示文案 */
export interface QrPayloadResult {
  ok: boolean
  payload: string
  reason: string
}

/** 按 UTF-8 语义计字节数（多字节字符按字节而非字符数，CM-09；正确处理代理对） */
export function utf8ByteLength(text: string): number {
  let bytes: number = 0
  let i: number = 0
  while (i < text.length) {
    const c: number = text.charCodeAt(i)
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
      const d: number = text.charCodeAt(i + 1)
      if (d >= 0xDC00 && d <= 0xDFFF) {
        bytes += 4
        i += 2
        continue
      }
    }
    if (c < 0x80) bytes += 1
    else if (c < 0x800) bytes += 2
    else bytes += 3
    i += 1
  }
  return bytes
}

/** 按固定三行格式拼接 UTF-8 载荷：逐字取入参（禁止重算/重排，CM-01）；超 271 字节前置拒绝（CM-06） */
export function buildQrPayload(expression: string, result: string): QrPayloadResult {
  const payload: string = PAYLOAD_PREFIX + expression + PAYLOAD_RESULT_PREFIX + result
  if (utf8ByteLength(payload) > MAX_BYTES) {
    const rejected: QrPayloadResult = { ok: false, payload: '', reason: '内容过长，无法生成二维码' }
    return rejected
  }
  const built: QrPayloadResult = { ok: true, payload: payload, reason: '' }
  return built
}

/** 三分支门控判定：算式非空 ∧ 结果非空 ∧ 无错误 → 可分享（AC4/CM-03） */
export function isShareable(expression: string, result: string, errorMsg: string): boolean {
  return expression.length > 0 && result.length > 0 && errorMsg.length === 0
}
