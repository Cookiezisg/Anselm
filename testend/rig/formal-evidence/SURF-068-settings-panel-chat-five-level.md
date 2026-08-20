# SURF-068 · settings/panel-chat

## 判定

`pass`。真实 App 中完成 Chat 设置的产品闭环：右岛自动登台、发送键和 Web fetch mode 都可发现、可切换、即时反馈并恢复默认；默认对话模型行真实跳转到 Models & keys，返回 Chat 后设置状态没有丢失。

本轮没有把 Computer Use 的组合键映射误判成产品缺陷：`super+enter` 不是该 Computer Use 驱动支持的 key 名，`super+Return` 未触发发送；产品本身的 Cmd+Enter 语义由 Flutter 定向测试锁定，真实 App 则通过发送按钮完成了同一聊天闭环。真实工具活动使用了 `Glob`，它按产品定义不属于右岛 stage-worthy 工具集合；因此没有把“不自动展开右岛”误记为缺陷。工具调用被用户停止后，UI、后端和 SSE 均正确落为 cancelled。

相邻观察：模型把“当前工作目录”解释为 `~`，并发起了 `Glob("~", "**/README.md")`，递归搜索持续约 53 秒。停止按钮立即给出 `Interrupted`，没有孤儿回合；这是路径/工具意图选择导致的长等待，不属于 Chat 设置行本身，保留为后续工具意图与 workdir 引导审计项。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-221915`
- Data: `/private/tmp/anselm-data-surf068-20260819-r1`
- Workspace: `ws_02acc0a8ce4f704e` (`Acceptance SURF-068`)
- 全新 workspace onboarding 后进入 Settings → Chat；每次 Computer Use 动作后重新读取 App state。
- 初始值为 `First per chat`、`⌘Enter sends`、`Local fetch`。
- 自动登台切换完成 `Never → First per chat`；发送键切换为 `⌘Enter sends`；Web fetch 完成 `Local fetch → Jina proxy → Local fetch`。
- Web fetch 两次真实 workspace PATCH 均为 `200`，最终 SQLite 行为 `web_fetch_mode=local`。
- 点击 `Default chat model → Models & keys` 真实进入 Models & keys，呈现 `Anselm Free · Auto multimodal`、managed key、Dialogue/Utility/Agent 等 scenario defaults；返回 Chat 后三项设置仍保持预期。
- 真实聊天 `Reply with the single word OK.` 经 managed gateway 完成，UI 从 thinking 收束为 `OK.` 并恢复可输入。
- 第二个真实回合触发 `Glob`，工具卡明确显示路径、匹配结果和 elapsed；点击 Stop 后显示 `Interrupted` / `Stopped`，发送区重新可用。

关键录制：`screen.mov`（`963.813333s`，`2560x1584`，H.264，60fps）。关键状态均包含在连续录制中；Computer Use 临时截图在台架停机后由服务清理，未伪造为持久图片证据。

## 五通道证据

1. **Frame**：`recording-lifecycle.json` 绑定同一 Anselm 窗口；`screen.mov` 覆盖 Chat 设置初态、三项切换、Models & keys 跳转、真实聊天、工具活动和取消收尾。
2. **Backend**：`backend.log`=`1063` 行；无 WARN / ERROR / panic / FATAL。聊天提交、取消、workspace PATCH、workspace readback 均由同一 workspace 记录。
3. **SSE**：`sse.jsonl`=`79` 行；独立 witness 同时连接 `messages`、`entities`、`notifications` 三流；真实聊天和 Glob 的 open/close/tool_result/取消帧均有记录，durable seq 共 24 个且按流的实际连接边界递进，取消最终发出 `status=cancelled`。
4. **Frontend terminal**：`frontend.log`=`5` 行；仅正常启动、Flutter VM、已知 macOS `IMKCFRunLoopWakeUpReliable` 和 CapsLock 宿主噪声，无 Dart / Flutter / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl`=`25` 行；managed proof challenge、chat completions 和模型链路均经过 llmtap，相关响应为 `200`；未把没有发生的 completion 当成证据。

`rig-check` 在 App 仍运行时通过五通道归属检查；随后 `rig-down` 完成收束，录制正常封存，未发现 backend、ssetap、llmtap、App 或 recorder 残留进程。

## 本地验证

- `mise exec -- flutter test test/features/settings/s1_panels_test.dart test/features/settings/settings_demo_fixture_test.dart test/features/settings/settings_shell_test.dart test/features/chat/ui/chat_composer_test.dart test/features/chat/model/stage_director_test.dart test/features/chat/state/sidestage_auto_reveal_test.dart test/features/chat/state/stage_director_provider_test.dart`：通过，`97 tests`。
- 其中包含 `sendKey=cmdEnter: bare Enter is a newline, ⌘Enter sends`、同一 `followModeProvider` 读写、Web fetch PATCH/失败回滚、stage auto-reveal 和手动关闭门禁。
- SQLite 最终核验：`ws_02acc0a8ce4f704e.web_fetch_mode=local`。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 RIG_DATA=/private/tmp/anselm-data-surf068-20260819-r1 RIG_PORT=9081 RIG_LLMTAP_PORT=8788 bash testend/rig/rig-check.sh`：App 运行时通过。

## 法条

- `G1`：Chat 设置位于 Settings → Chat，三项设置有直接人话文案；默认模型行明确写出跳转目标 `Models & keys`。
- `F1`：真实聊天、workspace PATCH/readback、SSE tool lifecycle、取消 API 和最终 SQLite 真相互相吻合。
- `B2`：设置切换、Chat 发送、工具卡从进行中到 `Interrupted` 的收尾均在连续录制中无跳变、无残留 generating 状态。
- `C4`：Web fetch 的隐私/动态页面取舍、发送键规则、右岛三档含义都有邻近解释；停止后的 `Interrupted` 明确说明发生了什么。
- `G1`：Settings → Chat、默认模型跳转行和 Chat 返回路径均可发现；真实活动使用非 stage-worthy 的 Glob，未将设计上的不登台错误归因于 UI。
