# EDGE-350 语音帧越界

- 判定对象：超限音频帧与非法控制帧。
- 证据：`TestValidSpeechControl_AllowsKnownControlsOnly` 及 speech handler 定向包测试通过；协议解码拒绝未知控制形状，未把坏帧送入上游。
- 产品判断：协议错误被挡在边界，错误保持可解释，连接不会因脏控制帧进入不可见半状态。
- 法条：E1。

