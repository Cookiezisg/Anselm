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
	"path/filepath"
	"strings"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	limitspkg "github.com/sunweilin/anselm/backend/internal/pkg/limits"
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
	a := &attachmentdomain.Attachment{
		ID:        idgenpkg.New("att"),
		SHA256:    sha,
		Filename:  filepath.Base(filename), // display only; blob is keyed by sha, not name
		MimeType:  mime,
		SizeBytes: int64(len(data)),
		Kind:      attachmentdomain.KindFromMIME(mime, filename),
	}
	if err := s.repo.Insert(ctx, a); err != nil {
		return nil, err
	}
	return a, nil
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
	// RemoteMedia, when set by the composition root for the managed gateway, replaces inline
	// image/video data URLs with a short-lived remote source. This package owns the decision of
	// which attachment kinds may use it; bootstrap owns the transport implementation.
	//
	// RemoteMedia 由 composition root 仅为受管网关注入时，会把内联 image/video data URL 换成短期
	// remote source。本包拥有哪些附件类型可使用它的判断；bootstrap 拥有传输实现。
	RemoteMedia *RemoteMedia
}

// RemoteMediaUploader stages one immutable byte sequence and returns its provider-fetchable,
// expiring HTTPS URL. It is a narrow application port so attachment rendering never depends on a
// concrete HTTP client or gateway implementation.
//
// RemoteMediaUploader 暂存一份不可变字节并返回 provider 可拉取、会过期的 HTTPS URL。它是窄应用端口，
// 使附件渲染永不依赖具体 HTTP client 或网关实现。
type RemoteMediaUploader interface {
	Upload(ctx context.Context, baseURL, installID, mime string, data []byte) (string, error)
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
}

// ToContentParts resolves attachment ids into provider-agnostic LLM content parts for one user turn
// (the chat loop prepends the user's own text part, then sends; each provider renders the parts into
// its own wire). Mapping by Kind:
//   - image    → image_url (data-URL) when caps.Vision; else a text note (degrade — don't send a
//     part the model would reject).
//   - text     → the file's content inlined as a text part (cheap, universal).
//   - document → caps.NativeDocs ? a file part (PDF handed over raw, read natively) : sandbox
//     text-extracted, token-capped text — with a placeholder note if no extractor / extraction fails.
//   - video → video_url when caps.Video and the attachment is an MP4; else a text note.
//   - audio → input_audio when caps.Audio and it is WAV/MP3; else a text note.
//   - other → a text placeholder.
//
// Order follows ids. A missing/unreadable blob is skipped with a warning — a stale id must never
// fail the turn (best-effort, like a dangling mention).
//
// ToContentParts 把附件 id 解析成与 provider 无关的 LLM 内容块，供一个 user 回合（chat loop 前面拼上
// 用户文本 part 再发；各家渲成自家 wire）。按 Kind 映射：image→image_url（data-URL，仅 caps.Vision；
// 否则文字提示降级）；text→文件内容内联 text part；document→caps.NativeDocs ? file part（PDF 原样递交、
// 原生读）: sandbox 抽取文本（token 截断），无 extractor / 抽取失败则占位；audio/video/other→文字占位
// （那些 extractor 是未来插件）。顺序随 ids；缺失/不可读 blob 告警跳过——陈旧 id 绝不让回合失败。
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
			if caps.Vision && caps.RemoteMedia != nil {
				source, err := stagedMediaURL(ctx, caps.RemoteMedia, remoteURLs, a, data)
				if err != nil {
					return nil, err
				}
				out = append(out, llminfra.ContentPart{Type: llminfra.PartImageURL, ImageURL: source})
			} else if caps.Vision && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				out = append(out, llminfra.ContentPart{Type: llminfra.PartImageURL, ImageURL: dataURL(a.MimeType, data)})
				mediaParts++
				mediaBytes += int64(len(data))
			} else {
				out = append(out, unavailableMediaNote("image", a.Filename, caps.Vision, "vision", caps, mediaParts, mediaBytes, int64(len(data))))
			}
		case attachmentdomain.KindVideo:
			if caps.Video && normalizedMIME(a.MimeType) == "video/mp4" && caps.RemoteMedia != nil {
				source, err := stagedMediaURL(ctx, caps.RemoteMedia, remoteURLs, a, data)
				if err != nil {
					return nil, err
				}
				out = append(out, llminfra.ContentPart{Type: llminfra.PartVideoURL, VideoURL: source})
			} else if caps.Video && normalizedMIME(a.MimeType) == "video/mp4" && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				out = append(out, llminfra.ContentPart{Type: llminfra.PartVideoURL, VideoURL: dataURL("video/mp4", data)})
				mediaParts++
				mediaBytes += int64(len(data))
			} else if caps.Video && normalizedMIME(a.MimeType) != "video/mp4" {
				out = append(out, textNote("video %q attached, but this model accepts inline video only as MP4", a.Filename))
			} else {
				out = append(out, unavailableMediaNote("video", a.Filename, caps.Video, "video", caps, mediaParts, mediaBytes, int64(len(data))))
			}
		case attachmentdomain.KindAudio:
			if caps.Audio && audioFormat(a.MimeType) != "" && fitsMediaEnvelope(caps, mediaParts, mediaBytes, int64(len(data))) {
				out = append(out, llminfra.ContentPart{
					Type: llminfra.PartInputAudio, MediaType: normalizedMIME(a.MimeType),
					Data: base64.StdEncoding.EncodeToString(data),
				})
				mediaParts++
				mediaBytes += int64(len(data))
			} else if caps.Audio && audioFormat(a.MimeType) == "" {
				out = append(out, textNote("audio %q attached, but this model accepts inline audio only as WAV or MP3", a.Filename))
			} else {
				out = append(out, unavailableMediaNote("audio", a.Filename, caps.Audio, "audio", caps, mediaParts, mediaBytes, int64(len(data))))
			}
		case attachmentdomain.KindText:
			out = append(out, llminfra.ContentPart{Type: llminfra.PartText, Text: inlineText(a.Filename, data)})
		case attachmentdomain.KindDocument:
			if caps.NativeDocs {
				out = append(out, llminfra.ContentPart{
					Type:      llminfra.PartFile,
					MediaType: a.MimeType,
					Data:      base64.StdEncoding.EncodeToString(data),
					Filename:  a.Filename,
				})
			} else {
				out = append(out, s.extractDocPart(ctx, a, data))
			}
		default:
			out = append(out, textNote("file %q (%s) attached; content extraction is not yet available", a.Filename, a.Kind))
		}
	}
	return out, nil
}

func stagedMediaURL(ctx context.Context, remote *RemoteMedia, cache map[string]string, a *attachmentdomain.Attachment, data []byte) (string, error) {
	if remote == nil || remote.Uploader == nil || remote.BaseURL == "" || remote.InstallID == "" {
		return "", fmt.Errorf("attachment: managed media destination is unavailable")
	}
	key := a.SHA256 + "\x00" + normalizedMIME(a.MimeType)
	if source := cache[key]; source != "" {
		return source, nil
	}
	source, err := remote.Uploader.Upload(ctx, remote.BaseURL, remote.InstallID, a.MimeType, data)
	if err != nil {
		return "", fmt.Errorf("attachment: stage %q for managed media: %w", a.Filename, err)
	}
	if source == "" {
		return "", fmt.Errorf("attachment: managed media returned an empty source for %q", a.Filename)
	}
	cache[key] = source
	return source, nil
}

func fitsMediaEnvelope(caps Capabilities, usedParts int, usedBytes, nextBytes int64) bool {
	if caps.MaxMediaParts > 0 && usedParts >= caps.MaxMediaParts {
		return false
	}
	return caps.MaxMediaBytes <= 0 || nextBytes <= caps.MaxMediaBytes-usedBytes
}

func unavailableMediaNote(kind, filename string, enabled bool, capability string, caps Capabilities, usedParts int, usedBytes, nextBytes int64) llminfra.ContentPart {
	if !enabled {
		return textNote("%s %q attached, but the current model has no native %s input", kind, filename, capability)
	}
	if caps.MaxMediaParts > 0 && usedParts >= caps.MaxMediaParts {
		return textNote("%s %q attached, but the model's inline-media item limit was reached", kind, filename)
	}
	if caps.MaxMediaBytes > 0 && nextBytes > caps.MaxMediaBytes-usedBytes {
		return textNote("%s %q attached, but it exceeds the model's inline-media size budget", kind, filename)
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
