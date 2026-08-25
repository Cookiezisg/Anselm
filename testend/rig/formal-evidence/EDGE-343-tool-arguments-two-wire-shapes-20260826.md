# EDGE-343 工具参数双线缆形

- 判定对象：provider 返回原生 object 与 JSON-stringified object 的工具参数。
- 证据：`mise exec -- go test -count=1 ./internal/app/tool ./internal/app/loop` 通过；其中 `TestObjectMapAcceptsNativeAndStringifiedObject`、`TestNormalizeToolCallArgumentsUpdatesDurableToolBlock` 通过。
- 产品判断：两种上游线缆都被归一化为同一参数对象；数组、标量和坏 JSON 仍拒绝，不用模型重试掩盖协议错误。
- 法条：H2。

