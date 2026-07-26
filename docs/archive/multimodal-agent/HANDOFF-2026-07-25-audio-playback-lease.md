---
id: WRK-079
type: working
status: active
owner: "@weilin"
created: 2026-07-25
reviewed: 2026-07-25
review-due: 2026-10-23
audience: [human, ai]
landed-into:
---

# WRK-078 交接 · audio playback lease 片

日期：2026-07-25  
仓库：`/Users/SP14921/Documents/Personal/PersonalCodeBase/Anselm`  
当前边界：本交接只覆盖“原始音频附件播放源 production 化”这一片；不要在接手后立刻开始 WRK-078 总战役收尾，先把本片验证、提交、推送完成。

## 1. 当前状态

本片代码和文档已改完，但还没有提交、没有推送。

目标问题：

- Flutter 端 `audioplayers.UrlSource` 不能给媒体请求附带 `Authorization` header。
- 直接把受 bearer 保护的 `/api/v1/attachments/{id}/content` URL 交给播放器不可行。
- 继续先把整段音频拉成 Dart bytes 再播放能用，但不是生产级播放源：大音频会额外占内存，也绕不开“loopback playback source”验收。

当前实现方案：

- `POST /api/v1/attachments/{id}/playback-lease`
  - 正常走 bearer + workspace middleware；
  - 只允许 `kind=audio`；
  - 非 audio 返回 `ATTACHMENT_PLAYBACK_UNSUPPORTED` / 415；
  - 返回 `{url, expiresAt}`。
- `GET /api/v1/attachment-playback/{token}`
  - 给原生播放器使用，豁免 bearer/workspace header；
  - 仍受全局 loopback Host gate 保护；
  - token 高熵、只驻内存、绑定 workspace + attachment id、短 TTL；
  - 过期或不存在统一走 `ATTACHMENT_NOT_FOUND` / 404；
  - 使用 `http.ServeContent`，支持 Range/seek。
- request logger 会把 `/api/v1/attachment-playback/<token>` 脱敏为 `/api/v1/attachment-playback/<redacted>`。
- Flutter transcript 音频播放已经改为：
  - 点击播放 → repository 签发 playback lease；
  - `AttachmentAudioPlaybackController.toggleUrl(...)`；
  - driver 用 `audioplayers.UrlSource` 播放。
- bytes 播放 seam 仍保留，用于兼容和状态测试。

## 2. 已修改文件

后端：

- `backend/internal/domain/attachment/attachment.go`
  - 新增 `ErrPlaybackUnsupported`。
- `backend/internal/transport/httpapi/handlers/attachment.go`
  - 新增 playback lease 签发和 fetch handler；
  - 内存 token map、TTL、过期清理；
  - fetch 使用 workspace 绑定读取原始 CAS。
- `backend/internal/transport/httpapi/handlers/attachment_test.go`
  - 覆盖 audio lease 签发、bearerless fetch、Range、非 audio 拒绝、过期 404。
- `backend/internal/transport/httpapi/middleware/bearer.go`
  - bearer gate 豁免 `/api/v1/attachment-playback/`。
- `backend/internal/transport/httpapi/middleware/bearer_test.go`
  - 覆盖 playback fetch bearer 豁免。
- `backend/internal/transport/httpapi/middleware/logger.go`
  - request path 脱敏 playback token。
- `backend/internal/transport/httpapi/middleware/logger_test.go`
  - 覆盖 token 不进日志。
- `backend/internal/transport/httpapi/router/chain.go`
  - workspace gate 豁免 `/api/v1/attachment-playback/`。
- `backend/internal/transport/httpapi/router/chain_test.go`
  - 覆盖 playback fetch workspace 豁免。

前端：

- `frontend/lib/features/chat/data/chat_repository.dart`
  - 新增 `AttachmentPlaybackLease` DTO；
  - `ChatRepository.createAttachmentPlaybackLease(...)`；
  - live repository 调 `POST /attachments/{id}/playback-lease`。
- `frontend/lib/features/chat/data/chat_fixtures.dart`
  - fixture repository 返回本机 fixture playback URL。
- `frontend/lib/features/chat/state/attachment_audio_player.dart`
  - driver 新增 `playUrl(...)`；
  - `AudioplayersAttachmentAudioDriver` 使用 `UrlSource`；
  - controller 新增 `toggleUrl(...)`，并抽出 shared toggle 逻辑。
- `frontend/lib/features/chat/ui/chat_transcript.dart`
  - 已发送音频附件点击播放改为签发 lease URL 再播放。
- `frontend/test/features/chat/state/attachment_audio_player_test.dart`
  - 覆盖 URL 播放路径。
- `frontend/test/features/chat/ui/chat_transcript_test.dart`
  - 历史音频播放从“取 bytes”改为“签发 short loopback lease”；
  - 离线/404 测试改到 lease 签发语义。

文档：

- `docs/working/multimodal-agent/README.md`
  - V2/M1 状态更新：短期 loopback playback lease 已落地，剩余是真机 smoke/总战役收口。
- `docs/references/backend/error-codes.md`
  - 登记 `ATTACHMENT_PLAYBACK_UNSUPPORTED`。
- `docs/references/backend/api.md`
  - 登记 `playback-lease` 与 `attachment-playback` endpoint。
- `docs/references/backend/domains/attachment.md`
  - 同步 endpoint 与 `ATTACHMENT_*` 计数。

## 3. 已跑过的验证

目标测试已通过：

```bash
cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Anselm/backend
go test ./internal/transport/httpapi/handlers ./internal/transport/httpapi/middleware ./internal/transport/httpapi/router ./internal/domain/attachment

cd ../frontend
mise exec -- flutter test test/features/chat/state/attachment_audio_player_test.dart test/features/chat/ui/chat_transcript_test.dart
```

结果：

- Go handler/middleware/router 目标测试通过；
- Flutter audio player + transcript 目标测试通过，`30 passed`。

前端 quick 已通过：

```bash
cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Anselm/frontend
make quick
```

结果：

- format check 通过；
- analyze + affected tests 通过；
- 输出：`✓ quick 绿(analyze + 受影响范围;推送前仍需 make verify 全量)`。

根目录 verify 跑过一次，失败在 docs drift，非代码测试：

```bash
cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Anselm
make verify
```

当时结果：

- backend 通过；
- frontend 通过；
- demo 通过；
- docs 失败：
  - `ATTACHMENT_PLAYBACK_UNSUPPORTED` 未登记到 `error-codes.md`；
  - `POST /api/v1/attachments/{id}/playback-lease` 未登记到 `api.md`；
  - `GET /api/v1/attachment-playback/{token}` 未登记到 `api.md`。

这些 docs drift 项已在本交接前补上，但补完后还没有重跑 `make verify`。

## 4. 接手后的下一步

先不要开始 WRK-078 总战役收尾。请先完成本片：

1. 检查当前 diff：

   ```bash
   cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Anselm
   git diff --check
   git diff --stat
   ```

2. 重新跑根目录 verify：

   ```bash
   make verify
   ```

3. 如果 verify 仍失败：

   - 若还是 docs drift，按 checker 输出补 `docs/references/backend/*`；
   - 若是 analyzer/test，优先修本片相关文件，不扩大范围。

4. verify 绿后提交：

   ```bash
   git add \
     backend/internal/domain/attachment/attachment.go \
     backend/internal/transport/httpapi/handlers/attachment.go \
     backend/internal/transport/httpapi/handlers/attachment_test.go \
     backend/internal/transport/httpapi/middleware/bearer.go \
     backend/internal/transport/httpapi/middleware/bearer_test.go \
     backend/internal/transport/httpapi/middleware/logger.go \
     backend/internal/transport/httpapi/middleware/logger_test.go \
     backend/internal/transport/httpapi/router/chain.go \
     backend/internal/transport/httpapi/router/chain_test.go \
     docs/references/backend/api.md \
     docs/references/backend/domains/attachment.md \
     docs/references/backend/error-codes.md \
     docs/working/multimodal-agent/README.md \
     docs/working/multimodal-agent/HANDOFF-2026-07-25-audio-playback-lease.md \
     frontend/lib/features/chat/data/chat_fixtures.dart \
     frontend/lib/features/chat/data/chat_repository.dart \
     frontend/lib/features/chat/state/attachment_audio_player.dart \
     frontend/lib/features/chat/ui/chat_transcript.dart \
     frontend/test/features/chat/state/attachment_audio_player_test.dart \
     frontend/test/features/chat/ui/chat_transcript_test.dart

   git commit -m "feat(audio): stream attachments through playback leases"
   git push
   ```

5. 推送后再开始 WRK-078 总战役收尾：

   - 回看 `docs/working/multimodal-agent/README.md` 的 §12 / H0；
   - 明确区分“代码主线已完成”和“真实环境验收仍待跑”；
   - 不要把未跑的真实 1M eval、真实 Qwen/DeepSeek paid eval、生产 media lease 抓包、三平台语音真机 smoke 写成已完成。

## 5. 注意事项

- 不要把 playback token 改成一次性消费。原生音频栈可能会发多次 GET / Range 请求；一次性 token 会破坏 seek 和分段加载。
- 不要让 `/api/v1/attachment-playback/{token}` 重新要求 bearer/workspace header；这正是为了解决播放器不能带 header。
- 不要把 playback fetch 扩展到任意附件。当前只允许 audio，避免 bearerless URL 变成通用下载旁路。
- 不要记录 token。request logger 已脱敏 path；如果新增日志，也必须只记录固定 route label。
- 不要把这个本机 playback lease 和公网网关 media lease 混淆。前者服务本机播放器；后者服务上游模型抓取图片/视频代理。
