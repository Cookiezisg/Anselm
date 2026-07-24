// Package media owns media-ingestion identity. It is intentionally processor-agnostic in its
// first increment: callers can claim deduplicated work now, while image/video/audio processors
// and their workers attach later without changing cache semantics.
package media

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// AttachmentSource is deliberately the small read seam this service needs. It prevents a media
// worker from reaching around application boundaries into an attachment repository.
type AttachmentSource interface {
	Get(ctx context.Context, id string) (*attachmentdomain.Attachment, error)
	Download(ctx context.Context, id string) (*attachmentdomain.Attachment, []byte, error)
}

// ArtifactStore is a CAS separate from attachment originals. A derivative is always safe to
// regenerate, so its lifecycle must never share the original blob GC's keep-set.
type ArtifactStore interface {
	Put(ctx context.Context, data []byte) (sha256 string, err error)
	Get(ctx context.Context, sha256 string) ([]byte, error)
	Sweep(ctx context.Context, keep map[string]bool) (int, error)
}

// Processor is the deliberately narrow seam for deterministic local transforms and later remote
// perception adapters. It receives original bytes once per durable work item, never per ReAct
// sampling. Implementations must return bounded evidence and must not log source bytes/task text.
type Processor interface {
	Derive(ctx context.Context, attachment *attachmentdomain.Attachment, original []byte, derivative *mediadomain.Derivative) (DerivativeResult, error)
	Perceive(ctx context.Context, attachment *attachmentdomain.Attachment, original []byte, perception *mediadomain.Perception) (PerceptionResult, error)
}

type DerivativeResult struct {
	Data       []byte
	MimeType   string
	Width      int
	Height     int
	DurationMS int64
}

type PerceptionResult struct {
	CapsuleJSON  string
	InputTokens  int
	OutputTokens int
}

const (
	PreparationStatusNotRequired = "not_required"
	PreparationStatusPending     = mediadomain.StatusPending
	PreparationStatusRunning     = mediadomain.StatusRunning
	PreparationStatusReady       = mediadomain.StatusReady
	PreparationStatusFailed      = mediadomain.StatusFailed
	PreparationStatusUnavailable = "unavailable"
)

// Preparation is the small, UI-facing readiness surface for an attachment's app-managed media
// proxies. It is intentionally metadata only: no URLs, no bytes, no task-conditioned prompt text.
//
// Preparation 是面向 UI 的附件媒体准备状态面。它刻意只含元数据：无 URL、无字节、无任务化 prompt 文本。
type Preparation struct {
	Status    string `json:"status"`
	Target    string `json:"target,omitempty"`
	Width     int    `json:"width,omitempty"`
	Height    int    `json:"height,omitempty"`
	MimeType  string `json:"mimeType,omitempty"`
	SizeBytes int64  `json:"sizeBytes,omitempty"`
	ErrorCode string `json:"errorCode,omitempty"`
}

const (
	DerivativeThumbnail    = "thumbnail"
	DerivativeModelDefault = "model-default"
	DerivativeModelDetail  = "model-detail"
	DerivativeDocumentText = "document-text-v1"
)

const modelDefaultImageWait = 2 * time.Second

// ImageDerivativeParams is the stable, non-secret execution contract for deterministic image
// proxies. It is stored as canonical JSON so a worker can reproduce the exact transform represented
// by ParamsHash.
type ImageDerivativeParams struct {
	Version   int        `json:"version,omitempty"`
	MaxEdge   int        `json:"maxEdge,omitempty"`
	MaxWidth  int        `json:"maxWidth,omitempty"`
	MaxHeight int        `json:"maxHeight,omitempty"`
	Quality   int        `json:"quality,omitempty"`
	Format    string     `json:"format,omitempty"`
	Crop      *ImageCrop `json:"crop,omitempty"`
}

type ImageCrop struct {
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
}

type DocumentTextParams struct {
	Version int `json:"version"`
}

type Service struct {
	attachments AttachmentSource
	repo        mediadomain.Repository
	artifacts   ArtifactStore
	log         *zap.Logger

	mu        sync.Mutex
	processor Processor
	started   bool
	closing   bool
	runCtx    context.Context
	queue     chan job
	queued    map[string]bool
	stop      context.CancelFunc
	wg        sync.WaitGroup
}

type job struct {
	workspaceID string
	derivative  *mediadomain.Derivative
	perception  *mediadomain.Perception
}

func (j job) key() string {
	if j.derivative != nil {
		return "d:" + j.derivative.ID
	}
	return "p:" + j.perception.ID
}

func NewService(attachments AttachmentSource, repo mediadomain.Repository, artifacts ArtifactStore, log *zap.Logger) *Service {
	if attachments == nil || repo == nil || artifacts == nil || log == nil {
		panic("mediaapp.NewService: attachments, repo, artifacts, and logger are required")
	}
	return &Service{attachments: attachments, repo: repo, artifacts: artifacts, log: log, queue: make(chan job, 64), queued: map[string]bool{}}
}

// SetProcessor must run before Start. This lets bootstrap keep the durable media contract alive
// before M2/M3 processors land, without accidentally accepting a work item that no process can run.
func (s *Service) SetProcessor(processor Processor) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.started {
		panic("mediaapp.SetProcessor: called after Start")
	}
	s.processor = processor
}

// ClaimDerivative returns the one record for this exact original and canonical transform request.
// Encoding JSON through encoding/json gives deterministic map-key order; callers should pass a
// typed parameter struct whenever the request format is externally versioned.
func (s *Service) ClaimDerivative(ctx context.Context, attachmentID, kind string, params any) (*mediadomain.Derivative, bool, error) {
	if strings.TrimSpace(attachmentID) == "" || strings.TrimSpace(kind) == "" {
		return nil, false, mediadomain.ErrInvalidRequest
	}
	encoded, err := json.Marshal(params)
	if err != nil {
		return nil, false, fmt.Errorf("mediaapp.ClaimDerivative: params: %w", err)
	}
	a, err := s.attachments.Get(ctx, attachmentID)
	if err != nil {
		return nil, false, err
	}
	got, created, err := s.repo.ClaimDerivative(ctx, &mediadomain.Derivative{
		ID: idgenpkg.New("mdr"), AttachmentID: a.ID, Kind: strings.TrimSpace(kind),
		SourceSHA256: a.SHA256, ParamsHash: mediadomain.Hash(encoded), ParamsJSON: string(encoded), Status: mediadomain.StatusPending,
	})
	if err != nil {
		return nil, false, err
	}
	if created || got.Status == mediadomain.StatusPending {
		s.enqueue(ctx, job{derivative: got})
	}
	return got, created, nil
}

// ClaimPerception applies the same exact-source discipline to task-conditioned evidence. It stores
// only an opaque task digest; the later processor may store its bounded evidence capsule, never the
// original prompt or upstream raw response.
func (s *Service) ClaimPerception(ctx context.Context, attachmentID, kind, provider, model, task string, params any) (*mediadomain.Perception, bool, error) {
	if strings.TrimSpace(attachmentID) == "" || strings.TrimSpace(kind) == "" ||
		strings.TrimSpace(provider) == "" || strings.TrimSpace(model) == "" || strings.TrimSpace(task) == "" {
		return nil, false, mediadomain.ErrInvalidRequest
	}
	encoded, err := json.Marshal(params)
	if err != nil {
		return nil, false, fmt.Errorf("mediaapp.ClaimPerception: params: %w", err)
	}
	a, err := s.attachments.Get(ctx, attachmentID)
	if err != nil {
		return nil, false, err
	}
	got, created, err := s.repo.ClaimPerception(ctx, &mediadomain.Perception{
		ID: idgenpkg.New("mpr"), AttachmentID: a.ID, Kind: strings.TrimSpace(kind), SourceSHA256: a.SHA256,
		TaskHash: mediadomain.Hash([]byte(task)), Provider: strings.TrimSpace(provider), Model: strings.TrimSpace(model),
		ParamsHash: mediadomain.Hash(encoded), ParamsJSON: string(encoded), Status: mediadomain.StatusPending,
	})
	if err != nil {
		return nil, false, err
	}
	if created || got.Status == mediadomain.StatusPending {
		s.enqueue(ctx, job{perception: got})
	}
	return got, created, nil
}

// ModelDefaultImage returns a ready model-default image proxy when one exists. If it has not been
// generated yet, this method claims/enqueues the work and returns ready=false so the caller can fall
// back to the original for this turn without blocking the user.
func (s *Service) ModelDefaultImage(ctx context.Context, attachmentID string) ([]byte, string, bool, error) {
	derivative, _, err := s.ClaimDerivative(ctx, attachmentID, DerivativeModelDefault, ImageDerivativeParams{Version: 2, Quality: 90, Format: "auto"})
	if err != nil {
		return nil, "", false, err
	}
	derivative = s.waitReadyDerivative(ctx, derivative, modelDefaultImageWait)
	if derivative.Status != mediadomain.StatusReady || derivative.BlobSHA256 == "" {
		return nil, "", false, nil
	}
	data, err := s.artifacts.Get(ctx, derivative.BlobSHA256)
	if err != nil {
		return nil, "", false, fmt.Errorf("mediaapp.ModelDefaultImage: artifact: %w", err)
	}
	return data, derivative.MimeType, true, nil
}

// DocumentText returns cached extracted text for text/document tooling. It is intentionally a
// synchronous lazy cache rather than a worker job: extraction is requested only when an agent reads
// a document, and the ready derivative then prevents repeated sandbox extraction on later
// read_attachment / inspect_media calls for the same source.
func (s *Service) DocumentText(ctx context.Context, attachmentID string, extract func(context.Context, *attachmentdomain.Attachment, []byte) (string, error)) (string, error) {
	if strings.TrimSpace(attachmentID) == "" || extract == nil {
		return "", mediadomain.ErrInvalidRequest
	}
	a, err := s.attachments.Get(ctx, attachmentID)
	if err != nil {
		return "", err
	}
	encoded, err := json.Marshal(DocumentTextParams{Version: 1})
	if err != nil {
		return "", fmt.Errorf("mediaapp.DocumentText: params: %w", err)
	}
	derivative, _, err := s.repo.ClaimDerivative(ctx, &mediadomain.Derivative{
		ID:           idgenpkg.New("mdr"),
		AttachmentID: a.ID,
		Kind:         DerivativeDocumentText,
		SourceSHA256: a.SHA256,
		ParamsHash:   mediadomain.Hash(encoded),
		ParamsJSON:   string(encoded),
		Status:       mediadomain.StatusPending,
	})
	if err != nil {
		return "", err
	}
	if derivative.Status == mediadomain.StatusReady && derivative.BlobSHA256 != "" {
		data, err := s.artifacts.Get(ctx, derivative.BlobSHA256)
		if err == nil {
			return string(data), nil
		}
		s.log.Warn("media: document text artifact missing; regenerating", zap.String("work_id", derivative.ID), zap.Error(err))
	}
	derivative.Status, derivative.ErrorCode = mediadomain.StatusRunning, ""
	if err := s.repo.SaveDerivative(ctx, derivative); err != nil {
		return "", err
	}
	a, original, err := s.attachments.Download(ctx, attachmentID)
	if err == nil {
		var text string
		text, err = extract(ctx, a, original)
		if err == nil {
			sha, putErr := s.artifacts.Put(ctx, []byte(text))
			if putErr == nil {
				derivative.Status, derivative.BlobSHA256, derivative.MimeType = mediadomain.StatusReady, sha, "text/plain; charset=utf-8"
				derivative.SizeBytes, derivative.Width, derivative.Height, derivative.DurationMS = int64(len(text)), 0, 0, 0
				derivative.ErrorCode = ""
				if saveErr := s.repo.SaveDerivative(ctx, derivative); saveErr != nil {
					return "", saveErr
				}
				return text, nil
			}
			err = putErr
		}
	}
	if ctx.Err() != nil {
		derivative.Status, derivative.ErrorCode = mediadomain.StatusPending, ""
	} else {
		derivative.Status, derivative.ErrorCode = mediadomain.StatusFailed, "MEDIA_DERIVATIVE_FAILED"
	}
	_ = s.repo.SaveDerivative(reqctxpkg.Detached(derivative.WorkspaceID), derivative)
	return "", err
}

// Preparation returns and, for supported attachments, claims the durable preparation work needed by
// the default chat path. Images currently publish the model-default proxy status; other kinds have
// no app-managed preparation yet and return not_required.
//
// Preparation 返回并（对支持的附件）认领默认聊天路径所需的 durable 准备工作。当前 image 发布
// model-default 代理状态；其它 kind 尚无 app-managed preparation，返回 not_required。
func (s *Service) Preparation(ctx context.Context, attachmentID string) (Preparation, error) {
	a, err := s.attachments.Get(ctx, attachmentID)
	if err != nil {
		return Preparation{}, err
	}
	if a.Kind != attachmentdomain.KindImage {
		return Preparation{Status: PreparationStatusNotRequired}, nil
	}
	derivative, _, err := s.ClaimDerivative(ctx, attachmentID, DerivativeModelDefault, ImageDerivativeParams{Version: 2, Quality: 90, Format: "auto"})
	if err != nil {
		return Preparation{}, err
	}
	return preparationFromDerivative(derivative), nil
}

func preparationFromDerivative(derivative *mediadomain.Derivative) Preparation {
	if derivative == nil {
		return Preparation{Status: PreparationStatusUnavailable}
	}
	status := derivative.Status
	switch status {
	case mediadomain.StatusPending, mediadomain.StatusRunning, mediadomain.StatusReady, mediadomain.StatusFailed:
	default:
		status = PreparationStatusUnavailable
	}
	return Preparation{
		Status:    status,
		Target:    derivative.Kind,
		Width:     derivative.Width,
		Height:    derivative.Height,
		MimeType:  derivative.MimeType,
		SizeBytes: derivative.SizeBytes,
		ErrorCode: derivative.ErrorCode,
	}
}

func (s *Service) waitReadyDerivative(ctx context.Context, derivative *mediadomain.Derivative, maxWait time.Duration) *mediadomain.Derivative {
	if derivative.Status == mediadomain.StatusReady || maxWait <= 0 {
		return derivative
	}
	s.mu.Lock()
	canWait := s.started && !s.closing && s.processor != nil
	s.mu.Unlock()
	if !canWait {
		return derivative
	}
	deadline := time.NewTimer(maxWait)
	defer deadline.Stop()
	tick := time.NewTicker(10 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case <-ctx.Done():
			return derivative
		case <-deadline.C:
			return derivative
		case <-tick.C:
			got, _, err := s.repo.ClaimDerivative(ctx, derivative)
			if err != nil {
				return derivative
			}
			derivative = got
			switch derivative.Status {
			case mediadomain.StatusReady, mediadomain.StatusFailed, mediadomain.StatusCancelled:
				return derivative
			}
		}
	}
}

// Start recovers work interrupted by a prior crash, then drains durable pending work with one
// bounded worker. No processor means the contract is present but intentionally inert until the
// matching media family lands; pending rows remain truthful and recoverable.
func (s *Service) Start(workspaceIDs []string) {
	s.mu.Lock()
	if s.started {
		s.mu.Unlock()
		return
	}
	s.started = true
	processor := s.processor
	ctx, cancel := context.WithCancel(context.Background())
	s.stop = cancel
	s.runCtx = ctx
	s.mu.Unlock()

	for _, workspaceID := range workspaceIDs {
		wsCtx := reqctxpkg.Detached(workspaceID)
		if n, err := s.repo.RequeueRunning(wsCtx); err != nil {
			s.log.Warn("media: crash recovery failed", zap.String("workspace_id", workspaceID), zap.Error(err))
		} else if n > 0 {
			s.log.Info("media: requeued interrupted work", zap.String("workspace_id", workspaceID), zap.Int("count", n))
		}
		if processor != nil {
			s.enqueuePending(wsCtx)
		}
	}
	if processor != nil {
		s.wg.Add(1)
		go s.worker(ctx)
	}
}

// Close stops new processing and returns an interrupted item to pending rather than marking it as
// a user-visible failure. The next boot's RequeueRunning is the hard-crash counterpart.
func (s *Service) Close(ctx context.Context) {
	s.mu.Lock()
	s.closing = true
	stop := s.stop
	s.mu.Unlock()
	if stop == nil {
		return
	}
	stop()
	done := make(chan struct{})
	go func() { s.wg.Wait(); close(done) }()
	select {
	case <-done:
	case <-ctx.Done():
	}
}

// GC reclaims only unreferenced regenerated artifacts. Originals remain exclusively under the
// attachment service's GC policy.
func (s *Service) GC(ctx context.Context) (int, error) {
	shas, err := s.repo.ListReadyDerivativeBlobs(ctx)
	if err != nil {
		return 0, err
	}
	keep := make(map[string]bool, len(shas))
	for _, sha := range shas {
		keep[sha] = true
	}
	return s.artifacts.Sweep(ctx, keep)
}

func (s *Service) enqueuePending(ctx context.Context) {
	derivatives, err := s.repo.ListPendingDerivatives(ctx, 100)
	if err != nil {
		s.log.Warn("media: list pending derivatives failed", zap.Error(err))
		return
	}
	for _, derivative := range derivatives {
		s.enqueue(ctx, job{derivative: derivative})
	}
	perceptions, err := s.repo.ListPendingPerceptions(ctx, 100)
	if err != nil {
		s.log.Warn("media: list pending perceptions failed", zap.Error(err))
		return
	}
	for _, perception := range perceptions {
		s.enqueue(ctx, job{perception: perception})
	}
}

func (s *Service) enqueue(ctx context.Context, j job) {
	workspaceID, ok := reqctxpkg.GetWorkspaceID(ctx)
	if !ok {
		return // only a caller bug could reach here; the repository will have already rejected it.
	}
	s.mu.Lock()
	if !s.started || s.closing || s.processor == nil || s.queued[j.key()] {
		s.mu.Unlock()
		return
	}
	s.queued[j.key()] = true
	s.mu.Unlock()
	j.workspaceID = workspaceID
	select {
	case s.queue <- j:
	default:
		runCtx := s.runCtx
		go func() {
			select {
			case s.queue <- j:
			case <-runCtx.Done():
				s.mu.Lock()
				delete(s.queued, j.key())
				s.mu.Unlock()
			}
		}() // durable DB row remains the source of truth; don't block an HTTP caller.
	}
}

func (s *Service) worker(ctx context.Context) {
	defer s.wg.Done()
	for {
		select {
		case <-ctx.Done():
			return
		case j := <-s.queue:
			s.runJob(ctx, j)
			s.mu.Lock()
			delete(s.queued, j.key())
			s.mu.Unlock()
		}
	}
}

func (s *Service) runJob(ctx context.Context, j job) {
	wsCtx := reqctxpkg.SetWorkspaceID(ctx, j.workspaceID)
	if j.derivative != nil {
		s.runDerivative(wsCtx, j.derivative)
		return
	}
	s.runPerception(wsCtx, j.perception)
}

func (s *Service) runDerivative(ctx context.Context, derivative *mediadomain.Derivative) {
	derivative.Status, derivative.ErrorCode = mediadomain.StatusRunning, ""
	if err := s.repo.SaveDerivative(ctx, derivative); err != nil {
		s.log.Warn("media: derivative start persistence failed", zap.String("work_id", derivative.ID))
		return
	}
	a, original, err := s.attachments.Download(ctx, derivative.AttachmentID)
	if err == nil {
		result, processErr := s.processor.Derive(ctx, a, original, derivative)
		if processErr == nil {
			sha, putErr := s.artifacts.Put(ctx, result.Data)
			if putErr == nil {
				derivative.Status, derivative.BlobSHA256, derivative.MimeType = mediadomain.StatusReady, sha, result.MimeType
				derivative.SizeBytes, derivative.Width, derivative.Height, derivative.DurationMS = int64(len(result.Data)), result.Width, result.Height, result.DurationMS
				err = s.repo.SaveDerivative(ctx, derivative)
			} else {
				err = putErr
			}
		} else {
			err = processErr
		}
	}
	if err != nil {
		if ctx.Err() != nil {
			derivative.Status, derivative.ErrorCode = mediadomain.StatusPending, ""
		} else {
			derivative.Status, derivative.ErrorCode = mediadomain.StatusFailed, "MEDIA_DERIVATIVE_FAILED"
		}
		_ = s.repo.SaveDerivative(reqctxpkg.Detached(derivative.WorkspaceID), derivative)
		s.log.Warn("media: derivative processing failed", zap.String("work_id", derivative.ID))
	}
}

func (s *Service) runPerception(ctx context.Context, perception *mediadomain.Perception) {
	perception.Status, perception.ErrorCode = mediadomain.StatusRunning, ""
	if err := s.repo.SavePerception(ctx, perception); err != nil {
		s.log.Warn("media: perception start persistence failed", zap.String("work_id", perception.ID))
		return
	}
	a, original, err := s.attachments.Download(ctx, perception.AttachmentID)
	if err == nil {
		result, processErr := s.processor.Perceive(ctx, a, original, perception)
		if processErr == nil {
			perception.Status, perception.CapsuleJSON = mediadomain.StatusReady, result.CapsuleJSON
			perception.InputTokens, perception.OutputTokens = result.InputTokens, result.OutputTokens
			err = s.repo.SavePerception(ctx, perception)
		} else {
			err = processErr
		}
	}
	if err != nil {
		if ctx.Err() != nil {
			perception.Status, perception.ErrorCode = mediadomain.StatusPending, ""
		} else {
			perception.Status, perception.ErrorCode = mediadomain.StatusFailed, "MEDIA_PERCEPTION_FAILED"
		}
		_ = s.repo.SavePerception(reqctxpkg.Detached(perception.WorkspaceID), perception)
		s.log.Warn("media: perception processing failed", zap.String("work_id", perception.ID))
	}
}
