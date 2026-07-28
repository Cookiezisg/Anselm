package mediaartifact

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
)

// The declaration comes from USER CODE, and the collector reads files off disk on its word. That
// makes two of these tests security tests rather than feature tests: a path that escapes the run
// directory, and a name that lies about its content.
//
// 声明来自**用户代码**,而采集器凭它的话去盘上读文件。这让其中两个测试是安全测试而非功能测试:
// 逃出运行目录的路径,以及一个对自己内容撒谎的文件名。

type fakeUploader struct {
	uploads []string
	fail    bool
}

func (f *fakeUploader) Upload(_ context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	if f.fail {
		return nil, os.ErrPermission
	}
	f.uploads = append(f.uploads, filename+"|"+mime)
	return &attachmentdomain.Attachment{
		ID: "att_00112233445566aa", Filename: filename, MimeType: mime, SizeBytes: int64(len(data)),
	}, nil
}

// tinyPNG is a real 1×1 PNG — the collector sniffs CONTENT, so a fixture of arbitrary bytes would
// test nothing. tinyPNG 是真 1×1 PNG——采集器嗅**内容**,随便的字节测不出任何东西。
var tinyPNG = []byte{
	0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a,
	0, 0, 0, 0x0d, 'I', 'H', 'D', 'R', 0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0,
	0x90, 0x77, 0x53, 0xde, 0, 0, 0, 0x0c, 'I', 'D', 'A', 'T',
	0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xc0, 0, 0, 3, 1, 1, 0, 0xc9, 0xfe, 0x92, 0xef,
	0, 0, 0, 0, 'I', 'E', 'N', 'D', 0xae, 0x42, 0x60, 0x82,
}

func writeOut(t *testing.T, dir, name string, data []byte) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), data, 0o644); err != nil {
		t.Fatal(err)
	}
}

// TestCollectArtifacts_ReplacesInPlace: the declaration becomes a MediaRef receipt ON ITS OWN KEY,
// and the surrounding data is untouched. In place, not appended — `result.chart` IS the picture,
// rather than a chart field plus a sibling artifacts array the caller has to correlate.
func TestCollectArtifacts_ReplacesInPlace(t *testing.T) {
	dir := t.TempDir()
	writeOut(t, dir, "chart.png", tinyPNG)
	up := &fakeUploader{}

	got, notes := Collect(context.Background(), up, dir, SourceFunction, map[string]any{
		"chart": map[string]any{MediaKey: "chart.png"},
		"n":     float64(12),
	})
	if len(notes) != 0 {
		t.Fatalf("unexpected notes: %v", notes)
	}
	m, _ := got.(map[string]any)
	if m["n"] != float64(12) {
		t.Fatalf("sibling data mangled: %+v", m)
	}
	chart, _ := m["chart"].(map[string]any)
	if chart["attachmentId"] != "att_00112233445566aa" || chart["source"] != string(SourceFunction) {
		t.Fatalf("chart key is not a MediaRef receipt: %+v", chart)
	}
	if chart["mime"] != "image/png" {
		t.Fatalf("mime = %v, want the SNIFFED image/png", chart["mime"])
	}
	if len(up.uploads) != 1 {
		t.Fatalf("uploads = %v", up.uploads)
	}
}

// TestCollectArtifacts_RefusesPathEscape: `../../.ssh/id_rsa` is not hypothetical — it is a thing a
// function will eventually say. The declaration must be refused BEFORE anything is opened, and the
// refusal must leave the declaration visible rather than silently dropping it.
//
// `../../.ssh/id_rsa` 不是假想——它是函数迟早会说出口的东西。声明必须在**打开任何东西之前**被拒,
// 且拒绝要把声明留在原地、而不是静默抹掉。
func TestCollectArtifacts_RefusesPathEscape(t *testing.T) {
	root := t.TempDir()
	outDir := filepath.Join(root, "run")
	if err := os.Mkdir(outDir, 0o755); err != nil {
		t.Fatal(err)
	}
	// A real, readable, image-shaped file OUTSIDE the run dir — so the only thing standing between
	// the function and it is the containment check.
	writeOut(t, root, "secret.png", tinyPNG)
	up := &fakeUploader{}

	got, notes := Collect(context.Background(), up, outDir, SourceFunction, map[string]any{
		"stolen": map[string]any{MediaKey: "../secret.png"},
	})
	if len(up.uploads) != 0 {
		t.Fatalf("a path escape was uploaded: %v", up.uploads)
	}
	m, _ := got.(map[string]any)
	decl, _ := m["stolen"].(map[string]any)
	if decl[MediaKey] != "../secret.png" {
		t.Fatalf("refused declaration should stay visible, got %+v", decl)
	}
	if len(notes) != 1 || !strings.Contains(notes[0], "inside") {
		t.Fatalf("refusal must be explained in the logs, got %v", notes)
	}
}

// TestCollectArtifacts_SniffsContentNotExtension: a file named .png whose bytes are a shell script
// must not become an image attachment on the strength of its name.
func TestCollectArtifacts_SniffsContentNotExtension(t *testing.T) {
	dir := t.TempDir()
	writeOut(t, dir, "chart.png", []byte("#!/bin/sh\nrm -rf /\n"))
	up := &fakeUploader{}

	_, notes := Collect(context.Background(), up, dir, SourceFunction, map[string]any{
		"chart": map[string]any{MediaKey: "chart.png"},
	})
	if len(up.uploads) != 0 {
		t.Fatalf("a non-media file was uploaded on the strength of its name: %v", up.uploads)
	}
	if len(notes) != 1 || !strings.Contains(notes[0], "render") {
		t.Fatalf("skip must be explained, got %v", notes)
	}
}

// TestCollectArtifacts_OneBadArtifactDoesNotVoidTheRun: a missing declaration is noted and skipped
// while every good artifact and every plain field still comes through — a run whose numbers are
// right must not be lost to one absent chart.
func TestCollectArtifacts_OneBadArtifactDoesNotVoidTheRun(t *testing.T) {
	dir := t.TempDir()
	writeOut(t, dir, "good.png", tinyPNG)
	up := &fakeUploader{}

	got, notes := Collect(context.Background(), up, dir, SourceFunction, map[string]any{
		"good":    map[string]any{MediaKey: "good.png"},
		"missing": map[string]any{MediaKey: "nope.png"},
		"total":   float64(7),
	})
	m, _ := got.(map[string]any)
	good, _ := m["good"].(map[string]any)
	if good["attachmentId"] == nil {
		t.Fatalf("the good artifact was lost: %+v", m)
	}
	if m["total"] != float64(7) {
		t.Fatalf("plain data was lost: %+v", m)
	}
	if len(notes) != 1 || !strings.Contains(notes[0], "not found") {
		t.Fatalf("notes = %v", notes)
	}
}

// TestCollectArtifacts_NestedAndCapped: declarations are found at any depth (inside lists and
// nested objects), and one run cannot exceed the cap the consumption chokepoint will expand.
func TestCollectArtifacts_NestedAndCapped(t *testing.T) {
	dir := t.TempDir()
	payload := map[string]any{}
	var items []any
	for i := 0; i < maxArtifacts+3; i++ {
		name := "f" + string(rune('a'+i)) + ".png"
		writeOut(t, dir, name, tinyPNG)
		items = append(items, map[string]any{"pic": map[string]any{MediaKey: name}})
	}
	payload["items"] = items
	up := &fakeUploader{}

	got, notes := Collect(context.Background(), up, dir, SourceFunction, payload)
	if len(up.uploads) != maxArtifacts {
		t.Fatalf("uploads = %d, want the %d cap", len(up.uploads), maxArtifacts)
	}
	if len(notes) != 3 {
		t.Fatalf("every skipped declaration must be explained, got %v", notes)
	}
	// The collected ones really landed on their nested keys.
	m, _ := got.(map[string]any)
	list, _ := m["items"].([]any)
	first, _ := list[0].(map[string]any)
	pic, _ := first["pic"].(map[string]any)
	if pic["attachmentId"] == nil {
		t.Fatalf("nested declaration not replaced: %+v", first)
	}
}

// TestCollectArtifacts_NoUploaderPassesThrough: an un-wired assembly (tests, REST-only) must run
// functions correctly — the declaration simply stays a declaration.
func TestCollectArtifacts_NoUploaderPassesThrough(t *testing.T) {
	in := map[string]any{"chart": map[string]any{MediaKey: "chart.png"}}
	got, notes := Collect(context.Background(), nil, t.TempDir(), SourceFunction, in)
	if len(notes) != 0 {
		t.Fatalf("notes = %v", notes)
	}
	m, _ := got.(map[string]any)
	decl, _ := m["chart"].(map[string]any)
	if decl[MediaKey] != "chart.png" {
		t.Fatalf("declaration should pass through untouched, got %+v", decl)
	}
}

// TestCollectArtifacts_UploadFailureIsNotedNotFatal: the store refusing one file leaves the rest of
// the result intact and says why.
func TestCollectArtifacts_UploadFailureIsNotedNotFatal(t *testing.T) {
	dir := t.TempDir()
	writeOut(t, dir, "chart.png", tinyPNG)
	got, notes := Collect(context.Background(), &fakeUploader{fail: true}, dir, SourceFunction,
		map[string]any{"chart": map[string]any{MediaKey: "chart.png"}, "n": float64(1)})
	m, _ := got.(map[string]any)
	if m["n"] != float64(1) {
		t.Fatalf("result lost on an upload failure: %+v", m)
	}
	if len(notes) != 1 || !strings.Contains(notes[0], "could not be saved") {
		t.Fatalf("notes = %v", notes)
	}
}
