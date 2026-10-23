// OpenCalc — 二维码画布布局纯函数（Issue #42）

/** 避免超大模块使标准截图解码器的定位采样失效。 */
export const MAX_SCREENSHOT_MODULE_PX: number = 4

/** 按可用画布尺寸计算整数模块像素，保证完整二维码居中且不裁切。 */
export function qrModulePixels(canvasWidth: number, canvasHeight: number,
  matrixSize: number, quietModules: number): number {
  const available: number = Math.floor(Math.min(canvasWidth, canvasHeight) /
    (matrixSize + quietModules * 2))
  return Math.min(available, MAX_SCREENSHOT_MODULE_PX)
}
