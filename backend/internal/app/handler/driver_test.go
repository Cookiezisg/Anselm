package handler

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	handlerdomain "github.com/sunweilin/anselm/backend/internal/domain/handler"
)

// TestDriverScript_GeneratorFinals runs the generated class and the production driver together.
// It protects both generator terminal conventions at the actual stdio protocol boundary rather
// than only checking that the driver source contains a StopIteration branch.
func TestDriverScript_GeneratorFinals(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Skip("python3 is required for the generated handler driver regression")
	}

	dir := t.TempDir()
	class := AssembleClass(&VersionDraft{Methods: []handlerdomain.MethodSpec{
		{Name: "yield_final", Body: "yield {\"progress\": \"half\"}\nyield {\"v\": \"yield-final\"}"},
		{Name: "return_final", Body: "yield {\"progress\": \"half\"}\nreturn {\"v\": \"return-final\"}"},
	}})
	if err := os.WriteFile(filepath.Join(dir, "user_handler.py"), []byte(class), 0o600); err != nil {
		t.Fatal(err)
	}
	script := filepath.Join(dir, "driver.py")
	if err := os.WriteFile(script, []byte(DriverScript), 0o600); err != nil {
		t.Fatal(err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, python, script)
	cmd.Dir = dir
	cmd.Stdin = bytes.NewBufferString(
		`{"args":{}}` + "\n" +
			`{"type":"call","id":"yield","method":"yield_final","args":{}}` + "\n" +
			`{"type":"call","id":"return","method":"return_final","args":{}}` + "\n" +
			`{"type":"shutdown"}` + "\n",
	)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		t.Fatalf("generated driver failed: %v\nstderr:\n%s\nstdout:\n%s", err, stderr.String(), stdout.String())
	}

	var messages []map[string]any
	scanner := bufio.NewScanner(&stdout)
	for scanner.Scan() {
		var message map[string]any
		if err := json.Unmarshal(scanner.Bytes(), &message); err != nil {
			t.Fatalf("driver emitted invalid JSON %q: %v", scanner.Text(), err)
		}
		messages = append(messages, message)
	}
	if err := scanner.Err(); err != nil {
		t.Fatal(err)
	}
	if len(messages) != 5 {
		t.Fatalf("message count = %d, want ready + 2 progress + 2 return: %#v", len(messages), messages)
	}
	if messages[0]["type"] != "ready" {
		t.Fatalf("first message = %#v, want ready", messages[0])
	}
	if messages[1]["type"] != "progress" || messages[1]["id"] != "yield" {
		t.Fatalf("yield progress = %#v", messages[1])
	}
	if messages[2]["type"] != "return" || messages[2]["id"] != "yield" {
		t.Fatalf("yield return = %#v", messages[2])
	}
	if data, ok := messages[2]["data"].(map[string]any); !ok || data["v"] != "yield-final" {
		t.Fatalf("yield final = %#v", messages[2]["data"])
	}
	if messages[3]["type"] != "progress" || messages[3]["id"] != "return" {
		t.Fatalf("return progress = %#v", messages[3])
	}
	if messages[4]["type"] != "return" || messages[4]["id"] != "return" {
		t.Fatalf("return result = %#v", messages[4])
	}
	if data, ok := messages[4]["data"].(map[string]any); !ok || data["v"] != "return-final" {
		t.Fatalf("StopIteration.value final = %#v", messages[4]["data"])
	}
}

// TestDriverScript_ArtifactDirRestoresAfterFailure keeps the resident driver alive while the
// caller removes a completed call's output directory. A leaked cwd would make the next call fail
// before user code runs; a leaked ANSELM_OUT would also mislabel a later no-output call.
func TestDriverScript_ArtifactDirRestoresAfterFailure(t *testing.T) {
	python, err := exec.LookPath("python3")
	if err != nil {
		t.Skip("python3 is required for the generated handler driver regression")
	}

	dir := t.TempDir()
	firstOut := filepath.Join(dir, "out-first")
	secondOut := filepath.Join(dir, "out-second")
	for _, path := range []string{firstOut, secondOut} {
		if err := os.Mkdir(path, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	realDir, err := filepath.EvalSymlinks(dir)
	if err != nil {
		t.Fatal(err)
	}
	realSecondOut, err := filepath.EvalSymlinks(secondOut)
	if err != nil {
		t.Fatal(err)
	}
	class := AssembleClass(&VersionDraft{Methods: []handlerdomain.MethodSpec{
		{Name: "explode", Body: `raise RuntimeError("boom")`},
		{Name: "where", Body: `import os
return {"cwd": os.getcwd(), "out": os.environ.get("ANSELM_OUT", "")}`},
	}})
	if err := os.WriteFile(filepath.Join(dir, "user_handler.py"), []byte(class), 0o600); err != nil {
		t.Fatal(err)
	}
	script := filepath.Join(dir, "driver.py")
	if err := os.WriteFile(script, []byte(DriverScript), 0o600); err != nil {
		t.Fatal(err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, python, script)
	cmd.Dir = dir
	stdin, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	scanner := bufio.NewScanner(stdout)
	scanner.Buffer(make([]byte, 1024), 1024*1024)
	read := func(want string) map[string]any {
		if !scanner.Scan() {
			t.Fatalf("driver ended while waiting for %s: %v\nstderr:\n%s", want, scanner.Err(), stderr.String())
		}
		var message map[string]any
		if err := json.Unmarshal(scanner.Bytes(), &message); err != nil {
			t.Fatalf("driver emitted invalid JSON %q: %v", scanner.Text(), err)
		}
		return message
	}
	send := func(message map[string]any) {
		if err := json.NewEncoder(stdin).Encode(message); err != nil {
			t.Fatal(err)
		}
	}

	send(map[string]any{"args": map[string]any{}})
	if got := read("ready")["type"]; got != "ready" {
		t.Fatalf("ready message type = %#v", got)
	}
	send(map[string]any{
		"type":   "call",
		"id":     "explode",
		"method": "explode",
		"args":   map[string]any{},
		"out":    firstOut,
	})
	failed := read("failure")
	if failed["type"] != "error" || failed["id"] != "explode" {
		t.Fatalf("failure response = %#v", failed)
	}
	if err := os.RemoveAll(firstOut); err != nil {
		t.Fatal(err)
	}

	send(map[string]any{
		"type":   "call",
		"id":     "second",
		"method": "where",
		"args":   map[string]any{},
		"out":    secondOut,
	})
	second := read("second call")
	assertDriverLocation := func(message map[string]any, wantCWD, wantOut string) {
		if message["type"] != "return" {
			t.Fatalf("location response = %#v", message)
		}
		data, ok := message["data"].(map[string]any)
		if !ok || data["cwd"] != wantCWD || data["out"] != wantOut {
			t.Fatalf("location data = %#v, want cwd=%q out=%q", message["data"], wantCWD, wantOut)
		}
	}
	assertDriverLocation(second, realSecondOut, secondOut)
	if err := os.RemoveAll(secondOut); err != nil {
		t.Fatal(err)
	}

	send(map[string]any{
		"type":   "call",
		"id":     "restored",
		"method": "where",
		"args":   map[string]any{},
	})
	restored := read("restored cwd")
	assertDriverLocation(restored, realDir, "")

	send(map[string]any{"type": "shutdown"})
	if err := stdin.Close(); err != nil {
		t.Fatal(err)
	}
	if err := cmd.Wait(); err != nil {
		t.Fatalf("driver failed after cwd restoration: %v\nstderr:\n%s", err, stderr.String())
	}
}
