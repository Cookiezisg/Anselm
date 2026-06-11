// Package main is the backend-new server entrypoint: a thin shell over bootstrap.Build, which is
// the real DI composition root (M7). main only reads config from the environment, boots the
// assembled App, serves HTTP, and drains gracefully on SIGINT/SIGTERM.
//
// backend-new 服务入口：bootstrap.Build 的薄壳——Build 才是真正的 DI composition root（M7）。main 只
// 从环境读配置、Boot 装好的 App、服务 HTTP、并在 SIGINT/SIGTERM 时优雅排空。
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	bootstrappkg "github.com/sunweilin/forgify/backend/internal/bootstrap"
)

func main() {
	app, err := bootstrappkg.Build(bootstrappkg.Config{
		DataDir: dataDir(),
		Addr:    os.Getenv("FORGIFY_ADDR"), // "" → :8080
		Dev:     os.Getenv("FORGIFY_DEV") != "",
	})
	if err != nil {
		log.Fatalf("bootstrap: %v", err)
	}

	// Boot starts background work (sandbox runtimes, handler/mcp processes, trigger listeners,
	// scheduler drain ticker); best-effort so a degraded subsystem never blocks serving.
	//
	// Boot 启后台工作（sandbox runtime、handler/mcp 进程、trigger listener、scheduler drain ticker）；
	// best-effort，单子系统降级不阻塞服务。
	app.Boot(context.Background())

	srv := &http.Server{Addr: app.Addr, Handler: app.Handler}
	go func() {
		log.Printf("backend-new listening on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	// Block until SIGINT/SIGTERM, then drain in-flight requests + stop background work.
	//
	// 阻塞到 SIGINT/SIGTERM，再优雅排空在途请求 + 停后台工作。
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("http shutdown: %v", err)
	}
	app.Shutdown(ctx)
}

// dataDir resolves the local data root: $FORGIFY_DATA_DIR, else ~/.forgify.
//
// dataDir 解析本地数据根：$FORGIFY_DATA_DIR，否则 ~/.forgify。
func dataDir() string {
	if d := os.Getenv("FORGIFY_DATA_DIR"); d != "" {
		return d
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return ".forgify"
	}
	return filepath.Join(home, ".forgify")
}
