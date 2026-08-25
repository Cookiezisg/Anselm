# EDGE-194 attachment media envelope exhaustion

- 结论：`pass`（L1 focused local and remote-envelope regressions）；L2-L5 按当前独立台架边界记 `na`。
- 目标：单回合媒体超出 `MaxMediaParts` 或 `MaxMediaBytes` 时，已适配的媒体仍保持原生输入，超额项
  按附件顺序变为解释性文字占位；远端 managed staging 也必须在最终字节预算处降级，不能让整轮失败。

## focused local envelope regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \\
  -run '^TestToContentParts_(MediaEnvelopeDegradesWithoutDroppingOrder|RemoteMediaObeysTheEnvelope)$' \\
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.945s
```

两张图片配置 `MaxMediaParts=1` 时，第一张仍为 native image part，第二张为包含文件名和
`item limit` 的文本占位，顺序不变；远端 uploader 场景验证的是最终 staging 字节预算，超额时不建
lease、不返回 provider fetch URL，也不丢掉整轮。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中用受管网关完成媒体额度耗尽的五通道 App 录制
L3 na: 没有本格独立的多附件等待、逐件降级提示和预算反馈 Computer Use 时序测量
L4 na: 没有本格独立的原生媒体卡片与超额占位顺序/文案视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解媒体额度及分批发送建议的 discoverability session
```
