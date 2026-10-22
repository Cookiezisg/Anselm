package shell

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
)

// TestCallDangerFloor pins both halves of the net: what it must catch (each row is a route the red-team
// lane actually walked, or its obvious sibling) and what it must leave alone. The second half matters as
// much as the first — a floor that gates `ls` teaches the user to click through every prompt.
//
// TestCallDangerFloor 钉住这张网的两半：必须接住的（每行都是红队车道真走过的路，或它的近亲）与必须放过的。
// 后一半与前一半同样重要——一个连 `ls` 都设闸的下限，只会教用户闭眼点掉每个弹窗。
func TestCallDangerFloor(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "tidy.sh"), []byte("#!/bin/sh\necho hi\nrm -f "+filepath.Join(outside, "ledger.txt")+"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "kill.sh"), []byte("curl -s -X DELETE http://127.0.0.1:1/api/v1/functions/fn_x\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "clean.py"), []byte("import os\nos.remove('"+filepath.Join(outside, "ledger.txt")+"')\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "ok.sh"), []byte("echo build\nrm -rf ./dist\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	ledger := filepath.Join(outside, "ledger.txt")

	catch := []struct{ name, cmd string }{
		{"curl DELETE", `curl -s -X DELETE http://127.0.0.1:8080/api/v1/functions/fn_1 -H 'X: y'`},
		{"curl DELETE no space", `curl -XDELETE http://localhost/x`},
		{"curl --request", `curl --request DELETE http://localhost/x`},
		{"python method kw", `python3 -c "import urllib.request as u; u.urlopen(u.Request('http://x', method='DELETE'))"`},
		{"verb through a helper", `python3 - <<'PY'
import urllib.request
def request(method, path):
    return urllib.request.Request("http://x" + path, method=method)
request("DELETE", "/api/v1/workflows/wf_1")
PY`},
		{"requests.delete", `python3 -c "import requests; requests.delete('http://x')"`},
		{"rm outside absolute", `rm -f ` + ledger},
		{"rm outside dotdot", `rm ../x.txt`},
		{"rm in a chain", `ls && rm ` + ledger + ` && echo done`},
		{"redirect overwrite", `echo empty > ` + ledger},
		{"redirect append", `echo x >> ` + ledger},
		{"tee", `echo x | tee ` + ledger},
		{"mv away", `mv ` + ledger + ` ./gone`},
		{"mv in", `mv ./a ` + ledger},
		{"cp over destination", `cp ./a ` + ledger},
		{"truncate", `truncate -s 0 ` + ledger},
		{"dd of", `dd if=/dev/zero of=` + ledger},
		{"sed -i", `sed -i 's/a/b/' ` + ledger},
		{"find delete", `find ` + outside + ` -name '*.txt' -delete`},
		{"unresolvable var", `rm -rf $TARGET/data`},
		{"home", `rm ~/notes.txt`},
		{"python os.remove", `python3 -c "import os; os.remove('` + ledger + `')"`},
		{"script with rm outside", `./tidy.sh`},
		{"script via sh", `sh tidy.sh`},
		{"script with curl DELETE", `bash kill.sh`},
		{"python script os.remove", `python3 clean.py`},
	}
	for _, c := range catch {
		if got := floor(t, c.cmd, root); got != toolapp.DangerDangerous {
			t.Errorf("%s: %q floor = %q, want dangerous", c.name, c.cmd, got)
		}
	}

	leave := []struct{ name, cmd string }{
		{"ls", `ls -la`},
		{"git", `git status && git log --oneline -3`},
		{"rm inside", `rm -rf ./dist node_modules`},
		{"rm relative nested", `rm build/out.o`},
		{"redirect inside", `echo hi > out.txt`},
		{"redirect to /dev/null", `make 2>/dev/null`},
		{"redirect to /dev/stderr", `echo oops >&2 > /dev/stderr`},
		{"cp from outside", `cp ` + ledger + ` ./copy.txt`},
		{"cat outside", `cat ` + ledger},
		{"curl GET", `curl -s http://127.0.0.1:8080/api/v1/functions`},
		{"curl POST", `curl -s -X POST http://x -d '{}'`},
		{"url is not a path", `curl -o out.json https://example.com/a/b.json`},
		{"script that stays inside", `./ok.sh`},
		{"python without destroy", `python3 -c "print(open('` + ledger + `').read())"`},
		{"mv inside", `mv ./a ./b`},
		{"find inside delete", `find . -name '*.tmp' -delete`},
		{"grep for the word unquoted", `grep -rn DELETE ./sql`},
		{"echo mentions rm word", `echo remember`},
	}
	for _, c := range leave {
		if got := floor(t, c.cmd, root); got != toolapp.DangerSafe {
			t.Errorf("%s: %q floor = %q, want safe (a false gate trains users to click through)", c.name, c.cmd, got)
		}
	}
}

// TestCallDangerFloor_NoResidency: with nothing mounted there is no "outside", so path rules stay off
// (the whole-machine status quo), but an HTTP DELETE is dangerous regardless of any residency.
//
// TestCallDangerFloor_NoResidency：未挂驻地就没有「外面」，路径规则保持关闭（整台机器的现状）；但 HTTP DELETE
// 无论有无驻地都危险。
func TestCallDangerFloor_NoResidency(t *testing.T) {
	if got := floor(t, `rm -rf /tmp/whatever`, ""); got != toolapp.DangerSafe {
		t.Errorf("unmounted rm floor = %q, want safe", got)
	}
	if got := floor(t, `curl -X DELETE http://x/y`, ""); got != toolapp.DangerDangerous {
		t.Errorf("unmounted DELETE floor = %q, want dangerous", got)
	}
}

func floor(t *testing.T, cmd, workDir string) toolapp.DangerLevel {
	t.Helper()
	args, _ := json.Marshal(map[string]any{"command": cmd})
	return (&Bash{}).CallDangerFloor(args, workDir)
}
