// OpenCalc — 二维码分享本地单元测试（Issue #42）
// 覆盖：SR-00 载荷构建/门控/容量防护（CM-01/CM-03/CM-06/CM-09）
//       / SR-01 QR 编码链（CM-04/CM-10） ｜ 契约：delta-design §4.2
import { describe, it, expect } from '@ohos/hypium'
import {
  buildQrPayload, utf8ByteLength, isShareable,
  PAYLOAD_PREFIX, MAX_BYTES, QrPayloadResult
} from '../main/ets/qrcode/QrPayload'
import {
  utf8Bytes, selectQrVersion, buildDataCodewords, dataCodewordCount,
  gfMul, ecBlockInfo, rsEncodeBlock, buildFinalCodewords,
  buildMatrix, maskCondition, scoreMatrix, encodeQr, QrEncodeResult
} from '../main/ets/qrcode/QrEncoder'

/** 重复 ASCII 片段构造指定长度字符串（模块级函数——ArkTS 禁止嵌套函数） */
function asciiRepeat(fragment: string, times: number): string {
  let out: string = ''
  for (let i: number = 0; i < times; i++) out = out + fragment
  return out
}

/** 构造 三行载荷 且使 UTF-8 总字节恰为 targetBytes（expr/result 均补 ASCII 'a'） */
function payloadWithTotalBytes(targetBytes: number): QrPayloadResult {
  // 固定 result='3'（1 字节），其余字节给 expression
  const resultText: string = '3'
  const fixed: number = utf8ByteLength(PAYLOAD_PREFIX) + utf8ByteLength('\n结果: ') + resultText.length
  const exprLen: number = targetBytes - fixed
  const expr: string = asciiRepeat('a', exprLen)
  return buildQrPayload(expr, resultText)
}

/** ASCII 串 → 字节数组（模块级辅助，显式循环） */
function asciiBytes(s: string): number[] {
  const out: number[] = []
  for (let i: number = 0; i < s.length; i++) out.push(s.charCodeAt(i))
  return out
}

/** α^i（独立推导，不依赖实现的 GF 表） */
function alphaPow(i: number): number {
  let v: number = 1
  for (let k: number = 0; k < i; k++) {
    v = v << 1
    if (v >= 0x100) v ^= 0x11D
  }
  return v
}

/** 独立构造 g(x)=∏(x−α^i)（降幂系数）——与实现不同算法，交叉验证用 */
function indepGenerator(degree: number): number[] {
  let g: number[] = [1]
  for (let i: number = 0; i < degree; i++) {
    const a: number = alphaPow(i)
    const ng: number[] = []
    for (let k: number = 0; k < g.length + 1; k++) ng.push(0)
    for (let k: number = 0; k < g.length; k++) {
      ng[k] ^= g[k]
      ng[k + 1] ^= gfMul(g[k], a)
    }
    g = ng
  }
  return g
}

/** 独立实现的降幂长除法余数（与实现的移位寄存器风格不同；因子须先捕获再清零） */
function indepRemainder(dividend: number[], gen: number[]): number[] {
  const a: number[] = dividend.slice()
  const n: number = gen.length
  for (let i: number = 0; i <= a.length - n; i++) {
    const f: number = a[i]
    if (f !== 0) {
      for (let j: number = 0; j < n; j++) {
        a[i + j] ^= gfMul(gen[j], f)
      }
    }
  }
  return a.slice(a.length - (n - 1))
}

/** 诊断辅助：RS 输出对独立生成多项式的余数 XOR 归约（非零即不可整除） */
function rsDivisibleSum(data: number[], ecLen: number): number {
  const e: number[] = rsEncodeBlock(data, ecLen)
  const rem: number[] = indepRemainder(data.concat(e), indepGenerator(ecLen))
  let s: number = 0
  for (let i: number = 0; i < rem.length; i++) s ^= rem[i]
  return s
}

/** 构造某版本合法最终码字序列（10 字节载荷，v1-10 通用） */
function validFinal(v: number): number[] {
  const bytes: number[] = asciiBytes(asciiRepeat('a', 10))
  return buildFinalCodewords(buildDataCodewords(bytes, v), v)
}

/** 多项式模（BCH 交叉验证）：value 按位降幂对 poly 取余 */
function polyMod(value: number, poly: number, topBit: number, degree: number): number {
  let v: number = value
  for (let b: number = topBit; b >= degree; b--) {
    if (((v >> b) & 1) !== 0) {
      v ^= poly << (b - degree)
    }
  }
  return v
}

/** 测试侧独立实现的 8 个标准掩模条件（ISO 18004 §8.8.2） */
function testMaskCondition(maskId: number, r: number, c: number): boolean {
  let cond: boolean = false
  if (maskId === 0) cond = (r + c) % 2 === 0
  else if (maskId === 1) cond = r % 2 === 0
  else if (maskId === 2) cond = c % 3 === 0
  else if (maskId === 3) cond = (r + c) % 3 === 0
  else if (maskId === 4) cond = (Math.floor(r / 2) + Math.floor(c / 3)) % 2 === 0
  else if (maskId === 5) cond = (r * c) % 2 + (r * c) % 3 === 0
  else if (maskId === 6) cond = ((r * c) % 2 + (r * c) % 3) % 2 === 0
  else cond = ((r + c) % 2 + (r * c) % 3) % 2 === 0
  return cond
}

/** 输入码字序列的第 k 个数据 bit（MSB 先行；越界为 0） */
function codewordBitAt(codewords: number[], k: number): number {
  const byteIdx: number = Math.floor(k / 8)
  if (byteIdx >= codewords.length) return 0
  return (codewords[byteIdx] >> (7 - (k % 8))) & 1
}

/** 测试侧独立推导的校正图案中心表（v2-10，索引 v-2） */
function testAlignmentCenters(v: number): number[] {
  const table: number[][] = [
    [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
    [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]
  ]
  return table[v - 2]
}

/** 标记函数模块集合（测试侧独立推导）：true=功能模块（数据填充禁入） */
function testIsFunctionCell(size: number, version: number, r: number, c: number): boolean {
  if (r <= 8 && c <= 8) return true                      // 左上 finder+分隔+格式
  if (r <= 8 && c >= size - 8) return true               // 右上 finder+分隔+格式
  if (r >= size - 8 && c <= 8) return true               // 左下 finder+分隔+格式
  if (r === 6 || c === 6) return true                    // 时序线
  if (r === size - 8 && c === 8) return true             // 暗模块
  const centers: number[] = version >= 2 ? testAlignmentCenters(version) : []
  for (let i: number = 0; i < centers.length; i++) {
    for (let j: number = 0; j < centers.length; j++) {
      const cr: number = centers[i]
      const cc: number = centers[j]
      const overlapFinder: boolean = (cr <= 8 && cc <= 8) || (cr <= 8 && cc >= size - 9) || (cr >= size - 9 && cc <= 8)
      if (overlapFinder) continue
      if (Math.abs(r - cr) <= 2 && Math.abs(c - cc) <= 2) return true
    }
  }
  if (version >= 7) {
    if (r >= size - 11 && r <= size - 9 && c <= 5) return true    // 版本信息 左下
    if (r <= 5 && c >= size - 11 && c <= size - 9) return true    // 版本信息 右上
  }
  return false
}

/** 测试侧独立的之字形遍历读取器：按规范顺序返回数据单元坐标 [r,c] 列表 */
function testZigzagCells(size: number, version: number): number[][] {
  const cells: number[][] = []
  let right: number = size - 1
  while (right >= 1) {
    if (right === 6) right = 5
    for (let vert: number = 0; vert < size; vert++) {
      for (let j: number = 0; j < 2; j++) {
        const c: number = right - j
        const upward: boolean = ((right + 1) & 2) === 0
        const r: number = upward ? (size - 1 - vert) : vert
        if (!testIsFunctionCell(size, version, r, c)) {
          const rc: number[] = [r, c]
          cells.push(rc)
        }
      }
    }
    right = right - 2
  }
  return cells
}

/** 格式信息位提取（纵向序列，LSB=i=0 起；kazuhiko 惯例） */
function extractFormatVertical(m: boolean[][], size: number): number {
  let bits: number = 0
  for (let i: number = 0; i < 15; i++) {
    let dark: boolean = false
    if (i < 6) dark = m[i][8]
    else if (i < 8) dark = m[i + 1][8]
    else dark = m[size - 15 + i][8]
    if (dark) bits |= (1 << i)
  }
  return bits
}

/** 格式信息位提取（横向序列，第二份拷贝） */
function extractFormatHorizontal(m: boolean[][], size: number): number {
  let bits: number = 0
  for (let i: number = 0; i < 15; i++) {
    let dark: boolean = false
    if (i < 8) dark = m[8][size - 1 - i]
    else if (i === 8) dark = m[8][7]
    else dark = m[8][14 - i]
    if (dark) bits |= (1 << i)
  }
  return bits
}

/** 版本信息位提取（左下块，LSB=i=0 起） */
function extractVersion(m: boolean[][], size: number): number {
  let bits: number = 0
  for (let i: number = 0; i < 18; i++) {
    const r: number = size - 11 + (i % 3)
    const c: number = Math.floor(i / 3)
    if (m[r][c]) bits |= (1 << i)
  }
  return bits
}

export default function qrShareTest(): void {
  describe('QrPayloadTest', () => {

    it('payload_scientific_verbatim_ac2', 0, (): void => {
      const r: QrPayloadResult = buildQrPayload('sin(30)', '0.5')
      expect(r.ok).assertTrue()
      expect(r.payload).assertEqual('OpenCalc\n算式: sin(30)\n结果: 0.5')
    })

    it('payload_basic_verbatim_ac9', 0, (): void => {
      const r: QrPayloadResult = buildQrPayload('1+2', '3')
      expect(r.ok).assertTrue()
      expect(r.payload).assertEqual('OpenCalc\n算式: 1+2\n结果: 3')
    })

    it('payload_decimal_verbatim_ac9', 0, (): void => {
      const r: QrPayloadResult = buildQrPayload('1÷8', '0.125')
      expect(r.ok).assertTrue()
      expect(r.payload).assertEqual('OpenCalc\n算式: 1÷8\n结果: 0.125')
    })

    it('payload_negative_verbatim_ac9', 0, (): void => {
      const r: QrPayloadResult = buildQrPayload('0-5', '-5')
      expect(r.ok).assertTrue()
      expect(r.payload).assertEqual('OpenCalc\n算式: 0-5\n结果: -5')
    })

    it('payload_multibyte_verbatim_ac9', 0, (): void => {
      const r: QrPayloadResult = buildQrPayload('×÷π', '1')
      expect(r.ok).assertTrue()
      expect(r.payload).assertEqual('OpenCalc\n算式: ×÷π\n结果: 1')
    })

    it('utf8_bytes_multibyte_cm09', 0, (): void => {
      expect(utf8ByteLength('×')).assertEqual(2)
      expect(utf8ByteLength('π')).assertEqual(2)
      expect(utf8ByteLength('算')).assertEqual(3)
      expect(utf8ByteLength('a')).assertEqual(1)
      expect(utf8ByteLength('')).assertEqual(0)
      expect(utf8ByteLength('算式: sin(30)')).assertEqual(3 + 3 + 2 + 7)
    })

    it('gating_three_branches_ac4_cm03', 0, (): void => {
      // 空算式 / 空结果 / 错误非空 → 均不可分享；三者全通过 → 可分享
      expect(isShareable('', '', '')).assertFalse()
      expect(isShareable('', '3', '')).assertFalse()
      expect(isShareable('1+2', '', '')).assertFalse()
      expect(isShareable('1+2', '3', '计算错误')).assertFalse()
      expect(isShareable('1+2', '3', '')).assertTrue()
    })

    it('capacity_constants_contract', 0, (): void => {
      expect(MAX_BYTES).assertEqual(271)
      expect(PAYLOAD_PREFIX).assertEqual('OpenCalc\n算式: ')
    })

    it('capacity_271_bytes_ok_cm06', 0, (): void => {
      const r: QrPayloadResult = payloadWithTotalBytes(271)
      expect(r.ok).assertTrue()
      expect(utf8ByteLength(r.payload)).assertEqual(271)
    })

    it('capacity_272_bytes_rejected_cm06', 0, (): void => {
      const r: QrPayloadResult = payloadWithTotalBytes(272)
      expect(r.ok).assertFalse()
      expect(r.payload).assertEqual('')
      expect(r.reason.length > 0).assertTrue()
    })

    it('payload_determinism_pure', 0, (): void => {
      const a: QrPayloadResult = buildQrPayload('sin(30)', '0.5')
      const b: QrPayloadResult = buildQrPayload('sin(30)', '0.5')
      expect(a.payload === b.payload && a.ok === b.ok).assertTrue()
    })
  })

  // ==================== SR-01：QR 编码链 第 1-2 步（版本选择 + 数据码字） ====================
  describe('QrEncoderDataTest', () => {

    it('utf8_bytes_multibyte_cm09', 0, (): void => {
      const mult: number[] = utf8Bytes('×')
      expect(mult.length).assertEqual(2)
      expect(mult[0]).assertEqual(0xC3)
      expect(mult[1]).assertEqual(0x97)
      const pi: number[] = utf8Bytes('π')
      expect(pi.length).assertEqual(2)
      expect(pi[0]).assertEqual(0xCF)
      expect(pi[1]).assertEqual(0x80)
      const han: number[] = utf8Bytes('算')
      expect(han.length).assertEqual(3)
      expect(han[0]).assertEqual(0xE7)
      expect(han[1]).assertEqual(0xAE)
      expect(han[2]).assertEqual(0x97)
      expect(utf8Bytes('a').length).assertEqual(1)
      expect(utf8Bytes('').length).assertEqual(0)
    })

    it('version_selection_boundary_ecm', 0, (): void => {
      // EC-M byte 模式容量边界（ISO 18004）：14/26/42/62/84/106/122/152/180/213
      expect(selectQrVersion(1)).assertEqual(1)
      expect(selectQrVersion(14)).assertEqual(1)
      expect(selectQrVersion(15)).assertEqual(2)
      expect(selectQrVersion(26)).assertEqual(2)
      expect(selectQrVersion(27)).assertEqual(3)
      expect(selectQrVersion(42)).assertEqual(3)
      expect(selectQrVersion(43)).assertEqual(4)
      expect(selectQrVersion(62)).assertEqual(4)
      expect(selectQrVersion(63)).assertEqual(5)
      expect(selectQrVersion(84)).assertEqual(5)
      expect(selectQrVersion(85)).assertEqual(6)
      expect(selectQrVersion(106)).assertEqual(6)
      expect(selectQrVersion(107)).assertEqual(7)
      expect(selectQrVersion(122)).assertEqual(7)
      expect(selectQrVersion(123)).assertEqual(8)
      expect(selectQrVersion(152)).assertEqual(8)
      expect(selectQrVersion(153)).assertEqual(9)
      expect(selectQrVersion(180)).assertEqual(9)
      expect(selectQrVersion(181)).assertEqual(10)
      expect(selectQrVersion(213)).assertEqual(10)
    })

    it('version_selection_over_capacity_rejected', 0, (): void => {
      // EC-M v10 实际容量 213 字节（spec 中 271 为 EC-L v10 值，见 apply-report 差异记录）
      expect(selectQrVersion(214)).assertEqual(0)
      expect(selectQrVersion(271)).assertEqual(0)
      expect(selectQrVersion(272)).assertEqual(0)
    })

    it('typical_payload_version_adaptive_ac9', 0, (): void => {
      // 典型载荷选版与 EC-M 容量表一致：30 字节 → v3（27-42），36 字节 → v3
      const small: number = selectQrVersion(utf8Bytes('OpenCalc\n算式: 1+2\n结果: 3').length)
      expect(small).assertEqual(3)
      const sci: number = selectQrVersion(utf8Bytes('OpenCalc\n算式: sin(30)\n结果: 0.5').length)
      expect(sci).assertEqual(3)
    })

    it('data_codewords_total_length_matches_block_table', 0, (): void => {
      // 总码字数 = 该版本 EC-M 数据码字数（16/28/44/64/86/108/124/154/182/216）
      // 输入为该版本容量内合法载荷（byte 模式容量 14/26/42/62/84/106/122/152/180/213）
      const caps: number[] = [14, 26, 42, 62, 84, 106, 122, 152, 180, 213]
      expect(dataCodewordCount(1)).assertEqual(16)
      expect(dataCodewordCount(2)).assertEqual(28)
      expect(dataCodewordCount(3)).assertEqual(44)
      expect(dataCodewordCount(4)).assertEqual(64)
      expect(dataCodewordCount(5)).assertEqual(86)
      expect(dataCodewordCount(6)).assertEqual(108)
      expect(dataCodewordCount(7)).assertEqual(124)
      expect(dataCodewordCount(8)).assertEqual(154)
      expect(dataCodewordCount(9)).assertEqual(182)
      expect(dataCodewordCount(10)).assertEqual(216)
      for (let v: number = 1; v <= 10; v++) {
        const cw: number[] = buildDataCodewords(asciiBytes(asciiRepeat('a', caps[v - 1])), v)
        expect(cw.length).assertEqual(dataCodewordCount(v))
      }
    })

    it('data_codewords_mode_and_count_indicator_v1', 0, (): void => {
      // byte 模式 0100 + 8bit 字符数（v1-9）：20×'a' → 比特流 0100 00010100 01100001...
      // cw0=01000001=0x41，cw1=01000110=0x46，cw2=data0低半节+data1高半节=00010110=0x16
      const bytes: number[] = asciiBytes(asciiRepeat('a', 20))
      const cw: number[] = buildDataCodewords(bytes, 1)
      expect(cw[0]).assertEqual(0x41)
      expect(cw[1]).assertEqual(0x46)
      expect(cw[2]).assertEqual(0x16)
    })

    it('data_codewords_count_indicator_16bit_v10', 0, (): void => {
      // v10 使用 16bit 字符数指示：181×'a' → count=0x00B5，模式 4bit 后不对齐字节边界
      // 比特流 0100 0000000010110101 0110... → cw0=0x40，cw1=00001011=0x0B，cw2=0101 0110=0x56
      const bytes: number[] = asciiBytes(asciiRepeat('a', 181))
      const cw: number[] = buildDataCodewords(bytes, 10)
      expect(cw[0]).assertEqual(0x40)
      expect(cw[1]).assertEqual(0x0B)
      expect(cw[2]).assertEqual(0x56)
    })

    it('data_codewords_pad_alternating_ec11', 0, (): void => {
      // 填充字节交替 0xEC/0x11：1 字节载荷 → 数据段 3 码字 + 13 个填充码字（cw3 起自 0xEC 交替）
      const bytes: number[] = [0x61]
      const cw: number[] = buildDataCodewords(bytes, 1)
      expect(cw[3]).assertEqual(0xEC)
      expect(cw[4]).assertEqual(0x11)
      expect(cw[5]).assertEqual(0xEC)
      expect(cw[14]).assertEqual(0x11)
      expect(cw[15]).assertEqual(0xEC)
    })

    it('data_codewords_terminator_max4bits', 0, (): void => {
      // 终止符至多 4 bit：v1 恰好 14 字节时 124+4=128 bit，末码字低半字节为 0
      const bytes: number[] = asciiBytes(asciiRepeat('a', 14))
      const cw: number[] = buildDataCodewords(bytes, 1)
      expect(cw[15]).assertEqual(0x10)
    })
  })

  // ==================== SR-01：QR 编码链 第 3 步（RS 纠错 + 分块交错） ====================
  describe('QrEncoderRsTest', () => {

    it('gf256_known_vectors', 0, (): void => {
      // GF(256) 本原多项式 0x11D（QR 标准；0x53×0xCA=0x01 是 AES 0x11B 的例子，勿混用）
      // 0x53×0xCA：进位乘积 0x3F7E → mod g=0x11D 手算归约 = 0x8F
      expect(gfMul(0x53, 0xCA)).assertEqual(0x8F)
      expect(gfMul(2, 4)).assertEqual(8)
      expect(gfMul(0, 5)).assertEqual(0)
      expect(gfMul(1, 0xAB)).assertEqual(0xAB)
      // ×α 即左移（0x53<<1=0xA6 无溢出，无需约减）
      expect(gfMul(2, 0x53)).assertEqual(0xA6)
    })

    it('rs_single_byte_linear_property', 0, (): void => {
      // 单字节+1 纠错：m(x)=b·x, g(x)=x+1 → 余数 r=b（x ≡ 1 mod x+1，GF 上手算可证）
      expect(rsEncodeBlock([0x40], 1)[0]).assertEqual(0x40)
      expect(rsEncodeBlock([0xFF], 1)[0]).assertEqual(0xFF)
      // 全零数据 → 全零纠错（线性性）
      const ec0: number[] = rsEncodeBlock([0, 0, 0, 0], 2)
      expect(ec0[0]).assertEqual(0)
      expect(ec0[1]).assertEqual(0)
    })

    it('rs_codeword_divisible_by_independent_generator_cm04', 0, (): void => {
      // 数学性质校验：(数据‖纠错) 必须被 g(x)=∏(x−α^i) 整除——
      // 生成多项式与长除法均为测试内独立实现，与 QrEncoder 交叉验证（逐 ecLen 定位）
      const d3: number[] = [32, 91, 11]
      expect(rsDivisibleSum(d3, 1)).assertEqual(0)
      expect(rsDivisibleSum(d3, 2)).assertEqual(0)
      expect(rsDivisibleSum(d3, 3)).assertEqual(0)
      expect(rsDivisibleSum(d3, 4)).assertEqual(0)
      expect(rsDivisibleSum(d3, 5)).assertEqual(0)
      expect(rsDivisibleSum(d3, 6)).assertEqual(0)
      expect(rsDivisibleSum(d3, 7)).assertEqual(0)
      expect(rsDivisibleSum(d3, 8)).assertEqual(0)
      expect(rsDivisibleSum(d3, 9)).assertEqual(0)
      expect(rsDivisibleSum(d3, 10)).assertEqual(0)
      const data: number[] = [32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17]
      const ec: number[] = rsEncodeBlock(data, 10)
      expect(ec.length).assertEqual(10)
      const rem: number[] = indepRemainder(data.concat(ec), indepGenerator(10))
      for (let i: number = 0; i < rem.length; i++) {
        expect(rem[i]).assertEqual(0)
      }
    })

    it('ec_block_structure_m_v1_to_v10', 0, (): void => {
      // 各版本 EC-M 块结构（块数, 每块纠错码字数）与标准表一致
      const blocks: number[] = [1, 1, 1, 2, 2, 4, 4, 4, 5, 5]
      const ecPer: number[] = [10, 16, 26, 18, 24, 16, 18, 22, 22, 26]
      for (let v: number = 1; v <= 10; v++) {
        const info: number[] = ecBlockInfo(v)
        expect(info[0]).assertEqual(blocks[v - 1])
        expect(info[1]).assertEqual(ecPer[v - 1])
      }
    })

    it('final_codewords_total_per_version', 0, (): void => {
      // 交错输出总长 = 数据码字数 + 纠错码字数（= 版本总码字数 26..346）
      const totals: number[] = [26, 44, 70, 100, 134, 172, 196, 242, 292, 346]
      const caps: number[] = [14, 26, 42, 62, 84, 106, 122, 152, 180, 213]
      for (let v: number = 1; v <= 10; v++) {
        const data: number[] = buildDataCodewords(asciiBytes(asciiRepeat('a', caps[v - 1])), v)
        const final: number[] = buildFinalCodewords(data, v)
        expect(final.length).assertEqual(totals[v - 1])
      }
    })

    it('interleave_two_blocks_v4_order', 0, (): void => {
      // v4-M 2 块×32：交错顺序 d0,d32,d1,d33,...；数据段后接各块纠错码字交错
      const data: number[] = []
      for (let i: number = 0; i < 64; i++) data.push(i & 0xFF)
      const final: number[] = buildFinalCodewords(data, 4)
      expect(final.length).assertEqual(100)
      expect(final[0]).assertEqual(0)
      expect(final[1]).assertEqual(32)
      expect(final[2]).assertEqual(1)
      expect(final[3]).assertEqual(33)
      expect(final[62]).assertEqual(31)
      expect(final[63]).assertEqual(63)
    })

    it('interleave_uneven_blocks_v8_tail', 0, (): void => {
      // v8-M 两块组（2×38 + 2×39）：短块耗尽后长块继续交错（尾段处理）
      const data: number[] = []
      for (let i: number = 0; i < 154; i++) data.push(i & 0xFF)
      const final: number[] = buildFinalCodewords(data, 8)
      expect(final.length).assertEqual(242)
      // 前 4 个：d0, d38, d76, d115（B0/B1 38 码字，B2/B3 39 码字）
      expect(final[0]).assertEqual(0)
      expect(final[1]).assertEqual(38)
      expect(final[2]).assertEqual(76)
      expect(final[3]).assertEqual(115)
      // 第 38 轮后 B0/B1 耗尽，B2/B3 的第 39 个码字紧随其后
      expect(final[152]).assertEqual(114)
      expect(final[153]).assertEqual(153)
    })
  })

  // ==================== SR-01：QR 编码链 第 4 步（矩阵布置） ====================
  describe('QrEncoderMatrixTest', () => {

    it('matrix_size_formula_v1_to_v10_ac9', 0, (): void => {
      // 矩阵边长 = 4×版本+17（v1=21 … v10=57）
      for (let v: number = 1; v <= 10; v++) {
        const m: boolean[][] = buildMatrix(validFinal(v), v, 0)
        expect(m.length).assertEqual(4 * v + 17)
        expect(m[0].length).assertEqual(4 * v + 17)
      }
    })

    it('finder_patterns_shape_and_separators', 0, (): void => {
      const m: boolean[][] = buildMatrix(validFinal(2), 2, 0)
      const size: number = 25
      const corners: number[][] = [[0, 0], [0, size - 7], [size - 7, 0]]
      for (let k: number = 0; k < 3; k++) {
        const r0: number = corners[k][0]
        const c0: number = corners[k][1]
        for (let dr: number = 0; dr < 7; dr++) {
          for (let dc: number = 0; dc < 7; dc++) {
            const border: boolean = dr === 0 || dr === 6 || dc === 0 || dc === 6
            const center: boolean = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4
            const expectDark: boolean = border || center
            expect(m[r0 + dr][c0 + dc]).assertEqual(expectDark)
          }
        }
      }
      // 分隔符：finder 内侧一圈恒浅色
      for (let i: number = 0; i <= 7; i++) {
        expect(m[7][i]).assertFalse()
        expect(m[i][7]).assertFalse()
        expect(m[7][size - 1 - i]).assertFalse()
        expect(m[size - 1 - i][7]).assertFalse()
      }
    })

    it('timing_pattern_alternating', 0, (): void => {
      for (let v: number = 1; v <= 10; v++) {
        const m: boolean[][] = buildMatrix(validFinal(v), v, 0)
        const size: number = 4 * v + 17
        for (let c: number = 8; c <= size - 9; c++) {
          expect(m[6][c]).assertEqual(c % 2 === 0)
        }
        for (let r: number = 8; r <= size - 9; r++) {
          expect(m[r][6]).assertEqual(r % 2 === 0)
        }
      }
    })

    it('dark_module_fixed_cm04', 0, (): void => {
      for (let v: number = 1; v <= 10; v++) {
        const m: boolean[][] = buildMatrix(validFinal(v), v, 3)
        expect(m[4 * v + 9][8]).assertTrue()
      }
    })

    it('alignment_patterns_v2_to_v10', 0, (): void => {
      for (let v: number = 2; v <= 10; v++) {
        const m: boolean[][] = buildMatrix(validFinal(v), v, 0)
        const size: number = 4 * v + 17
        const centers: number[] = testAlignmentCenters(v)
        let firstBad: number = -1
        for (let i: number = 0; i < centers.length; i++) {
          for (let j: number = 0; j < centers.length; j++) {
            const cr: number = centers[i]
            const cc: number = centers[j]
            const overlapFinder: boolean = (cr <= 8 && cc <= 8) || (cr <= 8 && cc >= size - 9) || (cr >= size - 9 && cc <= 8)
            if (overlapFinder) continue
            // 5×5：外圈暗、中圈浅、中心暗
            for (let dr: number = -2; dr <= 2; dr++) {
              for (let dc: number = -2; dc <= 2; dc++) {
                const ring: boolean = Math.abs(dr) === 2 || Math.abs(dc) === 2
                const mid: boolean = Math.abs(dr) === 1 || Math.abs(dc) === 1
                const expectDark: boolean = ring || (!mid)
                if (m[cr + dr][cc + dc] !== expectDark) {
                  firstBad = (cr + dr) * 1000 + (cc + dc)
                }
              }
            }
          }
        }
        expect(firstBad).assertEqual(-1)
      }
    })

    it('format_info_bch_all_masks_cm04', 0, (): void => {
      for (let mask: number = 0; mask < 8; mask++) {
        const m: boolean[][] = buildMatrix(validFinal(3), 3, mask)
        const size: number = 29
        const vertical: number = extractFormatVertical(m, size)
        const horizontal: number = extractFormatHorizontal(m, size)
        // 两份拷贝一致
        expect(vertical).assertEqual(horizontal)
        // 反掩模后高 5 位数据 = EC-M(00)‖掩模号
        const unmasked: number = vertical ^ 0x5412
        expect((unmasked >> 10) & 0x1F).assertEqual(mask)
        // BCH 性质：(格式位 XOR 0x5412) 必须被 0x537 整除（测试侧独立多项式模）
        expect(polyMod(unmasked, 0x537, 14, 10)).assertEqual(0)
      }
    })

    it('format_info_differs_across_masks', 0, (): void => {
      const base: number = extractFormatVertical(buildMatrix(validFinal(1), 1, 0), 21)
      for (let mask: number = 1; mask < 8; mask++) {
        const bits: number = extractFormatVertical(buildMatrix(validFinal(1), 1, mask), 21)
        expect(bits !== base).assertTrue()
      }
    })

    it('version_info_bch_v7_to_v10_cm04', 0, (): void => {
      for (let v: number = 7; v <= 10; v++) {
        const m: boolean[][] = buildMatrix(validFinal(v), v, 0)
        const size: number = 4 * v + 17
        const bl: number = extractVersion(m, size)
        // 高 6 位 = 版本号
        expect(bl >> 12).assertEqual(v)
        // BCH 性质：18 位整体被 0x1F25 整除
        expect(polyMod(bl, 0x1F25, 17, 12)).assertEqual(0)
        // 右上块与左下块一致
        let tr: number = 0
        for (let i: number = 0; i < 18; i++) {
          const r: number = Math.floor(i / 3)
          const c: number = size - 11 + (i % 3)
          if (m[r][c]) tr |= (1 << i)
        }
        expect(tr).assertEqual(bl)
      }
    })

    it('zigzag_roundtrip_v1_mask0_cm04', 0, (): void => {
      const v: number = 1
      const size: number = 4 * v + 17
      const final: number[] = validFinal(v)
      const m: boolean[][] = buildMatrix(final, v, 0)
      const cells: number[][] = testZigzagCells(size, v)
      // 数据单元数 = 码字数×8
      expect(cells.length).assertEqual(final.length * 8)
      for (let k: number = 0; k < cells.length; k++) {
        const r: number = cells[k][0]
        const c: number = cells[k][1]
        const expectBit: number = codewordBitAt(final, k) ^ (maskCondition(0, r, c) ? 1 : 0)
        expect(m[r][c]).assertEqual(expectBit === 1)
      }
    })

    it('zigzag_roundtrip_v4_mask5_cm04', 0, (): void => {
      const v: number = 4
      const size: number = 4 * v + 17
      const final: number[] = validFinal(v)
      const m: boolean[][] = buildMatrix(final, v, 5)
      const cells: number[][] = testZigzagCells(size, v)
      // QR versions 2-6 append seven zero remainder bits after all codewords.
      expect(cells.length).assertEqual(final.length * 8 + 7)
      for (let k: number = 0; k < cells.length; k++) {
        const r: number = cells[k][0]
        const c: number = cells[k][1]
        const expectBit: number = codewordBitAt(final, k) ^ (maskCondition(5, r, c) ? 1 : 0)
        expect(m[r][c]).assertEqual(expectBit === 1)
      }
    })

    it('encode_qr_selects_lowest_penalty_mask', 0, (): void => {
      const text: string = 'OpenCalc\n算式: sin(30)\n结果: 0.5'
      const bytes: number[] = utf8Bytes(text)
      const version: number = selectQrVersion(bytes.length)
      const final: number[] = buildFinalCodewords(buildDataCodewords(bytes, version), version)
      let minimum: number = 2147483647
      for (let mask: number = 0; mask < 8; mask++) {
        const score: number = scoreMatrix(buildMatrix(final, version, mask))
        if (score < minimum) minimum = score
      }
      const encoded: QrEncodeResult = encodeQr(text)
      expect(encoded.ok).assertTrue()
      expect(encoded.matrix === null).assertFalse()
      if (encoded.matrix !== null) {
        expect(scoreMatrix(encoded.matrix.modules)).assertEqual(minimum)
      }
    })

    it('encode_qr_is_deterministic_and_supports_long_payload', 0, (): void => {
      const text: string = asciiRepeat('a', 200)
      const first: QrEncodeResult = encodeQr(text)
      const second: QrEncodeResult = encodeQr(text)
      expect(first.ok).assertTrue()
      expect(second.ok).assertTrue()
      expect(first.matrix === null).assertFalse()
      expect(second.matrix === null).assertFalse()
      if (first.matrix !== null && second.matrix !== null) {
        expect(first.matrix.size).assertEqual(57)
        expect(JSON.stringify(first.matrix.modules)).assertEqual(JSON.stringify(second.matrix.modules))
      }
    })

    it('encode_qr_rejects_empty_and_over_capacity_input', 0, (): void => {
      const empty: QrEncodeResult = encodeQr('')
      expect(empty.ok).assertFalse()
      expect(empty.matrix === null).assertTrue()
      expect(empty.reason.length > 0).assertTrue()
      const oversized: QrEncodeResult = encodeQr(asciiRepeat('a', 214))
      expect(oversized.ok).assertFalse()
      expect(oversized.matrix === null).assertTrue()
      expect(oversized.reason.length > 0).assertTrue()
    })
  })
}
