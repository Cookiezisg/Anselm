// drag.js — resizable panel dividers between sidebar/chat and chat/tools.

(function () {
  document.addEventListener('DOMContentLoaded', initDrag);

  // Layout policy:
  //   - sidebar: min 180px, max enough that chat keeps >= 380px after subtracting
  //   - tools:   min 380px (panels themselves get cramped below this)
  //   - chat:    minimum 380px is reserved by both maxes above
  //   - default: tools and chat split the remaining space 50/50; sidebar fixed
  //
  // 布局策略：sidebar ≥ 180、tools ≥ 380、chat ≥ 380；默认 tools 和 chat
  // 各占剩余宽度一半。
  const MIN_SIDEBAR = 180;
  const MIN_TOOLS   = 380;
  const MIN_CHAT    = 380;
  const HANDLE_W    = 4; // matches CSS .drag-handle width × 2 occurrences = 8px

  function initDrag() {
    const layout = document.querySelector('.layout');
    if (!layout) return;

    let sidebarW = 230;
    let toolsW   = computeDefaultToolsW(layout, sidebarW);

    let active = null; // 'sidebar' | 'tools'
    let startX = 0;
    let startW = 0;

    applyWidths();

    document.querySelectorAll('.drag-handle').forEach(handle => {
      handle.addEventListener('mousedown', e => {
        e.preventDefault();
        active = handle.dataset.panel;
        startX = e.clientX;
        startW = active === 'sidebar' ? sidebarW : toolsW;
        handle.classList.add('dragging');
        document.body.style.cursor    = 'col-resize';
        document.body.style.userSelect = 'none';
      });
    });

    document.addEventListener('mousemove', e => {
      if (!active) return;
      const delta = e.clientX - startX;
      const totalW = layout.getBoundingClientRect().width;

      if (active === 'sidebar') {
        const maxSidebar = totalW - toolsW - HANDLE_W * 2 - MIN_CHAT;
        sidebarW = clamp(startW + delta, MIN_SIDEBAR, Math.max(MIN_SIDEBAR, maxSidebar));
      } else {
        // Tools is on the right: dragging left (negative delta) grows it.
        const maxTools = totalW - sidebarW - HANDLE_W * 2 - MIN_CHAT;
        toolsW = clamp(startW - delta, MIN_TOOLS, Math.max(MIN_TOOLS, maxTools));
      }
      applyWidths();
    });

    document.addEventListener('mouseup', () => {
      if (!active) return;
      document.querySelectorAll('.drag-handle').forEach(h => h.classList.remove('dragging'));
      active = null;
      document.body.style.cursor     = '';
      document.body.style.userSelect = '';
    });

    // Reflow on window resize: keep tools at <= half-width fallback unless user
    // has already custom-sized it via drag (we don't try to detect that — they
    // can drag again).
    // 窗口变化时回到默认 50/50 分配（用户已 drag 过的话再次 drag 即可调整）。
    window.addEventListener('resize', () => {
      const totalW = layout.getBoundingClientRect().width;
      // Just clamp current values; don't reset (user might have set a width
      // they like; we just enforce the maxes don't violate MIN_CHAT).
      // 仅 clamp，不重置（用户偏好的宽度尽量保留）。
      const maxTools = totalW - sidebarW - HANDLE_W * 2 - MIN_CHAT;
      if (toolsW > maxTools) toolsW = Math.max(MIN_TOOLS, maxTools);
      const maxSidebar = totalW - toolsW - HANDLE_W * 2 - MIN_CHAT;
      if (sidebarW > maxSidebar) sidebarW = Math.max(MIN_SIDEBAR, maxSidebar);
      applyWidths();
    });

    function applyWidths() {
      layout.style.gridTemplateColumns =
        `${sidebarW}px 4px 1fr 4px ${toolsW}px`;
    }
  }

  function computeDefaultToolsW(layout, sidebarW) {
    const totalW = layout.getBoundingClientRect().width;
    const remaining = totalW - sidebarW - HANDLE_W * 2;
    // Default: tools and chat split remaining 50/50, but keep MIN_TOOLS as floor.
    // 默认：剩余空间 chat 与 tools 各半，最低 MIN_TOOLS。
    return Math.max(MIN_TOOLS, Math.floor(remaining / 2));
  }

  function clamp(val, min, max) {
    return Math.max(min, Math.min(max, val));
  }
})();
