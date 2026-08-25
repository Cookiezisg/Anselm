# EDGE-207 · 账本警报复审

本格写入时触发 `gap-too-fast` 与 `pass-burst`，近期无 fail 又触发 `discovery-collapse`。复审核对了后端单测、Flutter 两项真实 widget 守卫以及 L2-L5 明确 `na` 的边界；快速写账来自小格的本地验证，不代表省略了产品 session，也不改变警报算法。

未修改阈值、法典或锚点。后续真实 App session 仍必须重新提供五通道和逐帧证据；三项警报按本记录销账。
