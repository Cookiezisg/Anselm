# EDGE-199 attachment proxy not ready

- 结论：`pass`（L1 bounded preparation and fallback）；L2-L5 按当前独立台架边界记 `na`。
- 目标：用户上传大图后，model-default proxy 若尚未 ready，聊天最多等待一个有界窗口，之后诚实退回原图；
  worker 继续后台追上，不能把本回合卡死，也不能把未 ready 错误当成整轮失败。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/media \
  -run '^TestModelDefaultImage_(ReturnsReadyArtifactOrSchedulesWork|WaitsForStartedWorker|FallsBackAfterBoundedWaitWhileWorkerCatchesUp)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/media 3.597s

cd backend && mise exec -- go test ./internal/app/attachment \
  -run '^TestToContentParts_ManagedImageStagesModelDefaultProxyWhenReady$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.636s
```

`TestModelDefaultImage_FallsBackAfterBoundedWaitWhileWorkerCatchesUp` 刻意阻塞 image worker：调用在约
2 秒 `modelDefaultImageWait` 后返回 `ready=false`、无数据/无错误；解除阻塞后同一后台 worker 仍把 durable
derivative 处理到 ready。另有 ready-path 回归证明 proxy ready 时会正常进入 managed staging，而不是总退回
原图。这个边界把“准备慢”与“staging 失败”区分开：前者可用原图继续，后者必须按 EDGE-198 大声失败。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中用真实大图、Computer Use 和五通道观察准备等待与回退
L3 na: 没有本格独立的上传后首帧、2 秒等待、原图回退和后台 ready 时序测量
L4 na: 没有本格独立的准备状态、回退提示、原图/代理媒体卡片视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解代理准备中仍可继续发送以及后台追上的 discoverability session
```
