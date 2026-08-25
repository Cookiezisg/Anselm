# EDGE-135 产物四道闸逐件失败

- 结论：`pass`（L1 function 媒体产物逐件拒绝）；L2-L5 按当前台架边界记 `na`。
- 预期：同一次 function 运行声明一个 40 MiB 图片和一个伪装成 `.png` 的 shell script 时，坏产物各自被拒绝并写入 logs，声明原样保留；正常图片和普通结果继续成功，不因一个坏产物整次失败。

## 证据

focused collector regression：

```text
cd backend && mise exec -- go test ./internal/app/mediaartifact -run '^TestCollectArtifacts_RejectsBadArtifactsIndividually$' -count=1 -race -v
=== RUN   TestCollectArtifacts_RejectsBadArtifactsIndividually
--- PASS: TestCollectArtifacts_RejectsBadArtifactsIndividually (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/mediaartifact 1.557s
```

组合回归在同一个结果里放入真实 1×1 PNG、超过 32 MiB cap 的 sparse 40 MiB 文件和 shell script 内容的 `.png`。断言只有正常图片上传，两个坏声明分别保留，普通 `total` 字段不丢，logs 同时含 size cap 和不可渲染 MIME 的解释。

真实 function HTTP path：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestFunction_ArtifactBadFilesArePerItem$' -count=1 -v
--- PASS: TestFunction_ArtifactBadFilesArePerItem (4.51s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 5.122s
```

真实场景让 function 在 sandbox 中写入正常 PNG、40 MiB `huge.png` 与 shell `fake.png`，HTTP `:run` 返回成功；正常产物返回 `function_artifact` receipt 且下载字节匹配，两个坏声明仍是 `$media`，logs 各有拒绝理由，普通 `total=7` 保留，收台时 sandbox handles 为 0。

## 判定边界

L2-L5 暂记 `na`：focused 组合回归与真实 function HTTP 证据已核验，但没有该等级独立 Computer Use 逐帧、测量、视觉和 discoverability 证据；不越级登记。
