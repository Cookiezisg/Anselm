/* eslint-disable react/prop-types */
// AskAi — universal "tell AI to change this" inline composer

const { useState: useAskState } = React;

function AskAiTrigger({ context, label, suggestions, size = "sm" }) {
  const [open, setOpen] = useAskState(false);
  return (
    <>
      <button className={"btn btn-" + size + " ask-ai-btn"} onClick={() => setOpen(o => !o)}>
        <Icon.Sparkles /> {label || "让 AI 修改"}
      </button>
      {open && (
        <AskAiPopover
          context={context}
          suggestions={suggestions}
          onClose={() => setOpen(false)}
        />
      )}
    </>
  );
}

function AskAiPopover({ context, suggestions, onClose }) {
  const [text, setText] = useAskState("");
  const [sending, setSending] = useAskState(false);

  const send = () => {
    if (!text.trim()) return;
    setSending(true);
    setTimeout(() => {
      setSending(false);
      setText("");
      onClose();
      if (window.Shell?.toast) {
        window.Shell.toast({
          kind: "success",
          title: "锻造已启动",
          desc: text.slice(0, 60) + " · 已产生 pending 版本",
        });
      }
    }, 1400);
  };

  return (
    <div className="ask-ai-pop in-pane" onClick={e => e.stopPropagation()}>
      <div className="ask-ai-pop-head">
        <div className="ask-ai-pop-context">
          <Icon.Sparkles style={{ width: 12, height: 12, color: "var(--accent)" }} />
          <span className="cell-mono" style={{ fontSize: 11, color: "var(--fg-muted)" }}>
            上下文：<span style={{ color: "var(--fg-strong)" }}>{context}</span>
          </span>
        </div>
        <button className="icon-btn" onClick={onClose}><Icon.X /></button>
      </div>
      <textarea
        className="ask-ai-pop-input"
        placeholder="例如：把超时改成 60 秒 · 失败时重试 3 次（指数退避）· 给这段加单元测试…"
        rows={2}
        value={text}
        onChange={e => setText(e.target.value)}
        onKeyDown={e => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); send(); } }}
        autoFocus
      />
      {suggestions && suggestions.length > 0 && (
        <div className="ask-ai-pop-sugs">
          {suggestions.map((s, i) => (
            <button key={i} className="ask-ai-pop-sug" onClick={() => setText(s)}>{s}</button>
          ))}
        </div>
      )}
      <div className="ask-ai-pop-foot">
        <span style={{ fontSize: 11, color: "var(--fg-faint)" }}>提交后产生一个 pending 版本，需 Accept 才生效</span>
        <button className={"btn btn-sm btn-accent" + (sending ? " is-disabled" : "")} onClick={send} disabled={sending}>
          {sending ? <><span className="spinner" /> 锻造中…</> : <><Icon.ArrowUp /> 提交</>}
        </button>
      </div>
    </div>
  );
}

window.AskAiTrigger = AskAiTrigger;
window.AskAiPopover = AskAiPopover;
