// Package attachment provides the LLM system tools for discovering and re-reading user-uploaded
// attachments: list_attachments / read_attachment / inspect_media. These are thin adapters over
// attachmentapp.Service — no domain / store / handler / DDL / HTTP — implementing only the
// app/tool 5-method contract. They are lazy tools (Toolset.Lazy), surfaced via search_tools.
// Discovery is metadata-only; reading text-extracts (or descriptor-degrades binary) so the agent
// can pull back a file it (or the user) attached on an earlier turn; inspecting image media runs a
// bounded, single-image vision pass and returns text evidence only. An unknown id degrades to a
// soft-failure string for the LLM to self-correct; nothing bubbles to HTTP here.
//
// Package attachment 提供发现 + 重读 + 查看用户上传附件的 LLM system tool：list_attachments /
// read_attachment。它们是 attachmentapp.Service 之上的薄适配器——无 domain/store/handler/DDL/HTTP
// ——只实现 app/tool 的 5 方法契约。是懒加载工具（Toolset.Lazy），经 search_tools 浮现。发现只读
// 元数据；读取做文本抽取（二进制降级为描述符），使 agent 能把先前回合里它（或用户）附的文件重新拉
// 回；查看图片媒体会跑一次有界、单图视觉检查且只返回文本证据。未知 id 转软失败串供 LLM 自纠，不冒泡 HTTP。
package attachment

import (
	"context"

	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// ErrIDRequired is the read_attachment input-validation sentinel (empty id). Unknown-but-present
// ids are NOT this error — they soft-fail to a tool-result string so the LLM retries with a real id.
//
// ErrIDRequired 是 read_attachment 的输入校验 sentinel（id 空）。存在但未知的 id 不属此错误——它们
// 软失败成工具结果串，让 LLM 用真 id 重试。
var ErrIDRequired = errorspkg.New(errorspkg.KindInvalid, "ATTACHMENT_ID_REQUIRED", "id is required")

// TextCache is an optional media-ingestion cache for expensive document text extraction. It stores
// only bounded text artifacts keyed by attachment source SHA + versioned params; prompt/task text
// never enters the cache key.
type TextCache interface {
	DocumentText(ctx context.Context, attachmentID string, extract func(context.Context, *attachmentdomain.Attachment, []byte) (string, error)) (string, error)
}

// AttachmentTools constructs the attachment system tools over one Service. inspect_media is
// registered only when a resolver is supplied, because it needs an LLM vision route; the two
// metadata/text tools stay available in every boot.
//
// AttachmentTools 用一个 Service 构造 attachment 系统工具。inspect_media 仅在传入 resolver 时注册，
// 因其需要 LLM 视觉路由；两个 metadata/text 工具每次 boot 都可用。
func AttachmentTools(svc *attachmentapp.Service, resolver InspectMediaResolver, textCacheOpt ...TextCache) []toolapp.Tool {
	var textCache TextCache
	if len(textCacheOpt) > 0 {
		textCache = textCacheOpt[0]
	}
	tools := []toolapp.Tool{
		&ListAttachments{svc: svc},
		&ReadAttachment{svc: svc, textCache: textCache},
	}
	if resolver != nil {
		tools = append(tools, &InspectMedia{svc: svc, resolver: resolver, imageProcessor: mediaImageProcessor{}, textCache: textCache})
	}
	return tools
}

var (
	_ toolapp.Tool = (*ListAttachments)(nil)
	_ toolapp.Tool = (*ReadAttachment)(nil)
	_ toolapp.Tool = (*InspectMedia)(nil)
)
