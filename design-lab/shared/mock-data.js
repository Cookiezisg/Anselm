/* 演示用静态数据 + 图标集。绝不连后端。
   实体形状参照后端契约（Agent: name/model/system/tools/...），仅作示意。 */

// 线性描边图标（Lucide/Tabler 风，1.6 stroke）
const ICONS = {
  chat:    '<path d="M21 11.5a8.38 8.38 0 0 1-8.5 8.5 9 9 0 0 1-4-1L3 20l1.5-5.5a8.5 8.5 0 1 1 16.5-3Z"/>',
  build:   '<path d="M12 2 4 6v6c0 5 3.5 8 8 10 4.5-2 8-5 8-10V6Z"/><path d="m9 12 2 2 4-4"/>',
  docs:    '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8Z"/><path d="M14 2v6h6"/><path d="M8 13h8M8 17h6"/>',
  bell:    '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
  settings:'<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z"/>',
  agent:   '<rect x="5" y="8" width="14" height="11" rx="3"/><path d="M12 8V5M9 3h6"/><circle cx="9.5" cy="13" r="1.2"/><circle cx="14.5" cy="13" r="1.2"/>',
  function:'<path d="M9 3H8a3 3 0 0 0-3 3v3a2 2 0 0 1-2 2 2 2 0 0 1 2 2v3a3 3 0 0 0 3 3h1"/><path d="M15 3h1a3 3 0 0 1 3 3v3a2 2 0 0 0 2 2 2 2 0 0 0-2 2v3a3 3 0 0 1-3 3h-1"/>',
  handler: '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5M12 22V12"/>',
  workflow:'<circle cx="6" cy="6" r="2.5"/><circle cx="18" cy="6" r="2.5"/><circle cx="12" cy="18" r="2.5"/><path d="M8.5 6H18M6 8.5c0 4 6 3 6 7M18 8.5c0 4-6 3-6 7"/>',
  send:    '<path d="M22 2 11 13M22 2l-7 20-4-9-9-4Z"/>',
  spin:    '<path d="M21 12a9 9 0 1 1-6.2-8.5" />',
  check:   '<path d="M20 6 9 17l-5-5"/>',
  chevron: '<path d="m9 6 6 6-6 6"/>',
  collapse:'<path d="m15 6-6 6 6 6"/>',
  close:   '<path d="M18 6 6 18M6 6l12 12"/>',
  search:  '<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
  sun:     '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  moon:    '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"/>',
  edit:    '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
  sparkle: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M6.3 6.3l2.4 2.4M15.3 15.3l2.4 2.4M17.7 6.3l-2.4 2.4M8.7 15.3l-2.4 2.4"/>',
  plus:    '<path d="M12 5v14M5 12h14"/>',
  newchat: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
};
function icon(name, size = 18, stroke = 1.7) {
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">${ICONS[name] || ''}</svg>`;
}

// Build：四类实体示例（Quadrinity）
const BUILD = [
  { kind: 'agent',    name: 'Researcher',    desc: '深度调研：检索、交叉验证、带引用综述。', model: 'claude-opus-4-8', meta: 'v4 · 6 tools' },
  { kind: 'agent',    name: 'Code Reviewer', desc: '审 diff、抓回归、按团队规范给整改清单。', model: 'claude-sonnet-4-6', meta: 'v2 · 4 tools' },
  { kind: 'function', name: 'slugify',       desc: '把任意标题转成 URL-safe slug。', model: 'pure', meta: 'v1 · CEL' },
  { kind: 'function', name: 'fetch_weather', desc: '按城市取实时天气（结构化输出）。', model: 'pure', meta: 'v3 · HTTP' },
  { kind: 'handler',  name: 'PdfSession',    desc: '有状态 PDF 会话：打开、翻页、抽取。', model: 'stateful', meta: 'v2 · 5 ops' },
  { kind: 'workflow', name: 'Nightly Digest',desc: '每晚汇总仓库动态 → 生成简报 → 推送。', model: 'graph', meta: 'v5 · 7 nodes' },
];

const DOCS = [
  { name: 'API 契约速查',  sub: '由 Researcher 维护 · 12 分钟前更新', kind: 'docs' },
  { name: '上手指南',      sub: '手写 · 昨天',                       kind: 'docs' },
  { name: '故障处理手册',  sub: 'Nightly Digest 自动追加 · 3 天前',   kind: 'docs' },
  { name: '团队代码规范',  sub: 'Code Reviewer 引用 · 上周',          kind: 'docs' },
];

const NOTIFS = [
  { title: 'Nightly Digest 运行完成', sub: '7 节点全绿 · 生成简报「6 月 13 日」', time: '08:02', unread: true,  kind: 'workflow' },
  { title: 'PR triage 等待你审批',    sub: '工具 delete_branch 标记为 dangerous',  time: '昨天',  unread: true,  kind: 'workflow' },
  { title: 'Researcher 已升级到 v4',  sub: '聊天中由你触发 · 新增 web_search',     time: '昨天',  unread: false, kind: 'agent' },
  { title: 'Invoice OCR 运行失败',    sub: '节点 extract 超时 · 可一键重跑',        time: '周三',  unread: false, kind: 'workflow' },
];
