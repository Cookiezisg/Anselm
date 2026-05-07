// tab-routes.js — backend route directory. One-shot fetch of /dev/routes
// (the route manifest doesn't change at runtime), with client-side text
// filter and click-to-copy-curl. Saves the testers from grepping
// handlers/*.go to find an endpoint.
//
// tab-routes.js — 后端路由目录。一次性 fetch /dev/routes（manifest 运行时
// 不变），前端文字筛选 + 点击复制 curl。免去 grep handlers/*.go 找端点。

document.addEventListener('alpine:init', () => {
  Alpine.data('routesTab', () => ({
    routes: [],
    filter: '',
    loading: false,
    err: '',

    async init() {
      await this.load();
    },

    async load() {
      this.loading = true;
      try {
        const r = await fetch('/dev/routes');
        if (!r.ok) {
          this.err = `HTTP ${r.status}` + (r.status === 404 ? ' — restart backend with --dev' : '');
          this.routes = [];
          return;
        }
        const j = await r.json();
        this.routes = j.data || [];
        this.err = '';
      } catch (e) {
        this.err = String(e);
      } finally {
        this.loading = false;
      }
    },

    get filteredRoutes() {
      const q = this.filter.trim().toLowerCase();
      if (!q) return this.routes;
      return this.routes.filter(r =>
        r.path.toLowerCase().includes(q) ||
        r.method.toLowerCase().includes(q) ||
        (r.handler || '').toLowerCase().includes(q)
      );
    },

    copyCurl(r) {
      // Build a curl command: GET → simple, others get -X METHOD; POST/PUT
      // get a header hint. Path placeholders ({id} etc.) stay literal so
      // user obviously needs to fill them in — no point fabricating IDs.
      // 构造 curl：GET 直传；其它加 -X METHOD；POST/PUT 加 header 提示。
      // 路径占位符保留 {id}，让用户清楚要替换。
      const port = window.location.port || '8080';
      const base = `http://localhost:${port}`;
      let cmd;
      if (r.method === 'GET') {
        cmd = `curl ${base}${r.path}`;
      } else if (r.method === 'POST' || r.method === 'PUT' || r.method === 'PATCH') {
        cmd = `curl -X ${r.method} -H 'Content-Type: application/json' -d '{}' ${base}${r.path}`;
      } else {
        cmd = `curl -X ${r.method} ${base}${r.path}`;
      }
      navigator.clipboard.writeText(cmd).then(() => {
        window.toast.success(`copied: ${r.method} ${r.path}`);
      }).catch(() => {
        window.toast.error('copy failed — clipboard permission denied');
      });
    },
  }));
});
