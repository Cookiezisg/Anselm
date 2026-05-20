// DocumentsPane — Notion-style: tree sidebar + markdown page.
//
//   - Left: useDocumentTree() flat metadata → hierarchical render with
//     folder open/close, click leaf to load, hover for ActionMenu (rename
//     / delete / new child)
//   - Right: title (contentEditable PATCH on blur), meta line with
//     EntityRelMeta + AskAi, editor (textarea with autosave 1.5s debounce),
//     preview toggle
//   - Inside editor: typing `/` at line start opens slash command panel
//     (h1/h2/h3, list, code, quote, table); typing `@` opens doc picker
//     that inserts [[doc-name]] markdown wikilink
//
// DocumentsPane —— Notion 风格：左边树 + 右边 markdown 页。新建 / 重命名 /
// 删除 / 移动全走真后端；slash 面板 + @ 引用都嵌在 textarea 内。

import { useEffect, useMemo, useRef, useState } from "react";
import { Icon } from "../../components/primitives/Icon.jsx";
import { Button } from "../../components/primitives/Button.jsx";
import { ActionMenu } from "../../components/shared/ActionMenu.jsx";
import { AskAiTrigger } from "../../components/shared/AskAiTrigger.jsx";
import { EntityRelMeta } from "../../components/shared/EntityRelMeta.jsx";
import { RelTime } from "../../components/shared/RelTime.jsx";
import {
  useDocumentTree, useDocument,
  useCreateDocument, useUpdateDocument, useDeleteDocument, useMoveDocument,
} from "../../api/library.js";
import { useUIStore } from "../../store/ui.js";

export function DocumentsPane() {
  const treeQ = useDocumentTree();
  const setActiveDocument = useUIStore((s) => s.setActiveDocument);
  const activeDoc = useUIStore((s) => s.activeDocument);
  const [openSet, setOpenSet] = useState(new Set());

  const flat = treeQ.data || [];
  const rooted = useMemo(() => buildTree(flat), [flat]);

  const createDoc = useCreateDocument();
  const pushToast = useUIStore((s) => s.pushToast);

  const onCreateRoot = async () => {
    const name = prompt("新页面名称？", "未命名");
    if (!name) return;
    try {
      const res = await createDoc.mutateAsync({ name, parentId: null });
      setActiveDocument(res.id);
    } catch (e) { pushToast({ kind: "error", title: "创建失败", desc: e.message }); }
  };

  return (
    <div className="doc-shell">
      <DocSidebar
        tree={rooted}
        openSet={openSet}
        setOpenSet={setOpenSet}
        selectedId={activeDoc}
        onSelect={setActiveDocument}
        onCreateRoot={onCreateRoot}
        isLoading={treeQ.isLoading}
      />
      <div className="doc-main">
        {activeDoc
          ? <DocPage docId={activeDoc} />
          : <DocEmpty onCreate={onCreateRoot} />}
      </div>
    </div>
  );
}

function DocEmpty({ onCreate }) {
  return (
    <div className="empty" style={{ flex: 1 }}>
      <Icon.FileText className="icon" />
      <div className="title">还没有打开的文档</div>
      <div className="sub">左侧选一篇 · 或</div>
      <Button size="sm" variant="accent" onClick={onCreate} style={{ marginTop: 12 }}>
        <Icon.Plus /> 新建第一篇
      </Button>
    </div>
  );
}

// ── Tree helpers ─────────────────────────────────────────────────────────
function buildTree(flat) {
  const byId = new Map(flat.map((d) => [d.id, { ...d, children: [] }]));
  const roots = [];
  for (const d of byId.values()) {
    if (d.parentId && byId.has(d.parentId)) byId.get(d.parentId).children.push(d);
    else roots.push(d);
  }
  const sortRec = (n) => {
    n.children.sort((a, b) => (a.position - b.position) || a.name.localeCompare(b.name));
    n.children.forEach(sortRec);
  };
  roots.sort((a, b) => (a.position - b.position) || a.name.localeCompare(b.name));
  roots.forEach(sortRec);
  return roots;
}

function DocSidebar({ tree, openSet, setOpenSet, selectedId, onSelect, onCreateRoot, isLoading }) {
  const [q, setQ] = useState("");
  const filtered = useMemo(() => {
    if (!q.trim()) return tree;
    const ql = q.toLowerCase();
    const walk = (nodes) => nodes
      .map((n) => {
        const kids = n.children?.length ? walk(n.children) : [];
        if (n.name.toLowerCase().includes(ql) || kids.length) return { ...n, children: kids };
        return null;
      })
      .filter(Boolean);
    return walk(tree);
  }, [tree, q]);

  return (
    <aside className="doc-sidebar">
      <div className="doc-sidebar-head">
        <div className="search-input doc-search">
          <Icon.Search className="icon" />
          <input placeholder="搜索文档…" value={q} onChange={(e) => setQ(e.target.value)} />
        </div>
        <button className="icon-btn" title="新建顶级页面" onClick={onCreateRoot}>
          <Icon.Plus />
        </button>
      </div>
      <div className="doc-tree">
        {isLoading && <div style={{ padding: 16, fontSize: 12, color: "var(--fg-faint)" }}>加载中…</div>}
        {!isLoading && filtered.length === 0 && (
          <div style={{ padding: 16, fontSize: 12, color: "var(--fg-faint)" }}>
            还没有文档 · 点 <Icon.Plus style={{ display: "inline", width: 11, height: 11, verticalAlign: "-2px" }} /> 新建
          </div>
        )}
        {filtered.map((n) => (
          <DocTreeNode
            key={n.id} node={n} depth={0}
            openSet={openSet} setOpenSet={setOpenSet}
            selectedId={selectedId} onSelect={onSelect}
          />
        ))}
      </div>
    </aside>
  );
}

function DocTreeNode({ node, depth, openSet, setOpenSet, selectedId, onSelect }) {
  const hasChildren = node.children?.length > 0;
  const isOpen = openSet.has(node.id);
  const create = useCreateDocument();
  const update = useUpdateDocument(node.id);
  const del = useDeleteDocument();
  const pushToast = useUIStore((s) => s.pushToast);
  const setActiveDocument = useUIStore((s) => s.setActiveDocument);

  const toggle = () => {
    setOpenSet((s) => {
      const next = new Set(s);
      if (next.has(node.id)) next.delete(node.id); else next.add(node.id);
      return next;
    });
  };

  const onClick = () => {
    if (hasChildren) toggle();
    onSelect(node.id);
  };

  const onNewChild = async () => {
    const name = prompt("子页面名称？", "未命名");
    if (!name) return;
    try {
      const res = await create.mutateAsync({ name, parentId: node.id });
      setOpenSet((s) => { const n = new Set(s); n.add(node.id); return n; });
      setActiveDocument(res.id);
    } catch (e) { pushToast({ kind: "error", title: "新建失败", desc: e.message }); }
  };
  const onRename = async () => {
    const name = prompt("新名称", node.name);
    if (!name || name === node.name) return;
    update.mutate({ name }, {
      onError: (e) => pushToast({ kind: "error", title: "重命名失败", desc: e.message }),
    });
  };
  const onDelete = () => {
    if (!confirm(`删除 "${node.name}"? 包含子页面也会一起删`)) return;
    del.mutate(node.id, {
      onSuccess: () => pushToast({ kind: "success", title: "已删除" }),
      onError: (e) => pushToast({ kind: "error", title: "删除失败", desc: e.message }),
    });
  };

  return (
    <>
      <div className={"doc-tree-row" + (selectedId === node.id ? " is-selected" : "")}>
        <button
          className={"doc-tree-item" + (selectedId === node.id ? " is-selected" : "")}
          style={{ paddingLeft: 8 + depth * 14 }}
          onClick={onClick}
          onDoubleClick={onRename}
        >
          {hasChildren ? (
            <Icon.ChevronRight className="chev" style={{ transform: isOpen ? "rotate(90deg)" : "none" }} />
          ) : <span className="chev-placeholder" />}
          <span className="doc-icon">
            {hasChildren ? <Icon.Folder /> : <Icon.FileText />}
          </span>
          <span className="doc-label">{node.name}</span>
        </button>
        <ActionMenu
          placement="bottom-end"
          renderTrigger={({ ref, ...rest }) => (
            <button ref={ref} className="rel-more-btn" title="操作" {...rest}>
              <Icon.MoreHorizontal />
            </button>
          )}
          items={[
            { label: "新建子页面", icon: Icon.Plus, onClick: onNewChild },
            { label: "重命名", icon: Icon.Edit, onClick: onRename },
            "divider",
            { label: "删除", icon: Icon.Trash, danger: true, onClick: onDelete },
          ]}
        />
      </div>
      {isOpen && node.children.map((c) => (
        <DocTreeNode
          key={c.id} node={c} depth={depth + 1}
          openSet={openSet} setOpenSet={setOpenSet}
          selectedId={selectedId} onSelect={onSelect}
        />
      ))}
    </>
  );
}

// ── DocPage ──────────────────────────────────────────────────────────────
function DocPage({ docId }) {
  const { data: doc, isLoading } = useDocument(docId);
  const update = useUpdateDocument(docId);
  const pushToast = useUIStore((s) => s.pushToast);

  const [draftName, setDraftName] = useState("");
  const [draftBody, setDraftBody] = useState("");
  const [showPreview, setShowPreview] = useState(true);
  const [dirty, setDirty] = useState(false);
  const saveTimer = useRef(null);
  const taRef = useRef(null);

  // Sync local draft when doc loads / changes.
  useEffect(() => {
    if (!doc) return;
    setDraftName(doc.name || "");
    setDraftBody(doc.content || "");
    setDirty(false);
  }, [doc?.id]);

  // Debounced save on body change.
  useEffect(() => {
    if (!doc || !dirty) return;
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      const patch = {};
      if (draftName !== doc.name) patch.name = draftName;
      if (draftBody !== doc.content) patch.content = draftBody;
      if (!Object.keys(patch).length) { setDirty(false); return; }
      update.mutate(patch, {
        onSuccess: () => setDirty(false),
        onError: (e) => pushToast({ kind: "error", title: "保存失败", desc: e.message }),
      });
    }, 1500);
    return () => clearTimeout(saveTimer.current);
  }, [draftName, draftBody, dirty]);

  if (isLoading || !doc) {
    return <div className="empty" style={{ padding: 48 }}><div className="sub">加载中…</div></div>;
  }

  const status = update.isPending ? "saving" : dirty ? "dirty" : "clean";

  return (
    <div className="doc-page">
      <div className="doc-page-head">
        <div className="doc-page-icon"><Icon.FileText /></div>
        <input
          className="doc-page-title-input"
          value={draftName}
          onChange={(e) => { setDraftName(e.target.value); setDirty(true); }}
          placeholder="无标题"
        />
        <span className={"wf-saved is-" + status}>
          {status === "saving" && <><span className="spinner" /> 保存中…</>}
          {status === "dirty" && <><span className="dot" /> 未保存</>}
          {status === "clean" && <><span className="dot" /> 已保存</>}
        </span>
      </div>

      <div className="doc-page-meta">
        <span><Icon.Clock /> 编辑 <RelTime ts={doc.updatedAt} /></span>
        <EntityRelMeta entityId={doc.id} />
        <div style={{ flex: 1 }} />
        <Button size="xs" variant="ghost" onClick={() => setShowPreview((p) => !p)}>
          {showPreview ? <><Icon.EyeOff /> 隐藏预览</> : <><Icon.Eye /> 预览</>}
        </Button>
        <AskAiTrigger
          kind="document"
          entityId={doc.id}
          context={`文档 · ${doc.name}`}
          suggestions={[
            "把这一节扩写到 500 字",
            "把表格转成 bullet list",
            "翻译成英文",
            "提炼 200 字摘要",
          ]}
        />
      </div>

      <div className={"doc-page-body" + (showPreview ? " has-preview" : "")}>
        <DocEditor
          ref={taRef}
          value={draftBody}
          onChange={(v) => { setDraftBody(v); setDirty(true); }}
          allDocs={undefined}
        />
        {showPreview && (
          <div className="doc-preview md-body">
            {draftBody.trim() === ""
              ? <p style={{ color: "var(--fg-faint)" }}>空文档</p>
              : <MD source={draftBody} />}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Editor textarea with `/` slash menu + `@` doc reference picker ──────
import { forwardRef } from "react";
const DocEditor = forwardRef(function DocEditor({ value, onChange }, ref) {
  const taRef = useRef(null);
  const setRef = (el) => { taRef.current = el; if (ref) { if (typeof ref === "function") ref(el); else ref.current = el; } };
  const [menu, setMenu] = useState(null); // {kind: "slash"|"mention", x, y, query}
  const treeQ = useDocumentTree();
  const allDocs = treeQ.data || [];

  const onInput = (e) => {
    const v = e.target.value;
    onChange(v);
    const pos = e.target.selectionStart;
    const before = v.slice(0, pos);
    const slashMatch = /(?:^|\n)\/([\w-]*)$/.exec(before);
    const atMatch = /(?:^|[\s])@([\w-]*)$/.exec(before);
    if (slashMatch) {
      const rect = caretRect(e.target);
      setMenu({ kind: "slash", x: rect.left, y: rect.top + 18, query: slashMatch[1] });
      return;
    }
    if (atMatch) {
      const rect = caretRect(e.target);
      setMenu({ kind: "mention", x: rect.left, y: rect.top + 18, query: atMatch[1] });
      return;
    }
    setMenu(null);
  };

  const insertAtCursor = (insert, eat = 0) => {
    const ta = taRef.current;
    if (!ta) return;
    const pos = ta.selectionStart;
    const before = value.slice(0, pos - eat);
    const after  = value.slice(pos);
    const next = before + insert + after;
    onChange(next);
    setMenu(null);
    requestAnimationFrame(() => {
      ta.focus();
      const caret = (before + insert).length;
      ta.setSelectionRange(caret, caret);
    });
  };

  return (
    <div style={{ position: "relative", flex: 1, display: "flex" }}>
      <textarea
        ref={setRef}
        className="doc-editor"
        value={value}
        onChange={onInput}
        onKeyDown={(e) => { if (e.key === "Escape") setMenu(null); }}
        placeholder="开始写……  /  打开命令面板  ·  @  引用其他文档"
        spellCheck={false}
      />
      {menu?.kind === "slash" && (
        <SlashMenu
          x={menu.x} y={menu.y} query={menu.query}
          onPick={(snippet) => insertAtCursor(snippet, menu.query.length + 1)}
          onClose={() => setMenu(null)}
        />
      )}
      {menu?.kind === "mention" && (
        <MentionMenu
          x={menu.x} y={menu.y} query={menu.query} docs={allDocs}
          onPick={(d) => insertAtCursor(`[[${d.name}]]`, menu.query.length + 1)}
          onClose={() => setMenu(null)}
        />
      )}
    </div>
  );
});

function caretRect(ta) {
  const r = ta.getBoundingClientRect();
  // Approximate caret position using textarea's scroll + per-line height.
  // Good enough for /panel placement (it floats below cursor line).
  const lineHeight = 22;
  const text = ta.value.slice(0, ta.selectionStart);
  const lines = text.split("\n");
  const top = r.top + (lines.length - 1) * lineHeight - ta.scrollTop + 2;
  const lastLine = lines[lines.length - 1];
  const charW = 7.2;
  const left = r.left + Math.min(lastLine.length * charW, r.width - 280);
  return { left, top };
}

const SLASH_ITEMS = [
  { key: "h1",     label: "Heading 1",   insert: "# ",       desc: "大标题" },
  { key: "h2",     label: "Heading 2",   insert: "## ",      desc: "次级标题" },
  { key: "h3",     label: "Heading 3",   insert: "### ",     desc: "小标题" },
  { key: "list",   label: "Bullet list", insert: "- ",       desc: "无序列表" },
  { key: "num",    label: "Number list", insert: "1. ",      desc: "有序列表" },
  { key: "todo",   label: "Todo",        insert: "- [ ] ",   desc: "待办" },
  { key: "quote",  label: "Quote",       insert: "> ",       desc: "引用" },
  { key: "code",   label: "Code block",  insert: "```\n\n```", desc: "围栏代码块" },
  { key: "hr",     label: "Divider",     insert: "\n---\n",  desc: "分割线" },
  { key: "table",  label: "Table",       insert: "| col1 | col2 |\n| --- | --- |\n| a | b |\n", desc: "表格" },
];

function SlashMenu({ x, y, query, onPick, onClose }) {
  const list = SLASH_ITEMS.filter((it) => it.label.toLowerCase().includes(query.toLowerCase()));
  useEffect(() => {
    const onKey = (e) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="doc-floating-menu" style={{ left: x, top: y }}>
      <div className="doc-floating-menu-head">命令 · /{query}</div>
      {list.length === 0 && <div className="doc-floating-menu-empty">没有匹配</div>}
      {list.map((it) => (
        <button key={it.key} onClick={() => onPick(it.insert)}>
          <span style={{ flex: 1 }}>{it.label}</span>
          <span style={{ color: "var(--fg-faint)", fontSize: 11 }}>{it.desc}</span>
        </button>
      ))}
    </div>
  );
}

function MentionMenu({ x, y, query, docs, onPick, onClose }) {
  const list = docs
    .filter((d) => d.name.toLowerCase().includes(query.toLowerCase()))
    .slice(0, 8);
  useEffect(() => {
    const onKey = (e) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="doc-floating-menu" style={{ left: x, top: y }}>
      <div className="doc-floating-menu-head">引用文档 · @{query}</div>
      {list.length === 0 && <div className="doc-floating-menu-empty">没有匹配</div>}
      {list.map((d) => (
        <button key={d.id} onClick={() => onPick(d)}>
          <Icon.FileText style={{ width: 12, height: 12 }} />
          <span style={{ flex: 1 }}>{d.name}</span>
          <span className="cell-mono" style={{ color: "var(--fg-faint)", fontSize: 11 }}>{d.id}</span>
        </button>
      ))}
    </div>
  );
}

// ── Lightweight markdown renderer (h1/h2/h3, list, blockquote, code,
//   table, paragraph, [[wikilink]] inline) ───────────────────────────────
export function MD({ source }) {
  const lines = source.split("\n");
  const blocks = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i];
    if (/^#{1,3}\s/.test(line)) {
      const m = line.match(/^(#{1,3})\s(.*)/);
      const lvl = m[1].length;
      blocks.push({ type: "h", lvl, text: m[2], i });
      i++;
    } else if (line.startsWith(">")) {
      blocks.push({ type: "quote", text: line.replace(/^>\s?/, ""), i });
      i++;
    } else if (line.startsWith("```")) {
      const code = [];
      i++;
      while (i < lines.length && !lines[i].startsWith("```")) { code.push(lines[i]); i++; }
      i++;
      blocks.push({ type: "code", text: code.join("\n"), i });
    } else if (/^[-*]\s/.test(line)) {
      const items = [];
      while (i < lines.length && /^[-*]\s/.test(lines[i])) { items.push(lines[i].slice(2)); i++; }
      blocks.push({ type: "ul", items, i });
    } else if (line.startsWith("|")) {
      const rows = [];
      while (i < lines.length && lines[i].startsWith("|")) { rows.push(lines[i]); i++; }
      const headers = rows[0].split("|").slice(1, -1).map((s) => s.trim());
      const data = rows.slice(2).map((r) => r.split("|").slice(1, -1).map((s) => s.trim()));
      blocks.push({ type: "table", headers, data, i });
    } else if (line.trim() === "") {
      i++;
    } else {
      blocks.push({ type: "p", text: line, i });
      i++;
    }
  }
  return (
    <>
      {blocks.map((b) => {
        if (b.type === "h") return <Heading key={b.i} lvl={b.lvl}>{inline(b.text)}</Heading>;
        if (b.type === "quote") return <blockquote key={b.i}>{inline(b.text)}</blockquote>;
        if (b.type === "code") return <pre key={b.i} className="code-block">{b.text}</pre>;
        if (b.type === "ul") return <ul key={b.i}>{b.items.map((t, j) => <li key={j}>{inline(t)}</li>)}</ul>;
        if (b.type === "table") return (
          <table key={b.i} className="md-table">
            <thead><tr>{b.headers.map((h, j) => <th key={j}>{h}</th>)}</tr></thead>
            <tbody>{b.data.map((row, r) => <tr key={r}>{row.map((c, k) => <td key={k}>{inline(c)}</td>)}</tr>)}</tbody>
          </table>
        );
        return <p key={b.i}>{inline(b.text)}</p>;
      })}
    </>
  );
}

function Heading({ lvl, children }) {
  const Tag = `h${lvl}`;
  return <Tag>{children}</Tag>;
}

// inline formatting: **bold**, `code`, [[wikilink]]
function inline(s) {
  const parts = [];
  const re = /(\*\*[^*]+\*\*|`[^`]+`|\[\[[^\]]+\]\])/g;
  let last = 0; let m; let key = 0;
  while ((m = re.exec(s))) {
    if (m.index > last) parts.push(s.slice(last, m.index));
    const t = m[0];
    if (t.startsWith("**")) parts.push(<strong key={key++}>{t.slice(2, -2)}</strong>);
    else if (t.startsWith("`")) parts.push(<code key={key++}>{t.slice(1, -1)}</code>);
    else parts.push(<a key={key++} className="entity-link" style={{ cursor: "default" }}>{t.slice(2, -2)}</a>);
    last = m.index + t.length;
  }
  if (last < s.length) parts.push(s.slice(last));
  return parts;
}
