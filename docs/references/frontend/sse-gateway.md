---
id: DOC-047
type: reference
status: active
owner: @weilin
created: 2026-06-22
reviewed: 2026-06-22
review-due: 2026-09-22
audience: [human, ai]
---

# 前端 SSE gateway —— 三条实时流的客户端

> 决策依据 [`ADR 0004 §4`](../../decisions/0004-frontend-flutter-architecture.md);协议事实源 `references/backend/events.md`。前端最难三处之一。

## 1. 三条流(E1)

全系统仅 `messages` / `entities` / `notifications` 三条 SSE,**workspace 级、后端不发完整 delta 不过滤**。前端启动即常驻全连(`keepAlive`)。订阅:`GET /api/v1/{stream}/stream`。

## 2. `SseGateway`(`core/sse/`,纯 Dart,`app/` 持有)

三连接;每连接手写 SSE 行解析(`sse_parser.dart`:`event:/id:<seq>/data:<json>`);重连状态机(`sse_connection.dart`)。**关键:在 Riverpod 之下垫 `Map<Scope,Stream>` demux**(`sse_gateway.dart`)——gateway 把帧预分桶进 per-scope broadcast controller;直接 family 订阅会 O(帧×订阅者) 重建。

## 3. durable vs ephemeral(E2,铁律)

**DB 行是真相、流只为实时**。`seq>0` durable:推进续传游标、触耐久态(`Close` 快照 / durable 信号 invalidate 分页 provider)。`seq=0` ephemeral(delta/tick):**只改瞬时视图态,不进耐久缓存、不推进游标**。durable 不在线缆上(`Signal.Ephemeral` 是 `json:"-"`),故必达/可丢从 **`stream + node.type`** 推断、非 frame.kind。

## 4. frame + 续传 + 拦截

`frame.dart`:sealed 4 动词(open/delta/close/signal)+ `unknown` 兜底(前向兼容)。续传发 `Last-Event-ID`(回退 `?fromSeq`)。`410`(`SEQ_TOO_OLD`)→ 发 `ResyncRequired` → 订阅方走 REST 重取再从新 head 续。`401`(`UNAUTH_NO_WORKSPACE`)→ 清选区重选。
