# EDGE-209 · 账本警报复审

本格五个裁决快速写入触发 `gap-too-fast` 和 `pass-burst`，近期无 fail 触发 `discovery-collapse`。复审核对了附件软删、显式 GC、共享 blob 保留三条真实断言，并确认 L2-L5 是明确 `na`，不是被快速写入的伪绿。

未修改警报阈值、算法、法典或锚点；三项警报按本记录销账。
