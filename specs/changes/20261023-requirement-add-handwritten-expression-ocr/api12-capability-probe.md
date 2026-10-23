# API 12 能力探针

- 日期：2026-10-23
- SDK：HarmonyOS 5.0.0 (API 12)
- 构建：`opencalc/run-build-wt.bat`，BUILD SUCCESSFUL

## 结论

- 单次拍照：`@kit.CameraKit` 的 `cameraPicker.pick`，API 11 起可用，API 12 支持 atomic service。
- 端侧 OCR：`@kit.CoreVisionKit` 的 `textRecognition.recognizeText`，API 10 起可用；`init/release` 为 API 12。
- 图片解码：`@kit.ImageKit` 的 `image.createImageSource(...).createPixelMap()`。
- 权限：`@kit.AbilityKit` 的 `requestPermissionsFromUser`，API 12 的 `dialogShownResults` 可区分再次弹窗与永久拒绝。
- 设备能力：phone/tablet SDK syscap 均声明 `SystemCapability.AI.OCR.TextRecognition`。

实现仅使用系统相机、图片与端侧 OCR Kit；没有网络权限、URL、账号、密钥、付费服务或云端回退。照片 URI、PixelMap 和 OCR service 均在当前会话内释放，不写入 Preferences、历史或普通日志。

模拟器可验证权限和相机失败恢复，但不能代表物理相机或手写识别质量。
