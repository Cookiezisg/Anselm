# EDGE-312 版本组走 retryOf：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-092651`
- data: `/private/tmp/anselm-data-edge312-20260828-r1`
- workspace: `ws_46e90cfad6788e9a`
- conversation: `cv_edge312_retryof`
- recording: `screen.mov`, `91.045000s`, 60fps
- stable frames: `evidence/EDGE-312-l3-current-stable.png`, `EDGE-312-l3-middle-stable.png`, `EDGE-312-l3-return-stable.png`, `EDGE-312-l3-late-stable.png`
- L2 foundation: `testend/rig/formal-evidence/EDGE-312-retry-version-groups-real-app-20260828.md`

## Product path

1. 在真实 App 的 Recents 打开包含三个 assistant 版本的 retryOf 线程，默认显示当前版本 `3/3`。
2. 用户依次点击 `Previous version`，查看 `2/3` 和 `1/3`；每个旧版只占一个视觉回合，并显示“后续基于第 3 版”的关系提示。
3. 用户点击 `Next version` 返回 `3/3`；当前版本恢复，旧版关系提示消失，线程没有变成重复的三轮对话。

## Frame review and measurement

对同一份真实录屏抽取 1fps 样本，并使用
`(cd testend && go run ./cmd/measure diff ...)`，通道容差为 8、阈值为 `0.0005`：

- 会话首次打开阶段的 `000001→000003` 是页面初始化，不作为版本切换质量结论。
- 版本打开和用户点击版本箭头对应的窗口替换产生了可预期的局部/整窗变化：`000033→000034` 为 `changedFrac=0.03972`，`000034→000035` 为 `0.00395`；这些发生在用户主动打开/切换版本的动作窗口内。
- 后续可见切换收尾分别为 `000044→000045`=`0.00088`、`000059→000060`=`0.00117`、`000064→000065`=`0.00117`、`000074→000075`=`0.00097`，均对应版本导航或其可见交互反馈，不是静止期自发重排。
- 每个切换后的稳定段均无持续变化；从 `000075` 到录屏末尾的稳定样本没有超过 `0.0005` 的连续变化输出。固定帧显示 `3/3`、`2/3`、`1/3` 和回到 `3/3` 的内容均单一、可读、无重复容器。

## Five-channel cross-check

- **frames / Computer Use**: 原 L2 关键帧覆盖当前、中间、最旧和恢复当前四种状态；新增四张稳定帧确认每次版本切换收敛后没有自动回跳或二次重建。
- **backend**: backend journal 共 `157` 行；真实历史读取和版本导航完成，没有 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: ssetap 连接 `messages`、`entities`、`notifications` 三条流并正常 EOF 收台；这是 durable 历史读取，不伪造消息事件或 completion。
- **frontend**: frontend journal 共 `4` 行，仅有 Dart VM 启动和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主提示；没有 Flutter、RenderFlex、RenderBox、Unhandled 或应用级异常。
- **LLM wire**: llmtap 在同一 rig session 中 ready；本格不触发 LLM，`llm.jsonl` 保留 ready 作为在线证据，不虚构模型请求。
- **durable truth**: L2 证据中的 retryOf 和 `superseded_by` 链与 REST/SQLite 对齐；版本导航只改变当前读取窗口，没有写入新的对话回合。
- **rig lifecycle**: `rig-check`/`rig-down` 通过，录屏可读，App、backend、ssetap、llmtap 收台后无残留进程。

## Judgment

- **L3 `pass (B2)`**: 版本导航的用户触发变化与静止期分离；每次切换在落定后保持稳定，当前/旧版关系提示和单回合呈现没有自动抖动、重复或回跳。
- 本证据只覆盖版本组导航的稳定性，不把版本关系文案的视觉 craft 或用户盲走可发现性冒充 L4/L5。
