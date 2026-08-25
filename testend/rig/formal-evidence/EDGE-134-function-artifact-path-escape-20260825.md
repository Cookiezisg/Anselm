# EDGE-134 产物路径逃逸

- 结论：`pass`（L1 function 媒体产物路径 containment）；L2-L5 按当前台架边界记 `na`。
- 预期：function 声明 `{"$media":"../outside.png"}` 时，`fspath.Inside` 在打开任何路径前 fail-closed；声明原样保留，运行本身不被一个错误声明拖失败，也不产生附件 receipt。

## 证据

focused collector security regression：

```text
cd backend && mise exec -- go test ./internal/app/mediaartifact -run '^TestCollectArtifacts_RefusesPathEscape$' -count=1 -race -v
=== RUN   TestCollectArtifacts_RefusesPathEscape
--- PASS: TestCollectArtifacts_RefusesPathEscape (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/mediaartifact 1.559s
```

focused 测试在 run 目录外放置真实可读的 PNG，声明 `../secret.png`，断言 uploader 零次调用、声明仍在原键、拒绝说明包含 containment 语义；因此不是“外面没有文件”造成的假绿。

真实 function HTTP path：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestFunction_ArtifactPathEscape$' -count=1 -v
--- PASS: TestFunction_ArtifactPathEscape (4.59s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 5.179s
```

真实场景创建 function 并通过 sandbox 返回 `../outside.png` 声明；HTTP `:run` 返回成功，`stolen` 键仍是原 `$media` 声明，没有 `attachmentId`，logs 含 `inside` 拒绝说明，收台时 sandbox handles 为 0。

## 判定边界

L2-L5 暂记 `na`：focused 安全回归与真实 function HTTP 证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
