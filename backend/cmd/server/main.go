// Package main is the backend server entrypoint: a thin shell over bootstrap.Build (the real DI
// composition root). It reads config from the environment, wires SIGINT/SIGTERM to a context, and
// hands off to App.Serve — which owns boot, serving, and the ordered graceful shutdown. The shell
// knows nothing about the shutdown sequence; that is the backend's own feature.
//
// backend 服务入口：bootstrap.Build 的薄壳。从环境读配置、把 SIGINT/SIGTERM 接成 ctx，交给 App.Serve——
// 它拥有 boot、服务、有序优雅关停。壳不懂关停顺序，那是 backend 自己的功能。
package main

import (
	"context"
	"io"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"

	bootstrappkg "github.com/sunweilin/anselm/backend/internal/bootstrap"
)

// version is stamped at build time (`-ldflags "-X main.version=..."`, see Makefile); "dev" for a
// plain `go run`. version 由构建期 ldflags 盖章;裸 go run 为 "dev"。
var version = "dev"

func main() {
	app, err := bootstrappkg.Build(bootstrappkg.Config{
		DataDir:   dataDir(),
		Addr:      os.Getenv("ANSELM_ADDR"),       // "" → 127.0.0.1:8080 (loopback-only)
		AuthToken: os.Getenv("ANSELM_AUTH_TOKEN"), // "" → bearer enforcement off (dev / testend)
		// The at-rest master-key seed: ANSELM_MASTER_KEY (keychain-managed, WRK-062 拍板 #14) wins;
		// empty falls back to the machine fingerprint inside newEncryptor. ⚠️ changing the seed makes
		// EXISTING ciphertexts undecryptable — keys must be re-entered.
		// 静态加密主密钥种子:ANSELM_MASTER_KEY(钥匙串管理)优先,空则回落机器指纹。⚠️ 换种子=旧密文
		// 全部解不开,已录 key 须重录。
		Fingerprint: os.Getenv("ANSELM_MASTER_KEY"),
		Dev:         os.Getenv("ANSELM_DEV") != "",
		Version:     version,
	})
	if err != nil {
		log.Fatalf("bootstrap: %v", err)
	}

	// SIGINT/SIGTERM cancels ctx; App.Serve boots background work, serves HTTP, and runs the ordered
	// graceful shutdown (SSE streams → HTTP drain → background → DB) when ctx is cancelled.
	//
	// SIGINT/SIGTERM 取消 ctx；App.Serve 启后台、服务 HTTP，并在 ctx 取消时跑有序优雅关停（SSE 流 → HTTP
	// 排空 → 后台 → DB）。
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()
	// Sidecar deadman switch (WRK-070 T2): when the desktop app launches us it holds our stdin pipe
	// for its whole life and sets ANSELM_PARENT_WATCH=1 — stdin EOF therefore means the parent is
	// GONE, on every path (⌘Q, SIGTERM, SIGKILL, crash). macOS has no Pdeathsig, and only the clean-
	// quit path can run the app's own stop(); without this watch every other exit orphans the sidecar
	// under launchd (measured: 4 orphaned backends alive 5h+, each able to pull a 451MB llama child).
	// EOF funnels into the SAME stop as SIGTERM, so the ordered shutdown (and its child kill-set) runs.
	// Unset (terminal `go run`, testend) = zero behavior change: stdin is a tty/inherited, never EOFs
	// this way, and the goroutine is not even started.
	// 侧车「死人开关」(WRK-070 T2):桌面 app 拉起我们时全程握着 stdin 管道并置 ANSELM_PARENT_WATCH=1——
	// stdin EOF 即父进程已死,覆盖所有路径(⌘Q/SIGTERM/SIGKILL/崩溃)。macOS 无 Pdeathsig,且只有干净退出
	// 能跑 app 侧 stop();没有此守,其余退出路径一律把 sidecar 孤儿化(实测 4 个孤儿后端活 5h+)。EOF 汇入
	// 与 SIGTERM 同一个 stop,故有序关停(及其子进程 kill-set)照跑。未设(终端/testend)= 零行为变化。
	if os.Getenv("ANSELM_PARENT_WATCH") != "" {
		// The deadman is useless without this: when the parent dies, stdin AND our stderr pipe break
		// TOGETHER, and Go's default for SIGPIPE on fd 1/2 is instant death — the first log line the
		// ordered shutdown itself writes would murder it halfway (measured: sidecar died, log carried
		// zero shutdown lines, kill-set unproven). Ignoring SIGPIPE turns those writes into ignored
		// EPIPE errors so the shutdown runs to completion. Sidecar-mode only — a dev terminal keeps
		// stock signal behavior.
		// 没有这行,死人开关等于没装:父死时 stdin 与 stderr 管道**一起**断,而 Go 对 fd 1/2 的 SIGPIPE
		// 默认即死——有序关停自己写的第一条日志就会把它半路杀掉(实测:sidecar 死了,日志零关停行,
		// kill-set 未证)。忽略后写坏管道只得 EPIPE 错误,关停跑完整。仅 sidecar 模式;终端保持原生行为。
		signal.Ignore(syscall.SIGPIPE)
		go watchParent(os.Stdin, stop)
	}
	if err := app.Serve(ctx); err != nil {
		log.Fatalf("serve: %v", err)
	}
}

// watchParent blocks until r hits EOF (or any read error), then fires exit exactly once. Split out
// so the deadman semantics are unit-testable without a real pipe teardown.
//
// watchParent 阻塞读 r 至 EOF(或任何读错误)后触发 exit。拆出以便脱离真管道单测死人开关语义。
func watchParent(r io.Reader, exit func()) {
	_, _ = io.Copy(io.Discard, r)
	exit()
}

// dataDir resolves the local data root: $ANSELM_DATA_DIR, else ~/.anselm.
//
// dataDir 解析本地数据根：$ANSELM_DATA_DIR，否则 ~/.anselm。
func dataDir() string {
	if d := os.Getenv("ANSELM_DATA_DIR"); d != "" {
		return d
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".anselm"
	}
	return filepath.Join(home, ".anselm")
}
