package bootstrap

import (
	"context"
	"strings"
	"testing"

	attachmentapp "github.com/sunweilin/forgify/backend/internal/app/attachment"
	chatapp "github.com/sunweilin/forgify/backend/internal/app/chat"
	documentdomain "github.com/sunweilin/forgify/backend/internal/domain/document"
	llminfra "github.com/sunweilin/forgify/backend/internal/infra/llm"
)

// fakeParts records the caps it received so the test can assert the chat→attachment bridge maps
// fields straight (Vision→Vision, NativeDocs→NativeDocs — not swapped).
type fakeParts struct{ gotCaps attachmentapp.Capabilities }

func (f *fakeParts) ToContentParts(_ context.Context, _ []string, caps attachmentapp.Capabilities) ([]llminfra.ContentPart, error) {
	f.gotCaps = caps
	return nil, nil
}

func TestAttachmentRenderer_BridgesCaps(t *testing.T) {
	fp := &fakeParts{}
	r := NewAttachmentRenderer(fp)
	// Vision true, NativeDocs false — asymmetric on purpose to catch a field swap.
	if _, err := r.ToContentParts(context.Background(), []string{"att_1"}, chatapp.ContentCapabilities{Vision: true, NativeDocs: false}); err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if !fp.gotCaps.Vision || fp.gotCaps.NativeDocs {
		t.Fatalf("caps mis-bridged: got %+v, want {Vision:true, NativeDocs:false}", fp.gotCaps)
	}
}

// fakeDocs returns one document for both ResolveAttached and GetBatch.
type fakeDocs struct{}

func (fakeDocs) ResolveAttached(_ context.Context, _ []documentdomain.AttachedDocument) ([]*documentdomain.Document, error) {
	return []*documentdomain.Document{{ID: "doc_1", Name: "Spec", Path: "/spec", Content: "the body"}}, nil
}
func (fakeDocs) GetBatch(_ context.Context, _ []string) ([]*documentdomain.Document, error) {
	return []*documentdomain.Document{{ID: "doc_1", Name: "Spec", Path: "/spec", Content: "the body"}}, nil
}

func TestDocumentAndKnowledgeRenderers_ComposeXML(t *testing.T) {
	dr := NewDocumentRenderer(fakeDocs{})
	out, err := dr.RenderAttached(context.Background(), []documentdomain.AttachedDocument{{DocumentID: "doc_1"}})
	if err != nil {
		t.Fatalf("RenderAttached: %v", err)
	}
	if !strings.Contains(out, "the body") || !strings.Contains(out, "doc_1") {
		t.Fatalf("document XML missing content: %q", out)
	}

	kp := NewKnowledgeProvider(fakeDocs{})
	prefix, err := kp.BuildKnowledgePrefix(context.Background(), []string{"doc_1"})
	if err != nil {
		t.Fatalf("BuildKnowledgePrefix: %v", err)
	}
	if !strings.Contains(prefix, "the body") {
		t.Fatalf("knowledge prefix missing content: %q", prefix)
	}
}
