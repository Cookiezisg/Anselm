import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tsconfigPaths from "vite-tsconfig-paths";
import path from "node:path";

// V3 testend — shares entity types with frontend via vite path alias.
// type-only deep imports: @frontend/entities/<x>/model/types.
//
// V3 testend 通过 vite alias 共享 frontend entity 类型;只深引 type 文件。
export default defineConfig({
  base: "/dev/",
  plugins: [react(), tsconfigPaths()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
      "@frontend": path.resolve(__dirname, "../frontend/src"),
    },
  },
  build: {
    outDir: "dist",
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          monaco: ["monaco-editor", "@monaco-editor/react"],
          reactflow: ["reactflow"],
        },
      },
    },
  },
  server: {
    port: 5174,
    proxy: {
      "/api": "http://localhost:8742",
      "/dev/logs": { target: "http://localhost:8742", changeOrigin: true, ws: false },
      "/dev/info": "http://localhost:8742",
      "/dev/runtime": "http://localhost:8742",
      "/dev/sql": "http://localhost:8742",
      "/dev/routes": "http://localhost:8742",
      "/dev/forgify-home": "http://localhost:8742",
      "/dev/bash-processes": "http://localhost:8742",
      "/dev/mock-llm": "http://localhost:8742",
      "/dev/llm": "http://localhost:8742",
    },
  },
});
