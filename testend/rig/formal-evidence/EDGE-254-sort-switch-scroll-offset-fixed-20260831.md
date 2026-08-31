# EDGE-254 · keyset 排序切换 · 修复后的真实 App 证据

正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-200325`。

真实工作区创建 60 条 `Sort Probe` 对话后，Computer Use 在 App 中完成 Name 排序、滚动到中段、切回 Recently active。修复后 AX 和截图首项均为 `Sort Probe 60`，后续按 59、58 递减；65.33 秒录屏以 4 秒抽帧复核，没有空白帧、旧中段闪回或二次跳回。完整五通道证据、fixture、REST 顺序与 focused regression 见 session 内 `evidence/EDGE-254-real-app-fixed.md`。

实现位于共享 `AnSidebarList`：宿主通过 `scrollResetKey` 表示查询轴替换，在新 sliver 布局前归零；普通 SSE/model 更新不重置。对话 rail 将 sort/archive 作为该 key，输入过滤也回到头部。红现场保留在 `EDGE-254-sort-switch-scroll-offset-red-20260831.md`，未被覆盖。

正式台架检查：backend 无 WARN/ERROR，SSE 三路已连接，LLM 探针正常，Flutter 日志只有 macOS IMK 系统噪声，无应用级异常；完整 conversation rail widget suite 21 tests 通过。
