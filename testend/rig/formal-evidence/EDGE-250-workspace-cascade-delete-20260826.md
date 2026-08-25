# EDGE-250 · workspace 删除级联

## L1 focused evidence

- `testend/scenarios/platform_test.go:TestPlatform_WorkspaceCascadeDelete` 真实 HTTP 通过：删除 doomed workspace 后 workspace、function、conversation 读侧均按隔离语义消失，keeper workspace 存活。
- `backend/internal/app/workspace` delete guards 通过，最后一个 workspace 的保护也通过。
- 测试中关闭 loopback gateway 的 provision WARN 与 shutdown context-canceled 日志均是该测试故意的离线/收台尾声，不作为产品错误证据；场景 exit 0。

## 判定

L1=`F5`：删除是 workspace 边界内的级联清理，不污染其他 workspace。L2-L5 本轮未建立真实 App 五通道删除 session，记 `na`。
