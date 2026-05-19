// Composer — message input. textarea auto-grows up to 200px. Slash menu
// activates when "/" leads the input; @-mention menu activates when the
// last token begins with @. Drag-drop attaches files. Enter sends,
// Shift+Enter inserts newline, Esc cancels a streaming run.
//
// Composer —— 文本输入；/ 触发命令菜单；@ 触发实体引用菜单；
// 拖拽附件；Enter 发送 / Shift+Enter 换行 / Esc 取消流式。

import { useEffect, useRef, useState } from "react";
import { Icon } from "../../components/primitives/Icon.jsx";
import { useFunctions, useHandlers, useWorkflows } from "../../api/forge.js";
import { useSkills, useDocuments } from "../../api/library.js";

const SLASH_ITEMS = [
  { kw: "skill",   label: "/skill",   desc: "提示 agent 使用某个 Skill", icon: "Sparkles" },
  { kw: "forge",   label: "/forge",   desc: "把某个 Function/Handler/Workflow 作为上下文", icon: "Hammer" },
  { kw: "file",    label: "/file",    desc: "附加文件",                  icon: "Paperclip" },
  { kw: "run",     label: "/run",     desc: "运行一个 workflow",         icon: "Play" },
  { kw: "doc",     label: "/doc",     desc: "引用一篇文档",              icon: "FileText" },
  { kw: "memory",  label: "/memory",  desc: "写一条 memory",             icon: "Brain" },
  { kw: "clear",   label: "/clear",   desc: "清空当前对话(保留 ID)",     icon: "Trash" },
  { kw: "compact", label: "/compact", desc: "压缩历史",                  icon: "Layers" },
];

export function Composer({ disabled, isStreaming, onSend, onCancel }) {
  const [text, setText] = useState("");
  const [attached, setAttached] = useState([]);
  const [mentions, setMentions] = useState([]);
  const [slash, setSlash] = useState(null);
  const [atMenu, setAtMenu] = useState(null);
  const [dragging, setDragging] = useState(false);
  const ta = useRef(null);
  const fileInput = useRef(null);

  const { data: functions = [] } = useFunctions();
  const { data: handlers = [] } = useHandlers();
  const { data: workflows = [] } = useWorkflows();
  const { data: skills = [] } = useSkills();
  const { data: documents = [] } = useDocuments();

  useEffect(() => {
    if (!ta.current) return;
    ta.current.style.height = "auto";
    ta.current.style.height = Math.min(200, ta.current.scrollHeight) + "px";
  }, [text]);

  const send = () => {
    const t = text.trim();
    if (!t || disabled) return;
    onSend?.({ content: t, attachments: attached, mentions });
    setText("");
    setAttached([]);
    setMentions([]);
    setSlash(null);
    setAtMenu(null);
  };

  const mentionPool = () => [
    ...functions.map((f) => ({ id: f.id, label: f.name + " · function", icon: "Code" })),
    ...handlers.map((h) => ({ id: h.id, label: h.name + " · handler", icon: "Server" })),
    ...workflows.map((w) => ({ id: w.id, label: w.name + " · workflow", icon: "Workflow" })),
    ...skills.map((s) => ({ id: s.id || s.name, label: (s.name || s.id) + " · skill", icon: "Sparkles" })),
    ...documents.map((d) => ({ id: d.id, label: (d.title || d.id) + " · doc", icon: "FileText" })),
  ];

  const onChange = (e) => {
    const v = e.target.value;
    setText(v);
    if (v.startsWith("/") && !v.includes(" ")) {
      const q = v.slice(1).toLowerCase();
      const items = SLASH_ITEMS.filter((it) => it.kw.startsWith(q));
      setSlash({ items, idx: 0 });
    } else {
      setSlash(null);
    }
    const m = v.match(/(?:^|\s)@([^\s]*)$/);
    if (m) {
      const q = m[1].toLowerCase();
      const items = mentionPool()
        .filter((it) => it.label.toLowerCase().includes(q))
        .slice(0, 8);
      setAtMenu({ items, idx: 0, q });
    } else {
      setAtMenu(null);
    }
  };

  const pickSlash = (it) => {
    setText(it.label + " ");
    setSlash(null);
    ta.current?.focus();
  };
  const pickMention = (it) => {
    setMentions((ms) => (ms.find((x) => x.id === it.id) ? ms : [...ms, it]));
    setText((t) => t.replace(/(?:^|\s)@[^\s]*$/, (m) => (m.startsWith(" ") ? " " : "")));
    setAtMenu(null);
    ta.current?.focus();
  };

  const onKey = (e) => {
    if (slash?.items.length) {
      if (e.key === "ArrowDown") { e.preventDefault(); setSlash((s) => ({ ...s, idx: Math.min(s.idx + 1, s.items.length - 1) })); return; }
      if (e.key === "ArrowUp")   { e.preventDefault(); setSlash((s) => ({ ...s, idx: Math.max(s.idx - 1, 0) })); return; }
      if (e.key === "Enter" || e.key === "Tab") { e.preventDefault(); pickSlash(slash.items[slash.idx]); return; }
      if (e.key === "Escape") { setSlash(null); return; }
    }
    if (atMenu?.items.length) {
      if (e.key === "ArrowDown") { e.preventDefault(); setAtMenu((s) => ({ ...s, idx: Math.min(s.idx + 1, s.items.length - 1) })); return; }
      if (e.key === "ArrowUp")   { e.preventDefault(); setAtMenu((s) => ({ ...s, idx: Math.max(s.idx - 1, 0) })); return; }
      if (e.key === "Enter" || e.key === "Tab") { e.preventDefault(); pickMention(atMenu.items[atMenu.idx]); return; }
      if (e.key === "Escape") { setAtMenu(null); return; }
    }
    if (e.key === "Escape" && isStreaming) { onCancel?.(); return; }
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); }
  };

  const onDrop = (e) => {
    e.preventDefault();
    setDragging(false);
    const files = Array.from(e.dataTransfer?.files || []);
    if (files.length) onPickFiles(files);
  };

  const onPickFiles = (files) => {
    setAttached((a) => [...a, ...files.map((f) => ({ name: f.name, size: f.size, file: f }))]);
  };

  return (
    <div className="composer-wrap">
      <div className="composer-inner">
        {(attached.length > 0 || mentions.length > 0) && (
          <div className="attached-strip">
            {mentions.map((m) => {
              const Mi = Icon[m.icon] || Icon.At;
              return (
                <div key={m.id} className="attached-pill is-mention">
                  <Mi className="file-icon" style={{ color: "var(--accent)" }} />
                  <span>{m.label}</span>
                  <button className="x" onClick={() => setMentions((ms) => ms.filter((x) => x.id !== m.id))}>
                    <Icon.X />
                  </button>
                </div>
              );
            })}
            {attached.map((a, i) => (
              <div className="attached-pill" key={"a" + i}>
                <Icon.File className="file-icon" />
                <span>{a.name}</span>
                <button className="x" onClick={() => setAttached((s) => s.filter((_, j) => j !== i))}>
                  <Icon.X />
                </button>
              </div>
            ))}
          </div>
        )}

        <div
          className={"composer" + (disabled ? " is-disabled" : "") + (dragging ? " is-drop" : "")}
          onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
          onDragLeave={() => setDragging(false)}
          onDrop={onDrop}
        >
          {slash?.items.length > 0 && (
            <SlashPopover items={slash.items} idx={slash.idx} onPick={pickSlash} title="命令" />
          )}
          {atMenu?.items.length > 0 && (
            <SlashPopover items={atMenu.items} idx={atMenu.idx} onPick={pickMention} title="引用" />
          )}
          {dragging && <div className="drop-indicator">松手附加文件</div>}

          <textarea
            ref={ta}
            className="composer-textarea"
            placeholder={isStreaming ? "Agent 正在执行… (Esc 停止)" : "描述你想做的事，或向 AI 提问。试试 / 或 @"}
            value={text}
            onChange={onChange}
            onKeyDown={onKey}
            rows={2}
            disabled={disabled}
          />

          <input
            ref={fileInput}
            type="file"
            multiple
            style={{ display: "none" }}
            onChange={(e) => { onPickFiles(Array.from(e.target.files || [])); e.target.value = ""; }}
          />

          <div className="composer-toolbar">
            <button className="composer-tool" title="附加文件" onClick={() => fileInput.current?.click()}>
              <Icon.Paperclip />
            </button>
            <button
              className="composer-tool"
              title="@ 引用实体"
              onClick={() => { setText((t) => (t.endsWith(" ") || !t ? t : t + " ") + "@"); ta.current?.focus(); }}
            >
              <Icon.At />
            </button>
            <div className="composer-spacer" />
            <div className="composer-mode" title="切换 agent 模式">
              <Icon.Cpu style={{ width: 12, height: 12 }} />
              <span>Agent · max 20 steps</span>
              <Icon.ChevronDown style={{ width: 10, height: 10 }} />
            </div>
            {isStreaming ? (
              <button className="send-btn is-stop" onClick={onCancel} title="停止 (Esc)">
                <Icon.Square />
              </button>
            ) : (
              <button
                className={"send-btn" + (!text.trim() ? " is-disabled" : "")}
                onClick={send}
                title="发送 (Enter)"
                disabled={!text.trim() || disabled}
              >
                <Icon.ArrowUp />
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

function SlashPopover({ items, idx, onPick, title }) {
  return (
    <div className="slash-pop">
      <div className="slash-pop-title">{title}</div>
      {items.map((it, i) => {
        const I = Icon[it.icon] || Icon.Hammer;
        return (
          <div
            key={i}
            className={"slash-pop-row" + (i === idx ? " is-active" : "")}
            onClick={() => onPick(it)}
            onMouseEnter={() => {/* could update idx; left as-is */}}
          >
            <div className="slash-pop-icon"><I /></div>
            <div className="slash-pop-label">
              <span>{it.label}</span>
              <span className="slash-pop-desc">{it.desc || it.sub || ""}</span>
            </div>
            {i === idx && <Icon.CornerDownLeft style={{ width: 11, height: 11, color: "var(--fg-faint)" }} />}
          </div>
        );
      })}
    </div>
  );
}
