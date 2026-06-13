package handlers

import (
	"net/http"

	"go.uber.org/zap"

	skillapp "github.com/sunweilin/forgify/backend/internal/app/skill"
	skilldomain "github.com/sunweilin/forgify/backend/internal/domain/skill"
	responsehttpapi "github.com/sunweilin/forgify/backend/internal/transport/httpapi/response"
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
//
// Register 挂载 skill 端点。List 返回全集（文件式，不分页）。
func (h *SkillHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/skills", h.List)
	mux.HandleFunc("POST /api/v1/skills", h.Create)
	mux.HandleFunc("GET /api/v1/skills/{name}", h.Get)
	mux.HandleFunc("PUT /api/v1/skills/{name}", h.Replace)
	mux.HandleFunc("DELETE /api/v1/skills/{name}", h.Delete)
	mux.HandleFunc("POST /api/v1/skills/{nameAction}", h.postOnSkill) // {name}:activate
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
		http.NotFound(w, r)
		return
	}
	switch action {
	case "activate":
		h.activate(w, r, name)
	default:
		http.NotFound(w, r)
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
