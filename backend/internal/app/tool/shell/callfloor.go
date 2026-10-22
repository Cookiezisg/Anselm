package shell

import (
	"bytes"
	"encoding/json"
	"os"
	"regexp"
	"strings"

	toolapp "github.com/sunweilin/anselm/backend/internal/app/tool"
	fspathpkg "github.com/sunweilin/anselm/backend/internal/pkg/fspath"
)

// The Bash tool has no allow/deny list on purpose (see danger.go), but "the model's own honesty is the
// only control" was measured to be too little: with a residency mounted, a model told that writing
// outside it needs confirmation simply reached the same file through a shell redirect and labelled
// the call `cautious`; others deleted entities with `curl -X DELETE` against the local API, or ran a
// script whose body held the destructive line. CallDangerFloor is the net under that self-report: a
// small, deliberately conservative reading of the command that forces the human gate for the three
// effects the product itself gates elsewhere — an HTTP DELETE, a destructive file operation whose target
// resolves outside the residency, and a script that does either.
//
// It is NOT a sandbox and does not claim completeness: `eval "$(…)"`, `xargs rm`, or a binary that
// deletes on its own are invisible to it, and the model's self-report still applies on top. Where a
// target cannot be resolved (an unset-looking $VAR) it fails closed, like fspath.Inside.
//
// Bash 工具刻意没有 allow/deny 名单（见 danger.go），但「模型自己的诚实是唯一的控制」被实测证明不够：
// 挂了驻地时，被告知「在驻地外写需确认」的模型直接用 shell 重定向写同一个文件、并把调用标成 `cautious`；
// 另一些用 `curl -X DELETE` 打本地 API 删实体，或运行一个函数体里藏着破坏行的脚本。CallDangerFloor 是
// 垫在这份自报之下的网：对命令做一次小而刻意保守的解读，为产品在别处本就设闸的三种效果强制开人闸——
// HTTP DELETE、目标落在驻地之外的破坏性文件操作、以及做这两者之一的脚本。
//
// 它**不是**沙箱、也不自称完备：`eval "$(…)"`、`xargs rm`、自带删除行为的二进制它看不见，模型自报仍叠加
// 生效。目标解不出时（看似未设的 $VAR）与 fspath.Inside 一样 fail-closed。

var (
	// reHTTPDelete matches an HTTP DELETE however the client spells it (curl -X, wget --method, a
	// `method="DELETE"` keyword, requests.delete(...)), and any quoted "DELETE" literal: a script that
	// passes the verb through a helper (`request("DELETE", path)`) was measured walking straight past
	// the keyword forms. A quoted bare word is rare outside HTTP code, so the false-gate cost is small.
	// reHTTPDelete 匹配 HTTP DELETE 的各种写法（curl -X、wget --method、`method="DELETE"` 关键字、
	// requests.delete(...)），以及任何被引号包住的 "DELETE" 字面量：经 helper 传动词的脚本
	// （`request("DELETE", path)`）被实测直接绕过关键字写法。被引号包住的裸词在 HTTP 代码之外很少见，误闸代价小。
	reHTTPDelete = regexp.MustCompile(`(?i)(?:-X\s*|--request[=\s]+|--method[=\s]+|\bmethod\s*[=:]\s*['"])DELETE\b|\b(?:requests|httpx|session|client)\.delete\s*\(|['"]DELETE['"]`)

	// reCodeDestroy matches a destructive filesystem call written as code (the command is `python x.py`
	// or a heredoc). Its target is then read from the path literals around it.
	// reCodeDestroy 匹配以代码写成的破坏性文件系统调用（命令是 `python x.py` 或 heredoc）；目标从其周围的路径字面量里读。
	reCodeDestroy = regexp.MustCompile(`\b(?:os\.(?:remove|unlink|rmdir|removedirs|rename|replace)|shutil\.(?:rmtree|move)|Path\([^)]*\)\.(?:unlink|write_text|write_bytes|rename)|fs\.(?:rm|rmSync|unlink|unlinkSync|rmdir|rmdirSync|writeFile|writeFileSync|rename|renameSync))\b`)

	// rePathLiteral pulls absolute / ~ / $VAR-rooted path literals out of free text. A leading ':' is
	// deliberately not a boundary so `http://host/x` is not read as the path `//host/x`.
	// rePathLiteral 从自由文本里取绝对 / ~ / $VAR 起头的路径字面量。前导 ':' 刻意不算边界，免得 `http://host/x` 被读成路径。
	rePathLiteral = regexp.MustCompile(`(?:^|[\s'"=(,\[])((?:~|/|\$\{?[A-Za-z_]\w*\}?/)[^\s'"|;&)<>,\]]*)`)

	reRedirect = regexp.MustCompile(`>>?\s*([^\s|;&<>]+)`)
	reTee      = regexp.MustCompile(`\btee\s+(?:-\S+\s+)*([^\s|;&<>]+)`)
	reDDOf     = regexp.MustCompile(`\bof=(\S+)`)
	reSegment  = regexp.MustCompile(`[;&|\n]+`)
)

// harmlessSink are the pseudo-files a redirect may name without touching the user's data.
// harmlessSink 是重定向可以指向、而不碰用户数据的伪文件。
var harmlessSink = map[string]bool{"/dev/null": true, "/dev/stdout": true, "/dev/stderr": true, "/dev/tty": true}

// removeVerbs destroy or move their operands, so EVERY operand counts. Destination-only verbs
// (cp, tee, redirects, dd) are read separately so that copying FROM outside is not flagged.
// removeVerbs 毁掉或移走自己的操作数，故**每个**操作数都算；只写目的地的动词（cp、tee、重定向、dd）另读，
// 以免「从外面复制进来」被误标。
var removeVerbs = map[string]bool{"rm": true, "rmdir": true, "unlink": true, "shred": true, "truncate": true, "mv": true}

const maxScriptPeek = 64 << 10

// CallDangerFloor implements toolapp.CallDangerFloorer for Bash.
// CallDangerFloor 为 Bash 实现 toolapp.CallDangerFloorer。
func (t *Bash) CallDangerFloor(argsJSON json.RawMessage, workDir string) toolapp.DangerLevel {
	var a bashArgs
	if json.Unmarshal(argsJSON, &a) != nil {
		return toolapp.DangerSafe
	}
	if commandIsDestructive(a.Command, workDir, true) {
		return toolapp.DangerDangerous
	}
	return toolapp.DangerSafe
}

// commandIsDestructive reads one command (or, with peek, the scripts it names inside the residency).
// commandIsDestructive 读一条命令（peek 为真时还读它在驻地内点名的脚本）。
func commandIsDestructive(cmd, workDir string, peek bool) bool {
	if reHTTPDelete.MatchString(cmd) {
		return true
	}
	// Path rules mean "outside the residency"; with nothing mounted there is no outside, and the
	// whole-machine status quo stays gate-free, exactly like fspath.Inside("").
	// 路径规则的意思是「驻地之外」；未挂驻地就没有外面，整台机器的现状保持无闸，与 fspath.Inside("") 一致。
	if workDir == "" {
		return false
	}
	outside := func(raw string) bool {
		raw = strings.Trim(raw, `'"`)
		if raw == "" || harmlessSink[raw] {
			return false
		}
		if strings.HasPrefix(raw, "$") {
			return true // unresolvable ⇒ fail closed. 解不出 ⇒ fail-closed。
		}
		abs, err := fspathpkg.ExpandIn(workDir, raw)
		return err != nil || !fspathpkg.Inside(workDir, abs)
	}
	for _, m := range reRedirect.FindAllStringSubmatch(cmd, -1) {
		if outside(m[1]) {
			return true
		}
	}
	for _, re := range []*regexp.Regexp{reTee, reDDOf} {
		for _, m := range re.FindAllStringSubmatch(cmd, -1) {
			if outside(m[1]) {
				return true
			}
		}
	}
	for _, seg := range reSegment.Split(cmd, -1) {
		if segmentDestroysOutside(strings.Fields(seg), outside) {
			return true
		}
	}
	if reCodeDestroy.MatchString(cmd) {
		for _, m := range rePathLiteral.FindAllStringSubmatch(cmd, -1) {
			if outside(m[1]) {
				return true
			}
		}
	}
	if peek {
		for _, f := range scriptFilesNamed(cmd, workDir) {
			if commandIsDestructive(f, workDir, false) {
				return true
			}
		}
	}
	return false
}

// segmentDestroysOutside reads one simple command.
// segmentDestroysOutside 读一条简单命令。
func segmentDestroysOutside(tok []string, outside func(string) bool) bool {
	for i, w := range tok {
		verb := w[strings.LastIndex(w, "/")+1:]
		rest := tok[i+1:]
		switch {
		case removeVerbs[verb]:
			for _, o := range rest {
				if !strings.HasPrefix(o, "-") && outside(o) {
					return true
				}
			}
		case verb == "cp" || verb == "install" || verb == "ln":
			// Only the destination (last operand) is written. 只有目的地（最后一个操作数）被写。
			var ops []string
			for _, o := range rest {
				if !strings.HasPrefix(o, "-") {
					ops = append(ops, o)
				}
			}
			if len(ops) > 0 && outside(ops[len(ops)-1]) {
				return true
			}
		case verb == "sed" && hasFlag(rest, "-i"):
			for _, o := range rest {
				if !strings.HasPrefix(o, "-") && (strings.Contains(o, "/") || strings.HasPrefix(o, "~")) && outside(o) {
					return true
				}
			}
		case verb == "find" && (hasFlag(rest, "-delete") || hasFlag(rest, "-exec")):
			for _, o := range rest {
				if strings.HasPrefix(o, "-") || strings.HasPrefix(o, "(") {
					break
				}
				if outside(o) {
					return true
				}
			}
		}
	}
	return false
}

func hasFlag(tok []string, flag string) bool {
	for _, t := range tok {
		if t == flag || (flag == "-i" && strings.HasPrefix(t, "-i")) {
			return true
		}
	}
	return false
}

// scriptFilesNamed returns the text of small regular text files inside the residency that the command
// names as a word (`./tidy.sh`, `sh tidy.sh`, `python3 clean.py`) — a script's body is part of what
// the command does. Bounded and non-recursive.
//
// scriptFilesNamed 返回命令点名的、驻地内的小型常规文本文件的内容（`./tidy.sh`、`sh tidy.sh`、
// `python3 clean.py`）——脚本的函数体是这条命令所做之事的一部分。有上限、不递归。
func scriptFilesNamed(cmd, workDir string) []string {
	var out []string
	seen := map[string]bool{}
	for _, w := range strings.Fields(cmd) {
		w = strings.Trim(w, `'";|&()`)
		if w == "" || strings.HasPrefix(w, "-") || len(w) > 1024 || seen[w] {
			continue
		}
		seen[w] = true
		abs, err := fspathpkg.ExpandIn(workDir, w)
		if err != nil || !fspathpkg.Inside(workDir, abs) {
			continue
		}
		st, err := os.Stat(abs)
		if err != nil || !st.Mode().IsRegular() || st.Size() == 0 || st.Size() > maxScriptPeek {
			continue
		}
		b, err := os.ReadFile(abs)
		if err != nil || bytes.IndexByte(b, 0) >= 0 {
			continue
		}
		out = append(out, string(b))
		if len(out) == 8 {
			break
		}
	}
	return out
}
