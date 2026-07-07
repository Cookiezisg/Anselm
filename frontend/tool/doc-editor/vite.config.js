import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

// One self-contained HTML (all JS + CSS inlined) so the WKWebView loads it offline as a Flutter
// asset with ZERO sub-resource fetches — this dodges WKWebView's relative-asset bugs entirely.
// target safari15 = the WKWebView engine floor (macOS 10.15+). 单文件离线包,规避 WKWebView 相对资源 bug。
export default defineConfig({
  plugins: [viteSingleFile()],
  build: {
    target: 'safari15',
    assetsInlineLimit: Number.MAX_SAFE_INTEGER,
  },
});
