// i18n — react-i18next 配置。import 即 init(side-effect)。lng 初值取已
// hydrate 的 forgify-settings.lang;切换由 App 的 effect 调 changeLanguage 驱动。
// 直接读 localStorage 避免 shared→entities 的 FSD 违规。

import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import { resources } from "./resources.js";

function getPersistedLang() {
  try {
    const raw = localStorage.getItem("forgify-settings");
    if (raw) {
      const parsed = JSON.parse(raw);
      const lang = parsed?.state?.lang;
      if (lang === "zh" || lang === "en") return lang;
    }
  } catch { /* ignore */ }
  // Fallback: detect from navigator
  if (typeof navigator === "undefined") return "zh";
  const l = (navigator.language || "").toLowerCase();
  return l.startsWith("zh") ? "zh" : "en";
}

i18n.use(initReactI18next).init({
  resources,
  lng: getPersistedLang(),
  fallbackLng: "zh",
  defaultNS: "common",
  interpolation: { escapeValue: false },
  returnNull: false,
});

export default i18n;
