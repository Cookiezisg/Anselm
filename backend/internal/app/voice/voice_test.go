package voice

import (
	"context"
	"errors"
	"reflect"
	"testing"

	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
)

// These tests pin the irreversible boundary: the upstream registration is deleted first, and
// the local pointer is deleted only after that succeeds. Otherwise a failed remote call would
// leave a paid resource with no local handle.
//
// 这些测试锁住不可逆边界：先删上游登记，只有成功后才删本地指针。否则远端调用失败时，本地行一删，
// 一个已付费却再也没有本地把手的资源就会被遗留。

type fakeVoiceRepo struct {
	rows       []*voicedomain.Voice
	deleteErr  error
	deleteErrs []error
	listErr    error
	deleteIDs  []string
	events     *[]string
}

func (f *fakeVoiceRepo) Create(context.Context, *voicedomain.Voice) error { return nil }

func (f *fakeVoiceRepo) List(context.Context) ([]*voicedomain.Voice, error) {
	if f.listErr != nil {
		return nil, f.listErr
	}
	if f.events != nil {
		*f.events = append(*f.events, "repo.list")
	}
	return f.rows, nil
}

func (f *fakeVoiceRepo) GetByName(context.Context, string) (*voicedomain.Voice, error) {
	return nil, voicedomain.ErrNotFound
}

func (f *fakeVoiceRepo) Delete(_ context.Context, id string) error {
	if f.events != nil {
		*f.events = append(*f.events, "repo.delete")
	}
	f.deleteIDs = append(f.deleteIDs, id)
	if len(f.deleteErrs) > 0 {
		err := f.deleteErrs[0]
		f.deleteErrs = f.deleteErrs[1:]
		if err != nil {
			return err
		}
	}
	if f.deleteErr != nil {
		return f.deleteErr
	}
	for i, row := range f.rows {
		if row.ID == id {
			f.rows = append(f.rows[:i], f.rows[i+1:]...)
			break
		}
	}
	return nil
}

type fakeVoiceUpstream struct {
	err    error
	calls  []struct{ provider, upstreamID string }
	events *[]string
}

func (f *fakeVoiceUpstream) DeleteVoice(_ context.Context, provider, upstreamID string) error {
	f.calls = append(f.calls, struct{ provider, upstreamID string }{provider, upstreamID})
	if f.events != nil {
		*f.events = append(*f.events, "upstream.delete")
	}
	return f.err
}

func testVoice() *voicedomain.Voice {
	return &voicedomain.Voice{
		ID:         "vce_1111111111111111",
		Name:       "narrator",
		Provider:   "anselm",
		UpstreamID: "vce_upstream_111",
	}
}

// TestDelete_UpstreamFirstThenLocalDelete protects the order as well as the outcome. A service
// that deletes both but reverses the order is still unsafe.
//
// TestDelete_UpstreamFirstThenLocalDelete 同时保护顺序与结果。两边都删但顺序反了的 service 仍然不安全。
func TestDelete_UpstreamFirstThenLocalDelete(t *testing.T) {
	events := []string{}
	repo := &fakeVoiceRepo{rows: []*voicedomain.Voice{testVoice()}, events: &events}
	upstream := &fakeVoiceUpstream{events: &events}

	if err := New(repo, upstream, nil).Delete(context.Background(), "vce_1111111111111111"); err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if want := []string{"repo.list", "upstream.delete", "repo.delete"}; !reflect.DeepEqual(events, want) {
		t.Fatalf("events = %v, want %v", events, want)
	}
	if len(upstream.calls) != 1 || upstream.calls[0].provider != "anselm" || upstream.calls[0].upstreamID != "vce_upstream_111" {
		t.Fatalf("upstream calls = %+v, want the row's provider and upstream id", upstream.calls)
	}
	if !reflect.DeepEqual(repo.deleteIDs, []string{"vce_1111111111111111"}) {
		t.Fatalf("local delete ids = %v, want the requested row id", repo.deleteIDs)
	}
}

// TestDelete_UpstreamFailureKeepsLocalPointer ensures a retry remains possible and the inventory
// still tells the truth after a remote failure.
//
// TestDelete_UpstreamFailureKeepsLocalPointer 确保远端失败后仍可重试，库存也继续说真话。
func TestDelete_UpstreamFailureKeepsLocalPointer(t *testing.T) {
	remoteErr := errors.New("gateway unavailable")
	repo := &fakeVoiceRepo{rows: []*voicedomain.Voice{testVoice()}}
	upstream := &fakeVoiceUpstream{err: remoteErr}

	err := New(repo, upstream, nil).Delete(context.Background(), "vce_1111111111111111")
	if !errors.Is(err, remoteErr) {
		t.Fatalf("Delete error = %v, want the upstream error in the chain", err)
	}
	if len(repo.deleteIDs) != 0 {
		t.Fatalf("local delete ids = %v, want no local delete after upstream failure", repo.deleteIDs)
	}
}

// TestDelete_LocalFailureCanConvergeOnRetry protects the half-committed boundary. The upstream
// deletion may have succeeded while the local pointer failed to persist; the next attempt must be
// safe because the managed gateway treats deletion of an already-absent registration as success.
//
// TestDelete_LocalFailureCanConvergeOnRetry 锁住半提交边界。上游删除可能已经成功,但本地指针落库
// 失败;下一次必须能安全收敛,因为受管网关把「登记已不存在」的删除视为成功。
func TestDelete_LocalFailureCanConvergeOnRetry(t *testing.T) {
	localErr := errors.New("database temporarily unavailable")
	repo := &fakeVoiceRepo{
		rows:       []*voicedomain.Voice{testVoice()},
		deleteErrs: []error{localErr, nil},
	}
	upstream := &fakeVoiceUpstream{}
	svc := New(repo, upstream, nil)

	err := svc.Delete(context.Background(), "vce_1111111111111111")
	if !errors.Is(err, localErr) {
		t.Fatalf("first Delete error = %v, want local persistence error", err)
	}
	if len(upstream.calls) != 1 || len(repo.deleteIDs) != 1 {
		t.Fatalf("first attempt calls = upstream %d, local %d; want one each", len(upstream.calls), len(repo.deleteIDs))
	}
	if len(repo.rows) != 1 {
		t.Fatalf("local rows after failed persistence = %d, want one for retry", len(repo.rows))
	}

	if err := svc.Delete(context.Background(), "vce_1111111111111111"); err != nil {
		t.Fatalf("retry Delete: %v", err)
	}
	if len(upstream.calls) != 2 {
		t.Fatalf("upstream calls after retry = %d, want two idempotent attempts", len(upstream.calls))
	}
	if !reflect.DeepEqual(repo.deleteIDs, []string{
		"vce_1111111111111111",
		"vce_1111111111111111",
	}) {
		t.Fatalf("local delete ids = %v, want the same pointer retried", repo.deleteIDs)
	}
	if len(repo.rows) != 0 {
		t.Fatalf("local rows after retry = %d, want zero", len(repo.rows))
	}
}

// TestDelete_MissingRowDoesNotSpendUpstream verifies that a stale UI action cannot spend a remote
// call when the local workspace no longer owns that id.
//
// TestDelete_MissingRowDoesNotSpendUpstream 验证过期 UI 动作在本地已没有该 id 时不会再发远端调用。
func TestDelete_MissingRowDoesNotSpendUpstream(t *testing.T) {
	repo := &fakeVoiceRepo{}
	upstream := &fakeVoiceUpstream{}

	err := New(repo, upstream, nil).Delete(context.Background(), "vce_missing1111111")
	if !errors.Is(err, voicedomain.ErrNotFound) {
		t.Fatalf("Delete error = %v, want ErrNotFound", err)
	}
	if len(upstream.calls) != 0 {
		t.Fatalf("upstream calls = %+v, want none", upstream.calls)
	}
	if len(repo.deleteIDs) != 0 {
		t.Fatalf("local delete ids = %v, want none", repo.deleteIDs)
	}
}
