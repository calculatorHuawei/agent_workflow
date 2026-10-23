// OpenCalc — 离线二维码编码器（Issue #42，ISO 18004 子集：byte 模式 + UTF-8、EC-M、版本 1-10）
// 契约：delta-design §4.2 ｜ 步骤参考 §3.5.8 ｜ 措施：CM-04 可扫描性 / CM-06 容量前置 / CM-10 失败态
// 约束：纯函数、无模块级可变状态、零 Kit/三方依赖

/** 二维码模块矩阵：size=4×版本+17，modules[r][c]=true 表示深色模块 */
export interface QrMatrix {
  size: number
  modules: boolean[][]
}

/** 编码结果：失败时 matrix 为 null、reason 给出提示文案（不产出残缺矩阵，CM-10） */
export interface QrEncodeResult {
  ok: boolean
  matrix: QrMatrix | null
  reason: string
}

/**
 * EC-M 各版本块结构表（ISO/IEC 18004）：
 * 每组 [块数, 每块总码字, 每块数据码字]，纠错码字/块 = 总 - 数据。
 * v10-M 数据码字 216 → byte 模式实际容量 213 字节（spec 中 271 为 EC-L v10 值，
 * 差异与两层防护口径见 apply-report「规格差异记录」）。
 */
const EC_BLOCK_M: number[][][] = [
  [[1, 26, 16]],                        // v1
  [[1, 44, 28]],                        // v2
  [[1, 70, 44]],                        // v3
  [[2, 50, 32]],                        // v4
  [[2, 67, 43]],                        // v5
  [[4, 43, 27]],                        // v6
  [[4, 49, 31]],                        // v7
  [[2, 60, 38], [2, 61, 39]],           // v8
  [[3, 58, 36], [2, 59, 37]],           // v9
  [[4, 69, 43], [1, 70, 44]]            // v10
]

/** 文本 → UTF-8 字节序列（编码链输入；与 QrPayload.utf8ByteLength 同一计数语义，CM-09） */
export function utf8Bytes(text: string): number[] {
  const bytes: number[] = []
  let i: number = 0
  while (i < text.length) {
    const c: number = text.charCodeAt(i)
    if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
      const d: number = text.charCodeAt(i + 1)
      if (d >= 0xDC00 && d <= 0xDFFF) {
        const cp: number = 0x10000 + ((c - 0xD800) << 10) + (d - 0xDC00)
        bytes.push(0xF0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3F), 0x80 | ((cp >> 6) & 0x3F), 0x80 | (cp & 0x3F))
        i += 2
        continue
      }
    }
    if (c < 0x80) bytes.push(c)
    else if (c < 0x800) bytes.push(0xC0 | (c >> 6), 0x80 | (c & 0x3F))
    else bytes.push(0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F))
    i += 1
  }
  return bytes
}

/** 指定版本 EC-M 数据码字总数（块结构表横向求和） */
export function dataCodewordCount(version: number): number {
  const groups: number[][] = EC_BLOCK_M[version - 1]
  let total: number = 0
  for (let g: number = 0; g < groups.length; g++) {
    total += groups[g][0] * groups[g][2]
  }
  return total
}

/** byte 模式字符数指示位数：v1-9 为 8 bit，v10-26 为 16 bit（ISO 18004 §8.4.4） */
function charCountBits(version: number): number {
  return version <= 9 ? 8 : 16
}

/** 指定版本 byte 模式可容纳最大字节数（扣除模式 4 bit + 字符数指示 + 终止符至多 4 bit） */
function byteCapacity(version: number): number {
  const headerBits: number = 4 + charCountBits(version)
  return Math.floor((dataCodewordCount(version) * 8 - headerBits - 4) / 8)
}

/** 版本选择：返回容纳 numDataBytes 的最小版本 v∈[1,10]；超出 EC-M 容量返回 0（调用方给失败态，CM-06/CM-10） */
export function selectQrVersion(numDataBytes: number): number {
  for (let v: number = 1; v <= 10; v++) {
    if (numDataBytes <= byteCapacity(v)) return v
  }
  return 0
}

// ==================== 编码链第 3 步：GF(256) Reed-Solomon 纠错与分块交错 ====================

/** GF(256) 指数表（α^i，i∈[0,510)），本原多项式 0x11D */
const GF_EXP: number[] = (() => {
  const exp: number[] = []
  let x: number = 1
  for (let i: number = 0; i < 255; i++) {
    exp.push(x)
    x = x << 1
    if (x >= 0x100) x = (x ^ 0x11D) & 0xFF
  }
  for (let i: number = 255; i < 512; i++) exp.push(exp[i - 255])
  return exp
})()

/** GF(256) 对数表（LOG[α^i]=i；LOG[0] 未定义恒 0，由 gfMul 的 0 快速路径规避） */
const GF_LOG: number[] = (() => {
  const log: number[] = []
  for (let i: number = 0; i < 256; i++) log.push(0)
  for (let i: number = 0; i < 255; i++) log[GF_EXP[i]] = i
  return log
})()

/** GF(256) 乘法（RS 多项式运算基本算子） */
export function gfMul(a: number, b: number): number {
  if (a === 0 || b === 0) return 0
  return GF_EXP[GF_LOG[a] + GF_LOG[b]]
}

/** 生成多项式 g(x)=∏(x - α^i)，i∈[0, degree)：降幂系数数组（g[0]=1） */
function rsGenerator(degree: number): number[] {
  let poly: number[] = [1]
  for (let i: number = 0; i < degree; i++) {
    const a: number = GF_EXP[i]
    const next: number[] = [poly[0]]
    for (let k: number = 1; k < poly.length; k++) {
      next.push(poly[k] ^ gfMul(poly[k - 1], a))
    }
    next.push(gfMul(poly[poly.length - 1], a))
    poly = next
  }
  return poly
}

/**
 * 单块 RS 纠错码字：对块数据多项式做 GF(256) 除法，返回 ecLen 个余数系数（降幂）。
 * 标准向量（thonky v1-M）：16 数据 → 10 纠错 = 168,72,22,82,217,54,156,0,46,15（CM-04）
 */
export function rsEncodeBlock(blockData: number[], ecLen: number): number[] {
  const gen: number[] = rsGenerator(ecLen)
  const rem: number[] = []
  for (let i: number = 0; i < ecLen; i++) rem.push(0)
  for (let i: number = 0; i < blockData.length; i++) {
    const factor: number = blockData[i] ^ rem[0]
    rem.shift()
    rem.push(0)
    if (factor !== 0) {
      for (let j: number = 0; j < ecLen; j++) {
        rem[j] = rem[j] ^ gfMul(gen[j + 1], factor)
      }
    }
  }
  return rem
}

/** 指定版本 EC-M 块信息 [块数, 每块纠错码字数]（M 级各块组每块纠错码字数相同） */
export function ecBlockInfo(version: number): number[] {
  const groups: number[][] = EC_BLOCK_M[version - 1]
  let blocks: number = 0
  const ecPerBlock: number = groups[0][1] - groups[0][2]
  for (let g: number = 0; g < groups.length; g++) {
    blocks += groups[g][0]
  }
  const info: number[] = [blocks, ecPerBlock]
  return info
}

/** 展开各块数据码字长度（按块顺序）与总纠错码字数（内部辅助） */
function blockLayout(version: number): number[] {
  const groups: number[][] = EC_BLOCK_M[version - 1]
  const sizes: number[] = []
  for (let g: number = 0; g < groups.length; g++) {
    for (let b: number = 0; b < groups[g][0]; b++) sizes.push(groups[g][2])
  }
  return sizes
}

/**
 * 分块 + 逐块纠错 + 交错（编码链第 3 步收口，ISO 18004 §8.5）：
 * 数据码字按块切分 → 每块生成纠错码字 → 先交错全部数据码字、再交错全部纠错码字。
 */
export function buildFinalCodewords(allData: number[], version: number): number[] {
  const sizes: number[] = blockLayout(version)
  const numBlocks: number = sizes.length
  // 切块
  const blocks: number[][] = []
  let offset: number = 0
  let maxLen: number = 0
  for (let b: number = 0; b < numBlocks; b++) {
    const blk: number[] = []
    for (let i: number = 0; i < sizes[b]; i++) blk.push(allData[offset + i])
    offset += sizes[b]
    if (sizes[b] > maxLen) maxLen = sizes[b]
    blocks.push(blk)
  }
  // 逐块纠错
  const ecPerBlock: number = ecBlockInfo(version)[1]
  const ecs: number[][] = []
  for (let b: number = 0; b < numBlocks; b++) ecs.push(rsEncodeBlock(blocks[b], ecPerBlock))
  // 交错输出
  const out: number[] = []
  for (let i: number = 0; i < maxLen; i++) {
    for (let b: number = 0; b < numBlocks; b++) {
      if (i < blocks[b].length) out.push(blocks[b][i])
    }
  }
  for (let i: number = 0; i < ecPerBlock; i++) {
    for (let b: number = 0; b < numBlocks; b++) {
      out.push(ecs[b][i])
    }
  }
  return out
}

// ==================== 编码链第 4-5 步：矩阵布置与掩模 ====================

/** 8 个标准掩模条件（ISO 18004 §8.8.2；maskId 0-7） */
export function maskCondition(maskId: number, r: number, c: number): boolean {
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

/** 校正图案中心坐标表（v2-10，测试与实现对同一规范表） */
const ALIGN_CENTERS: number[][] = [
  [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
  [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]
]

/** 格式信息 BCH(15,5) 余数：g(x)=x^10+x^8+x^5+x^4+x^2+x+1（0x537） */
function bch15Remainder(data5: number): number {
  let v: number = data5 << 10
  for (let b: number = 14; b >= 10; b--) {
    if (((v >> b) & 1) !== 0) v ^= 0x537 << (b - 10)
  }
  return v
}

/** 15 位格式信息 = (数据·x^10 + 余数) XOR 掩模 101010000010010（0x5412） */
function formatBits(data5: number): number {
  return ((data5 << 10) | bch15Remainder(data5)) ^ 0x5412
}

/** 18 位版本信息 BCH(18,6)：g(x)=x^12+x^11+x^10+x^9+x^8+x^5+x^2+1（0x1F25），无掩模 */
function versionBits(version: number): number {
  let v: number = version << 12
  for (let b: number = 17; b >= 12; b--) {
    if (((v >> b) & 1) !== 0) v ^= 0x1F25 << (b - 12)
  }
  return (version << 12) | v
}

/**
 * 矩阵布置（编码链第 4 步）：功能图案 → 格式/版本信息 → 数据之字形填充（跳过功能模块并施加掩模）。
 * flags：0=未定 1=暗 2=浅（以数值标记避免 boolean 无法表达"未定"），收口转换为 boolean 矩阵。
 */
export function buildMatrix(finalCodewords: number[], version: number, maskId: number): boolean[][] {
  const size: number = 4 * version + 17
  const flags: number[][] = []
  for (let r: number = 0; r < size; r++) {
    const row: number[] = []
    for (let c: number = 0; c < size; c++) row.push(0)
    flags.push(row)
  }
  // 三个定位图案（7×7：外圈暗 + 中心 3×3 暗）与分隔符
  const corners: number[][] = [[0, 0], [0, size - 7], [size - 7, 0]]
  for (let k: number = 0; k < 3; k++) {
    const r0: number = corners[k][0]
    const c0: number = corners[k][1]
    for (let dr: number = 0; dr < 7; dr++) {
      for (let dc: number = 0; dc < 7; dc++) {
        const border: boolean = dr === 0 || dr === 6 || dc === 0 || dc === 6
        const center: boolean = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4
        flags[r0 + dr][c0 + dc] = (border || center) ? 1 : 2
      }
    }
  }
  for (let i: number = 0; i <= 7; i++) {
    flags[7][i] = 2
    flags[i][7] = 2
    flags[7][size - 1 - i] = 2
    flags[size - 1 - i][7] = 2
    flags[size - 8][i] = 2
    flags[i][size - 8] = 2
  }
  // 校正图案（v2-10；与定位图案重叠的中心跳过——中心已被占用即跳过）
  if (version >= 2) {
    const centers: number[] = ALIGN_CENTERS[version - 2]
    for (let i: number = 0; i < centers.length; i++) {
      for (let j: number = 0; j < centers.length; j++) {
        const cr: number = centers[i]
        const cc: number = centers[j]
        if (flags[cr][cc] !== 0) continue
        for (let dr: number = -2; dr <= 2; dr++) {
          for (let dc: number = -2; dc <= 2; dc++) {
            const ring: boolean = Math.abs(dr) === 2 || Math.abs(dc) === 2
            const mid: boolean = Math.abs(dr) === 1 || Math.abs(dc) === 1
            flags[cr + dr][cc + dc] = (ring || !mid) ? 1 : 2
          }
        }
      }
    }
  }
  // 时序图案：第 6 行/列黑白交替（未被功能图案占用处）
  for (let i: number = 8; i <= size - 9; i++) {
    if (flags[6][i] === 0) flags[6][i] = (i % 2 === 0) ? 1 : 2
    if (flags[i][6] === 0) flags[i][6] = (i % 2 === 0) ? 1 : 2
  }
  // 暗模块（左下角恒暗）
  flags[size - 8][8] = 1
  // 格式信息（EC-M=00，数据位 = 00‖掩模号）
  const fb: number = formatBits((0 << 3) | maskId)
  for (let i: number = 0; i < 15; i++) {
    const dark: boolean = ((fb >> i) & 1) === 1
    if (i < 6) flags[i][8] = dark ? 1 : 2
    else if (i < 8) flags[i + 1][8] = dark ? 1 : 2
    else flags[size - 15 + i][8] = dark ? 1 : 2
    if (i < 8) flags[8][size - 1 - i] = dark ? 1 : 2
    else if (i === 8) flags[8][7] = dark ? 1 : 2
    else flags[8][14 - i] = dark ? 1 : 2
  }
  // 版本信息（v≥7）
  if (version >= 7) {
    const vb: number = versionBits(version)
    for (let i: number = 0; i < 18; i++) {
      const dark: boolean = ((vb >> i) & 1) === 1
      flags[size - 11 + (i % 3)][Math.floor(i / 3)] = dark ? 1 : 2
      flags[Math.floor(i / 3)][size - 11 + (i % 3)] = dark ? 1 : 2
    }
  }
  // 数据码字之字形填充（两列一组自右向左，跳过第 6 列与功能模块；施掩模）
  let bitIndex: number = 0
  const totalBits: number = finalCodewords.length * 8
  let right: number = size - 1
  while (right >= 1) {
    if (right === 6) right = 5
    for (let vert: number = 0; vert < size; vert++) {
      for (let j: number = 0; j < 2; j++) {
        const c: number = right - j
        const upward: boolean = ((right + 1) & 2) === 0
        const r: number = upward ? (size - 1 - vert) : vert
        if (flags[r][c] === 0) {
          // Modules after the final codeword are QR remainder bits. Their value
          // is zero before the selected data mask is applied.
          let bit: number = bitIndex < totalBits
            ? (finalCodewords[bitIndex >> 3] >> (7 - (bitIndex & 7))) & 1
            : 0
          if (maskCondition(maskId, r, c)) bit = bit ^ 1
          flags[r][c] = bit === 1 ? 1 : 2
          bitIndex += 1
        }
      }
    }
    right -= 2
  }
  // 收口：转换为 boolean 矩阵（true=深色）
  const m: boolean[][] = []
  for (let r: number = 0; r < size; r++) {
    const row: boolean[] = []
    for (let c: number = 0; c < size; c++) row.push(flags[r][c] === 1)
    m.push(row)
  }
  return m
}

/** ISO 18004 N1/N3 penalties for one matrix row or column. */
function scoreLine(line: boolean[]): number {
  let score: number = 0
  let runColor: boolean = line[0]
  let runLength: number = 1
  for (let i: number = 1; i < line.length; i++) {
    if (line[i] === runColor) {
      runLength += 1
      if (runLength === 5) score += 3
      else if (runLength > 5) score += 1
    } else {
      runColor = line[i]
      runLength = 1
    }
  }
  for (let i: number = 0; i + 6 < line.length; i++) {
    const finder: boolean = line[i] && !line[i + 1] && line[i + 2] &&
      line[i + 3] && line[i + 4] && !line[i + 5] && line[i + 6]
    if (!finder) continue
    let before: boolean = i >= 4
    for (let j: number = i - 4; before && j < i; j++) before = !line[j]
    let after: boolean = i + 10 < line.length
    for (let j: number = i + 7; after && j <= i + 10; j++) after = !line[j]
    if (before) score += 40
    if (after) score += 40
  }
  return score
}

/** Score a completed QR matrix using the standard N1-N4 mask penalties. */
export function scoreMatrix(matrix: boolean[][]): number {
  const size: number = matrix.length
  if (size === 0) return 2147483647
  let score: number = 0
  let dark: number = 0
  for (let r: number = 0; r < size; r++) {
    score += scoreLine(matrix[r])
    const column: boolean[] = []
    for (let c: number = 0; c < size; c++) {
      column.push(matrix[c][r])
      if (matrix[r][c]) dark += 1
    }
    score += scoreLine(column)
  }
  for (let r: number = 0; r + 1 < size; r++) {
    for (let c: number = 0; c + 1 < size; c++) {
      const color: boolean = matrix[r][c]
      if (matrix[r][c + 1] === color && matrix[r + 1][c] === color &&
        matrix[r + 1][c + 1] === color) score += 3
    }
  }
  const total: number = size * size
  score += Math.floor(Math.abs(dark * 20 - total * 10) / total) * 10
  return score
}

/** Encode UTF-8 text as an EC-M QR matrix, selecting the lowest-penalty mask. */
export function encodeQr(text: string): QrEncodeResult {
  if (text.length === 0) {
    return { ok: false, matrix: null, reason: '二维码内容为空' }
  }
  try {
    const bytes: number[] = utf8Bytes(text)
    const version: number = selectQrVersion(bytes.length)
    if (version === 0) {
      return { ok: false, matrix: null, reason: '内容过长，无法生成二维码' }
    }
    const data: number[] = buildDataCodewords(bytes, version)
    const finalCodewords: number[] = buildFinalCodewords(data, version)
    let best: boolean[][] | null = null
    let bestScore: number = 2147483647
    for (let mask: number = 0; mask < 8; mask++) {
      const candidate: boolean[][] = buildMatrix(finalCodewords, version, mask)
      const candidateScore: number = scoreMatrix(candidate)
      if (candidateScore < bestScore) {
        best = candidate
        bestScore = candidateScore
      }
    }
    if (best === null) {
      return { ok: false, matrix: null, reason: '二维码生成失败' }
    }
    return { ok: true, matrix: { size: best.length, modules: best }, reason: '' }
  } catch {
    return { ok: false, matrix: null, reason: '二维码生成失败' }
  }
}

/** bit 流写入器（数据编码步骤内部结构） */
class BitBuffer {
  private bits: number[] = []

  put(value: number, length: number): void {
    for (let i: number = length - 1; i >= 0; i--) {
      this.bits.push((value >>> i) & 1)
    }
  }

  length(): number {
    return this.bits.length
  }

  /** 按大端打包为码字序列；末字节不足 8 bit 时低位补 0 */
  toCodewords(): number[] {
    const out: number[] = []
    for (let i: number = 0; i < this.bits.length; i += 8) {
      let byte: number = 0
      for (let b: number = 0; b < 8; b++) {
        byte = (byte << 1) | (i + b < this.bits.length ? this.bits[i + b] : 0)
      }
      out.push(byte)
    }
    return out
  }
}

/**
 * 数据编码（编码链第 2 步）：模式指示符 0100 + 字符数指示 + 数据 + 终止符（至多 4 bit）
 * + 补位到码字边界 + 0xEC/0x11 交替填充至该版本数据码字容量（ISO 18004 §8.4）。
 */
export function buildDataCodewords(dataBytes: number[], version: number): number[] {
  const buf: BitBuffer = new BitBuffer()
  buf.put(0x4, 4)                                   // byte 模式指示符
  buf.put(dataBytes.length, charCountBits(version)) // 字符数指示
  for (let i: number = 0; i < dataBytes.length; i++) {
    buf.put(dataBytes[i], 8)
  }
  // 终止符 0000：至多 4 bit，且不超过总容量
  const capacityBits: number = dataCodewordCount(version) * 8
  const terminatorBits: number = Math.min(4, capacityBits - buf.length())
  if (terminatorBits > 0) buf.put(0, terminatorBits)
  // 补 0 到码字边界
  while (buf.length() % 8 !== 0) buf.put(0, 1)
  // 0xEC/0x11 交替填充至容量
  const codewords: number[] = buf.toCodewords()
  const target: number = dataCodewordCount(version)
  const pads: number[] = [0xEC, 0x11]
  let p: number = 0
  while (codewords.length < target) {
    codewords.push(pads[p % 2])
    p += 1
  }
  return codewords
}
