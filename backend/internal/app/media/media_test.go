package media

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

type fakeAttachments struct{ row *attachmentdomain.Attachment }

func (f fakeAttachments) Get(_ context.Context, id string) (*attachmentdomain.Attachment, error) {
	if f.row == nil || id != f.row.ID {
		return nil, attachmentdomain.ErrNotFound
	}
	return f.row, nil
}

func (f fakeAttachments) Download(_ context.Context, id string) (*attachmentdomain.Attachment, []byte, error) {
	row, err := f.Get(context.Background(), id)
	if err != nil {
		return nil, nil, err
	}
	return row, []byte("original"), nil
}

type fakeRepo struct {
	derivative *mediadomain.Derivative
	perception *mediadomain.Perception
}

func (f *fakeRepo) ClaimDerivative(_ context.Context, d *mediadomain.Derivative) (*mediadomain.Derivative, bool, error) {
	if f.derivative != nil && f.derivative.AttachmentID == d.AttachmentID && f.derivative.Kind == d.Kind && f.derivative.SourceSHA256 == d.SourceSHA256 && f.derivative.ParamsHash == d.ParamsHash {
		return f.derivative, false, nil
	}
	f.derivative = d
	return d, true, nil
}
func (f *fakeRepo) ClaimPerception(_ context.Context, p *mediadomain.Perception) (*mediadomain.Perception, bool, error) {
	f.perception = p
	return p, true, nil
}
func (f *fakeRepo) GetDerivative(_ context.Context, id string) (*mediadomain.Derivative, error) {
	if f.derivative == nil || f.derivative.ID != id {
		return nil, mediadomain.ErrNotFound
	}
	return f.derivative, nil
}
func (f *fakeRepo) GetPerception(_ context.Context, id string) (*mediadomain.Perception, error) {
	if f.perception == nil || f.perception.ID != id {
		return nil, mediadomain.ErrNotFound
	}
	return f.perception, nil
}
func (f *fakeRepo) SaveDerivative(context.Context, *mediadomain.Derivative) error { return nil }
func (f *fakeRepo) SavePerception(context.Context, *mediadomain.Perception) error { return nil }
func (f *fakeRepo) ListPendingDerivatives(context.Context, int) ([]*mediadomain.Derivative, error) {
	return nil, nil
}
func (f *fakeRepo) ListPendingPerceptions(context.Context, int) ([]*mediadomain.Perception, error) {
	return nil, nil
}
func (f *fakeRepo) RequeueRunning(context.Context) (int, error) { return 0, nil }
func (f *fakeRepo) ListReadyDerivativeBlobs(context.Context) ([]string, error) {
	return nil, nil
}

type fakeArtifacts struct {
	data map[string][]byte
}

func (f fakeArtifacts) Put(_ context.Context, data []byte) (string, error) {
	sha := mediadomain.Hash(data)
	if f.data != nil {
		f.data[sha] = data
	}
	return sha, nil
}
func (f fakeArtifacts) Get(_ context.Context, sha string) ([]byte, error) {
	return f.data[sha], nil
}
func (fakeArtifacts) Sweep(context.Context, map[string]bool) (int, error) { return 0, nil }

type fakeProcessor struct {
	mu      sync.Mutex
	derives int
	derived chan struct{}
	block   chan struct{}
}

func (f *fakeProcessor) Derive(_ context.Context, _ *attachmentdomain.Attachment, _ []byte, _ *mediadomain.Derivative) (DerivativeResult, error) {
	f.mu.Lock()
	f.derives++
	f.mu.Unlock()
	select {
	case f.derived <- struct{}{}:
	default:
	}
	if f.block != nil {
		<-f.block
	}
	return DerivativeResult{Data: []byte("proxy"), MimeType: "image/webp", Width: 320, Height: 240}, nil
}

func (f *fakeProcessor) Perceive(context.Context, *attachmentdomain.Attachment, []byte, *mediadomain.Perception) (PerceptionResult, error) {
	return PerceptionResult{CapsuleJSON: `{"summary":"ok"}`}, nil
}

func TestClaimDerivative_CanonicalParamsAndSourceAreTheIdentity(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, fakeArtifacts{}, zap.NewNop())
	first, created, err := svc.ClaimDerivative(context.Background(), "att_1", "model-default", map[string]any{"height": 2048, "width": 2048})
	if err != nil || !created {
		t.Fatalf("first claim: (%+v, %v, %v)", first, created, err)
	}
	again, created, err := svc.ClaimDerivative(context.Background(), "att_1", "model-default", map[string]any{"width": 2048, "height": 2048})
	if err != nil || created || again.ID != first.ID {
		t.Fatalf("map order must not recompute: (%+v, %v, %v)", again, created, err)
	}
	if first.SourceSHA256 != "source-a" || first.Status != mediadomain.StatusPending {
		t.Fatalf("derivative did not bind original source/pending status: %+v", first)
	}
	if first.ParamsJSON != `{"height":2048,"width":2048}` {
		t.Fatalf("canonical params json = %q", first.ParamsJSON)
	}
}

func TestClaimPerception_HashesTaskInsteadOfPersistingIt(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, fakeArtifacts{}, zap.NewNop())
	secretTask := "请找出录音里提到的客户名字"
	p, created, err := svc.ClaimPerception(context.Background(), "att_1", "audio-evidence", "qwen", "qwen3.5-omni-plus", secretTask, struct{ Detail string }{"default"})
	if err != nil || !created {
		t.Fatalf("claim: (%+v, %v, %v)", p, created, err)
	}
	if p.TaskHash == secretTask || p.TaskHash != mediadomain.Hash([]byte(secretTask)) {
		t.Fatalf("task must be represented only by opaque hash: %+v", p)
	}
}

func TestClaimRejectsIncompleteRequest(t *testing.T) {
	svc := NewService(fakeAttachments{}, &fakeRepo{}, fakeArtifacts{}, zap.NewNop())
	if _, _, err := svc.ClaimDerivative(context.Background(), "", "model-default", nil); !errors.Is(err, mediadomain.ErrInvalidRequest) {
		t.Fatalf("empty request error = %v", err)
	}
}

func TestWorker_ProcessesOneDurableIdentityOnlyOnce(t *testing.T) {
	repo := &fakeRepo{}
	processor := &fakeProcessor{derived: make(chan struct{}, 2)}
	artifacts := fakeArtifacts{data: map[string][]byte{}}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, artifacts, zap.NewNop())
	svc.SetProcessor(processor)
	svc.Start([]string{"ws_1"})
	t.Cleanup(func() { svc.Close(context.Background()) })
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	first, created, err := svc.ClaimDerivative(ctx, "att_1", "model-default", map[string]any{"width": 320})
	if err != nil || !created {
		t.Fatalf("first claim = (%+v, %v, %v)", first, created, err)
	}
	select {
	case <-processor.derived:
	case <-time.After(time.Second):
		t.Fatal("worker did not process pending derivative")
	}
	deadline := time.After(time.Second)
	for first.Status != mediadomain.StatusReady || first.BlobSHA256 != mediadomain.Hash([]byte("proxy")) {
		select {
		case <-deadline:
			t.Fatalf("worker result was not persisted on durable work: %+v", first)
		default:
			time.Sleep(time.Millisecond)
		}
	}
	if first.Status != mediadomain.StatusReady || first.BlobSHA256 != mediadomain.Hash([]byte("proxy")) {
		t.Fatalf("worker result was not persisted on durable work: %+v", first)
	}
	second, created, err := svc.ClaimDerivative(ctx, "att_1", "model-default", map[string]any{"width": 320})
	if err != nil || created || second.ID != first.ID {
		t.Fatalf("same identity should reuse ready work: (%+v, %v, %v)", second, created, err)
	}
	select {
	case <-processor.derived:
		t.Fatal("ready work was processed again")
	case <-time.After(50 * time.Millisecond):
	}
	processor.mu.Lock()
	defer processor.mu.Unlock()
	if processor.derives != 1 {
		t.Fatalf("processor calls = %d, want 1", processor.derives)
	}
}

func TestModelDefaultImage_ReturnsReadyArtifactOrSchedulesWork(t *testing.T) {
	repo := &fakeRepo{}
	artifacts := fakeArtifacts{data: map[string][]byte{}}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, artifacts, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")

	if data, _, ready, err := svc.ModelDefaultImage(ctx, "att_1"); err != nil || ready || data != nil {
		t.Fatalf("first proxy should only claim pending work: data=%q ready=%v err=%v", data, ready, err)
	}
	repo.derivative.Status = mediadomain.StatusReady
	repo.derivative.MimeType = "image/jpeg"
	repo.derivative.BlobSHA256 = mediadomain.Hash([]byte("proxy"))
	artifacts.data[repo.derivative.BlobSHA256] = []byte("proxy")

	data, mime, ready, err := svc.ModelDefaultImage(ctx, "att_1")
	if err != nil || !ready || string(data) != "proxy" || mime != "image/jpeg" {
		t.Fatalf("ready proxy = (%q, %q, %v, %v)", data, mime, ready, err)
	}
}

func TestDocumentText_CachesExtractedTextBySourceAndVersion(t *testing.T) {
	repo := &fakeRepo{}
	artifacts := fakeArtifacts{data: map[string][]byte{}}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a", Kind: attachmentdomain.KindDocument}}, repo, artifacts, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")
	calls := 0

	first, err := svc.DocumentText(ctx, "att_1", func(context.Context, *attachmentdomain.Attachment, []byte) (string, error) {
		calls++
		return "# Page 1\ncached text", nil
	})
	if err != nil || first != "# Page 1\ncached text" {
		t.Fatalf("first document text = (%q, %v)", first, err)
	}
	if repo.derivative == nil || repo.derivative.Kind != DerivativeDocumentText ||
		repo.derivative.Status != mediadomain.StatusReady || repo.derivative.MimeType != "text/plain; charset=utf-8" {
		t.Fatalf("ready document derivative not persisted: %+v", repo.derivative)
	}

	second, err := svc.DocumentText(ctx, "att_1", func(context.Context, *attachmentdomain.Attachment, []byte) (string, error) {
		calls++
		return "should not run", nil
	})
	if err != nil || second != first || calls != 1 {
		t.Fatalf("cached document text = (%q, calls=%d, err=%v), want first text and one extraction", second, calls, err)
	}
}

func TestPreparation_ImageClaimsModelDefaultStatus(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a", Kind: attachmentdomain.KindImage}}, repo, fakeArtifacts{}, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")

	prep, err := svc.Preparation(ctx, "att_1")
	if err != nil {
		t.Fatalf("preparation: %v", err)
	}
	if prep.Status != PreparationStatusPending || prep.Target != DerivativeModelDefault {
		t.Fatalf("image preparation should claim model-default pending work: %+v", prep)
	}
	repo.derivative.Status = mediadomain.StatusReady
	repo.derivative.MimeType = "image/jpeg"
	repo.derivative.SizeBytes = 123
	repo.derivative.Width = 640
	repo.derivative.Height = 480

	prep, err = svc.Preparation(ctx, "att_1")
	if err != nil {
		t.Fatalf("ready preparation: %v", err)
	}
	if prep.Status != PreparationStatusReady || prep.MimeType != "image/jpeg" ||
		prep.SizeBytes != 123 || prep.Width != 640 || prep.Height != 480 {
		t.Fatalf("ready preparation metadata not surfaced: %+v", prep)
	}
}

func TestPreparation_SurfaceCancelledStatus(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a", Kind: attachmentdomain.KindImage}}, repo, fakeArtifacts{}, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")

	prep, err := svc.Preparation(ctx, "att_1")
	if err != nil {
		t.Fatalf("preparation: %v", err)
	}
	cancelled, err := svc.CancelDerivative(ctx, repo.derivative.ID)
	if err != nil {
		t.Fatalf("cancel: %v", err)
	}
	if cancelled.Status != mediadomain.StatusCancelled {
		t.Fatalf("cancelled work status = %+v", cancelled)
	}
	prep, err = svc.Preparation(ctx, "att_1")
	if err != nil {
		t.Fatalf("cancelled preparation: %v", err)
	}
	if prep.Status != mediadomain.StatusCancelled {
		t.Fatalf("cancelled preparation should surface cancelled, got %+v", prep)
	}
}

func TestPreparation_NonImageNotRequired(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a", Kind: attachmentdomain.KindDocument}}, repo, fakeArtifacts{}, zap.NewNop())
	prep, err := svc.Preparation(reqctxpkg.SetWorkspaceID(context.Background(), "ws_1"), "att_1")
	if err != nil {
		t.Fatalf("preparation: %v", err)
	}
	if prep.Status != PreparationStatusNotRequired || repo.derivative != nil {
		t.Fatalf("non-image should not claim derivative work: prep=%+v derivative=%+v", prep, repo.derivative)
	}
}

func TestModelDefaultImage_WaitsForStartedWorker(t *testing.T) {
	repo := &fakeRepo{}
	processor := &fakeProcessor{derived: make(chan struct{}, 1)}
	artifacts := fakeArtifacts{data: map[string][]byte{}}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, artifacts, zap.NewNop())
	svc.SetProcessor(processor)
	svc.Start([]string{"ws_1"})
	t.Cleanup(func() { svc.Close(context.Background()) })

	data, mime, ready, err := svc.ModelDefaultImage(reqctxpkg.SetWorkspaceID(context.Background(), "ws_1"), "att_1")
	if err != nil || !ready || string(data) != "proxy" || mime != "image/webp" {
		t.Fatalf("proxy = (%q, %q, %v, %v)", data, mime, ready, err)
	}
}

func TestRetryDerivative_RequeuesFailedWork(t *testing.T) {
	repo := &fakeRepo{}
	processor := &fakeProcessor{derived: make(chan struct{}, 1)}
	artifacts := fakeArtifacts{data: map[string][]byte{}}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, artifacts, zap.NewNop())
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")

	derivative, _, err := svc.ClaimDerivative(ctx, "att_1", "model-default", map[string]any{"width": 320})
	if err != nil {
		t.Fatalf("claim: %v", err)
	}
	derivative.Status, derivative.ErrorCode = mediadomain.StatusFailed, "MEDIA_DERIVATIVE_FAILED"
	if err := repo.SaveDerivative(ctx, derivative); err != nil {
		t.Fatalf("save failed status: %v", err)
	}
	svc.SetProcessor(processor)
	svc.Start([]string{"ws_1"})
	t.Cleanup(func() { svc.Close(context.Background()) })
	retried, err := svc.RetryDerivative(ctx, derivative.ID)
	if err != nil {
		t.Fatalf("retry: %v", err)
	}
	if retried.Status != mediadomain.StatusPending || retried.ErrorCode != "" {
		t.Fatalf("retry should reset to pending: %+v", retried)
	}
	select {
	case <-processor.derived:
	case <-time.After(time.Second):
		t.Fatal("retry did not enqueue failed work")
	}
}

func TestCancelDerivativeDuringProcessingWinsOverReadyWrite(t *testing.T) {
	repo := &fakeRepo{}
	processor := &fakeProcessor{derived: make(chan struct{}, 1), block: make(chan struct{})}
	artifacts := fakeArtifacts{data: map[string][]byte{}}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, artifacts, zap.NewNop())
	svc.SetProcessor(processor)
	svc.Start([]string{"ws_1"})
	t.Cleanup(func() { svc.Close(context.Background()) })
	ctx := reqctxpkg.SetWorkspaceID(context.Background(), "ws_1")

	derivative, _, err := svc.ClaimDerivative(ctx, "att_1", "model-default", map[string]any{"width": 320})
	if err != nil {
		t.Fatalf("claim: %v", err)
	}
	select {
	case <-processor.derived:
	case <-time.After(time.Second):
		t.Fatal("worker did not start")
	}
	cancelled, err := svc.CancelDerivative(ctx, derivative.ID)
	if err != nil {
		t.Fatalf("cancel running: %v", err)
	}
	if cancelled.Status != mediadomain.StatusCancelled {
		t.Fatalf("cancelled status = %+v", cancelled)
	}
	close(processor.block)

	deadline := time.After(time.Second)
	for repo.derivative.Status != mediadomain.StatusCancelled {
		select {
		case <-deadline:
			t.Fatalf("processing completion overwrote cancellation: %+v", repo.derivative)
		default:
			time.Sleep(time.Millisecond)
		}
	}
	if repo.derivative.BlobSHA256 != "" {
		t.Fatalf("cancelled work must not publish a blob: %+v", repo.derivative)
	}
}
