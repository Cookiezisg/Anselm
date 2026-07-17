package handlers

import (
	"net/http"

	"go.uber.org/zap"

	storageapp "github.com/sunweilin/anselm/backend/internal/app/storage"
	responsehttpapi "github.com/sunweilin/anselm/backend/internal/transport/httpapi/response"
)

// StorageHandler serves the settings storage panel's database-file surface: GET /storage-stat (the
// DB size + reclaimable dead space it displays) and POST /storage:compact (the "Compact database"
// button — a synchronous VACUUM). Machine-level and guarded like /limits and /data-dir: the whole
// install has one .db file, so the workspace header is identity, not isolation.
//
// StorageHandler 提供设置存储面板的数据库文件面：GET /storage-stat（它显示的库大小 + 可回收死空间）与
// POST /storage:compact（「压缩数据库」按钮——一次同步 VACUUM）。与 /limits、/data-dir 一样机器级且受守：
// 整个安装只有一个 .db 文件，故 workspace header 是身份、非隔离。
type StorageHandler struct {
	svc *storageapp.Service
	log *zap.Logger
}

func NewStorageHandler(svc *storageapp.Service, log *zap.Logger) *StorageHandler {
	if log == nil {
		log = zap.NewNop()
	}
	return &StorageHandler{svc: svc, log: log.Named("handlers.storage")}
}

func (h *StorageHandler) Register(mux Registrar) {
	mux.HandleFunc("GET /api/v1/storage-stat", h.Stat)
	mux.HandleFunc("POST /api/v1/storage:compact", h.Compact)
}

// Stat returns the DB's logical size and dead (reclaimable) bytes. N4-exempt: a single machine-level
// system resource, one object, no cursor — a bounded resource, not a collection.
//
// Stat 返回 DB 的逻辑大小与死（可回收）字节。N4 豁免：单一机器级系统资源、单个对象、无游标——有界资源、非集合。
func (h *StorageHandler) Stat(w http.ResponseWriter, r *http.Request) {
	stat, err := h.svc.Stat(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, stat)
}

// Compact runs the full VACUUM and returns the bytes reclaimed once it completes. 200 not 202: VACUUM
// is a synchronous, few-seconds blocking operation with a concrete result, not an async stream — the
// client waits (button spinner) and gets the reclaimed figure back. Failure (disk-full) → 500
// STORAGE_COMPACT_FAILED, DB untouched.
//
// Compact 跑全量 VACUUM，完成后返回回收的字节数。200 而非 202：VACUUM 是同步、阻塞几秒、有具体结果的操作，
// 不是异步流——客户端等待（按钮转圈）并拿回回收数。失败（磁盘满）→ 500 STORAGE_COMPACT_FAILED，库不动。
func (h *StorageHandler) Compact(w http.ResponseWriter, r *http.Request) {
	res, err := h.svc.Compact(r.Context())
	if err != nil {
		responsehttpapi.FromDomainError(w, h.log, err)
		return
	}
	responsehttpapi.Success(w, http.StatusOK, res)
}
