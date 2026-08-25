# SURF-100 · i18n/appName · 正式调查记录

## 受验对象

`SURF-100 i18n/appName`：产品名 wordmark 的 locale 来源、窗口标题/通知/无障碍等调用面，以及首次启动 onboarding 的真实视觉表现。

## 静态审查

`appName` 在英文和中文翻译中均为 `Anselm`。主要调用面包括窗口标题、workspace onboarding wordmark、launch-at-login、系统通知标题和窗口控制无障碍语义。onboarding 的 `toUpperCase()` 是明确的品牌排版选择，因此显示 `ANSELM` 不构成翻译不一致。

本格新增 locale 回归：`frontend/test/core/settings/locale_boot_test.dart` 断言 `AppLocale.en` 与 `AppLocale.zhCn` 的 `translations.appName` 都精确等于 `Anselm`。focused Flutter test 12 项全部通过。

## 真实 App 观察

台架以全新数据目录启动真实 App。onboarding 关键帧
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-071353/evidence/frames/SURF-100-app-name-onboarding.png`
显示右上角 `ANSELM`，字标与图形标记在同一水平带内，未见截断、重叠、异常跳位或语言混入。完成工作区创建后，关键帧
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-071353/evidence/frames/SURF-100-app-name-final.png`
显示中文 Chat；产品名没有被错误翻译，工作区名称作为独立用户数据显示在左下角。

## 五通道交叉核验

正式 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-071353`：screen `75.223333s`，backend `136` 行，frontend `4` 行，SSE `8` 行，LLM `10` 行。三条 SSE 均连接成功；由于本路径只验证启动、品牌和 onboarding，不产生业务实体，SSE 没有 durable business frame，这是路径性质而非漏记。backend 无应用红线，frontend 唯一 error 为已披露的 macOS IMK 平台噪声，LLM managed proof/install/models 均成功。

`rig-check.sh` 与 `rig-down.sh` 均通过，录制正常结束且无残留进程。所有事实均可从 session journal、关键帧、源代码和 focused test 复取。

## 产品裁决

没有 stop-and-fix 项。品牌词在 locale 层稳定，真实 onboarding 的 uppercase wordmark 是有意且视觉上干净的呈现，workspace 创建后的落点清楚。L2 仅把三路 SSE 的连接事实记入，不把无 durable frame 的确定性路径误写成业务流成功。
