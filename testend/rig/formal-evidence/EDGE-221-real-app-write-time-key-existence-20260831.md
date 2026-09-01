# EDGE-221 · 写时校 apiKeyId 存在性：真实 App/API 五通道现场

## 结论

`L1` 与 `L2` 通过；`L3`、`L4`、`L5` 记为明确适用性 `na`，不是 waiver。该格验证的是写入边界：四个写入口均在落库前拒绝不存在的 `apiKeyId`，没有独立的用户等待、视觉表面或可发现入口可供后三级单独判定。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-122143`
- workspace=`ws_7474ee453ad8d806`，data=`/private/tmp/anselm-rig-formal-20260831-11/data-edge221`
- Computer Use 真实创建工作区 `EDGE221 write-time key`，App 窗口由 conductor 启动并录制；健康帧=`evidence/edge221-app-healthy.png`
- `rig-check` 五通道通过；`rig-down` 正常封口，录屏=`171.705000s / 3104x1844 / H.264 / 60fps`，收台后无 Anselm/llmtap/ssetap 残留进程

## L1 · focused regression

`mise exec -- go test ./internal/app/modelref ./internal/app/conversation ./internal/app/agent ./internal/app/workspace -run 'Dangling|TestValidate|ModelRef' -count=1 -race -v` 通过；覆盖 modelref、conversation override、agent override、workspace scenario default 与 workspace search default 的写时 key existence 端口。

## L2 · 真实写入与数据真相

同一真实 sidecar、同一 workspace 依次执行四个无效写入，均返回完全一致的 N1 envelope：

```text
HTTP 404
{"error":{"code":"API_KEY_NOT_FOUND","message":"api key not found","details":null}}
```

覆盖的真实路径为：

- `PATCH /api/v1/conversations/cv_98606dfa9c78a548`，`modelOverride.apiKeyId=aki_missing_edge221`
- `POST /api/v1/agents`，`modelOverride.apiKeyId=aki_missing_edge221`
- `PUT /api/v1/workspaces/ws_7474ee453ad8d806/default-models/dialogue`，`apiKeyId=aki_missing_edge221`
- `PUT /api/v1/workspaces/ws_7474ee453ad8d806/default-search`，`apiKeyId=aki_missing_edge221`

写入后重新读取：conversation 的 `modelOverride` 仍为 `null`；workspace 的六个默认模型仍指向真实 managed key，`default_search_key_id` 为空。SQLite 交叉查询中 conversation、agent version、workspace model、workspace search 的 `aki_missing_edge221` 悬挂引用均为 `0`。后端 journal 记录四个 `404`，无 panic/WARN/ERROR/FATAL；三路 SSE 已连接并记录 workspace/conversation 生命周期帧。

## L3-L5 · 适用性边界

- `L3 na`：四个接口是同步写入合同，没有独立的用户可见 loading/首反馈控件；本次真实响应已被后端 journal 记录，但不能把 HTTP 耗时冒充产品顺滑度。
- `L4 na`：写时拒绝不生成独立 UI 产物；错误 envelope 的视觉呈现归属各自已公开的 Settings/Chat 表面，不能用 onboarding 健康帧替代错误状态 craft 复核。
- `L5 na`：当前 App 的模型选择器只暴露 probe-OK 的 capability rows，用户没有可发现的悬挂 `apiKeyId` 输入入口；该格是 API/持久化防悬挂合同，不是独立 discoverability journey。若未来公开任意 key/model 输入，必须撤销三项 `na` 并重跑 L2-L5。

## 五通道交叉核验

- screen：真实 App 窗口录屏与 Computer Use 健康帧属于同一 session
- backend：conductor 持有的 sidecar journal 非空，四个拒绝请求与读取回查一致
- SSE：messages/entities/notifications 三流均连接；无错误写入帧被伪造为成功
- frontend：真实 App 完成 onboarding 并保持健康；frontend journal 仅有已知 macOS IMK 平台诊断，无 Flutter/Dart/布局红线
- LLM wire：受管网关 challenge/install/models 全部经 llmtap 返回 `200`；本格不需要调用模型，未伪造模型流量
