# EDGE-345 音色登记到指名说话全链

- 判定对象：参考音色登记后，合成请求使用本地名称解析出的上游句柄。
- 证据：`backend/internal/app/voice` 定向测试通过；`TestLiveVoice_EnrollSpeakDelete` 与 `TestLiveMedia_EnrollVoice` 已存在并要求真实网关时显式 opt-in，未在本轮无授权环境冒充运行。
- 产品判断：本地音色行保存上游 ID，合成按名称解析，不把用户可见名称误当 provider ID；真实网关五通道重跑仍是后续 L2 待办。
- 法条：F1。

