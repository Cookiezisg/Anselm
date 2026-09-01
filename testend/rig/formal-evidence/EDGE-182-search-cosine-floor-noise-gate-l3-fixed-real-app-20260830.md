# EDGE-182 cosineFloor 噪声闸：L3 修复后真实 App 时序

- 结论：`pass`。
- session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-222330`；录屏=`screen.mov`，时长=`209.861667s`；稳定抽帧=`frames-edge182/stable-001.png`至`stable-060.png`。

修复后的真实 App 先完成自然乱码检索，再完成语义召回；无关查询没有出现错误结果后再撤回的闪烁，语义结果也没有在候选切换时造成内容跳变。稳定尾段逐帧保持同一结果布局，Composer、侧栏和正文收口后无 loading 残留；backend、三路 SSE、LLM wire 与前端记录属于同一 session。这里不把模型多轮搜索耗时包装成低延迟承诺，只判断本格要求的错误结果抑制、结果收尾和持续稳定性。

判定依据：`CODEX B2`。
