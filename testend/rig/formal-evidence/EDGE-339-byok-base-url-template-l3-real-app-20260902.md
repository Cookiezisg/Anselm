# EDGE-339 · BYOK base URL 模板未填 · real App L3

## 现场

- session=`/private/tmp/anselm-rig-formal-20260902-04/sessions/20260902-004134`
- workspace=`ws_37ac08d0693fb048`
- App 为当前 checkout 构建的真实 macOS Flutter binary，录屏为 `screen.mov`，
  `3104x1848 / 60fps / 46.650000s`。
- 路径：`Settings → Models & keys → Add key → Azure`；使用隔离测试凭证和 Azure
  模板地址，不向 Azure 发送用户数据，也不使用真实 Azure 凭证。

## L3 判定（A1）

将 `https://{resource}.openai.azure.com` 作为用户填写的 Base URL 后执行 `Save & test`。
真实 backend 记录该凭证先 `PATCH 200` 保存，再对 `:test` 返回 `422`；App 在同一表单保留
名称和地址，并显示：

- `The key was saved, but its connectivity probe failed. Check the key or Base URL and try again.`
- `Suspect: a wrong address answers exactly like a wrong key.`
- `An auth failure can also mean the Base URL points somewhere else — check that field before re-copying your key.`

该反馈没有把保存成功伪装成连接成功，也没有清空用户刚填写的地址。60fps 局部测量：action
frame=`150`，首个超过 `0.001` 变化阈值的可见反馈 frame=`152`，`33.3ms`；变化框为
`(1200,523)-(2156,1196)`，位于当前表单区域。

action frame 依据录屏内实际交互序列定位，不宣称 Computer Use RPC 的墙钟耗时。

## 五通道

- 帧：真实窗口连续 `screen.mov`，并以 60fps 提取 `evidence/form-60fps/`。
- backend：`PATCH /api/v1/api-keys/aki_fd8684897935be3a`=`200`，随后
  `POST /api/v1/api-keys/aki_fd8684897935be3a:test`=`422`；probe 记录 `ok=false`。
- SSE：messages/entities/notifications 三流均连接；设置页不产生业务 durable 帧，收台时正常 EOF。
- frontend：无 Dart/Flutter/RenderFlex/overflow/Unhandled/Exception 红线。
- LLM wire：受管 challenge/quota 请求均 `200`；本路径不需要模型 completion，未虚构模型调用。

SQLite `integrity_check=ok`，`foreign_key_check` 为空；本次使用的是隔离 acceptance 数据目录。
