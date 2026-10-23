// OpenCalc — 二维码画布布局纯函数（Issue #42）

/** 避免超大模块使标准截图解码器的定位采样失效。 */
export const MAX_SCREENSHOT_MODULE_PX: number = 4

/** 按可用画布尺寸计算整数模块像素，保证完整二维码居中且不裁切。 */
export function qrModulePixels(canvasWidth: number, canvasHeight: number,
  matrixSize: number, quietModules: number): number {
  if (!Number.isFinite(canvasWidth) || !Number.isFinite(canvasHeight) ||
    canvasWidth <= 0 || canvasHeight <= 0 || !Number.isFinite(matrixSize) ||
    matrixSize <= 0 || !Number.isInteger(matrixSize) || !Number.isFinite(quietModules) ||
    quietModules < 4 || !Number.isInteger(quietModules)) return 0
  const available: number = Math.floor(Math.min(canvasWidth, canvasHeight) /
    (matrixSize + quietModules * 2))
  return Math.max(0, Math.min(available, MAX_SCREENSHOT_MODULE_PX))
}
