// Root component — applies theme/accent/density on every settings change,
// listens to system color-scheme when theme="system", then renders
// AppShell. All actual UI lives in components/layout/AppShell.jsx.
//
// 根组件 —— 监听 settings 变化写 dataset；theme=system 时监听系统配色。

import { useEffect } from "react";
import { AppShell } from "./components/layout/AppShell.jsx";
import { SSEProvider } from "./sse/SSEProvider.jsx";
import { useSettings, applyTheme } from "./store/settings.js";

export default function App() {
  const settings = useSettings();

  useEffect(() => {
    applyTheme(settings);
  }, [settings.theme, settings.accent, settings.density, settings.lang]);

  useEffect(() => {
    if (settings.theme !== "system") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const fn = () => applyTheme(settings);
    mql.addEventListener?.("change", fn);
    return () => mql.removeEventListener?.("change", fn);
  }, [settings.theme]);

  return (
    <SSEProvider>
      <AppShell />
    </SSEProvider>
  );
}
