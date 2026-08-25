# SURF-101 · i18n/markdown · 正式调查记录

## 受验对象

`SURF-101 i18n/markdown`：markdown 图片引用无法加载时的本地化提示，以及长 URL
在真实 Chat transcript 中的可读性和布局稳定性。

## 静态审查

`imageNotLoaded` 在英文 locale 中为 `image not loaded`，在中文 locale 中为
`图片未加载`；生成文件与源文件一致。`AnMarkdown` 的 `ImageMd` 统一接入
`_imagePlaceholder`，不创建网络图片 widget。占位芯片将翻译文案、图片图标和 URL
放入固定单行容器，超长 URL 只做 ellipsis。现有 markdown widget test 锁住无网络
`Image`，新增 locale test 锁住两种语言的精确值；focused suite 通过。

## 真实产品观察

formal session：
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-072409`

真实 App 完成 onboarding 后，使用真实 backend 和 managed gateway 创建两条独立对话，
分别验证短 URL 和 298 字符长 URL。Computer Use 直接输入 markdown 的第一次尝试因
输入层转义损坏 `![...]`、冒号和斜杠，产生 malformed URL；该会话明确排除，不计为
产品绿证据。随后用 REST 只负责把精确 markdown 写入真实 durable conversation，再在
真实 App 打开对话并由 Flutter markdown renderer 渲染，避免把 harness 的字符注入问题
冒充产品行为。

最终中文画面和 AX 树都显示 `图片未加载`；短 URL 正常落在占位芯片内，长 URL 在同一
芯片中省略，联系表覆盖约 218--223 秒连续帧，没有持续跳变、溢出、遮挡或历史内容
重排。完整 URL 仍可由 AX 树读取。

## 五通道事实

- Screen：225.711667 秒；窗口录制正常收台。
- Backend：347 行；无应用 WARN/ERROR/panic/fatal/exception。
- SSE：三条流各一次 connect/一次 disconnect；messages durable `1..24`、
  notifications durable `1..4`，无 gap；delta 为 `seq=0`，entities 无业务 durable 帧。
- LLM：managed proof/install/models 和四次 chat completion 观察均为 HTTP 200；带状态
  的 LLM journal 共 14 条，全部 200。
- Frontend：只有已知 macOS IMK 平台桥接噪声，没有 Flutter/Dart/布局/Unhandled 红线。
- `rig-check.sh`、`rig-down.sh` 通过，无残留进程。

## 结论

没有产品 stop-and-fix。此格通过的判定是：文案来自 locale、降级语义诚实、图片 URL
不触发隐式网络取图、长 URL 不破坏版面，且真实 App、SSE、backend journal、LLM wire
和 frontend console 相互一致。
