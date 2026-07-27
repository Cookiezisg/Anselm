// Package attachment is the domain layer for user-uploaded files attached to chat turns: a
// content-addressed blob (the bytes, stored on disk by SHA-256) plus a metadata row (att_).
// The bytes NEVER enter SQLite — the blob lives under the workspace, the row carries only
// identity (sha / filename / mime / size / kind). Multiple rows may reference one blob
// (content-addressed dedup). Kind classifies how the file reaches the LLM in a chat turn:
// image → vision block, document/text → inline-or-extract, audio/video → extraction (deferred,
// pluggable). Pure structs + the storage contract; upload / download / GC orchestration is in app.
//
// Package attachment 是聊天回合上传文件的 domain 层：一个内容寻址的 blob（字节按 SHA-256 存盘）
// + 一条元数据行（att_）。字节**绝不进 SQLite**——blob 在 workspace 下，行只承载身份
// （sha / 文件名 / mime / 大小 / 类别）。多行可指同一 blob（内容寻址 dedup）。Kind 决定文件如何
// 进 LLM（聊天回合）：image→vision 块、document/text→内联或抽取、audio/video→抽取（延后、可插）。
// 纯 struct + 存储契约；上传/下载/GC 编排在 app。
package attachment

import (
	"context"
	"path/filepath"
	"strings"
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Attachment is one uploaded file's metadata row. SHA256 is the content-addressed key into
// the blob store (identical uploads dedup to one blob, many rows). A business/Log table with
// soft-delete (D1): a deleted row is a tombstone; its blob is reclaimed by GC once no live row
// references the sha.
//
// Attachment 是一个上传文件的元数据行。SHA256 是 blob 存储的内容寻址键（相同上传 dedup 成一个
// blob、多行）。业务表软删（D1）：删行留墓碑；当无活跃行引用该 sha 时 blob 由 GC 回收。
type Attachment struct {
	ID          string     `db:"id,pk"              json:"id"` // att_<16hex>
	WorkspaceID string     `db:"workspace_id,ws"    json:"-"`
	SHA256      string     `db:"sha256"             json:"sha256"`
	Filename    string     `db:"filename"           json:"filename"`
	MimeType    string     `db:"mime_type"          json:"mimeType"`
	SizeBytes   int64      `db:"size_bytes"         json:"sizeBytes"`
	Kind        string     `db:"kind"               json:"kind"`
	CreatedAt   time.Time  `db:"created_at,created" json:"createdAt"`
	DeletedAt   *time.Time `db:"deleted_at,deleted" json:"-"`

	// Provenance — WHO minted this row and INSIDE WHAT (WRK-082 H5.7). Recorded, not yet enforced.
	//
	// ADR 0014 left one debt written down: a receipt is forgeable text, so a tool can hand back a
	// JSON blob naming an attachment it never produced. Today that is harmless — single user, and
	// pkg/orm isolates every read by workspace — but the day this becomes multi-user, the consumption
	// chokepoint has to verify ownership BEFORE expanding, and it can only verify what was recorded.
	// Rows minted before these columns existed can never be back-filled, which is the whole argument
	// for adding them now rather than then.
	//
	// Source is the producer's own name (the same vocabulary the receipt stamps: generate_video,
	// function_artifact, mcp…); "" means a person picked a file. The two origin columns name the
	// execution it was minted inside — a conversation, a flowrun, or neither.
	//
	// 溯源——**谁**铸了这一行、铸在**什么之内**(H5.7)。**只记录、尚不执行**。
	//
	// ADR 0014 留下过一笔写在纸上的债:receipt 是可伪造的文本,故一个工具可以交回一段点名了它从未产出过
	// 的附件的 JSON。今天无害——单用户,且 pkg/orm 逐次读都按 workspace 隔离——但这东西变成多用户的那天,
	// 消费咽喉必须在展开**之前**校验归属,而它只能校验**被记下来过**的东西。在这几列存在之前铸的行
	// **永远补不回来**,这正是「现在加、而不是到时候再加」的全部理由。
	//
	// Source 是产地自己的名字(与 receipt 盖的是同一套词表:generate_video / function_artifact / mcp…);
	// ""=某个人挑了个文件。两个 origin 列指出它被铸在哪一次执行之内——一个对话、一次 flowrun,或者都不是。
	Source               string `db:"source"                 json:"source,omitempty"`
	OriginConversationID string `db:"origin_conversation_id" json:"-"`
	OriginFlowrunID      string `db:"origin_flowrun_id"      json:"-"`
	// OriginToolCallID is the one provenance column that is ENFORCED (WRK-082 H5.8): the tool_result
	// chokepoint expands an attachment only when this call is the call that minted it.
	// OriginToolCallID 是唯一**被执行**的溯源列(H5.8):tool_result 咽喉只在「本次调用就是铸它的那次调用」
	// 时才展开一份附件。
	OriginToolCallID string `db:"origin_tool_call_id" json:"-"`
}

// Kind buckets an upload by how it reaches the LLM. image → vision; document / text → text
// (inline or extracted); audio / video → extraction (pluggable, deferred); other → opaque.
//
// Kind 按文件如何进 LLM 分桶。image→vision；document/text→文本（内联或抽取）；audio/video→抽取
// （可插、延后）；other→不透明。
const (
	KindImage    = "image"
	KindDocument = "document"
	KindText     = "text"
	KindAudio    = "audio"
	KindVideo    = "video"
	KindOther    = "other"
)

var (
	ErrNotFound            = errorspkg.New(errorspkg.KindNotFound, "ATTACHMENT_NOT_FOUND", "attachment not found")
	ErrTooLarge            = errorspkg.New(errorspkg.KindTooLarge, "ATTACHMENT_TOO_LARGE", "file exceeds the 50 MB limit")
	ErrEmpty               = errorspkg.New(errorspkg.KindInvalid, "ATTACHMENT_EMPTY", "empty file")
	ErrBadUpload           = errorspkg.New(errorspkg.KindInvalid, "ATTACHMENT_BAD_UPLOAD", "malformed multipart upload or missing 'file' field")
	ErrPlaybackUnsupported = errorspkg.New(
		errorspkg.KindUnsupportedMedia,
		"ATTACHMENT_PLAYBACK_UNSUPPORTED",
		"attachment is not playable audio",
	)
)

// KindFromMIME classifies an upload by mime type (a "; charset=…" suffix is stripped), with a
// filename-extension fallback for the generic application/octet-stream case.
//
// KindFromMIME 按 mime 类型分类（剥 "; charset=…" 后缀），对 application/octet-stream 等泛型用
// 文件扩展名兜底。
func KindFromMIME(mime, filename string) string {
	m := strings.ToLower(strings.TrimSpace(mime))
	if i := strings.IndexByte(m, ';'); i >= 0 {
		m = strings.TrimSpace(m[:i])
	}
	switch {
	case strings.HasPrefix(m, "image/"):
		return KindImage
	case strings.HasPrefix(m, "audio/"):
		return KindAudio
	case strings.HasPrefix(m, "video/"):
		return KindVideo
	case m == "application/pdf", isOfficeMIME(m):
		return KindDocument
	case strings.HasPrefix(m, "text/"), isTextualMIME(m):
		return KindText
	}
	switch strings.ToLower(filepath.Ext(filename)) {
	case ".pdf", ".docx", ".xlsx", ".pptx", ".odt", ".epub":
		return KindDocument
	case ".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".heif":
		return KindImage
	case ".mp3", ".wav", ".m4a", ".flac", ".ogg":
		return KindAudio
	case ".mp4", ".mov", ".avi", ".webm", ".mkv":
		return KindVideo
	case ".txt", ".md", ".markdown", ".json", ".csv", ".tsv", ".xml", ".yaml", ".yml", ".html", ".htm",
		".go", ".py", ".js", ".ts", ".java", ".c", ".cpp", ".h", ".rs", ".rb", ".php", ".sh", ".sql":
		return KindText
	}
	return KindOther
}

func isOfficeMIME(m string) bool {
	switch m {
	case "application/vnd.openxmlformats-officedocument.wordprocessingml.document", // docx
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",         // xlsx
		"application/vnd.openxmlformats-officedocument.presentationml.presentation", // pptx
		"application/vnd.oasis.opendocument.text",                                   // odt
		"application/epub+zip": // epub
		return true
	}
	return false
}

func isTextualMIME(m string) bool {
	switch m {
	case "application/json", "application/xml", "application/yaml", "application/x-yaml",
		"application/javascript", "application/csv", "application/x-sh", "application/sql":
		return true
	}
	return false
}

// Repository is the metadata storage contract; workspace isolation + soft-delete are applied by
// the orm layer from ctx. The blob bytes live in a separate content-addressed store (app port).
//
// Repository 是元数据存储契约；workspace 隔离 + 软删由 orm 层据 ctx 施加。blob 字节在另一个内容
// 寻址存储（app 端口）。
type Repository interface {
	Insert(ctx context.Context, a *Attachment) error
	Get(ctx context.Context, id string) (*Attachment, error)
	GetBatch(ctx context.Context, ids []string) ([]*Attachment, error)
	SoftDelete(ctx context.Context, id string) error

	// List returns every live attachment row in the ctx workspace (newest first) — the discovery
	// surface for the list_attachments tool / catalog source. Distinct from ListLiveSHAs (which
	// projects to GC sha strings): this carries full metadata rows for the LLM to reference by id.
	//
	// List 返 ctx workspace 内每条活跃附件行（新→旧）——list_attachments 工具 / catalog source 的
	// 发现面。与 ListLiveSHAs（投影成 GC sha 串）不同：本方法带完整元数据行，供 LLM 按 id 引用。
	List(ctx context.Context) ([]*Attachment, error)

	// ListLiveSHAs returns the distinct sha256 of every live (non-deleted) attachment in the
	// ctx workspace — the keep-set for blob GC.
	//
	// ListLiveSHAs 返 ctx workspace 内每个活跃（未删）附件的去重 sha256——blob GC 的保留集。
	ListLiveSHAs(ctx context.Context) ([]string, error)
}
