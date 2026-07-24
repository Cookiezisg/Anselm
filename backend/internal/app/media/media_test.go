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

type fakeArtifacts struct{}

func (fakeArtifacts) Put(_ context.Context, data []byte) (string, error) {
	return mediadomain.Hash(data), nil
}
func (fakeArtifacts) Sweep(context.Context, map[string]bool) (int, error) { return 0, nil }

type fakeProcessor struct {
	mu      sync.Mutex
	derives int
	derived chan struct{}
}

func (f *fakeProcessor) Derive(_ context.Context, _ *attachmentdomain.Attachment, _ []byte, _ *mediadomain.Derivative) (DerivativeResult, error) {
	f.mu.Lock()
	f.derives++
	f.mu.Unlock()
	select {
	case f.derived <- struct{}{}:
	default:
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
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, fakeArtifacts{}, zap.NewNop())
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
