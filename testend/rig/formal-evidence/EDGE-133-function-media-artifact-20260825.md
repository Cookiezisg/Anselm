# EDGE-133 function 媒体产物声明

- 结论：`pass`（L1 function 媒体声明的真实 HTTP 产物路径）；L2-L5 按当前台架边界记 `na`。
- 预期：function 写入 `ANSELM_OUT/chart.png` 并返回 `{"chart":{"$media":"chart.png"}}` 后，声明在 `chart` 原键就地替换成可下载的 MediaRef receipt；receipt 标记 `source=function_artifact`，同级普通字段不丢失，附件内容来自该次运行而不是共享或伪造的结果。

## 证据

focused collector regression：

```text
cd backend && mise exec -- go test ./internal/app/mediaartifact -run '^TestCollectArtifacts_ReplacesInPlace$' -count=1 -race -v
=== RUN   TestCollectArtifacts_ReplacesInPlace
--- PASS: TestCollectArtifacts_ReplacesInPlace (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/mediaartifact 1.579s
```

该回归使用真实 1×1 PNG 内容，断言 `chart` 自身变为 receipt、`source` 为 `function_artifact`、嗅探 MIME 为 `image/png`，并确认同级 `n` 字段和单次上传均保持正确。

真实 function HTTP path：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestFunction_ArtifactProduct$' -count=1 -v
--- PASS: TestFunction_ArtifactProduct (6.02s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 6.834s
```

真实场景创建 function，函数在每次 sandbox run 中写入带不同尾字节的 PNG 产物并返回 `$media` 声明；HTTP `:run` 两次均成功，原 `chart` 键返回 `attachmentId`、`image/png` 和 `function_artifact`，随后通过附件 content endpoint 下载并核对完整字节。两次不同产物得到不同附件 ID，证明不是复用静态 receipt。

## 判定边界

L2-L5 暂记 `na`：真实 function、sandbox、附件落库、receipt 下载和内容一致性已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
