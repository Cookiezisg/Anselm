import { Icon } from "../primitives/Icon.jsx";

export function SystemSection({ open, onToggle }) {
  return (
    <div className="set-sec">
      <button className="set-sec-h" onClick={onToggle}>
        <Icon.Server className="set-sec-ic icon" />
        <div className="set-sec-tt">
          <div className="set-sec-t1">系统</div>
          <div className="set-sec-t2">本地存储 · 内置运行时</div>
        </div>
        <Icon.ChevronRight
          className={"set-sec-chev icon" + (open ? " is-open" : "")}
        />
      </button>
      {open && (
        <div className="set-sec-p">
          <div className="set-sys-row">
            <div className="set-sys-k">数据目录</div>
            <div>
              <span className="set-sys-mono">~/.forgify/</span>
              <span className="set-sys-hint">本地 · 不上传 · 无需登录</span>
            </div>
          </div>
          <div className="set-sys-row">
            <div className="set-sys-k">沙箱运行时</div>
            <div>
              <span className="set-sys-mono">mise</span>
              {" "}
              <span className="badge success" style={{ verticalAlign: "middle" }}>内置</span>
              <span className="set-sys-hint">python / node 按需安装</span>
            </div>
          </div>
          <div className="set-sys-row">
            <div className="set-sys-k">版本</div>
            <div>
              <span className="set-sys-mono">Forgify v1.2</span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
