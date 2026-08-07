package bootstrap

import (
	"context"
	"strings"
	"testing"

	agentapp "github.com/sunweilin/anselm/backend/internal/app/agent"
	attachmentapp "github.com/sunweilin/anselm/backend/internal/app/attachment"
	chatapp "github.com/sunweilin/anselm/backend/internal/app/chat"
	documentdomain "github.com/sunweilin/anselm/backend/internal/domain/document"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// fakeParts records the caps it received so the test can assert the chat→attachment bridge maps
// fields straight (Vision→Vision, NativeDocs→NativeDocs — not swapped).
type fakeParts struct{ gotCaps attachmentapp.Capabilities }

func (f *fakeParts) ToContentParts(_ context.Context, _ []string, caps attachmentapp.Capabilities) ([]llminfra.ContentPart, error) {
	f.gotCaps = caps
	return nil, nil
}

// The tool_result-narrowed sibling delegates to the same body: these fakes exist to observe
// WHAT was asked for, and the narrowing itself is covered by the attachment service's own tests.
// 收窄到 tool_result 的孪生方法委派给同一个函数体:这些假件的作用是观察**要了什么**,而收窄本身
// 由 attachment 服务自己的测试覆盖。
func (f *fakeParts) ToolResultContentParts(ctx context.Context, toolCallID string, ids []string, caps attachmentapp.Capabilities) ([]llminfra.ContentPart, error) {
	return f.ToContentParts(ctx, ids, caps)
}

func TestAttachmentRenderer_BridgesCaps(t *testing.T) {
	fp := &fakeParts{}
	r := NewAttachmentRenderer(fp, nil, nil)
	// Deliberately asymmetric flags and a finite envelope catch a dropped/scrambled bridge field.
	if _, err := r.ToContentParts(context.Background(), []string{"att_1"}, chatapp.ContentCapabilities{
		Vision: true, Video: true, Audio: false, NativeDocs: false, MaxMediaParts: 3, MaxMediaBytes: 42,
	}); err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if !fp.gotCaps.Vision || !fp.gotCaps.Video || fp.gotCaps.Audio || fp.gotCaps.NativeDocs ||
		fp.gotCaps.MaxMediaParts != 3 || fp.gotCaps.MaxMediaBytes != 42 {
		t.Fatalf("caps mis-bridged: got %+v", fp.gotCaps)
	}
}

type fakeMediaUploader struct{}

func (fakeMediaUploader) Upload(context.Context, string, string, string, []byte) (string, error) {
	return "https://media.example/source", nil
}

func TestAttachmentRenderer_BridgesManagedGatewayOnlyWhenConfigured(t *testing.T) {
	fp := &fakeParts{}
	r := NewAttachmentRenderer(fp, fakeMediaUploader{}, nil)
	_, err := r.ToContentParts(context.Background(), []string{"att_1"}, chatapp.ContentCapabilities{
		ManagedGateway: &chatapp.ManagedGatewayMedia{BaseURL: "https://api.example/v1", InstallID: "ins_1"},
	})
	if err != nil {
		t.Fatalf("ToContentParts: %v", err)
	}
	if fp.gotCaps.RemoteMedia == nil || fp.gotCaps.RemoteMedia.BaseURL != "https://api.example/v1" ||
		fp.gotCaps.RemoteMedia.InstallID != "ins_1" || fp.gotCaps.RemoteMedia.Uploader == nil {
		t.Fatalf("managed gateway not bridged: %+v", fp.gotCaps.RemoteMedia)
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
	namer, ok := kp.(agentapp.KnowledgeNamer)
	if !ok {
		t.Fatal("knowledge provider must expose optional document naming for mount health")
	}
	names, err := namer.ResolveKnowledgeNames(context.Background(), []string{"doc_1", "doc_missing"})
	if err != nil {
		t.Fatalf("ResolveKnowledgeNames: %v", err)
	}
	if names["doc_1"] != "Spec" || names["doc_missing"] != "" {
		t.Fatalf("unexpected knowledge names: %#v", names)
	}
}
