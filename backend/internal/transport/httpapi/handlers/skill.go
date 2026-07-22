package handlers

import (
	"io"
	"mime"
	"net/http"
	"path"
	"strconv"
	"strings"

	"go.uber.org/zap"

	skillapp "github.com/sunweilin/anselm/backend/internal/app/skill"
	skilldomain "github.com/sunweilin/anselm/backend/internal/domain/skill"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// SkillHandler serves the skill REST surface (file-based: human-managed CRUD + manual activate).
//
// SkillHandler 提供 skill REST 面（文件式：人工管理 CRUD + 手动 activate）。
type SkillHandler struct {
	svc *skillapp.Service
	log *zap.Logger
}

func NewSkillHandler(svc *skillapp.Service, log *zap.Logger) *SkillHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &SkillHandler{svc: svc, log: log.Named("handlers.skill")}
}

// Register mounts the skill endpoints. List returns the full set (file-based, unpaginated).
// The files sub-resource (SKILL.md included) is the file-is-truth surface: raw bytes in and
// out, `{path...}` is the codebase's first trailing-wildcard route (WRK-076).
//
// Register 挂载 skill 端点。List 返回全集（文件式，不分页）。files 子资源（含 SKILL.md）是
// 文件即真相面：原始字节进出，`{path...}` 是全仓首条尾随通配路由（WRK-076）。
func (h *SkillHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/skills", h.List)
	mux.HandleFunc("POST /api/v1/skills", h.Create)
	mux.HandleFunc("GET /api/v1/skills/{name}", h.Get)
	mux.HandleFunc("PUT /api/v1/skills/{name}", h.Replace)
	mux.HandleFunc("DELETE /api/v1/skills/{name}", h.Delete)
	mux.HandleFunc("POST /api/v1/skills/{nameAction}", h.postOnSkill) // {name}:activate
	mux.HandleFunc("GET /api/v1/skills/{name}/files", h.ListFiles)
	mux.HandleFunc("GET /api/v1/skills/{name}/files/{path...}", h.ReadFile)
	mux.HandleFunc("PUT /api/v1/skills/{name}/files/{path...}", h.WriteFile)
	mux.HandleFunc("DELETE /api/v1/skills/{name}/files/{path...}", h.DeleteFile)
}

type createSkillRequest struct {
	Name                   string   `json:"name"`
	Description            string   `json:"description"`
	Body                   string   `json:"body"`
	AllowedTools           []string `json:"allowedTools"`
	Context                string   `json:"context"`
	Agent                  string   `json:"agent"`
	Arguments              []string `json:"arguments"`
	DisableModelInvocation bool     `json:"disableModelInvocation"`
	UserInvocable          bool     `json:"userInvocable"`
}

type replaceSkillRequest struct {
	Description            string   `json:"description"`
	Body                   string   `json:"body"`
	AllowedTools           []string `json:"allowedTools"`
	Context                string   `json:"context"`
	Agent                  string   `json:"agent"`
	Arguments              []string `json:"arguments"`
	DisableModelInvocation bool     `json:"disableModelInvocation"`
	UserInvocable          bool     `json:"userInvocable"`
}

type activateSkillRequest struct {
	Arguments []string `json:"arguments"`
}

func (h *SkillHandler) List(w http.ResponseWriter, r *http.Request) {
	items, err := h.svc.List(r.Context(), skilldomain.ListFilter{})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, items)
}

func (h *SkillHandler) Get(w http.ResponseWriter, r *http.Request) {
	sk, err := h.svc.Get(r.Context(), r.PathValue("name"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, sk)
}

// Create authors a skill via HTTP (source=user — the human-managed path).
//
// Create 经 HTTP 创作 skill（source=user——人工管理路径）。
func (h *SkillHandler) Create(w http.ResponseWriter, r *http.Request) {
	var req createSkillRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	sk, err := h.svc.Create(r.Context(), skillapp.SaveInput{
		Name:                   req.Name,
		Description:            req.Description,
		Body:                   req.Body,
		AllowedTools:           req.AllowedTools,
		Context:                req.Context,
		Agent:                  req.Agent,
		Arguments:              req.Arguments,
		DisableModelInvocation: req.DisableModelInvocation,
		UserInvocable:          req.UserInvocable,
		Source:                 skilldomain.SourceUser,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Created(w, sk)
}

func (h *SkillHandler) Replace(w http.ResponseWriter, r *http.Request) {
	var req replaceSkillRequest
	if err := decodeJSON(r, &req); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	sk, err := h.svc.Replace(r.Context(), skillapp.SaveInput{
		Name:                   r.PathValue("name"),
		Description:            req.Description,
		Body:                   req.Body,
		AllowedTools:           req.AllowedTools,
		Context:                req.Context,
		Agent:                  req.Agent,
		Arguments:              req.Arguments,
		DisableModelInvocation: req.DisableModelInvocation,
		UserInvocable:          req.UserInvocable,
		Source:                 skilldomain.SourceUser,
	})
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, sk)
}

func (h *SkillHandler) Delete(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.Delete(r.Context(), r.PathValue("name")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

// postOnSkill dispatches POST /skills/{name}:action (currently only :activate).
//
// postOnSkill 派发 POST /skills/{name}:action（当前仅 :activate）。
func (h *SkillHandler) postOnSkill(w http.ResponseWriter, r *http.Request) {
	name, action, ok := idAndAction(r, "nameAction")
	if !ok {
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
		return
	}
	switch action {
	case "activate":
		h.activate(w, r, name)
	default:
		responsehttpapi.FromDomainError(w, h.log, errorspkg.ErrNotFound)
	}
}

func (h *SkillHandler) activate(w http.ResponseWriter, r *http.Request, name string) {
	var req activateSkillRequest
	if r.ContentLength != 0 {
		if err := decodeJSON(r, &req); err != nil {
			responsehttpapi.FromDomainError(w, h.log, err)
			return
		}
	}
	out, err := h.svc.Activate(r.Context(), name, req.Arguments)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, out) // 裸结果,不裹 {output}(envelope 内层)
}

// ── files sub-resource（文件即真相面）──────────────────────────────────────────

func (h *SkillHandler) ListFiles(w http.ResponseWriter, r *http.Request) {
	files, err := h.svc.ListFiles(r.Context(), r.PathValue("name"))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, files)
}

// skillFileMime supplements the platform mime table for extensions skills actually bundle —
// mime.TypeByExtension is OS-table-backed and misses .md/.py & co on a bare system.
//
// skillFileMime 为 skill 实际捆绑的扩展名补充平台 mime 表——mime.TypeByExtension 依赖系统表，
// 裸机上查不到 .md/.py 等。
var skillFileMime = map[string]string{
	".md": "text/markdown; charset=utf-8", ".markdown": "text/markdown; charset=utf-8",
	".txt": "text/plain; charset=utf-8", ".py": "text/x-python; charset=utf-8",
	".sh": "text/x-shellscript; charset=utf-8", ".js": "text/javascript; charset=utf-8",
	".ts": "text/typescript; charset=utf-8", ".json": "application/json",
	".yaml": "application/yaml", ".yml": "application/yaml",
	".toml": "application/toml", ".csv": "text/csv; charset=utf-8",
}

// ReadFile streams one bundled file's raw bytes — mime sniffed from the extension (attachment
// precedent), never the JSON envelope.
//
// ReadFile 流出单个捆绑文件的原始字节——mime 按扩展名推断（attachment 先例），不走 JSON envelope。
func (h *SkillHandler) ReadFile(w http.ResponseWriter, r *http.Request) {
	rel := r.PathValue("path")
	data, err := h.svc.ReadFile(r.Context(), r.PathValue("name"), rel)
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	ext := strings.ToLower(path.Ext(rel))
	mt := skillFileMime[ext]
	if mt == "" {
		mt = mime.TypeByExtension(ext)
	}
	if mt == "" {
		mt = "application/octet-stream"
	}
	w.Header().Set("Content-Type", mt)
	w.Header().Set("Content-Length", strconv.Itoa(len(data)))
	// inline preview; strip quotes so the header can't be broken (attachment precedent).
	// 内联预览；剥引号防 header 被破坏（attachment 先例）。
	w.Header().Set("Content-Disposition", `inline; filename="`+strings.ReplaceAll(path.Base(rel), `"`, "")+`"`)
	_, _ = w.Write(data)
}

// WriteFile lands a raw byte body (no JSON wrapper). The transport cap is the bundled-file
// guard; the tighter 32KB manifest cap is enforced below (app/store) when the path IS the
// manifest.
//
// WriteFile 落原始字节体（无 JSON 包裹）。transport 封顶取附属文件护栏；路径为清单时更紧的
// 32KB 护栏由下层（app/store）执行。
func (h *SkillHandler) WriteFile(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, skilldomain.MaxFileBytes+1))
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, skilldomain.ErrFileTooLarge.WithCause(err))
		return
	}
	if len(body) > skilldomain.MaxFileBytes {
		responsehttpapi.FromDomainError(w, h.log, skilldomain.ErrFileTooLarge)
		return
	}
	if err := h.svc.WriteFile(r.Context(), r.PathValue("name"), r.PathValue("path"), body); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}

func (h *SkillHandler) DeleteFile(w http.ResponseWriter, r *http.Request) {
	if err := h.svc.DeleteFile(r.Context(), r.PathValue("name"), r.PathValue("path")); err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.NoContent(w)
}
