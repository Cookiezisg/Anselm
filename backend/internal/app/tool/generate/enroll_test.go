package generate

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
	"time"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	voicedomain "github.com/sunweilin/anselm/backend/internal/domain/voice"
)

// The enrollment tool's correctness is almost entirely about ORDER and ROLLBACK, because the thing
// it creates lives on someone else's servers. These tests assert the two failure modes that cost
// something real: an orphan upstream (a voice nobody can see, name or delete, occupying inventory),
// and a paid call made after we already knew it could not be recorded.
//
// 登记工具的正确性几乎全在**顺序**与**回滚**上,因为它创建的东西住在别人的服务器上。这些测试断言的是
// 两种**真有代价**的失败:上游孤儿(一个谁也看不见、叫不出名、删不掉,却占着库存的音色),以及在**已经
// 知道记不下来之后**才发出的那次付费调用。

type fakeVoices struct {
	rows      []*voicedomain.Voice
	failWrite error
}

func (f *fakeVoices) Create(_ context.Context, v *voicedomain.Voice) error {
	if f.failWrite != nil {
		return f.failWrite
	}
	f.rows = append(f.rows, v)
	return nil
}
func (f *fakeVoices) List(context.Context) ([]*voicedomain.Voice, error) { return f.rows, nil }
func (f *fakeVoices) GetByName(context.Context, string) (*voicedomain.Voice, error) {
	return nil, voicedomain.ErrNotFound
}
func (f *fakeVoices) Delete(context.Context, string) error { return nil }

type fakeFetcher struct {
	mime string
	data []byte
}

func (f fakeFetcher) Download(_ context.Context, id string) (*attachmentdomain.Attachment, []byte, error) {
	return &attachmentdomain.Attachment{ID: id, MimeType: f.mime}, f.data, nil
}

func enrollTool(voices voicedomain.Repository, mime string) *EnrollVoice {
	return &EnrollVoice{
		router: &Router{},
		source: fakeFetcher{mime: mime, data: []byte("RIFF....WAVE")},
		voices: voices,
	}
}

func enrollArgs(name string) string {
	b, _ := json.Marshal(enrollVoiceInput{AttachmentID: "att_00112233445566aa", Name: name})
	return string(b)
}

// TestEnroll_InventoryFullBeforeSpending: the cap is checked BEFORE the paid upstream call. Calling
// first and refusing after would charge the user for a voice they cannot keep.
//
// TestEnroll_InventoryFullBeforeSpending:上限在**付费上游调用之前**查。先调再拒,等于为一个用户留不住
// 的音色收了他的钱。
func TestEnroll_InventoryFullBeforeSpending(t *testing.T) {
	full := &fakeVoices{}
	for i := 0; i < VoiceInventory; i++ {
		full.rows = append(full.rows, &voicedomain.Voice{Name: string(rune('a' + i)), CreatedAt: time.Now()})
	}
	_, err := enrollTool(full, "audio/wav").Execute(context.Background(), enrollArgs("another"))
	if !errors.Is(err, voicedomain.ErrInventoryFull) {
		t.Fatalf("err = %v, want ErrInventoryFull", err)
	}
	// The message must name the remedy: nothing frees a slot tomorrow, so "try later" would be a lie.
	// 消息必须点明补救办法:明天不会腾出位置,故「过会儿再来」是撒谎。
	if !strings.Contains(err.Error(), "delete") {
		t.Fatalf("the inventory error must tell the user to delete one, got %q", err)
	}
}

// TestEnroll_DuplicateNameBeforeSpending: same discipline, other precondition. Enrolling over a
// name would strand the first registration upstream.
//
// TestEnroll_DuplicateNameBeforeSpending:同一条纪律、另一个前置条件。覆盖一个名字会让第一个登记在
// 上游搁浅。
func TestEnroll_DuplicateNameBeforeSpending(t *testing.T) {
	taken := &fakeVoices{rows: []*voicedomain.Voice{{Name: "narrator"}}}
	_, err := enrollTool(taken, "audio/wav").Execute(context.Background(), enrollArgs("narrator"))
	if !errors.Is(err, voicedomain.ErrNameTaken) {
		t.Fatalf("err = %v, want ErrNameTaken", err)
	}
}

// TestEnroll_NonAudioSourceIsRefused: caught locally so a picture handed to a cloning route fails
// with a sentence about the file rather than a remote error about a decoder.
//
// TestEnroll_NonAudioSourceIsRefused:本地就拦下,使一张图被递给克隆路由时,失败于一句**关于这个文件**
// 的话,而不是一个关于解码器的远端错误。
func TestEnroll_NonAudioSourceIsRefused(t *testing.T) {
	_, err := enrollTool(&fakeVoices{}, "image/png").Execute(context.Background(), enrollArgs("narrator"))
	if err == nil || !strings.Contains(err.Error(), "not audio") {
		t.Fatalf("err = %v, want a refusal naming the wrong kind", err)
	}
}

// TestEnroll_ValidateRejectsABareName: the name IS the handle a later synthesis uses, so an empty
// one produces a voice that can never be asked for.
//
// TestEnroll_ValidateRejectsABareName:名字**就是**此后合成用的那个把手,故空名产出的音色永远点不到。
func TestEnroll_ValidateRejectsABareName(t *testing.T) {
	tool := &EnrollVoice{}
	if err := tool.ValidateInput(json.RawMessage(`{"attachmentId":"att_00112233445566aa","name":"  "}`)); !errors.Is(err, voicedomain.ErrNameRequired) {
		t.Fatalf("err = %v, want ErrNameRequired", err)
	}
	if err := tool.ValidateInput(json.RawMessage(`{"attachmentId":"not-an-id","name":"x"}`)); !errors.Is(err, ErrSourceRequired) {
		t.Fatalf("err = %v, want ErrSourceRequired", err)
	}
}

// TestEnroll_DangerAnchorIsInTheDescription: S18 has no central permission gate — the LLM's per-call
// self-report is the control, and the description is where the anchor lives. This one must read
// `dangerous`, and for the identity reason rather than the money one: the fee is small, a voice is
// a person's.
//
// TestEnroll_DangerAnchorIsInTheDescription:S18 无中央权限门控——LLM 逐次自报**就是**那个控制,而锚点
// 住在描述里。这一个必须写 `dangerous`,且理由是**身份**而非钱:费用很小,而声音是某个人的。
func TestEnroll_DangerAnchorIsInTheDescription(t *testing.T) {
	d := (&EnrollVoice{}).Description()
	if !strings.Contains(d, "danger=dangerous") {
		t.Fatalf("enroll_voice must anchor danger=dangerous, got: %s", d)
	}
	if !strings.Contains(d, "PERSISTENT") || !strings.Contains(d, "real person") {
		t.Fatalf("the anchor must name WHY (persistent state, a real person's voice), got: %s", d)
	}
}
