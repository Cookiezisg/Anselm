import { Crepe } from '@milkdown/crepe';
import { replaceAll } from '@milkdown/kit/utils';
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { tags as t } from '@lezer/highlight';
import '@milkdown/crepe/theme/common/style.css'; // structural CSS only — NOT frame.css (we own the vars)
import './theme.css'; // our design tokens + selector overrides + two-weight rule
import { installBridge } from './bridge.js';
import { mentionPlugins, mentionSlashPlugin } from './mention.js';

// Code syntax highlight (One Light / One Dark) — colours are read from CSS vars (--syntax-*, defined per
// theme in theme.css), so the highlighting follows the light/dark toggle without reconfiguring CodeMirror.
// Replaces Crepe's basicSetup default (a stray One-Dark that read wrong in light). 语法色走 CSS 变量、随亮暗切换。
const anHighlight = HighlightStyle.define([
  { tag: [t.lineComment, t.blockComment, t.comment, t.docComment], color: 'var(--syntax-comment)', fontStyle: 'italic' },
  { tag: [t.keyword, t.controlKeyword, t.moduleKeyword, t.operatorKeyword, t.definitionKeyword, t.self], color: 'var(--syntax-keyword)' },
  { tag: [t.string, t.special(t.string), t.regexp, t.escape], color: 'var(--syntax-string)' },
  { tag: [t.number, t.bool, t.atom, t.null], color: 'var(--syntax-number)' },
  { tag: [t.function(t.variableName), t.function(t.propertyName), t.definition(t.function(t.variableName))], color: 'var(--syntax-function)' },
  { tag: [t.className, t.typeName, t.namespace], color: 'var(--syntax-type)' },
  { tag: [t.propertyName, t.attributeName], color: 'var(--syntax-function)' },
  { tag: [t.tagName], color: 'var(--syntax-tag)' },
  { tag: [t.special(t.brace)], color: 'var(--syntax-interp)', fontWeight: '400' },
]);

// A1 sample — only used when running STANDALONE (no Flutter host), for headless build/render checks.
// In the real app the host pushes content via setMarkdown after the ready handshake. 独立运行时的样本。
const SAMPLE = [
  '# 项目说明',
  '',
  '这是 **重点**,还有 *强调* 和 `内联代码`。你可以直接打字,不用敲符号。',
  '',
  '## 步骤',
  '',
  '1. 第一步',
  '2. 第二步',
  '3. 第三步',
  '',
  '- 无序 A',
  '  - 嵌套 B',
  '',
  '```dart',
  'void main() {',
  '  print("你好,世界");',
  '}',
  '```',
  '',
  '| 列 A | 列 B |',
  '| --- | --- |',
  '| 1 | 2 |',
  '',
  '> 引用第一行',
  '> 引用第二行',
  '',
  '- [ ] 待办未完成',
  '- [x] 待办已完成',
].join('\n');

const hasHost = typeof window.AnselmHost !== 'undefined';

// The mention pill re-hydrates label/kind from this cache (host primes it over the bridge in the real
// app). window.flutterMentionSearch feeds the @ picker candidates. Standalone = sample entities so the
// pill + picker work headlessly. 提及缓存/候选源:真 app 由桥灌,独立运行用样本实体。
window.AnMentionCache = window.AnMentionCache || new Map();
if (!hasHost) {
  const SAMPLE_ENTITIES = [
    { id: 'fn_abc123', kind: 'function', label: '汇总日报' },
    { id: 'hd_def456', kind: 'handler', label: 'Slack 通知' },
    { id: 'ag_ghi789', kind: 'agent', label: '研究助理' },
    { id: 'wf_jkl012', kind: 'workflow', label: '每日晨报流程' },
    { id: 'doc_mno345', kind: 'document', label: '产品需求文档' },
  ];
  SAMPLE_ENTITIES.forEach((e) => window.AnMentionCache.set(e.id, { kind: e.kind, label: e.label }));
  window.flutterMentionSearch = (q) =>
    SAMPLE_ENTITIES.filter((e) => e.label.includes(q) || e.id.includes(q));
}

(async () => {
  const appEl = document.querySelector('#app');

  const crepe = new Crepe({
    root: appEl,
    defaultValue: hasHost ? '' : SAMPLE,
    features: {
      // A1 core set. Image (needs backend host) + Latex (needs offline KaTeX assets) land in their
      // own sub-steps; TopBar + AI stay off. 核心集;图片/数学各自专步再开;TopBar/AI 关。
      [Crepe.Feature.ImageBlock]: false,
      [Crepe.Feature.Latex]: false,
    },
    featureConfigs: {
      [Crepe.Feature.Placeholder]: { text: '输入内容,或按 / 唤起命令…', mode: 'block' },
      // One Light/Dark syntax highlight over the code block (colours via CSS vars → theme-aware). 语法主题。
      [Crepe.Feature.CodeMirror]: { theme: syntaxHighlighting(anHighlight) },
      [Crepe.Feature.BlockEdit]: {
        // Kill the Notion-style left drag/add handle; keep the "/" slash menu. 关拖拽把手、保 slash。
        blockHandle: { shouldShow: () => false },
        // A2: localize the slash menu to Chinese + list all functions. Labels only — default icons are
        // preserved via defaultsDeep; h4–h6 dropped (null removes). The menu filters by label, so typing
        // after "/" is Chinese-aware. image/math items auto-appear once those features are enabled.
        // A2:slash 菜单中文化 + 列全功能。只给 label(默认图标经 defaultsDeep 保留);h4-6 置 null 移除。
        textGroup: {
          label: '文本',
          text: { label: '正文' },
          h1: { label: '标题 1' },
          h2: { label: '标题 2' },
          h3: { label: '标题 3' },
          h4: null,
          h5: null,
          h6: null,
          quote: { label: '引用' },
          divider: { label: '分割线' },
        },
        listGroup: {
          label: '列表',
          bulletList: { label: '无序列表' },
          orderedList: { label: '有序列表' },
          taskList: { label: '待办列表' },
        },
        advancedGroup: {
          label: '高级',
          image: { label: '图片' },
          codeBlock: { label: '代码块' },
          table: { label: '表格' },
          math: { label: '数学公式' },
        },
      },
    },
  });

  // Attach the @ mention plugins onto Crepe's underlying editor BEFORE create() (schema freezes after).
  // 提及插件须在 create() 前挂到底层 editor(create 后 schema 冻结)。
  crepe.editor.use(mentionPlugins).config(mentionSlashPlugin);

  await crepe.create();

  // ---- guard the save↔push feedback loop --------------------------------
  let programmatic = false;
  const setMarkdown = (md) => {
    programmatic = true;
    crepe.editor.action(replaceAll(md ?? ''));
    // Crepe autofocuses + scrolls the caret into view on load, which pushes the doc header off the
    // top; reset to the top so the title is always visible on open. 载入后回滚到顶,标题不被顶出视野。
    requestAnimationFrame(() => {
      const s = document.querySelector('#scroll');
      if (s) s.scrollTop = 0;
    });
    // markdownUpdated fires synchronously-ish after replaceAll; clear the guard next microtask.
    queueMicrotask(() => {
      programmatic = false;
    });
  };

  // ---- document header (title / description / tags) ----------------------
  const crumbEl = document.querySelector('#doc-crumb');
  const titleEl = document.querySelector('#doc-title');
  const descEl = document.querySelector('#doc-desc');
  const tagsEl = document.querySelector('#doc-tags');
  // Editable tags live in the co-scroll header (props edit near the title — the inspector has no property
  // form). A remove-× per chip + an add-input; changes emit {tags} to the host → PATCH. 头内可编辑标签。
  let currentTags = [];
  let editableTags = true;
  let emitTags = () => {}; // wired to the bridge after it exists (avoids TDZ on `bridge`).
  const renderTags = () => {
    tagsEl.innerHTML = '';
    currentTags.forEach((tag, i) => {
      const chip = document.createElement('span');
      chip.className = 'an-tag';
      const label = document.createElement('span');
      label.textContent = tag;
      chip.appendChild(label);
      if (editableTags) {
        const x = document.createElement('button');
        x.className = 'an-tag__x';
        x.type = 'button';
        x.tabIndex = -1;
        x.textContent = '×';
        x.addEventListener('mousedown', (e) => {
          e.preventDefault();
          currentTags.splice(i, 1);
          renderTags();
          emitTags();
        });
        chip.appendChild(x);
      }
      tagsEl.appendChild(chip);
    });
    if (!editableTags) return;
    const input = document.createElement('input');
    input.className = 'an-tag-input';
    input.placeholder = currentTags.length ? '' : '添加标签…';
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ',') {
        e.preventDefault();
        const v = input.value.trim();
        if (v && !currentTags.includes(v)) {
          currentTags.push(v);
          renderTags();
          emitTags();
          tagsEl.querySelector('.an-tag-input')?.focus();
        }
      } else if (e.key === 'Backspace' && !input.value && currentTags.length) {
        currentTags.pop();
        renderTags();
        emitTags();
        tagsEl.querySelector('.an-tag-input')?.focus();
      }
    });
    tagsEl.appendChild(input);
  };

  const setMeta = ({ crumb, name, nameEditable, description, tags } = {}) => {
    if (crumb !== undefined) crumbEl.textContent = crumb;
    if (nameEditable !== undefined) {
      titleEl.contentEditable = String(nameEditable);
      editableTags = nameEditable; // skills (name = identity) don't edit tags here either
    }
    if (name !== undefined && name !== titleEl.textContent) titleEl.textContent = name;
    if (description !== undefined && description !== descEl.textContent) descEl.textContent = description;
    if (tags !== undefined) {
      currentTags = Array.isArray(tags) ? tags.slice() : [];
      renderTags();
    }
  };

  // ---- outline geometry (scroll-spy + jump) — used by the Flutter outline -
  const scrollEl = document.querySelector('#scroll');
  const headingEls = () => Array.from(appEl.querySelectorAll('h1, h2, h3, h4, h5, h6'));
  const headingRects = () => {
    const base = scrollEl.getBoundingClientRect().top - scrollEl.scrollTop;
    return headingEls().map((h) => ({
      level: Number(h.tagName.slice(1)),
      text: h.textContent || '',
      top: Math.round(h.getBoundingClientRect().top - base),
    }));
  };
  const scrollToHeading = (index) => {
    const h = headingEls()[index];
    if (h) scrollEl.scrollTo({ top: h.offsetTop - 12, behavior: 'smooth' });
  };
  // Scroll-spy: the LAST heading scrolled up to/past a band just below the top; clamp to the last
  // heading when scrolled to the bottom (bottom sections can't physically reach the band). 大纲实时焦点。
  const activeHeading = () => {
    const hs = headingEls();
    if (!hs.length) return -1;
    if (scrollEl.scrollTop + scrollEl.clientHeight >= scrollEl.scrollHeight - 2) return hs.length - 1;
    const band = scrollEl.getBoundingClientRect().top + 24;
    let active = -1;
    for (let i = 0; i < hs.length; i++) {
      if (hs[i].getBoundingClientRect().top <= band) active = i;
      else break;
    }
    return active;
  };

  // ---- wire the bridge ---------------------------------------------------
  const bridge = installBridge({
    getMarkdown: () => crepe.getMarkdown(),
    setMarkdown,
    setMeta,
    headingRects,
    scrollToHeading,
    scrollToTop: () => scrollEl.scrollTo({ top: 0, behavior: 'smooth' }),
    focus: () => crepe.editor.action((ctx) => {}),
  });

  // Now that the bridge exists, wire the tag-edit emitter (header chips → host → PATCH tags).
  emitTags = () => bridge.emitMeta({ tags: currentTags.slice() });

  // editor change → host (debounced), guarding the programmatic echo
  crepe.on((l) =>
    l.markdownUpdated(() => {
      if (programmatic) return;
      bridge.emitChange();
    }),
  );

  // header edits → host (name/description), debounced
  let metaTimer = null;
  const emitMetaSoon = () => {
    clearTimeout(metaTimer);
    metaTimer = setTimeout(
      () => bridge.emitMeta({ name: titleEl.textContent || '', description: descEl.textContent || '' }),
      400,
    );
  };
  titleEl?.addEventListener('input', emitMetaSoon);
  descEl?.addEventListener('input', emitMetaSoon);
  // Enter in the title should not insert a newline — move focus into the body instead.
  titleEl?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      appEl.querySelector('.ProseMirror')?.focus();
    }
  });

  // scroll → (a) offset for the floating-head collapse (immediate) + (b) outline active recompute
  // (debounced). host derives the collapse + active heading. 滚动→浮层头(即时)+ 大纲(防抖)。
  let scrollTimer = null;
  scrollEl?.addEventListener('scroll', () => {
    bridge.emitScroll(scrollEl.scrollTop);
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(() => bridge.emitActive(activeHeading()), 80);
  });

  // reveal (avoid the empty→populated flash): host pushed content, now show
  document.body.classList.add('is-ready');

  // expose a stable API for the headless round-trip harness (test/roundtrip.mjs)
  window.docEditor = { getMarkdown: () => crepe.getMarkdown(), setMarkdown, setMeta };

  // handshake — the editor is mounted and the bridge is live
  bridge.ready();
})();
