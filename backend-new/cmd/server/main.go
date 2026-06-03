// Package main is the backend-new server entrypoint (clean-room rewrite).
// It grows one module per wave; wave 7 turns this into the real DI wiring.
//
// backend-new 服务入口（clean-room 重写）。按波次逐模块生长；波次 7 收口成正式 DI 装配。
package main

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/v1/health", handleHealth)

	srv := &http.Server{Addr: ":8080", Handler: mux}

	go func() {
		log.Printf("backend-new listening on %s", srv.Addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server: %v", err)
		}
	}()

	// Block until SIGINT/SIGTERM, then drain in-flight requests before exit.
	//
	// 阻塞到收到 SIGINT/SIGTERM，再优雅排空在途请求后退出。
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

// handleHealth reports liveness as the N1 success envelope.
//
// handleHealth 以 N1 成功 envelope 返回存活状态。
func handleHealth(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]any{"data": map[string]any{"status": "ok"}})
}
