# EDGE-256 · 驻地目录被移走 · 修复后的真实 App 证据

正式 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-201616`，真实
workspace=`ws_74bc3124d5dc41b9`，对话=`cv_22750cfee57c0e4d`。通过真实 backend 创建对话并
挂载临时目录后，在 App 外将该目录移走，随后用 Computer Use 打开驻地菜单。

修复后的产品状态符合契约：保存的原始 path 仍可见，按钮没有退回未挂态；菜单明确显示
`This directory no longer exists`，`Reveal in Finder` / `Open in Terminal` 被禁用，仍保留
`Switch working directory…` / `Leave working directory`。backend 在移走后重新读取 workdir
投影返回 200，`exists=false` 的状态由 UI 与 AX 同时呈现。

录屏=`screen.mov`，3104x1844/60fps/94.913333s；关键帧=`frame-menu.png`，抽帧复核=`contact-edge256.png`。
菜单打开前后无空白、未挂图标闪回、旧状态闪回或二次跳回；按钮、标题、输入框保持固定几何。
完整五通道、manifest、日志与测试见 session 内
`evidence/EDGE-256-moved-workdir-real-app.md`。backend 无应用级 WARN/ERROR/panic，frontend
仅有已分类 macOS IMK 宿主诊断，三路 SSE 与 managed LLM bootstrap 均正常收台。

红/旧证据=`testend/rig/formal-evidence/EDGE-256-moved-workdir-20260826.md`，其中只有
L1 focused evidence，未覆盖本次真实 App 五通道现场。
