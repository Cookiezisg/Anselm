// Package fspath resolves user-supplied file paths into clean absolute paths, and answers the one
// question the residency needs: does a path land inside a given root?
//
// It is the single physical enforcement point of Anselm's path rules, and there are two of them
// because a conversation may or may not have a mounted work dir (a "residency"):
//
//   - No residency (the default): the agent navigates the whole machine by absolute path the way a
//     person clicks through Finder. There is no cwd, so a relative path is rejected — [Expand].
//   - A residency is mounted: the agent is ZOOMED IN, not caged. A relative path resolves against
//     the residency root, absolute paths keep working everywhere — [ExpandIn].
//
// Either way a leading ~ expands to the OS home dir (which the backend process knows natively via
// os.UserHomeDir — the agent itself does not know whose home it is), and every file tool
// (Read/Write/Edit/LS/Glob/Grep) resolves through here rather than touching filepath itself.
//
// [Inside] is the residency's other half: the write gate asks it whether a target escapes the root.
// It is a SAFETY predicate, so it is fail-closed — see its doc for why it is built on os.Root
// instead of a string prefix.
//
// Package fspath 把用户给的路径解析成干净的绝对路径,并回答驻地唯一需要的那个问题:某路径是否落在某根内。
//
// 它是 Anselm 路径规则的唯一物理执行点;规则有两条,因为一个对话可能挂了工作目录(「驻地」)也可能没挂:
//
//   - 未挂驻地(默认):agent 像人点 Finder 一样用绝对路径在整台机器上导航。没有 cwd,故相对路径被
//     拒绝——[Expand]。
//   - 挂了驻地:agent 是**zoom in、不是被关起来**。相对路径以驻地为根解析,绝对路径在任何地方照旧
//     可用——[ExpandIn]。
//
// 两种情形下开头的 ~ 都展开为系统 home(后端进程经 os.UserHomeDir 天然知道——agent 自己并不知道这是
// 谁的 home);每个文件工具 (Read/Write/Edit/LS/Glob/Grep) 都走这里、不自己碰 filepath。
//
// [Inside] 是驻地的另一半:越界写闸问它目标是否逃出了根。它是**安全**谓词,故 fail-closed——为何用
// os.Root 而非字符串前缀,见其文档。
package fspath

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

var (
	// ErrEmptyPath: path is empty or whitespace-only.
	//
	// ErrEmptyPath:路径为空或纯空白。
	ErrEmptyPath = errorspkg.New(errorspkg.KindInvalid, "FSPATH_EMPTY_PATH", "path is required")

	// ErrNotAbsolute: path is not absolute after ~ expansion AND this conversation has no work dir to
	// resolve it against. The message names the recovery the LLM actually has — mounting a residency
	// is the user's action, not the agent's, so it is told to pass an absolute path.
	//
	// ErrNotAbsolute:展开 ~ 后仍非绝对,**且**本对话没有可据以解析的工作目录。文案只说 LLM 真正
	// 拥有的恢复手段——挂驻地是用户的动作、不是 agent 的,故只告诉它传绝对路径。
	ErrNotAbsolute = errorspkg.New(errorspkg.KindInvalid, "FSPATH_NOT_ABSOLUTE", "path must be absolute (no work directory is mounted for this conversation; pass an absolute path or one starting with ~)")

	// ErrNoHome: path starts with ~ but the OS home directory is unknown.
	//
	// ErrNoHome:路径以 ~ 开头但系统 home 目录未知。
	ErrNoHome = errorspkg.New(errorspkg.KindInternal, "FSPATH_NO_HOME", "cannot expand ~: home directory is unknown")
)

// Expand turns a user-supplied path into a clean absolute path. A leading "~" or
// "~/" expands to the OS home dir; the result must then be absolute. Bare "~" and
// "~/rest" are supported — "~user" is NOT (no cross-user resolution; it falls
// through to the not-absolute rejection).
//
// Expand 把用户路径变成干净绝对路径。开头的 "~" 或 "~/" 展开为系统 home;展开后结果
// 必须绝对。支持 "~" 和 "~/rest"——不支持 "~user"(不跨用户解析;它会落到非绝对拒绝)。
func Expand(path string) (string, error) {
	p := strings.TrimSpace(path)
	if p == "" {
		return "", ErrEmptyPath
	}

	if p == "~" || strings.HasPrefix(p, "~/") {
		home, err := os.UserHomeDir()
		if err != nil || home == "" {
			return "", ErrNoHome
		}
		if p == "~" {
			p = home
		} else {
			p = filepath.Join(home, p[2:])
		}
	}

	if !filepath.IsAbs(p) {
		return "", ErrNotAbsolute
	}
	return filepath.Clean(p), nil
}

// ExpandIn is [Expand] with a residency root: a path that is still relative after ~ expansion
// resolves against root instead of being rejected. root == "" is exactly [Expand] (no residency →
// no cwd → relative is unrecoverable), which is why every call site can pass the ctx value straight
// through without branching.
//
// This is a ZOOM, not a cage: an absolute path is returned untouched even when it points far outside
// root. Keeping the residency out of the resolver is deliberate — confinement would make Read refuse
// the rest of the machine, and the user's instruction was "if I want to look outside, I can". The
// only thing the root gates is WRITING outside it, and that gate is [Inside] + the human confirmation,
// not this function.
//
// ExpandIn 是带驻地根的 [Expand]:展开 ~ 后仍相对的路径以 root 解析、而不是被拒。root == "" 时它
// **就是** [Expand](无驻地 → 无 cwd → 相对不可恢复),故每个调用点都能把 ctx 里的值直接透传、无需分支。
//
// 这是 **zoom、不是笼子**:绝对路径原样返回,即便它指向 root 之外很远的地方。把驻地关在解析器之外是
// 刻意的——若做成禁闭,Read 会拒掉机器的其余部分,而用户的原话是「想看外面什么的,都可以」。根唯一
// 管的是**往外写**,而那道闸是 [Inside] + 人工确认、不是本函数。
func ExpandIn(root, path string) (string, error) {
	p := strings.TrimSpace(path)
	if p == "" {
		return "", ErrEmptyPath
	}
	// ~ wins over the residency (an explicit home reference is not a relative path), so try the
	// no-root resolution first and only fall back to the root for a genuinely relative path.
	// ~ 优先于驻地(显式 home 引用不是相对路径),故先走无根解析,只对真正相对的路径回落到根。
	abs, err := Expand(p)
	if err == nil || !errors.Is(err, ErrNotAbsolute) || root == "" {
		return abs, err
	}
	return filepath.Clean(filepath.Join(root, p)), nil
}

// Inside reports whether target lands inside root's subtree (root itself counts). It is the write
// gate's predicate, so it is FAIL-CLOSED: any uncertainty answers false, which forces the human
// confirmation rather than skipping it. root == "" answers true — with no residency there is nothing
// to be outside of, and the whole-machine status quo must stay gate-free.
//
// It is built on os.Root (Go ≥1.24; this repo pins 1.25 in mise.toml) rather than a string prefix,
// because a prefix check is wrong in three ways this function must not be wrong in:
//
//   - Sibling directories: strings.HasPrefix("/root-evil/x", "/root") is TRUE. filepath.Rel gives
//     "../root-evil/x" and the ".." is the honest answer.
//   - Symlink escape: root/link → /etc/passwd is lexically inside and physically outside. os.Root
//     re-resolves every component against a kernel-checked root and returns "path escapes from
//     parent"; verified empirically on darwin/go1.25 for absolute, relative AND directory symlinks
//     (Root does NOT chroot-rewrite an absolute link target, so its verdict matches what the real
//     os.Rename/os.WriteFile would follow — which is the only thing that matters here).
//   - Non-existent targets: a fresh Write has no file to resolve. Walking the components top-down
//     and stopping at the first ErrNotExist is exact: everything below a path that does not exist
//     cannot be a symlink, so it cannot escape.
//
// Stat (not Lstat) is used on purpose: Write/Edit FOLLOW a final symlink, so a last component
// pointing out of the root is a real escape and must gate.
//
// Known conservative edge (fail-closed, documented rather than papered over): the lexical
// filepath.Rel step is case-SENSITIVE, so on a case-insensitive filesystem (macOS/Windows) a target
// spelled /Root/x under a residency /root answers false and gates. Likewise a residency given as a
// symlink while the target is spelled with its real path. Both cost one extra confirmation; neither
// can ever let an outside write through unasked.
//
// Inside 报告 target 是否落在 root 子树内(root 自身算内)。它是越界写闸的谓词,故 **fail-closed**:
// 任何不确定都答 false,即宁可**多**弹一次人闸也不跳过。root == "" 答 true——无驻地即无「外面」,
// 整台机器的现状必须保持无闸。
//
// 它建在 os.Root 上(Go ≥1.24;本仓 mise.toml 钉 1.25)、而非字符串前缀,因为前缀判定会在本函数
// 绝不能错的三处出错:
//
//   - **兄弟目录**:strings.HasPrefix("/root-evil/x", "/root") 为**真**。filepath.Rel 给出
//     "../root-evil/x",那个 ".." 才是诚实答案。
//   - **符号链接逃逸**:root/link → /etc/passwd 字面在内、物理在外。os.Root 对着内核校验过的根
//     重新解析每个组件、返回 "path escapes from parent";在 darwin/go1.25 上对绝对、相对**与目录**
//     三种符号链接实测确认(Root **不会**把绝对链接目标 chroot 式重写,故它的判词与真正的
//     os.Rename/os.WriteFile 会跟随的目标一致——而这里唯一重要的就是这一点)。
//   - **尚不存在的目标**:一次全新 Write 没有文件可解析。自顶向下逐组件走、在首个 ErrNotExist 处
//     停,是精确的:一个不存在的路径之下的一切都不可能是符号链接,故不可能逃逸。
//
// 刻意用 Stat 而非 Lstat:Write/Edit 会**跟随**末段符号链接,故指向根外的末段是真逃逸、必须设闸。
//
// **已知的保守边界**(fail-closed,如实记档而非糊过去):字面的 filepath.Rel 一步对大小写**敏感**,
// 故在大小写不敏感的文件系统(macOS/Windows)上,驻地为 /root 而目标拼作 /Root/x 会答 false 并设闸;
// 驻地给的是符号链接而目标拼的是真实路径同理。两者各多付一次确认;两者都绝不可能让一次外部写悄悄通过。
func Inside(root, target string) bool {
	if root == "" {
		return true
	}
	rel, err := filepath.Rel(filepath.Clean(root), filepath.Clean(target))
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return false
	}
	r, err := os.OpenRoot(root)
	if err != nil {
		return false // an unopenable root (gone, not a dir, no permission) is not a root we can vouch for
	}
	defer func() { _ = r.Close() }()
	if rel == "." {
		return true // the residency root itself
	}
	parts := strings.Split(rel, string(filepath.Separator))
	for i := range parts {
		if _, err := r.Stat(filepath.Join(parts[:i+1]...)); err != nil {
			// ErrNotExist stops the walk: nothing below a missing component exists, so nothing below
			// it can be a symlink out. Anything else (an escape, a permission error) fails closed.
			// ErrNotExist 即止步:缺失组件之下一无所有,故其下不可能有向外的符号链接。其余一切
			// (逃逸、权限错)一律 fail-closed。
			return errors.Is(err, fs.ErrNotExist)
		}
	}
	return true
}
