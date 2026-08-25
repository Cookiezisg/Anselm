# EDGE-226 受管档视频路由

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge226-managed-video-route`

## 目标

只有受管 key 时，`generate_video` 仍必须是可用能力：路由选择使用 install id、模型名
留给网关，不因没有桌面侧 model 而误判缺席；实际 submit/poll/fetch 路径要带受管 install
身份并能形成附件 receipt。图生视频则只能在网关明确广告 `image_to_video` 时出现。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/app/tool/generate ./internal/infra/llm \
  -run 'Test(Video_ManagedTierRoutesVideo|Video_ImpossibleLengthIsClampedOnWireAndReceipt|SubmitVideoAnselm_TextRouteOmitsFirstFrame|SubmitVideoAnselm_UsesAnimationRouteForFirstFrame)$' \
  -count=1 -race -v
```

结果：4 个测试均 `PASS`。

- `TestVideo_ManagedTierRoutesVideo` 验证只有 managed key 时 video/image/speech 能力存在，
  video route 为 `anselm`、install id 存在、model/key 不向桌面侧冒充，并验证 image-to-video
  只有显式 capability 才出现。
- `TestVideo_ImpossibleLengthIsClampedOnWireAndReceipt` 走本地 TLS 网关的完整生成路径，
  同时断言请求带 `X-Anselm-Install-ID`、submit/poll/fetch 成功并生成 receipt。
- 两个 infra 测试锁住 text-to-video 与 image-to-video 的不同 endpoint 和 payload 形状。

本格仍未调用真实网关，不消耗真实生成额度。

## 未声称的等级

本格本轮没有启动真实 App、真实受管视频、Computer Use 录屏、独立 SSE witness、frontend
console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、L5（可发现性）
均明确为 `na`。
