# EDGE-222 生成 origin 从凭证派生

- 日期：2026-08-26
- 判定：L1 `pass`；L2-L5 `na`
- 法条：`measure:edge222-llm-generation-origin`

## 目标

验证 DashScope/Qwen 的图片、语音、视频生成路由不把生成 origin 硬编码到北京，
而是从用户凭证的聊天 base URL 去掉 `/compatible-mode/v1` 后派生。这样新加坡或
workspace 域凭证不会被送往错误区域并得到误导性的 401。

## 可复核命令与结果

```text
cd backend
mise exec -- go test ./internal/app/tool/generate ./internal/infra/llm \
  -run 'Test(DashScopeNative_PreservesTheUsersRegion|QwenBuildRequest_UsesConfiguredRegionalWorkspaceEndpoint)$' \
  -count=1 -race -v
```

结果：两个测试均 `PASS`。

`TestDashScopeNative_PreservesTheUsersRegion` 覆盖 Singapore、Beijing、per-workspace、
trailing slash、代理路径和空 base fallback，并检查 image/speech/video 三张 Qwen
生成表都使用派生函数；`TestQwenBuildRequest_UsesConfiguredRegionalWorkspaceEndpoint`
确认实际兼容模式请求保留 workspace 区域 endpoint。

## 代码交叉证据

- `backend/internal/app/tool/generate/generate.go` 的 `dashScopeNative` 只剥离兼容路径，
  不猜测区域；空 base 回退国际域。
- 同文件的 image、speech、video provider 表均为 Qwen 配置 `nativeFrom: dashScopeNative`，
  没有硬编码北京生成 origin。
- `backend/internal/infra/llm/qwen.go` 的兼容请求使用传入的 `BaseURL`。

## 未声称的等级

本格本轮没有启动真实 App、真实生成调用、Computer Use 录屏、独立 SSE witness、
frontend console 或 LLM wire session，因此 L2（五通道真相）、L3（顺滑）、L4（craft）、
L5（可发现性）均明确为 `na`，不能由本地 Go 测试替代。
