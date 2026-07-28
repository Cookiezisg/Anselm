// Package voice is the domain layer for cloned voices (WRK-082 H9) — the local half of a resource
// that actually lives UPSTREAM. A row is a pointer: the user's name for a voice, the provider it
// was enrolled with, and the id that provider minted. Synthesis then passes that id as its `voice`.
//
// **The row is not the resource, and that shapes every rule here.** Deleting a row without deleting
// the upstream registration leaks a voice nobody can see or reclaim; enrolling twice under one name
// would leave the first registration orphaned the same way. So names are unique per workspace, and
// deletion is defined as "upstream first, then the row".
//
// **Voices are INVENTORY, not quota.** A daily allowance refills; an enrolled voice persists
// upstream until deleted and costs money once at creation. That is why the cap is a count of rows
// (delete one to make room), not a per-day counter.
//
// Package voice 是克隆音色的 domain 层(H9)——一个真正住在**上游**的资源的本地那一半。一行是一个
// **指针**:用户给音色起的名、登记时用的 provider、以及该 provider 铸出的 id。合成时把那个 id 当
// `voice` 传过去。
//
// **行不是资源,而这决定了这里的每一条规则。** 删了行却没删上游登记,会漏下一个谁也看不见、谁也收不回
// 的音色;同名登记两次会以同样的方式让第一次的登记变成孤儿。故名字**每 workspace 唯一**,而删除被
// 定义为「先上游、后行」。
//
// **音色是库存、不是配额。** 日额度会续,而一个已登记的音色在上游**一直存在**直到被删,且创建时花一次
// 钱。这正是上限为什么是**行数**(删一个才腾得出位)、而不是每日计数器。
package voice

import (
	"context"
	"time"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// Errors — each names a physical fact, not a policy mood.
//
// 错误——每个都命名一个物理事实,而非某种政策情绪。
var (
	// ErrNotFound: no such voice in this workspace.
	ErrNotFound = errorspkg.New(errorspkg.KindNotFound, "VOICE_NOT_FOUND", "voice not found")
	// ErrNameTaken: the name is already pointing at an upstream registration. Enrolling over it
	// would orphan that one. 该名已指向一个上游登记;覆盖它会让那一个变成孤儿。
	ErrNameTaken = errorspkg.New(errorspkg.KindConflict, "VOICE_NAME_TAKEN", "a voice with this name already exists — delete it first")
	// ErrInventoryFull: the per-workspace voice inventory is full. Inventory, not quota: nothing
	// refills tomorrow, so the remedy is deleting one — which the message must say.
	// 音色**库存**已满。是库存不是配额:明天不会自动腾出,故补救办法是删一个——消息必须这么说。
	ErrInventoryFull = errorspkg.New(errorspkg.KindConflict, "VOICE_INVENTORY_FULL", "voice inventory is full — delete a voice to make room")
	// ErrNameRequired: an unnamed voice is unusable — the name IS how a later synthesis asks for it.
	ErrNameRequired = errorspkg.New(errorspkg.KindInvalid, "VOICE_NAME_REQUIRED", "voice name is required")
)

// Voice is one enrolled voice: a local name pointing at an upstream registration.
//
// Voice 是一个已登记的音色:一个指向上游登记的本地名字。
type Voice struct {
	ID          string `db:"id,pk"           json:"id"`
	WorkspaceID string `db:"workspace_id,ws" json:"-"`
	Name        string `db:"name"            json:"name"`
	Provider    string `db:"provider"        json:"provider"`
	// UpstreamID is what the provider minted and what synthesis passes as `voice`. Losing it
	// strands the upstream registration — nothing else can address it.
	// UpstreamID 是 provider 铸出的东西,也是合成时作为 `voice` 传的值。丢了它,上游那个登记就搁浅了
	// ——再没有别的东西能寻址到它。
	UpstreamID string `db:"upstream_id" json:"upstreamId"`
	// SourceAttachmentID is the clip it was cloned from — kept so a user can hear what a voice was
	// made of, and so an audit can answer "whose voice is this" without guessing.
	// SourceAttachmentID 是它克隆自的那段音频——留着,使用户能听见一个音色由什么做成,也使审计能回答
	// 「这是谁的声音」而不必猜。
	SourceAttachmentID string    `db:"source_attachment_id" json:"sourceAttachmentId"`
	CreatedAt          time.Time `db:"created_at"           json:"createdAt"`
}

// Repository is the voices port.
//
// Repository 是音色端口。
type Repository interface {
	Create(ctx context.Context, v *Voice) error
	List(ctx context.Context) ([]*Voice, error)
	GetByName(ctx context.Context, name string) (*Voice, error)
	Delete(ctx context.Context, id string) error
}
