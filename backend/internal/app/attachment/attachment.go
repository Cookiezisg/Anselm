// Package attachment owns the Service for uploaded files: hash → content-addressed blob store +
// metadata row, download, soft-delete, orphan-blob GC, and LLM injection (ToContentParts turns
// attachments into provider-agnostic llm.ContentPart for a chat turn). The bytes live in a
// BlobStore (a port, implemented by infra/fs/blob); the metadata lives in attachmentdomain.
// Repository. Workspace isolation is automatic at both layers (orm + blob both key off ctx).
//
// Package attachment 持有上传文件的 Service：哈希 → 内容寻址 blob 存储 + 元数据行、下载、软删、
// 孤儿 blob GC，以及 LLM 注入（ToContentParts 把附件变成与 provider 无关的 llm.ContentPart 供聊天
// 回合）。字节在 BlobStore（端口，infra/fs/blob 实现）；元数据在 attachmentdomain.Repository。
// workspace 隔离两层都自动（orm + blob 都据 ctx）。
package attachment

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"net/url"
	"path/filepath"
	"strings"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// BlobStore is the content-addressed byte store (port; infra/fs/blob implements it). Put is a
// no-op when the sha already exists (dedup); Sweep is orphan GC against a keep-set.
//
// BlobStore 是内容寻址字节存储（端口；infra/fs/blob 实现）。sha 已存在时 Put 为 no-op（dedup）；
// Sweep 按保留集做孤儿 GC。
type BlobStore interface {
	Put(ctx context.Context, sha string, data []byte) error
	Get(ctx context.Context, sha string) ([]byte, error)
	Exists(ctx context.Context, sha string) (bool, error)
	Sweep(ctx context.Context, keep map[string]bool) (int, error)
}

// Service is the attachment application façade.
//
// Service 是附件应用 façade。
type Service struct {
	repo      attachmentdomain.Repository
	blobs     BlobStore
	extractor Extractor // optional (nil → documents degrade to a placeholder for non-native models)
	log       *zap.Logger
}

// New constructs a Service; panics on nil logger, repo, or blobs (all required). extractor is
// optional — nil means a document sent to a model without native document input degrades to a
// placeholder instead of being text-extracted.
//
// New 构造 Service；nil logger/repo/blobs panic（皆必需）。extractor 可选——nil 时，发给无原生文档
// 输入模型的文档降级为占位，而非抽文本。
func NewService(repo attachmentdomain.Repository, blobs BlobStore, extractor Extractor, log *zap.Logger) *Service {
	if log == nil {
		panic("attachmentapp.New: nil logger")
	}
	if repo == nil || blobs == nil {
		panic("attachmentapp.New: repo and blobs are required")
	}
	return &Service{repo: repo, blobs: blobs, extractor: extractor, log: log}
}

// Upload validates size, hashes the bytes, stores the blob (dedup), and inserts the metadata row.
// The blob is written before the row so a row never points at a missing blob.
//
// Upload 校验大小、哈希字节、存 blob（dedup）、插元数据行。blob 先于行写入，故行绝不指向缺失 blob。
func (s *Service) Upload(ctx context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	if len(data) == 0 {
		return nil, attachmentdomain.ErrEmpty
	}
	if int64(len(data)) > int64(limitspkg.Current().Guards.AttachmentMaxMB)<<20 {
		return nil, attachmentdomain.ErrTooLarge
	}
	sum := sha256.Sum256(data)
	sha := hex.EncodeToString(sum[:])
	if err := s.blobs.Put(ctx, sha, data); err != nil {
		return nil, fmt.Errorf("attachmentapp.Upload: blob: %w", err)
	}
	// Provenance is stamped from ctx at the ONE place every producer funnels through (WRK-082 H5.7).
	// Recorded, never enforced — see the domain field comments for why it is recorded now and what it
	// is for. An absent value is "" and that is a fact too: a plain user upload has no producer.
	// 溯源在**每个产地都必经的那一处**从 ctx 盖上(H5.7)。**只记录、从不执行**——为何现在就记、以及记
	// 给谁用,见 domain 字段注释。取不到即 "",而那**也是一个事实**:普通用户上传没有产地。
	conversationID, _ := reqctxpkg.GetConversationID(ctx)
	flowrunID, _ := reqctxpkg.GetFlowrunID(ctx)
	toolCallID, _ := reqctxpkg.GetToolCallID(ctx)
	a := &attachmentdomain.Attachment{
		ID:                   idgenpkg.New("att"),
		SHA256:               sha,
		Filename:             filepath.Base(filename), // display only; blob is keyed by sha, not name
		MimeType:             mime,
		SizeBytes:            int64(len(data)),
		Kind:                 attachmentdomain.KindFromMIME(mime, filename),
		Source:               reqctxpkg.GetMediaSource(ctx),
		OriginConversationID: conversationID,
		OriginFlowrunID:      flowrunID,
		OriginToolCallID:     toolCallID,
	}
	if err := s.repo.Insert(ctx, a); err != nil {
		return nil, err
	}
	return a, nil
}

// ToolResultContentParts is the tool_result half of the consumption chokepoint (WRK-082 H5.8). It
// expands ONLY attachments this very tool call minted, then hands the survivors to ToContentParts.
//
// **Why "this call" and not "this workspace".** A receipt is text a tool writes, so any tool can
// name any attachment id and the expander would dutifully inline it. Workspace isolation (already
// enforced in pkg/orm) stops a cross-workspace read, but inside one workspace the only thing
// standing between a third-party MCP server and somebody else's file is that it has to guess a
// 64-bit id. That is a thin thing to rely on, and it costs nothing to remove: every producer that
// legitimately wants its media seen — MCP binaries, function and handler artifacts — minted it
// during the call being expanded.
//
// **The audit that made this safe.** Two tools do legitimately name an attachment they did not
// mint: `inspect_media` and `read_attachment`, both of which echo the id they were asked about.
// Neither wants expansion — `inspect_media`'s own description says it "does not dump image bytes
// into the conversation", and `read_attachment` says binaries "return descriptors". So today's
// behaviour was already violating both contracts, and this filter fixes that as a side effect
// rather than breaking anything. No other tool in the inventory names a pre-existing attachment.
//
// ToolResultContentParts 是消费咽喉的 tool_result 那一半(H5.8)。它**只**展开**这一次工具调用自己铸出**
// 的附件,再把幸存者交给 ToContentParts。
//
// **为什么是「这次调用」而不是「这个 workspace」。** receipt 是工具写的文本,故任何工具都能点名任何一个
// 附件 id,而展开器会老老实实内联它。workspace 隔离(pkg/orm 早已强制)挡得住跨 workspace 读,但在同一个
// workspace 内,横在第三方 MCP server 与别人的文件之间的,只剩「它得猜中一个 64 位 id」。这是一根很细的
// 稻草,而拿掉它不花任何代价:每一个**正当地**希望自己的媒体被看到的产地——MCP 二进制、function 与
// handler 产物——都是在**正被展开的这次调用中**铸出它的。
//
// **让这条收紧变得安全的那次审计。** 确有两个工具正当地点名了它们没铸的附件:`inspect_media` 与
// `read_attachment`,两者都回显被问及的那个 id。而**两者都不想要展开**——`inspect_media` 自己的描述写着
// 它「不把图像字节倾倒进对话」,`read_attachment` 写着二进制「返回描述符」。也就是说,今天的行为**本来
// 就在违反这两份契约**,本过滤器是**顺手修好了它**、而不是弄坏了什么。工具清单里再没有第三个点名既有
// 附件的。
// **The tool call id is a PARAMETER, not a ctx read.** It was a ctx read when H5.8 landed, and that
// silently killed the whole expansion branch: the loop seeds SetToolCallID only inside the tool's
// own execution scope, while the expansion runs one level out on the loop's own ctx — where the id
// is empty, so this function returned nil for EVERY call. Every mocked test seeded the ctx by hand
// and passed; the first end-to-end run with a real producer (a function's matplotlib chart) showed
// the model going off to call inspect_media because it had never been handed the pixels.
// Taking it as an argument also makes a multi-tool step correct by construction — each tool_result
// expands under ITS OWN call id rather than whatever one id happened to be on ctx.
//
// **tool call id 是**参数**,不是从 ctx 读的。** H5.8 落地时它是 ctx 读,而那**静默杀死了整条展开路径**:
// loop 只在**工具自己的执行作用域内**种 SetToolCallID,而展开发生在外面一层、用的是 loop 自己的 ctx
// ——那上面 id 是空的,于是本函数对**每一次**调用都返回 nil。每个 mock 测试都手工种了 ctx、于是全绿;
// 而第一次带真产地的端到端跑(函数的 matplotlib 图表)里,模型跑去调 inspect_media——因为它从来没被
// 递过那些像素。把它收成参数,还让「一步多工具」天然正确:每个 tool_result 用**自己**那个调用 id 展开,
// 而不是碰巧躺在 ctx 上的某一个。
func (s *Service) ToolResultContentParts(ctx context.Context, toolCallID string, ids []string, caps Capabilities) ([]llminfra.ContentPart, error) {
	if toolCallID == "" || len(ids) == 0 {
		return nil, nil
	}
	metas, err := s.repo.GetBatch(ctx, ids)
	if err != nil {
		return nil, err
	}
	minted := make(map[string]bool, len(metas))
	for _, a := range metas {
		if a.OriginToolCallID == toolCallID {
			minted[a.ID] = true
		}
	}
	kept := make([]string, 0, len(ids))
	for _, id := range ids {
		if minted[id] {
			kept = append(kept, id)
		}
	}
	if len(kept) == 0 {
		return nil, nil
	}
	return s.ToContentParts(ctx, kept, caps)
}

// Get fetches one attachment's metadata.
//
// Get 取一个附件的元数据。
func (s *Service) Get(ctx context.Context, id string) (*attachmentdomain.Attachment, error) {
	return s.repo.Get(ctx, id)
}

// List returns every live attachment's metadata in the ctx workspace (newest first), for the
// list_attachments tool + catalog source. Bytes are not touched — discovery is metadata-only.
//
// List 返 ctx workspace 内每条活跃附件的元数据（新→旧），供 list_attachments 工具 + catalog
// source。不碰字节——发现只读元数据。
func (s *Service) List(ctx context.Context) ([]*attachmentdomain.Attachment, error) {
	return s.repo.List(ctx)
}

// Download returns an attachment's metadata + its blob bytes.
//
// Download 返回附件元数据 + 其 blob 字节。
func (s *Service) Download(ctx context.Context, id string) (*attachmentdomain.Attachment, []byte, error) {
	a, err := s.repo.Get(ctx, id)
	if err != nil {
		return nil, nil, err
	}
	data, err := s.blobs.Get(ctx, a.SHA256)
	if err != nil {
		return nil, nil, fmt.Errorf("attachmentapp.Download: %w", err)
	}
	return a, data, nil
}

// Delete soft-deletes the metadata row; the blob is reclaimed later by GC if no live row
// references its sha (another attachment may share it).
//
// Delete 软删元数据行；若无活跃行引用其 sha（另一附件可能共享），blob 稍后由 GC 回收。
func (s *Service) Delete(ctx context.Context, id string) error {
	return s.repo.SoftDelete(ctx, id)
}

// GC sweeps orphan blobs in the ctx workspace: blobs whose sha is referenced by no live row.
//
// GC 清 ctx workspace 的孤儿 blob：sha 无活跃行引用的 blob。
func (s *Service) GC(ctx context.Context) (int, error) {
	shas, err := s.repo.ListLiveSHAs(ctx)
	if err != nil {
		return 0, err
	}
	keep := make(map[string]bool, len(shas))
	for _, sha := range shas {
		keep[sha] = true
	}
	return s.blobs.Sweep(ctx, keep)
}

// Capabilities tells ToContentParts what the resolved target model can natively accept, so it can
// decide whether to hand a file over raw or degrade it. Both flags come from the caller (chat loop)
// via the model catalog — this layer holds no model knowledge.
//
// Capabilities 告诉 ToContentParts 解析后的目标模型能原生接受什么，据此决定原样递交还是降级。能力与
// 单回合媒体额度都由调用方（chat loop）按模型目录传入——本层不持模型知识。
type Capabilities struct {
	Vision     bool // model can see images natively / 模型能原生看图
	Video      bool // model can inspect an inline video natively / 模型能原生看内联视频
	Audio      bool // model can inspect an inline audio clip natively / 模型能原生听内联音频
	NativeDocs bool // model can read an inline document (PDF) natively / 模型能原生读内联文档(PDF)
	// Optional, per-turn decoded-media envelope. A zero value means no app-side cap was published
	// by the resolved model. The renderer still leaves provider-specific validation to the provider.
	// 可选的单回合解码媒体额度。零值表示解析模型未发布 app 侧上限；provider 专属校验仍由 provider 执行。
	MaxMediaParts int
	MaxMediaBytes int64
	// MaxDistinctMediaKinds is an optional cross-kind guard for native image/video/audio parts.
	// It is separate from MaxMediaParts: a model may accept several images while allowing only
	// one distinct non-text media kind in a turn. Zero means no finite constraint is known.
	// MaxDistinctMediaKinds 是原生图/视频/音频 part 的跨类型闸，与 MaxMediaParts 分开：模型可能接受
	// 多张图片，却只允许单回合一种非文本媒体类型。零表示未知或没有有限约束。
	MaxDistinctMediaKinds int
	// RemoteMedia, when set by the composition root for the managed gateway, replaces inline
	// image/video data URLs with a short-lived remote source. This package owns the decision of
	// which attachment kinds may use it; bootstrap owns the transport implementation.
	//
	// RemoteMedia 由 composition root 仅为受管网关注入时，会把内联 image/video data URL 换成短期
	// remote source。本包拥有哪些附件类型可使用它的判断；bootstrap 拥有传输实现。
	RemoteMedia *RemoteMedia
}

// RemoteMediaUploader stages one immutable byte sequence and returns the managed gateway's
// provider-fetchable, expiring relative lease path. It is a narrow application port so attachment
// rendering never depends on a concrete HTTP client or gateway implementation.
//
// RemoteMediaUploader 暂存一份不可变字节并返回 provider 可拉取、会过期的相对 lease 路径。它是窄应用端口，
// 使附件渲染永不依赖具体 HTTP client 或网关实现。
type RemoteMediaUploader interface {
	Upload(ctx context.Context, baseURL, installID, mime string, data []byte) (string, error)
}

// ValidateRemoteMediaSource accepts only the relative lease reference the managed gateway owns.
// Returning the trimmed value keeps every consumer from accidentally caching or forwarding
// surrounding whitespace.
//
// ValidateRemoteMediaSource 只接受受管网关拥有的相对 lease 引用，并返回去除首尾空白的值，避免不同
// 消费面各自缓存或转发带空白的来源。
func ValidateRemoteMediaSource(source string) (string, error) {
	source = strings.TrimSpace(source)
	parsed, err := url.Parse(source)
	if err != nil || parsed.IsAbs() || parsed.Host != "" || parsed.User != nil ||
		!strings.HasPrefix(parsed.Path, "/v1/media/leases/") || parsed.RawQuery == "" {
		return "", fmt.Errorf("attachment: managed media returned an invalid relative lease path")
	}
	return source, nil
}

// ImageProxy returns a bounded model-ready image when the media worker has produced one. ready=false
// means the caller should use the original for this turn and let the background worker catch up.
//
// ImageProxy 在媒体 worker 已产出时返回有界、面向模型的图片代理；ready=false 表示本回合继续用原件、
// 后台任务自行追上。
type ImageProxy interface {
	ModelDefaultImage(ctx context.Context, attachmentID string) (data []byte, mime string, ready bool, err error)
}

// RemoteMedia is the per-turn managed-gateway destination. InstallID is a public install handle;
// device proof is added by the uploader's HTTP transport and never crosses this boundary.
//
// RemoteMedia 是每回合的受管网关目的地。InstallID 是公开 install handle；device proof 由 uploader
// 的 HTTP transport 添加，绝不穿过此边界。
type RemoteMedia struct {
	BaseURL   string
	InstallID string
	Uploader  RemoteMediaUploader
	Images    ImageProxy
}

// ToContentParts resolves attachment ids into provider-agnostic LLM content parts for one user turn
// (the chat loop prepends the user's own text part, then sends; each provider renders the parts into
// its own wire). Mapping by Kind:
//   - image    → image_url (data-URL) when caps.Vision; else a text note (degrade — don't send a
//     part the model would reject).
//   - text     → the file's content inlined as a text part (cheap, universal).
//   - document → caps.NativeDocs and media envelope permits it ? a file part (PDF handed over raw,
//     read natively) : sandbox text-extracted, token-capped text — with a placeholder note if no
//     extractor / extraction fails.
//   - video → video_url when caps.Video and the attachment is an MP4; else a text note.
//   - audio → input_audio when caps.Audio and it is WAV/MP3; else a text note.
//   - when MaxDistinctMediaKinds is set, only that many distinct native media kinds are emitted;
//     extra kinds become an explanatory text note rather than a provider-level 400.
//   - other → a text placeholder.
//
// Order follows ids. A missing/unreadable blob is skipped with a warning — a stale id must never
// fail the turn (best-effort, like a dangling mention).
//
// ToContentParts 把附件 id 解析成与 provider 无关的 LLM 内容块，供一个 user 回合（chat loop 前面拼上
// 用户文本 part 再发；各家渲成自家 wire）。按 Kind 映射：image→image_url（data-URL，仅 caps.Vision；
// 否则文字提示降级）；text→文件内容内联 text part；document→caps.NativeDocs 且媒体 envelope 容纳 ? file
// part（PDF 原样递交、原生读）: sandbox 抽取文本（token 截断），无 extractor / 抽取失败则占位；
// audio/video/other→文字占位（那些 extractor 是未来插件）。顺序随 ids；缺失/不可读 blob 告警跳过——
// 陈旧 id 绝不让回合失败。
func (s *Service) ToContentParts(ctx context.Context, ids []string, caps Capabilities) ([]llminfra.ContentPart, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	metas, err := s.repo.GetBatch(ctx, ids)
	if err != nil {
		return nil, err
	}
	// GetBatch (WHERE id IN) does not preserve order; index by id and walk ids so parts keep the
	// caller's order (part order is semantically meaningful to the model).
	//
	// GetBatch（WHERE id IN）不保序；按 id 建索引、按 ids 遍历，使 parts 保持调用方顺序（part 顺序
	// 对模型有语义）。
	byID := make(map[string]*attachmentdomain.Attachment, len(metas))
	for _, a := range metas {
		byID[a.ID] = a
	}
	out := make([]llminfra.ContentPart, 0, len(ids))
	mediaParts := 0
	var mediaBytes int64
	nativeMediaKinds := make(map[string]struct{})
	// A duplicate attachment in one user turn must not create multiple leases or send the same
	// bytes twice. The URL is intentionally per-turn only: leases are install-bound and expiring.
	//
	// 同一 user 回合重复附件绝不能创建多个 lease 或重复传字节。URL 故意只作每回合缓存：lease 绑定 install
	// 且会过期。
	remoteURLs := make(map[string]string)
	for _, id := range ids {
		a := byID[id]
		if a == nil {
			// Surface the gap to the model instead of silently dropping it — a referenced-but-missing
			// attachment that vanishes from the turn with no signal misleads both model and user (F78).
			// 把缺口透给模型而非静默丢弃——被引用却失踪的附件无声消失会同时误导模型与用户（F78）。
			s.log.Warn("attachmentapp.ToContentParts: attachment not found, noting", zap.String("attachment_id", id))
			out = append(out, textNote("a referenced attachment (%s) is no longer available", id))
			continue
		}
		data, err := s.blobs.Get(ctx, a.SHA256)
		if err != nil {
			s.log.Warn("attachmentapp.ToContentParts: blob unreadable, noting",
				zap.String("attachment_id", a.ID), zap.String("sha256", a.SHA256), zap.Error(err))
			out = append(out, textNote("attachment %q is no longer available", a.Filename))
			continue
		}
		switch a.Kind {
		case attachmentdomain.KindImage:
			if caps.Vision && exceedsNativeMediaKinds(caps, nativeMediaKinds, "image") {
				out = append(out, distinctMediaKindNote("image", a.Filename, caps.MaxDistinctMediaKinds))
				continue
			}
			// The envelope binds the REMOTE path too. ADR 0012 made the gateway INLINE lease
			// content into the upstream body, so the final staged bytes must be counted before
			// creating a lease; an over-budget item degrades instead of killing the whole turn.
			// 信封同样约束**远端**路径。ADR 0012 把 lease 内容内联进上游请求体,所以创建 lease 前必须
			// 按最终 staging 字节计入预算;超限项目降级,不能让整轮死在网关 400。
			if caps.Vision && caps.RemoteMedia != nil {
				// The envelope applies to the bytes that the gateway will inline, not the original
				// attachment. A model-default proxy may be larger than a compressed original (for
				// example, a detailed PNG), so resolve the final staging payload before checking the
				// budget. Otherwise the local guard passes and the gateway rejects the whole turn.
				//
				// 信封约束的是网关最终内联的字节,不是原始附件。model-default 代理可能比压缩过的原图更大
				// (例如细节丰富的 PNG),所以必须先解析最终 staging 产物再查预算。否则本地闸放行、网关拒绝整轮。
				stageData, stageMIME := managedImageBytes(ctx, caps.RemoteMedia, a, data)
				// An undeliverable format must not take the whole turn down with it. Uploading it
				// anyway would 400 at the gateway and abort the turn; a note keeps the answer
				// alive and stays honest about what the model did NOT see.
				// 不可交付的格式不得把整个回合一起拖垮:照传会在网关 400 并中断回合;一句注记让回答活着,
				// 同时对「模型**没**看到什么」保持诚实。
				if !managedStagingAccepts(stageMIME) {
					out = append(out, textNote(
						"image %q attached, but its format (%s) cannot yet be prepared for the model; convert it to JPEG, PNG or WebP and re-attach",
						a.Filename, stageMIME))
					continue
				}
				if !fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(stageData))) {
					// A proxy is an optimization, not a reason to hide an otherwise deliverable
					// original. If the original fits the same envelope, send it instead; this keeps
					// ordinary JPEGs useful even when a lossless proxy grows larger than its source.
					//
					// 代理是优化,不是隐藏一份本来可交付的原图的理由。如果原图也能装进同一信封就退回原图;
					// 这样即使无损代理比源文件膨胀,普通 JPEG 仍然可用。
					originalMIME := normalizedMIME(a.MimeType)
					if managedStagingAccepts(originalMIME) && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
						stageData, stageMIME = data, originalMIME
					} else {
						out = append(out, unavailableMediaNote("image", a.Filename, caps.Vision, "vision", caps, mediaParts, mediaBytes, int64(len(stageData))))
						continue
					}
				}
				source, err := stagedMediaURL(ctx, caps.RemoteMedia, remoteURLs, a, stageMIME, stageData)
				if err != nil {
					return nil, err
				}
				out = append(out, llminfra.ContentPart{Type: llminfra.PartImageURL, ImageURL: source})
				mediaParts++
				mediaBytes += int64(len(stageData))
				nativeMediaKinds["image"] = struct{}{}
			} else if caps.Vision && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				out = append(out, llminfra.ContentPart{Type: llminfra.PartImageURL, ImageURL: dataURL(a.MimeType, data)})
				mediaParts++
				mediaBytes += int64(len(data))
				nativeMediaKinds["image"] = struct{}{}
			} else {
				out = append(out, unavailableMediaNote("image", a.Filename, caps.Vision, "vision", caps, mediaParts, mediaBytes, int64(len(data))))
			}
		case attachmentdomain.KindVideo:
			if caps.Video && normalizedMIME(a.MimeType) == "video/mp4" && exceedsNativeMediaKinds(caps, nativeMediaKinds, "video") {
				out = append(out, distinctMediaKindNote("video", a.Filename, caps.MaxDistinctMediaKinds))
				continue
			}
			if caps.Video && normalizedMIME(a.MimeType) == "video/mp4" && caps.RemoteMedia != nil &&
				fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				source, err := stagedMediaURL(ctx, caps.RemoteMedia, remoteURLs, a, normalizedMIME(a.MimeType), data)
				if err != nil {
					return nil, err
				}
				out = append(out, llminfra.ContentPart{Type: llminfra.PartVideoURL, VideoURL: source})
				mediaParts++
				mediaBytes += int64(len(data))
				nativeMediaKinds["video"] = struct{}{}
			} else if caps.Video && normalizedMIME(a.MimeType) == "video/mp4" && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				out = append(out, llminfra.ContentPart{Type: llminfra.PartVideoURL, VideoURL: dataURL("video/mp4", data)})
				mediaParts++
				mediaBytes += int64(len(data))
				nativeMediaKinds["video"] = struct{}{}
			} else if caps.Video && normalizedMIME(a.MimeType) != "video/mp4" {
				out = append(out, textNote("video %q attached, but this model accepts inline video only as MP4", a.Filename))
			} else {
				out = append(out, unavailableMediaNote("video", a.Filename, caps.Video, "video", caps, mediaParts, mediaBytes, int64(len(data))))
			}
		case attachmentdomain.KindAudio:
			if caps.Audio && audioFormat(a.MimeType) != "" && exceedsNativeMediaKinds(caps, nativeMediaKinds, "audio") {
				out = append(out, distinctMediaKindNote("audio", a.Filename, caps.MaxDistinctMediaKinds))
				continue
			}
			if caps.Audio && audioFormat(a.MimeType) != "" && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				out = append(out, llminfra.ContentPart{
					Type: llminfra.PartInputAudio, MediaType: normalizedMIME(a.MimeType),
					Data: base64.StdEncoding.EncodeToString(data),
				})
				mediaParts++
				mediaBytes += int64(len(data))
				nativeMediaKinds["audio"] = struct{}{}
			} else if caps.Audio && audioFormat(a.MimeType) == "" {
				out = append(out, textNote("audio %q attached, but this model accepts inline audio only as WAV or MP3", a.Filename))
			} else {
				out = append(out, unavailableMediaNote("audio", a.Filename, caps.Audio, "audio", caps, mediaParts, mediaBytes, int64(len(data))))
			}
		case attachmentdomain.KindText:
			out = append(out, llminfra.ContentPart{Type: llminfra.PartText, Text: inlineText(a.Filename, data)})
		case attachmentdomain.KindDocument:
			// NativeDocs means ONE thing: this model reads **PDF** inline (models_common.go builds it
			// from the catalog's `pdf` input modality). It was being applied to the whole document
			// KIND — so a .odt / .docx / .xlsx was base64'd and shipped to a model that never claimed
			// to read it. The provider either rejects the turn or silently makes something up, and
			// either way the file's bytes went out on the wire when the honest answer was to extract
			// its text locally. Found by a testend scenario that was red on main (WRK-082 H7).
			//
			// NativeDocs 只意味着**一件事**:这个模型原生读 **PDF**(models_common.go 就是从目录的 `pdf`
			// 输入模态推出它的)。它却被套用在整个文档**类**上——于是 .odt / .docx / .xlsx 被 base64 塞给
			// 一个**从没声称能读它**的模型。供应商要么拒掉这一轮、要么静默编一个,而无论哪种,那个文件的
			// 字节都已经上了线缆,而诚实的做法本是在本地把文本抽出来。由一条在 main 上就红着的 testend
			// 场景发现(H7)。
			if caps.NativeDocs && a.MimeType == "application/pdf" && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				out = append(out, llminfra.ContentPart{
					Type:      llminfra.PartFile,
					MediaType: a.MimeType,
					Data:      base64.StdEncoding.EncodeToString(data),
					Filename:  a.Filename,
				})
				mediaParts++
				mediaBytes += int64(len(data))
			} else if caps.NativeDocs && s.extractor == nil {
				out = append(out, unavailableMediaNote("document", a.Filename, true, "document", caps, mediaParts, mediaBytes, int64(len(data))))
			} else {
				out = append(out, s.extractDocPart(ctx, a, data))
			}
		default:
			out = append(out, textNote("file %q (%s) attached; content extraction is not yet available", a.Filename, a.Kind))
		}
	}
	return out, nil
}

// managedStagingMIMEs is the closed set the managed gateway's staging endpoint accepts. It is a
// MIRROR of the gateway's own supportedMIME check, kept here so an undeliverable format is caught
// BEFORE the upload attempt — the difference matters a lot: a rejected upload aborts the whole
// chat turn, whereas catching it here degrades to an honest note the same way the BYOK path does.
//
// Why the two sides can drift at all: the desktop classifies anything `image/*` as KindImage
// (HEIC — the iPhone default — AVIF, BMP, TIFF, SVG all qualify), while the gateway accepts six
// concrete types. The image proxy would normally normalise those away, but the decoder cannot read
// HEIC/AVIF, so the proxy never becomes ready and the ORIGINAL bytes are what get offered.
//
// managedStagingMIMEs 是受管网关 staging 端点接受的闭集,是对网关自身 supportedMIME 的**镜像**——放在这里
// 是为了在**上传之前**就发现无法交付的格式:差别很大——上传被拒会**中断整个聊天回合**,而在此拦下则像 BYOK
// 路径那样降级为一句诚实注记。
//
// 两侧为何会漂移:桌面端把一切 `image/*` 判为 KindImage(HEIC〔iPhone 默认〕/AVIF/BMP/TIFF/SVG 都算),
// 而网关只接受六个具体类型。图片代理本应把它们归一化掉,但解码器读不了 HEIC/AVIF,代理永远不会 ready,
// 于是被送出去的是**原件**字节。
var managedStagingMIMEs = map[string]struct{}{
	"image/jpeg": {}, "image/png": {}, "image/webp": {},
	"video/mp4": {}, "audio/wav": {}, "audio/mpeg": {},
}

func managedStagingAccepts(mime string) bool {
	_, ok := managedStagingMIMEs[normalizedMIME(mime)]
	return ok
}

func managedImageBytes(ctx context.Context, remote *RemoteMedia, a *attachmentdomain.Attachment, original []byte) ([]byte, string) {
	if remote == nil || remote.Images == nil {
		return original, normalizedMIME(a.MimeType)
	}
	data, mime, ready, err := remote.Images.ModelDefaultImage(ctx, a.ID)
	if err != nil || !ready || len(data) == 0 || normalizedMIME(mime) == "" {
		return original, normalizedMIME(a.MimeType)
	}
	return data, normalizedMIME(mime)
}

func stagedMediaURL(ctx context.Context, remote *RemoteMedia, cache map[string]string, a *attachmentdomain.Attachment, mime string, data []byte) (string, error) {
	if remote == nil || remote.Uploader == nil || remote.BaseURL == "" || remote.InstallID == "" {
		return "", fmt.Errorf("%w: attachment: managed media destination is unavailable", errorspkg.ErrAttachmentStagingFailed)
	}
	key := a.SHA256 + "\x00" + normalizedMIME(mime)
	if source := cache[key]; source != "" {
		return source, nil
	}
	source, err := remote.Uploader.Upload(ctx, remote.BaseURL, remote.InstallID, mime, data)
	if err != nil {
		return "", fmt.Errorf("%w: attachment: stage %q for managed media: %w", errorspkg.ErrAttachmentStagingFailed, a.Filename, err)
	}
	if source == "" {
		return "", fmt.Errorf("%w: attachment: managed media returned an empty source for %q", errorspkg.ErrAttachmentStagingFailed, a.Filename)
	}
	validated, err := ValidateRemoteMediaSource(source)
	if err != nil {
		return "", fmt.Errorf("%w: %w for %q", errorspkg.ErrAttachmentStagingFailed, err, a.Filename)
	}
	source = validated
	cache[key] = source
	return source, nil
}

func fitsMediaEnvelope(caps Capabilities, usedParts int, usedBytes, nextBytes int64) bool {
	if caps.MaxMediaParts > 0 && usedParts >= caps.MaxMediaParts {
		return false
	}
	return caps.MaxMediaBytes <= 0 || nextBytes <= caps.MaxMediaBytes-usedBytes
}

func exceedsNativeMediaKinds(caps Capabilities, used map[string]struct{}, kind string) bool {
	if caps.MaxDistinctMediaKinds <= 0 {
		return false
	}
	if _, ok := used[kind]; ok {
		return false
	}
	return len(used) >= caps.MaxDistinctMediaKinds
}

func distinctMediaKindNote(kind, filename string, max int) llminfra.ContentPart {
	return textNote("%s %q attached, but this model accepts at most %d distinct native media type per turn; send it in a separate turn or choose a model that supports mixed media", kind, filename, max)
}

func unavailableMediaNote(kind, filename string, enabled bool, capability string, caps Capabilities, usedParts int, usedBytes, nextBytes int64) llminfra.ContentPart {
	if !enabled {
		return textNote("[UNAVAILABLE %s] %q is already attached, but the current model cannot see or inspect its pixels because it has no native %s input. Do not ask the user to re-attach it, do not infer or describe its contents, and do not claim to access the file. If the user asks about this media, say directly: the current model cannot see or inspect the pixels in the attached %s; to continue, switch to a %s-capable model, or describe or paste the relevant content here. Do not add a generic upload acknowledgement or offer unrelated assistance", strings.ToUpper(kind), filename, capability, kind, capability)
	}
	if caps.MaxMediaParts > 0 && usedParts >= caps.MaxMediaParts {
		return textNote("%s %q attached at its original position, but the model's inline-media item limit was reached; this quoted filename is authoritative and must not be inferred or renamed", kind, filename)
	}
	if caps.MaxMediaBytes > 0 && nextBytes > caps.MaxMediaBytes-usedBytes {
		return textNote("%s %q attached at its original position, but it exceeds the model's inline-media size budget; this quoted filename is authoritative and must not be inferred or renamed", kind, filename)
	}
	return textNote("%s %q attached, but it could not be sent natively", kind, filename)
}

func normalizedMIME(mime string) string {
	if i := strings.IndexByte(mime, ';'); i >= 0 {
		mime = mime[:i]
	}
	return strings.ToLower(strings.TrimSpace(mime))
}

func audioFormat(mime string) string {
	switch normalizedMIME(mime) {
	case "audio/wav", "audio/x-wav", "audio/wave":
		return "wav"
	case "audio/mpeg", "audio/mp3":
		return "mp3"
	default:
		return ""
	}
}

// dataURL builds a base64 data-URL ("data:<mime>;base64,<data>") for an inline image.
//
// dataURL 为内联图构造 base64 data-URL。
func dataURL(mime string, data []byte) string {
	return "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(data)
}

// inlineText wraps a text file's content as a labelled text part so the model knows the filename.
//
// inlineText 把文本文件内容包成带文件名标注的 text part，让模型知道文件名。
func inlineText(filename string, data []byte) string {
	// Cap oversized text the same way extracted documents are capped — an unbounded inline text/CSV
	// would otherwise silently overflow the model's context with no app-side guard or signal (F77).
	// 像抽取文档一样给超大文本封顶——否则无界内联 text/CSV 会静默撑爆模型 context、无护栏无信号（F77）。
	body, truncated := truncateForLLM(string(data))
	suffix := ""
	if truncated {
		suffix = " (truncated)"
	}
	if filename != "" {
		return fmt.Sprintf("Attached file %q%s:\n%s", filename, suffix, body)
	}
	if truncated {
		return body + "\n[truncated]"
	}
	return body
}

// textNote renders a degraded-attachment placeholder as a text part.
//
// textNote 把降级附件占位渲成 text part。
func textNote(format string, args ...any) llminfra.ContentPart {
	return llminfra.ContentPart{Type: llminfra.PartText, Text: "[" + fmt.Sprintf(format, args...) + "]"}
}

// extractDocPart text-extracts a document for a model that can't read it natively, capping the
// result to maxExtractedChars. With no extractor configured, or on an unsupported mime / extraction
// failure, it degrades to a placeholder note — never failing the turn.
//
// extractDocPart 为不能原生读文档的模型抽取文本，截断到 maxExtractedChars。无 extractor、或 mime
// 不支持 / 抽取失败时，降级为占位——绝不让回合失败。
func (s *Service) extractDocPart(ctx context.Context, a *attachmentdomain.Attachment, data []byte) llminfra.ContentPart {
	if s.extractor == nil {
		return textNote("document %q attached, but text extraction is unavailable for this model", a.Filename)
	}
	text, err := s.extractor.Extract(ctx, a.MimeType, data)
	if err != nil {
		s.log.Warn("attachmentapp.ToContentParts: document extraction failed, degrading",
			zap.String("attachment_id", a.ID), zap.String("mime", a.MimeType), zap.Error(err))
		return textNote("document %q attached, but its text could not be extracted", a.Filename)
	}
	body, truncated := truncateForLLM(text)
	suffix := ""
	if truncated {
		suffix = ", truncated"
	}
	return llminfra.ContentPart{
		Type: llminfra.PartText,
		Text: fmt.Sprintf("Attached document %q (text-extracted%s):\n%s", a.Filename, suffix, body),
	}
}

// maxExtractedChars caps inlined extracted text (~100K tokens at ~4 chars/token, aligning with
// LibreChat's default fileTokenLimit). The head is kept — a document leads with its substance.
//
// maxExtractedChars 截断内联抽取文本（~4 字符/token 下约 100K token，对齐 LibreChat 默认
// fileTokenLimit）。保头部——文档开头即正文。
const maxExtractedChars = 400_000

// truncateForLLM caps s to maxExtractedChars runes, returning the (possibly trimmed) text and
// whether it was trimmed. A byte-length check short-circuits the common small-file case.
//
// truncateForLLM 把 s 截到 maxExtractedChars 个 rune，返回（可能裁过的）文本 + 是否裁过。字节长度
// 预检短路常见小文件。
func truncateForLLM(s string) (string, bool) {
	if len(s) <= maxExtractedChars { // bytes ≥ runes, so within cap by bytes ⇒ within cap by runes
		return s, false
	}
	r := []rune(s)
	if len(r) <= maxExtractedChars {
		return s, false
	}
	return string(r[:maxExtractedChars]), true
}
