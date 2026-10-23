# 拍照识别手写算式 - 架构变更

## 1. 变更概述

| 项目 | 内容 |
|------|------|
| 变更类型 | 新增 |
| 变更日期 | 2026-10-23 |
| 状态 | PLANNING 复核定版；PR #48 精确 head 已实现端侧离线 OCR |

## 2. 最新架构【架构前置】

### 2.1 架构总览

在单 entry HAP 内新增“识别编排域”，把 UI、系统相机/权限、端侧 OCR 实现和安全解析解耦。OCR provider 保持抽象边界以便测试替身，但首期只注入端侧离线实现，不增加云端、网络、账号或密钥边界。

### 2.2 分层架构图

```text
┌────────────────────────────────────────────────────┐
│ View: CalculatorPage + RecognitionPanel           │
├────────────────────────────────────────────────────┤
│ ViewModel/Service: RecognitionCoordinator          │
├───────────────────────────────┬────────────────────┤
│ Domain: ExpressionValidator   │ OCR Provider       │
│                               │ On-device implementation
├───────────────────────────────┴────────────────────┤
│ Platform: PermissionGateway + CaptureGateway       │
├────────────────────────────────────────────────────┤
│ Existing: Expression → CalcEngine (仅用户后续求值) │
└────────────────────────────────────────────────────┘
```

### 2.3 组件职责

| 组件 | 类型 | 职责 | 边界 |
|------|------|------|------|
| RecognitionPanel | View | 展示状态、编辑候选、重拍/确认/取消 | 不直接调用计算引擎 |
| RecognitionCoordinator | Service | 会话、异步编排、原值保护、过期结果丢弃 | 依赖抽象接口 |
| PermissionGateway | Platform | 查询/申请 CAMERA、区分拒绝与需设置 | 返回领域状态 |
| CaptureGateway | Platform | 取得一次拍照结果或取消/错误 | 不持久化照片 |
| HandwritingOcrProvider | Port | 图片 → 原始候选文本 | 首期端侧离线实现；5 s 超时 |
| ExpressionValidator | Domain | 归一化、白名单、长度、括号、语法校验 | 基础四则 grammar；最大 128 字符 |
| CalculatorPage | View owner | 在有效确认回调中更新 expression | 不自动求值 |

### 2.4 交互关系

```text
用户 → Panel → Coordinator → PermissionGateway → CaptureGateway
                                          ↓ image
                                      OCR Provider
                                          ↓ raw text
                                  ExpressionValidator
                                          ↓ candidate/result
用户编辑并确认 → Coordinator → CalculatorPage.expression
```

## 3. 变更原因

相机、OCR 与不可信文本引入新的平台边界和安全边界；若继续堆叠在 CalculatorPage 回调中，会使权限、异步竞态和原输入保护难以验证。

## 4. 变更点

### 4.1 识别会话编排

- 新增显式状态机与 session id。
- 进入会话时保存原表达式；只有有效确认事件提交。
- 迟到异步结果按 session id 丢弃。

### 4.2 平台能力适配

- 新增相机权限和拍照 gateway。
- 首次拒绝可重试；永久拒绝仅提示设置入口，禁止循环申请。

### 4.3 OCR Provider 边界

- 统一 `recognize(image): Promise<OcrResult>` 契约。
- 首期端侧实现：无网络/上传边界，图片仅在前台会话内临时存在。
- 页面层以 5 s 定时器驱动协调器进入超时错误态；端侧实现已定为 API 12 `@kit.CoreVisionKit.textRecognition`，图片解码使用 `@kit.ImageKit`。真机可用性由 Tester 验证；失败不得自动改用云端。

### 4.4 安全解析边界

- 原始 OCR 文本不能传给 `CalcEngine`。
- 只允许确定性 Unicode/运算符归一化：`×/x/X→*`、`÷→/`、Unicode 减号→`-`、忽略空白；拒绝其他未知字符。
- 语法限定为十进制数字、`.`、二元 `+ - * /` 和圆括号；不接受隐式乘法、函数、常量、变量、多行或长度超过 128 的候选。
- 使用严格语法校验，不沿用会自动补右括号的宽松行为作为安全判定。

## 5. 兼容性说明

- 现有按钮输入、历史、设置、绘图与求值 API 不变。
- 新入口失败时退化为现有手工输入。
- 默认不新增持久化 Schema；离开会话释放图像与候选。
- API 12 兼容性已在上游最小编译探针/HAP build 中核验；架构不允许以云端服务作为静默回退。真实设备能力与质量门禁不改变架构，仅作为 Tester 验证风险跟踪。

## 6. 迁移方案

本文档不涉及数据迁移。模块迁移仅为从 CalculatorPage 抽出新增识别逻辑；回滚时移除入口、权限声明与新增识别模块即可，既有数据不受影响。

## 7. 附录

| 术语 | 定义 |
|------|------|
| OCR | Optical Character Recognition，图像文字识别 |
| Provider | 对端侧 OCR 实现和测试替身的抽象接口 |
| Candidate | 尚未确认、可能可编辑的识别候选文本 |
