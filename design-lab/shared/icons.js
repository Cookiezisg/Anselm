/* Forgify design-lab — 共享图标集（线性描边，1.6–1.7 stroke）。
   ⚠ APPEND-ONLY：新增图标只「加 key」；**永不改名 / 删除**已有 key（别的海洋在用，改了就打架）。
   用法：icon('chat', 16) → SVG 字符串。 */
window.ICONS = {
  side:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M9 4v16"/>',
  search:'<circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/>',
  repo:'<rect x="2" y="4" width="20" height="14" rx="2"/><path d="M2 18h20M8 22h8"/>',
  chevd:'<path d="m6 9 6 6 6-6"/>', chevr:'<path d="m9 6 6 6-6 6"/>',
  panel:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M15 4v16"/>',
  moon:'<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8Z"/>',
  sun:'<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  chat:'<path d="M21 11.5a8.4 8.4 0 0 1-8.5 8.5 9 9 0 0 1-4-1L3 20l1.5-5.5a8.5 8.5 0 1 1 16.5-3Z"/>',
  tasks:'<path d="M11 6h10M11 12h10M11 18h10"/><path d="m3 6 1.5 1.5L7 5M3 12l1.5 1.5L7 11M3 18l1.5 1.5L7 17"/>',
  code:'<path d="m16 18 6-6-6-6M8 6l-6 6 6 6"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  zap:'<path d="M13 2 3 14h9l-1 8 10-12h-9z"/>',
  dispatch:'<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.5 5.5 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.5-6.5A2 2 0 0 0 16.8 4H7.2a2 2 0 0 0-1.7 1.5Z"/>',
  sliders:'<path d="M4 21v-7M4 10V3M12 21v-9M12 8V3M20 21v-5M20 12V3M1 14h6M9 8h6M17 16h6"/>',
  more:'<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
  sort:'<path d="M11 5h10M11 9h7M11 13h4M3 17l3 3 3-3M6 4v16"/>',
  branch:'<circle cx="6" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="9" r="3"/><path d="M18 12a9 9 0 0 1-9 9M6 9v6"/>',
  enter:'<path d="M9 10 4 15l5 5"/><path d="M20 4v7a4 4 0 0 1-4 4H4"/>',
  mic:'<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M5 10a7 7 0 0 0 14 0M12 19v3"/>',
  spin:'<path d="M21 12a9 9 0 1 1-6.2-8.5"/>',
  spark:'<path d="M12 2v6M12 16v6M2 12h6M16 12h6M5 5l3.5 3.5M15.5 15.5 19 19M19 5l-3.5 3.5M8.5 15.5 5 19"/>',
  agent:'<rect x="5" y="8" width="14" height="11" rx="3"/><path d="M12 8V5M9 3h6"/><circle cx="9.5" cy="13" r="1.2"/><circle cx="14.5" cy="13" r="1.2"/>',
  close:'<path d="M18 6 6 18M6 6l12 12"/>',
  edit:'<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
  play:'<path d="M8 5v14l11-7z"/>',
  // —— 四导航海洋图标 ——
  entities:'<rect x="3" y="3" width="8" height="8" rx="1.6"/><rect x="13" y="3" width="8" height="8" rx="1.6"/><rect x="3" y="13" width="8" height="8" rx="1.6"/><rect x="13" y="13" width="8" height="8" rx="1.6"/>',   // 2×2 格 = 四元
  scheduler:'<circle cx="12" cy="12" r="9"/><path d="M12 7.5V12l3 1.8"/>',                          // 钟（名/形待定，见 sidebar 注）
  doc:'<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 17h4"/>',  // 折角页
  // 后续海洋按需 append：function / handler / workflow / calendar / bell …（只加不改）
};
window.icon = (k, n = 16, w = 1.7) =>
  `<svg width="${n}" height="${n}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${ICONS[k] || ''}</svg>`;
