// The JS half of the Dart↔JS bridge. Protocol (see research report 5): ONE JS→Dart channel
// (window.AnselmHost, injected by the Flutter WebViewController) carries replies + events; Dart→JS
// requests arrive via window.__anselmDispatch(json) (called from runJavaScript). Every request has an
// {id}; we reply with {t:'reply', id, ok, result|error}. Editor changes push {t:'event', name:'change'}.
// READY is a handshake (we send {t:'ready'} once the editor is mounted) — NOT onPageFinished.
// 健壮桥:单条 JS→Dart 通道承载 reply/event;Dart→JS 走 __anselmDispatch;correlation-id 配对;ready 靠握手。

/**
 * @param {Object} api - editor methods the host can call.
 *   api.getMarkdown() -> string
 *   api.setMarkdown(md) -> void        (host push; must guard the change echo internally)
 *   api.setMeta({name?,description?,tags?}) -> void
 *   api.headingRects() -> Array<{level,text,top}>   (for outline scroll-spy)
 *   api.scrollToHeading(index) -> void
 *   api.mentionResolve(list) -> void   (host answers a pending mention search / cache prime)
 * @param {Function} onReady - called after the channel is wired; return the api once the editor mounts.
 */
export function installBridge(api) {
  const host = window.AnselmHost; // Dart-injected JavaScriptChannel; absent when run standalone.
  const send = (obj) => {
    try {
      host?.postMessage(JSON.stringify(obj));
    } catch (_) {
      /* standalone/dev: no host — swallow */
    }
  };

  // ---- Dart → JS request dispatch ----------------------------------------
  const handlers = {
    getMarkdown: () => api.getMarkdown(),
    setMarkdown: (p) => {
      api.setMarkdown(String(p ?? ''));
      return null;
    },
    setMeta: (p) => {
      api.setMeta?.(p ?? {});
      return null;
    },
    setTheme: (p) => {
      // p = 'light' | 'dark'
      document.documentElement.setAttribute('data-theme', p === 'dark' ? 'dark' : 'light');
      return null;
    },
    injectFont: (p) => {
      // p = { family, base64, weightRange? } — inject a bundled Flutter font as @font-face.
      injectFontFace(p);
      return null;
    },
    headingRects: () => api.headingRects?.() ?? [],
    scrollToHeading: (p) => {
      api.scrollToHeading?.(Number(p) || 0);
      return null;
    },
    scrollToTop: () => {
      api.scrollToTop?.();
      return null;
    },
    mentionResolve: (p) => {
      // host answers a pending @ search: { reqId, results:[{id,kind,label}] }
      const r = pendingMention[p && p.reqId];
      if (r) {
        delete pendingMention[p.reqId];
        r((p && p.results) || []);
      }
      return null;
    },
    primeMentionCache: (p) => {
      // host primes id→{kind,label} so [[id]] pills render name+icon on load: { entries:[{id,kind,label}] }
      const entries = (p && p.entries) || [];
      entries.forEach((e) => window.AnMentionCache.set(e.id, { kind: e.kind, label: e.label }));
      return null;
    },
    focusEditor: () => {
      api.focus?.();
      return null;
    },
  };

  // The @ picker asks Dart for candidates over the bridge (unless a standalone stub is already set).
  // JS→Dart-with-response: emit mentionSearch{query,reqId}, park the resolver, Dart answers via
  // mentionResolve. @ 候选走桥问 Dart(JS→Dart 带响应:emit+reqId,Dart 经 mentionResolve 回填)。
  const pendingMention = {};
  let mentionSeq = 0;
  if (typeof window.flutterMentionSearch !== 'function') {
    window.flutterMentionSearch = (query) =>
      new Promise((resolve) => {
        const reqId = String(mentionSeq++);
        pendingMention[reqId] = resolve;
        send({ t: 'event', name: 'mentionSearch', payload: { query, reqId } });
        setTimeout(() => {
          if (pendingMention[reqId]) {
            delete pendingMention[reqId];
            resolve([]);
          }
        }, 4000);
      });
  }

  window.__anselmDispatch = async function (json) {
    let env;
    try {
      env = JSON.parse(json);
    } catch (_) {
      return;
    }
    const { id, method, params } = env;
    try {
      const fn = handlers[method];
      if (!fn) throw new Error('unknown method: ' + method);
      const result = await fn(params);
      send({ t: 'reply', id, ok: true, result });
    } catch (e) {
      send({ t: 'reply', id, ok: false, error: String((e && e.message) || e) });
    }
  };

  // ---- JS → Dart events ---------------------------------------------------
  let changeTimer = null;
  const emitChange = () => {
    clearTimeout(changeTimer);
    changeTimer = setTimeout(() => {
      send({ t: 'event', name: 'change', payload: api.getMarkdown() });
    }, 300); // JS-side debounce to cut bridge chatter; Dart debounces the REST save again.
  };

  const emitMeta = (meta) => send({ t: 'event', name: 'meta', payload: meta });
  const emitActive = (index) => send({ t: 'event', name: 'active', payload: index });
  const emitScroll = (offset) => send({ t: 'event', name: 'scroll', payload: offset });

  return {
    emitChange,
    emitMeta,
    emitActive,
    emitScroll,
    ready: () => send({ t: 'ready' }),
  };
}

// Inject a bundled Flutter font (passed as base64 over the bridge) as an @font-face. Runtime injection
// keeps the 20 MB MiSans out of the HTML bundle while rendering CJK in the product face (1:1 with the
// app). Idempotent per family. 运行时注入字体,MiSans 不入 bundle、CJK 与产品一致。
const _injectedFonts = new Set();
function injectFontFace({ family, base64, format = 'truetype' }) {
  if (!family || !base64 || _injectedFonts.has(family)) return;
  _injectedFonts.add(family);
  const style = document.createElement('style');
  style.textContent =
    `@font-face{font-family:'${family}';` +
    `src:url(data:font/ttf;base64,${base64}) format('${format}');` +
    `font-weight:100 900;font-display:swap;}`;
  document.head.appendChild(style);
}
