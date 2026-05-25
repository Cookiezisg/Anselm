// Node 25+ ships a native globalThis.localStorage stub that has setItem=undefined
// unless --localstorage-file is set. This shim must run before any module that
// imports settings.js (which creates the zustand persist store) gets loaded.
//
// Node 25 内置的 localStorage stub 没有 setItem — 必须在 settings.js 被 import 前替换掉。

if (typeof globalThis.localStorage === "undefined" ||
    typeof globalThis.localStorage.setItem !== "function") {
  const m = new Map();
  globalThis.localStorage = {
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)),
    removeItem: (k) => m.delete(k),
    clear: () => m.clear(),
    key: (i) => Array.from(m.keys())[i] ?? null,
    get length() { return m.size; },
  };
}
