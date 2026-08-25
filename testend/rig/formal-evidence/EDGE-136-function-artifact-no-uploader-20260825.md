# EDGE-136 无 uploader 时的产物声明

- 结论：`pass`（L1 未接线装配的 function 媒体声明透传）；L2-L5 按当前台架边界记 `na`。
- 预期：在 test/REST-only 装配中没有 `ArtifactUploader` 时，`$media` 声明原样通过，不创建 output 目录、不铸造附件，也不引入新的失败或日志噪声。

## 证据

focused collector regression：

```text
cd backend && mise exec -- go test ./internal/app/mediaartifact -run '^TestCollectArtifacts_NoUploaderPassesThrough$' -count=1 -race -v
=== RUN   TestCollectArtifacts_NoUploaderPassesThrough
--- PASS: TestCollectArtifacts_NoUploaderPassesThrough (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/mediaartifact 1.531s
```

测试传入一个调用前不存在的 output 路径和 `nil` uploader，断言返回结果仍保留原 `$media` 声明、notes 为空，且调用后 output 路径依旧不存在；因此没有隐式建目录或失败副作用。

## 判定边界

该项刻意验证未接线装配，不存在可供真实 HTTP 端到端下载的 uploader。L2-L5 暂记 `na`：已核验 focused 装配行为，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
