# EDGE-125 envfix 拒绝丢包修复

- 结论：`pass`（L1 envfix 防假就绪）；L2-L5 按当前台架边界记 `na`。
- 预期：首次安装失败后，utility LLM 若返回比用户原始声明更短的依赖列表，系统必须拒绝该建议；不得再次安装缩减列表，不得产出缺包的绿 env，结果保留原始声明和真实安装错误。

## 证据

focused regression：

```text
cd backend && mise exec -- go test ./internal/app/envfix -run '^TestProvision_RejectsDepDrop$' -count=1 -race -v
=== RUN   TestProvision_RejectsDepDrop
--- PASS: TestProvision_RejectsDepDrop (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/envfix 1.602s
```

测试让第一次安装失败，并让 mock utility LLM 返回空依赖列表。断言确认：结果仍为 `OK=false`，`FinalDeps` 保留用户声明的 `definitely-not-a-real-pkg`，且 sandbox 只被调用一次；被拒绝的缩减依赖没有进入第二次安装，因此不会伪造 ready 环境并把问题推迟成运行时缺包错误。

生产实现位于 `backend/internal/app/envfix/envfix.go`：比较的是 `req.Deps` 的原始声明长度，而不是上一次建议长度；拒绝后返回最后一次真实安装失败记录。

## 判定边界

L2-L5 暂记 `na`：该格已有状态机 focused 证据，但当前台架没有可控的真实 utility model 输出“丢包修复”的产品会话，也没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；不把单测越级冒充这些通道。
