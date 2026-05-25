import { Icon } from "../primitives/Icon.jsx";
import { useSettings } from "../../store/settings.js";
import { ACCENTS } from "../overlays/onboarding-strings.js";

export function AppearanceSection({ open, onToggle }) {
  const settings = useSettings();
  return (
    <div className="set-sec">
      <button className="set-sec-h" onClick={onToggle}>
        <Icon.Brush className="set-sec-ic icon" />
        <div className="set-sec-tt">
          <div className="set-sec-t1">外观</div>
          <div className="set-sec-t2">主题 · 主题色 · 密度 · 语言</div>
        </div>
        <Icon.ChevronRight
          className={"set-sec-chev icon" + (open ? " is-open" : "")}
        />
      </button>
      {open && (
        <div className="set-sec-p">
          <div className="set-look-row">
            <div className="set-look-k">主题</div>
            <div className="onb-seg">
              {[["light", "浅色"], ["dark", "深色"], ["system", "跟随系统"]].map(([v, label]) => (
                <button
                  key={v}
                  className={"onb-seg-opt" + (settings.theme === v ? " is-active" : "")}
                  onClick={() => settings.set({ theme: v })}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div className="set-look-row">
            <div className="set-look-k">主题色</div>
            <div className="onb-swatches">
              {ACCENTS.map(([k, c]) => (
                <button
                  key={k}
                  className={"onb-swatch" + (settings.accent === k ? " is-active" : "")}
                  style={{ background: c }}
                  onClick={() => settings.set({ accent: k })}
                />
              ))}
            </div>
          </div>
          <div className="set-look-row">
            <div className="set-look-k">密度</div>
            <div className="onb-seg">
              {[["compact", "紧凑"], ["cozy", "适中"], ["comfortable", "舒展"]].map(([v, label]) => (
                <button
                  key={v}
                  className={"onb-seg-opt" + (settings.density === v ? " is-active" : "")}
                  onClick={() => settings.set({ density: v })}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div className="set-look-row">
            <div className="set-look-k">语言</div>
            <div className="onb-seg">
              {[["zh", "中文"], ["en", "English"]].map(([v, label]) => (
                <button
                  key={v}
                  className={"onb-seg-opt" + (settings.lang === v ? " is-active" : "")}
                  onClick={() => settings.set({ lang: v })}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div className="set-look-row">
            <div className="set-look-k">推理过程</div>
            <div className="onb-seg">
              {[["collapsed", "默认折叠"], ["expanded", "默认展开"]].map(([v, label]) => (
                <button
                  key={v}
                  className={"onb-seg-opt" + (settings.reasoningDefault === v ? " is-active" : "")}
                  onClick={() => settings.set({ reasoningDefault: v })}
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
