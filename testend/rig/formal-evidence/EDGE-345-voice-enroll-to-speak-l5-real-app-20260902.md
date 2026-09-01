# EDGE-345 | 音色登记→指名说话全链 | L5 真实 App 可发现性证据

## 判定

L5 通过，法典 `G1`：入口、命名和 affordance 使新用户不读文档也能完成旅程。

## 盲走路径

在全新隔离 workspace 的真实 App 中，不打开项目文档、不预先调用 API，也不向用户展示工具名或内部 ID，Computer Use 完成：

1. 从 onboarding 创建 workspace 后进入默认 Chat 和 New chat。
2. 通过 Composer 的附件入口选择一个 WAV 文件；附件卡显示文件名、格式、大小和播放 affordance，用户知道文件已进入当前消息。
3. 以用户目标表达“将上传的音频登记为一个具名克隆音色，并用它读出一句话”。模型完成登记后继续用同名音色朗读，用户从聊天中的工具状态、最终文本和音频附件知道目的已完成。
4. 打开 Settings → Models & keys，在 `Cloned voices` 区域看到具名音色和库存计数；hover 后出现 Delete affordance，点击后确认层用明确对象名和不可退款说明保护破坏性动作。
5. 删除后空态明确告诉用户“Ask the assistant to enroll one from an audio attachment”，既说明如何再次完成任务，也没有把内部 API 名称当作入口。

整个路径不依赖额外文档、隐藏 URL 或开发者知识；Chat 的附件入口、空态说明、具名结果和设置页分区共同构成可发现路径。

## 五通道与边界

- 真实 App、窗口录屏、backend journal、三路 SSE、frontend console 和 managed LLM wire 均来自同一封存 session：
  `/private/tmp/anselm-rig-formal-20260902-17/sessions/20260902-040120/`。
- 录屏确认关键 affordance 在真实窗口中出现且没有遮挡、溢出或布局跳变；SSE/LLM/REST 对证据确认登记、合成、删除和最终空态的事实一致。
- 该判定针对用户可完成的音色旅程，不把模型选择了正确工具本身当作发现性；发现性证据是用户可见的附件入口、完成反馈、Settings 分区、hover 操作和空态下一步。
