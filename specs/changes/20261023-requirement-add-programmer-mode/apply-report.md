# 应用报告

## 应用信息
- 变更类型：新增功能（new_requirement）
- 变更名称：程序员模式与 BIN/OCT/DEC/HEX 转换
- 关联 Issue：#45
- 关联全局文件：`specs/spec.md` / `specs/arch.md` / `specs/design.md`
- 应用日期：2026-10-23

## 前置制品核验
- Planning：proposal、delta-spec、info、new-arch、FMEA、delta-design、design-review、todo 均存在且非空；设计审视结论为“通过”。
- Implementing：`tasks.md` 存在且包含 7 个有序任务，无模板占位；IMPLEMENTING checkpoint 为 completed。
- 阶段边界：本报告仅完成 APPLYING；未执行 ARCHIVING 或审批。

## 代码完成情况
| 任务 | 状态 | 完成时间 |
|------|------|----------|
| Task 1.1 领域契约与典型值转换 | ✅ 完成 | 2026-10-23 |
| Task 1.2 U64 边界、错误分类与精确算法 | ✅ 完成 | 2026-10-23 |
| Task 2.1 不可变状态操作 | ✅ 完成 | 2026-10-23 |
| Task 3.1 模式状态、双向切换与普通状态隔离 | ✅ 完成 | 2026-10-23 |
| Task 3.2 四进制结果、进制选择与内联反馈 | ✅ 完成 | 2026-10-23 |
| Task 3.3 受限键盘、180ms 动画与响应式布局 | ✅ 完成 | 2026-10-23 |
| Task 4.1 测试聚合、构建、回归与交接 | ✅ 完成 | 2026-10-23 |

## TDD 执行记录
| 任务 | RED | GREEN | REFACTOR |
|------|-----|-------|----------|
| Task 1.1 | ✅ 模型/转换器缺失导致编译失败 | ✅ 典型值与字符矩阵通过 | ✅ 纯业务边界与字符串算法整理后保持绿色 |
| Task 1.2 | ✅ 超长 BIN 未被拒绝 | ✅ U64 边界/错误 5 项通过 | ✅ 最大输入长度集中化后保持绿色 |
| Task 2.1 | ✅ 原子状态 API 缺失导致编译失败 | ✅ 状态操作 4 项通过 | ✅ 完整新对象返回与失败原子性整理后保持绿色 |
| Task 3.1 | ✅ 模式选择契约缺失 | ✅ 模式契约 2 项通过，HAP 构建通过 | ✅ 页面只编排同步状态，普通状态未接入清理回调 |
| Task 3.2 | ✅ 展示映射契约缺失 | ✅ 展示契约 2 项通过，HAP 构建通过 | ✅ 结果/反馈集中映射并由 Builder 消费 |
| Task 3.3 | ✅ 键盘共源启停契约缺失 | ✅ 键盘契约 2 项通过，HAP 构建通过 | ✅ handler 整体替换状态，横屏 2:3/竖屏堆叠 |
| Task 4.1 | ✅ 不支持的 radix 未返回 INTERNAL | ✅ 回归门禁 2 项通过 | ✅ 统一支持进制校验后全量 71/71 绿色 |

## 测试结果
- 单元测试：通过，71/71，Failure 0，Error 0。
- 产品构建：通过，`assembleHap` 输出 `BUILD SUCCESSFUL`。
- Lint 检查：通过，DevEco CodeLinter 退出码 0，0 error；127 个 warn 为项目既有风格规则与非阻塞建议的汇总，未发现阻塞错误。
- 集成/设备：CLI 构建与测试完成；检测到模拟器 `127.0.0.1:5555`，但当前产物为 unsigned HAP，动画无闪烁、触控尺寸与 phone/tablet 横竖屏视觉证据明确交 Tester，不在 Developer 阶段虚构结论。

## 测试详情
### 全量 Local Test
- 命令：`hvigorw test -p module=entry -p coverage=false`
- 聚合入口：既有 `PlotFunction.test.ets` + 新增 `ProgrammerConverter.test.ets`
- 覆盖：典型转换、合法字符矩阵、U64 边界、非法/空/超长输入、失败原子性、退格/清空、进制切换、模式契约、展示契约、键盘契约和回归门禁。
- 结果日志：`logs/test-final.txt`、`logs/test-result-final.txt`

### 产品构建
- 命令：`opencalc/build-test.bat`（DevEco hvigor `assembleHap`）
- 结果：`BUILD SUCCESSFUL`
- 结果日志：`logs/build-final.txt`
- 说明：构建仍报告仓库基线已有的 deprecated/exception-handling 警告和缺少 signingConfig 警告；无新增编译错误。

### Lint 检查
- 命令：DevEco Studio CodeLinter，recommended TypeScript、stylistic、performance、security、correctness、cross-device 与 compatibility 规则集，`--exit-on error`。
- 结果：退出码 0；0 error，127 warn。
- 结果日志：`logs/codelinter-result.json`

## 代码变更摘要
- 新增程序员模式领域类型和 U64 精确字符串转换器，不经浮点 `number` 中转完整数值。
- 新增 append/backspace/clear/changeRadix 原子状态操作及结构化 EMPTY/INVALID_DIGIT/OUT_OF_RANGE/INTERNAL 反馈。
- 在主页面新增普通/程序员模式入口、四进制结果、进制选择、受限 4×4 数字键盘、AC/退格、180ms opacity + 4vp 过渡和横竖屏布局。
- 保持普通表达式、结果、历史、科学模式、主题、角度和绘图状态独立；不新增 Preferences key、路由、权限或依赖。

## 问题与解决
- 初次 Local Test 因声明但未安装的 `@ohos/hypium` 无法解析；执行 `ohpm install --all` 后测试环境恢复，未修改依赖清单。
- Hvigor Local Test 在 Hypium 断言失败时可能仍返回进程码 0；每次验证同时读取 `test_result.txt`，最终确认 71/71。
- DevEco CodeLinter 对既有大文件报告风格警告；门禁采用 error 级别并确认 0 error，完整警告保留在 JSON 日志供后续专项治理。

## Tester 验收重点
1. 普通 ↔ 程序员双向及 180ms 内快速切换，确认最终选择生效、无明显闪烁/空白帧/点击穿透。
2. DEC `10` 与 HEX `FF` 的四行结果；BIN 下 `2-9/A-F` 禁用且无法提交。
3. U64 最大值、越界、空态、非法字符和错误恢复。
4. 普通 expression/result/history/scientific/radianMode/theme/绘图入口往返后保持。
5. phone/tablet 横竖屏下模式入口、反馈、AC/退格、64 位 BIN 行的可见性和触控尺寸。

## 下一步
APPLYING 已完成。本次按指令不执行归档或审批；后续仅在独立阶段闸门明确授权后进入 ARCHIVING。
