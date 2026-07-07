// @ mention as an inline ATOM pill that round-trips to a [[id]] wikilink (research report 4).
// Design: only `id` lives in markdown; `kind`/`label` are transient (re-hydrated from AnMentionCache /
// the Flutter bridge at render time) — so renaming an entity or changing its icon never dirties a doc.
// Four composable plugins wired onto crepe.editor BEFORE create():
//   $node (schema + [[id]]⇄node runners) · $view (the pill) · $remark (remark-wiki-link) · slashFactory (@).
// @ 提及 = inline atom 药丸,round-trip 成 [[id]];只 id 进 markdown,kind/label 由桥/缓存重水合。
import { $nodeSchema, $view, $remark } from '@milkdown/kit/utils';
import { slashFactory, SlashProvider } from '@milkdown/kit/plugin/slash';
import wikiLinkPlugin from 'remark-wiki-link';

// ---- per-kind icons (inline SVG, currentColor so they take the pill's ink) --------------------------
// Approximate Lucide glyphs; exact alignment with the app's AnIcons happens when wired to real entity
// kinds (A5). 每种实体一图标(currentColor 随药丸着色)。
const svg = (inner) =>
  `<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${inner}</svg>`;
const ICONS = {
  function: svg('<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M9 17c1.8 0 2.5-1 2.5-2.6V8.6C11.5 7.7 12 7 13 7h1"/><path d="M8.5 12h4"/>'),
  handler: svg('<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>'),
  agent: svg('<path d="M12 8V4H8"/><rect width="16" height="12" x="4" y="8" rx="2"/><path d="M2 14h2"/><path d="M20 14h2"/><path d="M15 13v2"/><path d="M9 13v2"/>'),
  workflow: svg('<rect width="8" height="8" x="3" y="3" rx="2"/><path d="M7 11v4a2 2 0 0 0 2 2h4"/><rect width="8" height="8" x="13" y="13" rx="2"/>'),
  document: svg('<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M16 13H8"/><path d="M16 17H8"/>'),
  unknown: svg('<circle cx="12" cy="12" r="9"/><path d="M12 8v.01M12 12v4"/>'),
};
const iconFor = (kind) => ICONS[kind] || ICONS.unknown;

// The entity id prefix encodes the kind (S15 ID宪法: <prefix>_<hex>) — so a pill loaded from a bare
// [[id]] shows the right icon even before the label cache primes. id 前缀即 kind,裸 [[id]] 也能出对图标。
const KIND_BY_PREFIX = { fn: 'function', hd: 'handler', ag: 'agent', wf: 'workflow', doc: 'document' };
const kindFromId = (id) => KIND_BY_PREFIX[String(id).split('_')[0]] || null;

// ---- 1) the inline atom node (schema + markdown runners) -------------------------------------------
export const mentionNode = $nodeSchema('mention', () => ({
  group: 'inline',
  inline: true,
  atom: true,
  selectable: true,
  draggable: false,
  marks: '',
  attrs: {
    id: { default: '' }, // the ONLY thing that round-trips to markdown
    kind: { default: 'unknown' }, // transient
    label: { default: '' }, // transient (re-resolved from id on load)
  },
  parseDOM: [
    {
      tag: 'span[data-mention-id]',
      getAttrs: (dom) => ({
        id: dom.getAttribute('data-mention-id') || '',
        kind: dom.getAttribute('data-mention-kind') || 'unknown',
        label: dom.getAttribute('data-mention-label') || '',
      }),
    },
  ],
  toDOM: (node) => [
    'span',
    {
      'data-mention-id': node.attrs.id,
      'data-mention-kind': node.attrs.kind,
      'data-mention-label': node.attrs.label,
      class: 'an-mention',
      contenteditable: 'false',
    },
    `@${node.attrs.label || node.attrs.id}`,
  ],
  // markdown (mdast wikiLink) -> mention node
  parseMarkdown: {
    match: (node) => node.type === 'wikiLink',
    runner: (state, node, type) => {
      const id = node.value || '';
      const alias = node.data && node.data.alias;
      state.addNode(type, {
        id,
        kind: 'unknown',
        label: alias && alias !== id ? alias : '',
      });
    },
  },
  // mention node -> markdown (real wikiLink mdast, so brackets stay literal, NOT escaped text)
  toMarkdown: {
    match: (node) => node.type.name === 'mention',
    runner: (state, node) => {
      state.addNode('wikiLink', undefined, undefined, {
        value: node.attrs.id,
        data: {},
      });
    },
  },
}));

// ---- 2) the pill view (icon + label; re-hydrates label/kind from the cache) ------------------------
export const mentionView = $view(mentionNode.node, () => (initialNode) => {
  const dom = document.createElement('span');
  dom.className = 'an-mention';
  dom.setAttribute('contenteditable', 'false');

  const render = (node) => {
    const { id } = node.attrs;
    const cached = window.AnMentionCache && window.AnMentionCache.get(id);
    const kind = (cached && cached.kind) || kindFromId(id) || node.attrs.kind || 'unknown';
    const label = (cached && cached.label) || node.attrs.label || id;
    dom.dataset.kind = kind;
    dom.innerHTML =
      `<span class="an-mention__icon">${iconFor(kind)}</span><span class="an-mention__label"></span>`;
    dom.querySelector('.an-mention__label').textContent = label; // textContent = XSS-safe
  };
  render(initialNode);

  return {
    dom,
    ignoreMutation: () => true,
    stopEvent: () => false,
    update: (updated) => {
      if (updated.type !== initialNode.type) return false;
      render(updated);
      return true;
    },
    selectNode: () => dom.classList.add('is-selected'),
    deselectNode: () => dom.classList.remove('is-selected'),
    destroy: () => dom.remove(),
  };
});

// ---- 3) the remark plugin that teaches the processor the [[id]] token (parse + stringify) ----------
export const remarkMention = $remark('remarkMention', () => wikiLinkPlugin, {
  aliasDivider: '|',
  pageResolver: (name) => [name],
  hrefTemplate: (permalink) => `#${permalink}`,
});

// remark-wiki-link's OWN stringifier escapes `_` (→ `doc\_abc123`) and appends an empty `|` alias
// divider (→ `[[value|]]`) — both break the byte-exact `[[id]]` the backend re-parses for relation
// edges. Override the wikiLink toMarkdown handler to emit a RAW `[[value]]` (registered AFTER
// remark-wiki-link so it wins). Keep remark-wiki-link only for PARSING `[[id]]`.
// 覆盖 wikiLink 序列化为裸 `[[value]]`(remark-wiki-link 会转义 _ + 加空 | 破坏逐字保真);仅用它解析。
export const remarkMentionStringify = $remark('remarkMentionStringify', () =>
  function remarkMentionStringify() {
    const data = this.data();
    const toMd = data.toMarkdownExtensions || (data.toMarkdownExtensions = []);
    toMd.push({ handlers: { wikiLink: (node) => `[[${node.value ?? ''}]]` } });
  },
);

// ---- 4) the "@" trigger (slashFactory + SlashProvider, async candidates over the bridge) ----------
export const mentionSlash = slashFactory('an-mention');

// matches "@" then a run of query chars, anchored at the caret
const TRIGGER = /(?:^|\s)@([\w\-./]*)$/;

export function mentionSlashPlugin(ctx) {
  ctx.set(mentionSlash.key, {
    view: (view) => {
      const dom = document.createElement('div');
      dom.className = 'an-mention-menu';
      let items = [];
      let active = 0;
      let seq = 0;

      const textBeforeCaret = (v) => {
        const { from } = v.state.selection;
        return v.state.doc.textBetween(Math.max(0, from - 120), from, undefined, '￼');
      };
      const currentQuery = (v) => {
        const m = TRIGGER.exec(textBeforeCaret(v));
        return m ? m[1] : null;
      };

      const provider = new SlashProvider({
        content: dom,
        shouldShow: () => currentQuery(view) !== null,
        offset: 6,
      });

      const paint = () => {
        dom.innerHTML = '';
        if (!items.length) {
          const empty = document.createElement('div');
          empty.className = 'an-mention-menu__empty';
          empty.textContent = '无匹配实体';
          dom.appendChild(empty);
          return;
        }
        items.forEach((it, i) => {
          const row = document.createElement('div');
          row.className = 'an-mention-menu__row' + (i === active ? ' is-active' : '');
          row.innerHTML =
            `<span class="an-mention-menu__icon">${iconFor(it.kind)}</span>` +
            `<span class="an-mention-menu__label"></span>` +
            `<span class="an-mention-menu__kind"></span>`;
          row.querySelector('.an-mention-menu__label').textContent = it.label;
          row.querySelector('.an-mention-menu__kind').textContent = it.kind;
          row.addEventListener('mousedown', (e) => {
            e.preventDefault();
            commit(it);
          });
          dom.appendChild(row);
        });
      };

      let debounce;
      const refresh = (q) => {
        clearTimeout(debounce);
        debounce = setTimeout(async () => {
          const my = ++seq;
          const res = (await (window.flutterMentionSearch ? window.flutterMentionSearch(q) : [])) || [];
          if (my !== seq) return; // stale
          items = res;
          active = 0;
          paint();
        }, 120);
      };

      const commit = (it) => {
        const { state, dispatch } = view;
        const { from } = state.selection;
        const before = textBeforeCaret(view);
        const m = TRIGGER.exec(before);
        if (!m) return;
        const matchedAt = from - m[0].length + (m[0].startsWith('@') ? 0 : 1); // keep leading space
        const node = mentionNode.type(ctx).create(it);
        dispatch(state.tr.replaceRangeWith(matchedAt, from, node).scrollIntoView());
        if (window.AnMentionCache) window.AnMentionCache.set(it.id, { kind: it.kind, label: it.label });
        provider.hide();
        view.focus();
      };

      return {
        update: (updated, prev) => {
          provider.update(updated, prev);
          const q = currentQuery(updated);
          if (q !== null) refresh(q);
        },
        destroy: () => {
          provider.destroy();
          dom.remove();
        },
      };
    },
    props: {
      handleKeyDown: (view, event) => {
        // only intercept when the menu is open (query active)
        const sel = view.state.selection;
        const before = view.state.doc.textBetween(Math.max(0, sel.from - 120), sel.from, undefined, '￼');
        if (!TRIGGER.test(before)) return false;
        const menu = document.querySelector('.an-mention-menu');
        if (!menu || menu.offsetParent === null) return false;
        const rows = menu.querySelectorAll('.an-mention-menu__row');
        if (!rows.length) return false;
        const activeIdx = Array.from(rows).findIndex((r) => r.classList.contains('is-active'));
        const setActive = (i) => {
          rows.forEach((r, k) => r.classList.toggle('is-active', k === i));
        };
        if (event.key === 'ArrowDown') {
          setActive((activeIdx + 1) % rows.length);
          return true;
        }
        if (event.key === 'ArrowUp') {
          setActive((activeIdx - 1 + rows.length) % rows.length);
          return true;
        }
        if (event.key === 'Enter') {
          rows[Math.max(0, activeIdx)].dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
          return true;
        }
        return false;
      },
    },
  });
}

// convenience: everything to wire onto crepe.editor before create().
// remarkMentionStringify MUST come after remarkMention so its raw `[[value]]` handler wins.
export const mentionPlugins = [remarkMention, remarkMentionStringify, mentionNode, mentionView, mentionSlash];
