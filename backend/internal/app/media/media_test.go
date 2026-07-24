package media

import (
	"context"
	"errors"
	"testing"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	mediadomain "github.com/sunweilin/anselm/backend/internal/domain/media"
)

type fakeAttachments struct{ row *attachmentdomain.Attachment }

func (f fakeAttachments) Get(_ context.Context, id string) (*attachmentdomain.Attachment, error) {
	if f.row == nil || id != f.row.ID {
		return nil, attachmentdomain.ErrNotFound
	}
	return f.row, nil
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

func TestClaimDerivative_CanonicalParamsAndSourceAreTheIdentity(t *testing.T) {
	repo := &fakeRepo{}
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, zap.NewNop())
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
	svc := NewService(fakeAttachments{row: &attachmentdomain.Attachment{ID: "att_1", SHA256: "source-a"}}, repo, zap.NewNop())
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
	svc := NewService(fakeAttachments{}, &fakeRepo{}, zap.NewNop())
	if _, _, err := svc.ClaimDerivative(context.Background(), "", "model-default", nil); !errors.Is(err, mediadomain.ErrInvalidRequest) {
		t.Fatalf("empty request error = %v", err)
	}
}
