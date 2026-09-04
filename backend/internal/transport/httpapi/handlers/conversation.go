package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"

	"go.uber.org/zap"

	conversationapp "github.com/sunweilin/anselm/backend/internal/app/conversation"
	conversationdomain "github.com/sunweilin/anselm/backend/internal/domain/conversation"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// ConversationHandler serves the 5 /api/v1/conversations/* CRUD endpoints plus the whole residency surface:
// the projection (`GET /{id}/workdir`), the rail's grouping and its two bulk actions, and the three git
// actions (`workdir:switch-branch` / `:create-branch` / `:add-worktree`). The conversation-scoped usage
// aggregate and system-prompt-preview are chat data (message_blocks token sum / prompt assembly) and live
// on ChatHandler, not here.
//
// ConversationHandler 提供 /api/v1/conversations/* 的 5 个 CRUD 端点 + 驻地的**整个**面:投影
// （`GET /{id}/workdir`）、rail 的分组与它那两个批量动作、以及三个 git 动作（`workdir:switch-branch` /
// `:create-branch` / `:add-worktree`）。conversation-scoped usage 汇总 + system-prompt-preview 端点属
// chat 数据（message_blocks token 求和 / prompt 拼装），归 ChatHandler。
type ConversationHandler struct {
	svc *conversationapp.Service
	log *zap.Logger
}

// NewConversationHandler constructs the handler.
//
// NewConversationHandler 构造 handler。
func NewConversationHandler(svc *conversationapp.Service, log *zap.Logger) *ConversationHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &ConversationHandler{svc: svc, log: log.Named("handlers.conversation")}
}

// Register wires the endpoints onto mux.
//
// Register 把端点挂到 mux。
func (h *ConversationHandler) Register(mux Registrar) {
	mux.HandleFunc("POST /api/v1/conversations", h.Create)
	mux.HandleFunc("GET /api/v1/conversations", h.List)
	// The literal `workdir-groups` segment must be registered alongside `{id}` — Go's ServeMux prefers the
	// more specific pattern, so a literal never gets swallowed by the wildcard (same shape as
	// `GET /documents/tree` beside `GET /documents/{id}`).
	// 字面段 `workdir-groups` 与 `{id}` 并存——Go ServeMux 取更具体的模式，故字面段绝不被通配吞掉（与
	// `GET /documents/tree` 挨着 `GET /documents/{id}` 同形）。
	mux.HandleFunc("GET /api/v1/conversations/workdir-groups", h.WorkDirGroups)
	mux.HandleFunc("POST /api/v1/conversations:archive-workdir", h.ArchiveWorkDir)
	mux.HandleFunc("POST /api/v1/conversations:delete-workdir", h.DeleteWorkDir)
	mux.HandleFunc("GET /api/v1/conversations/{id}", h.Get)
	mux.HandleFunc("PATCH /api/v1/conversations/{id}", h.Update)
	mux.HandleFunc("DELETE /api/v1/conversations/{id}", h.Delete)
	mux.HandleFunc("GET /api/v1/conversations/{id}/workdir", h.WorkDir)
	// The three residency GIT actions (WD2 + WD3) ride the `workdir` SUB-RESOURCE rather than the
	// conversation itself (`{id}:switch-branch`), for a physical reason: Go's ServeMux allows ONE handler per
	// pattern, and `POST /api/v1/conversations/{idAction}` is already claimed by ChatHandler's
	// :cancel/:seen/:fork/:retry dispatcher — so a conversation-level `:action` here would have to be switched
	// from another handler's file. On the sub-resource each is its own literal segment and its own route, the
	// same shape as `POST /conversations/{id}/sandbox-envs:reset-all`. It also reads truer: these act on the
	// RESIDENCY, which is precisely what `workdir` names.
	// 三个驻地 **git** 动作（WD2 + WD3）骑在 `workdir` **子资源**上、而不是对话本身（`{id}:switch-branch`），理由
	// 是物理的:Go ServeMux 每个模式只许**一个**处理器，而 `POST /api/v1/conversations/{idAction}` 已被
	// ChatHandler 的 :cancel/:seen/:fork/:retry 派发器占了——故在此写一个对话级 `:action` 就得从**别人**的文件里
	// switch。挂在子资源上，每一个都是自己的字面段、自己的路由，与 `POST /conversations/{id}/sandbox-envs:reset-all`
	// 同形。它也读得更真:这些动作作用于**驻地**，而 `workdir` 正是驻地的名字。
	mux.HandleFunc("POST /api/v1/conversations/{id}/workdir:switch-branch", h.SwitchBranch)
	mux.HandleFunc("POST /api/v1/conversations/{id}/workdir:create-branch", h.CreateBranch)
	mux.HandleFunc("POST /api/v1/conversations/{id}/workdir:add-worktree", h.AddWorktree)
}

type createConversationRequest struct {
	Title string `json:"title"`
}

// updateConversationRequest uses pointer fields so absent vs explicit values stay distinct.
// hasModelOverride records whether the modelOverride key was present at all (so the handler can
// tell "leave unchanged" from "explicitly set to null").
//
// updateConversationRequest 用指针字段区分「未传」与「显式传值」。hasModelOverride 记录
// modelOverride key 是否出现（区分「不动」与「显式 null 清除」）。
type updateConversationRequest struct {
	Title             *string                            `json:"title,omitempty"`
	SystemPrompt      *string                            `json:"systemPrompt,omitempty"`
	AttachedDocuments *[]documentdomain.AttachedDocument `json:"attachedDocuments,omitempty"`
	Archived          *bool                              `json:"archived,omitempty"`
	Pinned            *bool                              `json:"pinned,omitempty"`
	ModelOverride     *modeldomain.ModelRef              `json:"modelOverride,omitempty"`
	hasModelOverride  bool
	// WorkDir needs no `has` companion: unlike modelOverride, its cleared value is the empty STRING, so
	// `{"workDir":""}` decodes to a non-nil pointer to "" and says "unmount" all by itself. An absent key
	// is the nil pointer = leave unchanged, as with every other field here.
	//
	// WorkDir 不需要 `has` 伴生字段:不同于 modelOverride,它清除后的值是**空字符串**,故 `{"workDir":""}`
	// 解出一个指向 "" 的非 nil 指针、它自己就说出了「退出驻地」。缺键即 nil 指针 = 不动,与此处其余字段一致。
	WorkDir *string `json:"workDir,omitempty"`
}

// UnmarshalJSON detects whether `modelOverride` was present as a key (vs absent), to distinguish
// "leave unchanged" from "explicitly clear to null" — the tristate the per-thread override needs.
// It stays STRICT (DisallowUnknownFields) like decodeJSON: this custom unmarshal shadows the
// transport's strict decoder, so without this a typo'd field (e.g. "titel") would silently no-op
// instead of a 400 — the same silent-drop inconsistency every other PATCH rejects.
//
// UnmarshalJSON 探测 `modelOverride` 是否在 JSON 中出现（区分「不动」与「显式 null 清除」）——
// 即线程级 override 需要的三态。它像 decodeJSON 一样保持**严格**（DisallowUnknownFields）:此自定义
// unmarshal 遮蔽了 transport 的严格解码器,不加则拼错的字段(如 "titel")会静默 no-op 而非 400——正是其余
// PATCH 都拒的静默丢弃不一致。
func (r *updateConversationRequest) UnmarshalJSON(data []byte) error {
	type raw updateConversationRequest
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode((*raw)(r)); err != nil {
		return err
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(data, &m); err == nil {
		_, r.hasModelOverride = m["modelOverride"]
	}
	return nil
}

func (h *ConversationHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createConversationRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	c, err := h.svc.Create(r.Context(), req.Title)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, c)
}

func (h *ConversationHandler) List(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()
	p, err := responsehttpapi.ParsePage(r)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	// archived: absent/else = active only (default); "true"/"1"/"archived" = archived only; "all" =
	// both (the rail's "show archived" — archived rows carry archived=true for the gray dot).
	// archived：缺省/其余 = 仅活跃（默认）；"true"/"1"/"archived" = 仅归档；"all" = 两者（rail「显示已归档」，归档行带 archived=true 供灰点）。
	var archive conversationdomain.ArchiveScope
	switch q.Get("archived") {
	case "all":
		archive = conversationdomain.ArchiveAll
	case "true", "1", "archived":
		archive = conversationdomain.ArchiveArchived
	default:
		archive = conversationdomain.ArchiveActive
	}
	// sort: "created" = pinned-first then creation order; "name" = pinned-first then title A–Z
	// (case-insensitive); anything else (incl absent) = "activity" (pinned-first then most-recently-
	// active, the default). Each sort keys its own keyset column, so switching sort MUST reset pagination.
	// sort："created" = 置顶优先再创建序；"name" = 置顶优先再 title A–Z（大小写不敏感）；其余（含缺省）= "activity"
	// （置顶优先再最近活跃，默认）。每种排序键各自的 keyset 列，故切换排序**必须重置分页**。
	// pinned: absent = both (the long-standing default); "true"/"1" = pinned only; "false"/"0" = unpinned
	// only. The grouped rail (WD1.5) asks for the two halves separately so each thread renders exactly once.
	// pinned：缺省 = 两者（长期默认）；"true"/"1" = 仅置顶；"false"/"0" = 仅未置顶。分组后的 rail（WD1.5）分别取
	// 两半，使每条线程恰好渲一次。
	var pinned conversationdomain.PinScope
	switch q.Get("pinned") {
	case "true", "1":
		pinned = conversationdomain.PinPinned
	case "false", "0":
		pinned = conversationdomain.PinUnpinned
	default:
		pinned = conversationdomain.PinAny
	}
	// workDir needs the three states a plain Get() cannot tell apart, so it reads PRESENCE with Has(): the
	// key ABSENT = no residency filter at all (every conversation), the key PRESENT AND EMPTY (`?workDir=`)
	// = only the UNMOUNTED threads (the rail's Recents section), a value = only that residency (one rail
	// group). `Get` alone returns "" for both of the first two, which would make the Recents section
	// silently list the whole workspace.
	// workDir 要三个状态，而裸 Get() 分不清，故用 Has() 读**键是否出现**:键**缺席** = 完全不按驻地过滤（每条
	// 对话）、键**出现且为空**（`?workDir=`）= **仅未挂**的线程（rail 的「最近」段）、有值 = 仅该驻地（一个 rail
	// 组）。只用 Get 时前两者都是 ""，那会让「最近」段静默地列出整个 workspace。
	var workDir *string
	if q.Has("workDir") {
		v := q.Get("workDir")
		workDir = &v
	}
	filter := conversationdomain.ListFilter{
		Cursor:  p.Cursor,
		Limit:   p.Limit,
		Search:  q.Get("search"),
		Archive: archive,
		Sort:    conversationdomain.ListSort(q.Get("sort")),
		Pinned:  pinned,
		WorkDir: workDir,
	}
	items, next, err := h.svc.List(r.Context(), filter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	total, err := h.svc.Count(r.Context(), filter)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.SetTotalCount(w, total)
	responsehttpapi.Paged(w, items, next, next != "")
}

func (h *ConversationHandler) Get(w http.ResponseWriter, r *http.Request) {
	c, err := h.svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

// Update is a partial-update PATCH; modelOverride is tristate (absent / null=clear / object=set).
//
// Update 是部分更新 PATCH；modelOverride 三态（缺 / null=清除 / object=设置）。
func (h *ConversationHandler) Update(w http.ResponseWriter, r *http.Request) {
	var req updateConversationRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	in := conversationapp.UpdateInput{
		Title:             req.Title,
		SystemPrompt:      req.SystemPrompt,
		AttachedDocuments: req.AttachedDocuments,
		Archived:          req.Archived,
		Pinned:            req.Pinned,
		WorkDir:           req.WorkDir,
	}
	if req.hasModelOverride {
		in.ModelOverride = &req.ModelOverride // **ModelRef tristate; req.ModelOverride nil = clear
	}
	c, err := h.svc.Update(r.Context(), r.PathValue("id"), in)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, c)
}

// WorkDir returns the residency's live projection for one conversation: the mounted path plus what is
// true about it right now (exists / git repo / branch / dirty, plus the repository's local `branches[]` and
// its `worktrees[]`). Recomputed per request and cached nowhere — the filesystem and git are the truth, so a
// directory the user just deleted, or a branch they just switched in their own terminal, reads as it now IS.
//
// The two LISTS (WD2 / WD3) are what make the menu's git segment actionable rather than a read-out — you
// cannot offer to switch to a branch you never listed. Both stay BOUNDED and cursor-free: `branches[]` is
// `refs/heads` only (the branches this person created — a fetched `refs/remotes` is the set that runs to
// thousands), and `worktrees[]` is however many checkouts exist, the current one included and flagged.
//
// N4: a derived BOUNDED PROJECTION, so no cursor and no `nextCursor`. It is not a stored collection at
// all — it is ONE object computed on demand, in the same class as `GET /storage-stat` rather than the
// trigger-schedule kind that takes real window parameters. It accepts NO parameters, so there is nothing
// to clamp and nothing to 422 over, and it never reports truncation.
//
// An UNMOUNTED conversation returns 200 with the zero projection (empty path, exists=false), not 404:
// "this thread has no residency" is a successful answer to the question, and the button that calls this
// has to render the unmounted state too. Only an unknown conversation is a 404.
//
// WorkDir 返回某对话驻地的活投影：已挂路径 + 此刻关于它为真的东西（存在 / 是否 git 仓库 / 分支 / 脏，外加仓库的
// 本地 `branches[]` 与它的 `worktrees[]`）。逐请求现算、零缓存——文件系统与 git 才是真相，故用户刚删掉的目录、或
// 刚在自己终端里切的分支，读作它**现在的样子**。
//
// 那两个**列表**（WD2 / WD3）正是让菜单 git 段可**操作**、而非一段读数的东西——没列出来的分支，无从提议切过去。
// 两者都保持**有界**、无游标:`branches[]` **只**取 `refs/heads`（这个人自己建的那些分支——会跑到上千条的是 fetch
// 来的 `refs/remotes`），`worktrees[]` 则是实际存在多少份 checkout 就多少条、含当前那一份并标出它。
//
// N4：派生的**有界投影**，故无游标、无 `nextCursor`。它根本不是已存集合——它是**一个**按需现算的对象，与
// `GET /storage-stat` 同类，而**不是** trigger-schedule 那种收真窗口参数的一类。它**不收任何参数**，故无从
// 钳制、无从 422，也从不上报截断。
//
// **未挂**对话返 200 + 零投影（空路径、exists=false）、**不是** 404：「这条线程没有驻地」是对该问题的一个
// **成功**回答，而调用它的那个按钮也得渲染未挂态。只有对话本身不存在才是 404。
func (h *ConversationHandler) WorkDir(w http.ResponseWriter, r *http.Request) {
	info, err := h.svc.WorkDirInfo(r.Context(), r.PathValue("id"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, info)
}

// workDirBranchRequest / workDirWorktreeRequest are the bodies of the residency's git actions. The worktree
// one takes a NAME and never a path: the target directory is DERIVED (repo sibling `<repo>-<name>`, branch
// `wt/<name>`, the `make worktree` convention), which is both why an app-made worktree is indistinguishable
// from a discipline-made one and why this endpoint cannot be talked into writing a checkout anywhere else on
// the disk.
//
// workDirBranchRequest / workDirWorktreeRequest 是驻地 git 动作的 body。worktree 那个收**名字**、绝不收路径:
// 目标目录是**派生**的（仓库兄弟位 `<repo>-<name>`、分支 `wt/<name>`，即 `make worktree` 约定）——正是这一点既让
// app 建的 worktree 与纪律建的无从区分，也让这个端点无法被说服往磁盘别处写出一份 checkout。
type workDirBranchRequest struct {
	Branch string `json:"branch"`
}

type workDirWorktreeRequest struct {
	Name string `json:"name"`
}

// SwitchBranch handles `POST /api/v1/conversations/{id}/workdir:switch-branch` — move the residency's work
// tree onto an EXISTING local branch (WD2, N5 `:action` on the workdir sub-resource). Returns 200 + the
// freshly re-probed `WorkDirInfo`, because one switch changes several of its fields at once and a client
// forced to re-GET is a client that paints one frame of the old branch.
//
// THE GUARDRAIL: a dirty work tree is refused 422 `CONVERSATION_WORK_DIR_DIRTY`, whose message carries the
// next step (commit or stash, then switch). Never `--force`, never a silent stash — see the sentinel for the
// full reasoning. Unknown branch → 404 `CONVERSATION_BRANCH_NOT_FOUND`; an illegal name → 422
// `CONVERSATION_INVALID_BRANCH`; a residency that is not a repository → 422
// `CONVERSATION_WORK_DIR_NOT_GIT_REPO`; anything else git refuses → 422 `CONVERSATION_GIT_FAILED` carrying
// git's own stderr in `details.git`.
//
// SwitchBranch 处理 `POST /api/v1/conversations/{id}/workdir:switch-branch`——把驻地的工作树移到一条**已存在**
// 的本地分支上（WD2，workdir 子资源上的 N5 `:action`）。返 200 + **重探**后的 `WorkDirInfo`，因为一次切换同时改
// 它的好几个字段，而一个被迫再 GET 一次的客户端就是一个会画出一帧旧分支的客户端。
//
// **护栏**:脏工作树拒为 422 `CONVERSATION_WORK_DIR_DIRTY`，其 message 带着下一步（先提交或贮藏，再切）。绝不
// `--force`、绝不静默 stash——完整理由见那个 sentinel。未知分支 → 404 `CONVERSATION_BRANCH_NOT_FOUND`;非法名 →
// 422 `CONVERSATION_INVALID_BRANCH`;驻地不是仓库 → 422 `CONVERSATION_WORK_DIR_NOT_GIT_REPO`;git 拒的其余一切
// → 422 `CONVERSATION_GIT_FAILED`，git 自己的 stderr 在 `details.git` 里。
func (h *ConversationHandler) SwitchBranch(w http.ResponseWriter, r *http.Request) {
	var req workDirBranchRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	info, err := h.svc.SwitchBranch(r.Context(), r.PathValue("id"), req.Branch)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, info)
}

// CreateBranch handles `POST /api/v1/conversations/{id}/workdir:create-branch` — create a branch at the
// residency's current HEAD and switch onto it (WD2). Returns 200 + the re-probed projection.
//
// A DIRTY work tree is deliberately ALLOWED here, unlike the switch: the new branch starts at the commit
// already checked out, so the work tree does not change by a byte and no conflict can exist — refusing the
// single most common branching flow ("I started, then realized this deserves its own branch") would be a
// guardrail against nothing. An existing name → 409 `CONVERSATION_BRANCH_EXISTS` (a create and a switch are
// different intents; quietly doing the second is how a user lands on somebody else's work).
//
// CreateBranch 处理 `POST /api/v1/conversations/{id}/workdir:create-branch`——在驻地当前 HEAD 上建一条分支并切
// 过去（WD2）。返 200 + 重探后的投影。
//
// 与切换不同，此处**刻意允许**脏工作树:新分支起点就是已 checkout 的那个 commit，故工作树一个字节都不变、冲突不
// 可能存在——拒掉最常见的那条开分支流程（「先动手，然后意识到这该有自己的分支」）等于守一道什么都不守的护栏。名字
// 已存在 → 409 `CONVERSATION_BRANCH_EXISTS`（新建与切换是两种意图，静默执行后者正是用户落到别人的活上面的方式）。
func (h *ConversationHandler) CreateBranch(w http.ResponseWriter, r *http.Request) {
	var req workDirBranchRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	info, err := h.svc.CreateBranch(r.Context(), r.PathValue("id"), req.Branch)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, info)
}

// AddWorktree handles `POST /api/v1/conversations/{id}/workdir:add-worktree` — the WD3 one-shot: create a
// parallel worktree for this conversation AND move the residency into it. Returns 200 + the projection of
// the NEW directory, so the client's next paint is already the new residency.
//
// Body `{name}`, never a path. The target is derived by the repository's own `make worktree` convention: a
// SIBLING of the work tree's root named `<root>-<name>`, on branch `wt/<name>`. An existing `wt/<name>`
// branch is REUSED exactly as the Makefile reuses it (`make worktree-rm` keeps the branch on purpose, so
// re-opening a worktree on it is the documented way back); an existing DIRECTORY is refused 409
// `CONVERSATION_WORKTREE_EXISTS` with the path in `details.path`; if the filesystem half completes but the
// residency row cannot be persisted, `CONVERSATION_WORKTREE_RESIDENCY_UPDATE_FAILED` carries the created path
// so the client can explain the honest half-state. An illegal name → 422
// `CONVERSATION_INVALID_WORKTREE_NAME` (stricter than a branch name — it becomes a directory segment too,
// which is what keeps the derived path provably a sibling).
//
// Moving the residency goes through the same PATCH path the folder button uses, so the thread gets its
// durable `marker` block and its `conversation.work_dir` echo for free (E1/E2: no new stream, no new frame).
//
// AddWorktree 处理 `POST /api/v1/conversations/{id}/workdir:add-worktree`——WD3 那条一条龙:为本对话建一份平行
// worktree **并**把驻地移进去。返 200 + **新**目录的投影，故客户端下一帧画的已经是新驻地。
//
// body `{name}`、绝不是路径。目标按本仓自己的 `make worktree` 约定派生:工作树根的**兄弟**位、名为 `<根>-<name>`、
// 分支 `wt/<name>`。已存在的 `wt/<name>` 分支被**复用**，与 Makefile 的复用完全一致（`make worktree-rm` **刻意**
// 保留分支，故在它之上重开一份 worktree 正是被写进文档的回头路）;已存在的**目录**拒为 409
// `CONVERSATION_WORKTREE_EXISTS`，路径在 `details.path` 里；如果文件系统一半已完成但驻地行无法持久化，
// `CONVERSATION_WORKTREE_RESIDENCY_UPDATE_FAILED` 会带出已创建路径，使客户端能诚实解释半成功状态。非法名 → 422
// （比分支名更严——它**也会**成为一个目录段，而正是这份更严让派生路径可证明地落在兄弟位）。
//
// 移动驻地走的是文件夹按钮用的同一条 PATCH 路径，故线程白得它那条持久 `marker` 块与 `conversation.work_dir`
// 回声（E1/E2:不加流、不加帧型）。
func (h *ConversationHandler) AddWorktree(w http.ResponseWriter, r *http.Request) {
	var req workDirWorktreeRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	info, err := h.svc.AddWorktree(r.Context(), r.PathValue("id"), req.Name)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, info)
}

// WorkDirGroups returns the rail's residency grouping: one row per directory some UNPINNED thread lives
// in, `{workDir, activeCount, archivedCount, lastMessageAt}`, most-recently-active first.
//
// It exists because the rail pages FOREVER. Grouping one page client-side would make membership and counts
// DRIFT as the user scrolls — the head would state a number that changes while nothing changes — so the
// grouping is computed over the whole workspace in one GROUP BY.
//
// The counted set is the UNPINNED threads: a pinned thread is hoisted into the rail's own Pinned section and
// must appear exactly once, so counting it here would make the head's number disagree with the rows under
// it. The same rule governs `:archive-workdir` / `:delete-workdir`, which is what lets ONE number head the
// group AND inventory its confirm dialog.
//
// N4 — a BOUNDED PROJECTION, "zero-parameter" form: no cursor, no `nextCursor`, and NO parameters at all
// (hence nothing to clamp, nothing to 422 over, no truncation to report). It is bounded by how many
// directories a person mounts, which is a human-scale set like `workspaces` — not by how many conversations
// exist. The two counts are reported SEPARATELY rather than behind an `?archived=` scope precisely to keep
// it parameterless: the rail's toggle picks or sums them, and a bulk action (deliberately scope-blind)
// inventories the sum.
//
// WorkDirGroups 返回 rail 的驻地分组:每个住着**未置顶**线程的目录一行，`{workDir, activeCount, archivedCount,
// lastMessageAt}`，最近活跃在前。
//
// 它存在，是因为 rail **无限**翻页。在一窗内做客户端分组会让成员与计数随滚动**漂移**——组头会报出一个在什么
// 都没变时自己会变的数——故分组对整个 workspace 一次 GROUP BY 算出。
//
// 被计数的集合是**未置顶**线程:置顶线程被提到 rail 自己的置顶段、必须恰好出现一次，故在此计入它会让组头的数与
// 它下面的行不一致。`:archive-workdir` / `:delete-workdir` 遵守同一条规则，正是这一点让**一个**数既作组头、
// 又作它的确认框盘点。
//
// N4——**有界投影**的「零参数」形:无游标、无 `nextCursor`、**不收任何参数**（故无从钳制、无从 422、从不上报
// 截断）。它的有界性来自「一个人会挂多少个目录」，那是与 `workspaces` 同量级的人类尺度集合——**不是**来自有多少
// 条对话。两个计数**分开**上报、而不是藏在 `?archived=` 范围之后，正是为了让它保持零参数:rail 的开关自行取其一
// 或求和，而批量动作（刻意对范围盲）盘点二者之和。
func (h *ConversationHandler) WorkDirGroups(w http.ResponseWriter, r *http.Request) {
	groups, err := h.svc.WorkDirGroups(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, groups)
}

// workDirActionRequest is the body of both residency-wide actions: which group.
//
// workDirActionRequest 是两个驻地级动作的 body:哪个组。
type workDirActionRequest struct {
	WorkDir string `json:"workDir"`
}

// ArchiveWorkDir handles `POST /api/v1/conversations:archive-workdir` — file away one residency group's
// threads in ONE request. Returns `{workDir, archived}` where `archived` is how many conversations actually
// CHANGED (already-archived rows are not counted twice).
//
// A collection-level `:action` (N5), sibling of `POST /notifications:mark-all-read`. The rail needs it
// rather than a loop of N PATCHes for reasons that are not about speed: a loop can be interrupted half-way,
// leaving a group the user asked to file away neither filed nor unfiled, and a loop's N-th failure has
// nothing honest to report. One statement in one transaction has exactly two outcomes.
//
// An EMPTY `workDir` is refused 400 `INVALID_REQUEST`: the unmounted threads are a legitimate list FILTER
// but not a group — they have no folder head and no ⋯ menu — so accepting it would let one request file away
// every thread in the workspace that never picked a directory. A non-absolute path is 422
// `CONVERSATION_INVALID_WORK_DIR` (WD1's rule: a relative root roots nothing).
//
// ArchiveWorkDir 处理 `POST /api/v1/conversations:archive-workdir`——**一个**请求收起一个驻地组的线程。返回
// `{workDir, archived}`，其中 `archived` 是真正**改变**了的对话数（已归档的行不重复计入）。
//
// 集合级 `:action`（N5），与 `POST /notifications:mark-all-read` 同族。rail 需要它而不是 N 次 PATCH 的循环，
// 理由与速度无关:循环可能半途被打断，把用户要收起的一组留在既非收起也非未收起的状态，而循环的第 N 次失败没有
// 任何诚实的话可报。一个事务里的一条语句恰好只有两种结局。
//
// **空** `workDir` 拒为 400 `INVALID_REQUEST`:未挂的线程是一个正当的列表**过滤**、但不是一个**组**——它们没有
// 文件夹头、没有 ⋯ 菜单——故接受它会让一个请求收起本 workspace 里每一条从未选过目录的线程。非绝对路径为 422
// `CONVERSATION_INVALID_WORK_DIR`（WD1 的规则:相对的根扎不住任何东西）。
func (h *ConversationHandler) ArchiveWorkDir(w http.ResponseWriter, r *http.Request) {
	var req workDirActionRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	n, err := h.svc.ArchiveWorkDir(r.Context(), req.WorkDir)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"workDir": req.WorkDir, "archived": n})
}

// DeleteWorkDir handles `POST /api/v1/conversations:delete-workdir` — delete one residency group's threads
// in ONE request. Returns `{workDir, deleted}`.
//
// WHAT IT DELETES, exactly: the `deleted_at` stamp on those `conversations` rows, plus each thread's
// relation edges and touchpoint ledger (derived indexes of a thread that no longer exists — the same
// cascade a single DELETE performs). WHAT IT DOES NOT DELETE: any message row. `messages` /
// `message_blocks` are D1 Log tables — no `deleted_at`, never physically deleted — so the transcripts stay
// on disk byte-for-byte. And nothing on the FILESYSTEM: the residency is a string on a row, read here as a
// grouping key; the directory it names is never touched. That is why the UI's word for this action is
// «delete all conversations» and never «delete the directory».
//
// Scope-BLIND across archive states, on purpose: a destructive action must not silently depend on which
// view toggle happens to be on. Pinned threads of that residency are NOT deleted — pinning is the user
// saying "this one matters", and a folder-wide sweep should not carry it off.
//
// DeleteWorkDir 处理 `POST /api/v1/conversations:delete-workdir`——**一个**请求删除一个驻地组的线程。返回
// `{workDir, deleted}`。
//
// **它到底删了什么**:那些 `conversations` 行上的 `deleted_at` 戳，加上每条线程的 relation 边与触点台账（一条
// 已不存在的线程的派生索引——与单条 DELETE 完全相同的级联）。**它没有删什么**:任何消息行。`messages` /
// `message_blocks` 是 D1 Log 表——无 `deleted_at`、绝不物理删——故那些逐字记录**逐字节留在盘上**。以及**文件
// 系统上什么都没动**:驻地是行上的一个字符串，在此被当作分组键读;它点出的那个目录绝不被碰。正因如此，UI 给这个
// 动作的用词是「删除全部对话」、而**绝不是**「删除目录」。
//
// **跨归档态、对范围盲**，刻意如此:一个破坏性动作不该静默地取决于哪个视图开关正好开着。该驻地的**置顶**线程
// **不**被删——置顶是用户在说「这条我在意」，一次目录级的清扫不该把它一并带走。
func (h *ConversationHandler) DeleteWorkDir(w http.ResponseWriter, r *http.Request) {
	var req workDirActionRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	n, err := h.svc.DeleteWorkDir(r.Context(), req.WorkDir)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, map[string]any{"workDir": req.WorkDir, "deleted": n})
}

func (h *ConversationHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("id")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
