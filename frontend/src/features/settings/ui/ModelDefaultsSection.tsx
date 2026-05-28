// ModelDefaultsSection — 3 scenario rows (dialogue/utility/agent) inside
// SettingsModal. Each row binds one model-config row via KeyModelPicker;
// upsert is fire-and-forget (mutation cache shows errors globally).
//
// 设置弹窗的"模型默认"区段;3 个 scenario 各自一行,KeyModelPicker 绑定
// 一条 model-config;upsert 走全局 mutation 错误处理。

import { useTranslation } from "react-i18next";
import { Icon } from "@shared/ui/Icon";
import { useModelConfigs, useUpsertModelConfig, type Scenario } from "@entities/model-config";
import { KeyModelPicker } from "./KeyModelPicker.tsx";

const SCENARIOS: Scenario[] = ["dialogue", "utility", "agent"];

interface Props {
  open: boolean;
  onToggle: () => void;
}

export function ModelDefaultsSection({ open, onToggle }: Props) {
  const { t } = useTranslation("settings");
  const { data: configs = [] } = useModelConfigs();
  const upsert = useUpsertModelConfig();

  const valueFor = (scenario: Scenario) => {
    const c = configs.find((x) => x.scenario === scenario);
    return c ? { apiKeyId: c.apiKeyId, modelId: c.modelId } : null;
  };

  return (
    <div className="set-sec">
      <button className="set-sec-h" onClick={onToggle}>
        <Icon.Sparkles className="set-sec-ic icon" />
        <div className="set-sec-tt">
          <div className="set-sec-t1">{t("modelDefaults.title")}</div>
          <div className="set-sec-t2">{t("modelDefaults.subtitle")}</div>
        </div>
        <Icon.ChevronRight className={"set-sec-chev icon" + (open ? " is-open" : "")} />
      </button>
      {open && (
        <div className="set-sec-p">
          {SCENARIOS.map((sc) => (
            <div className="set-mrow" key={sc}>
              <div className="set-mrow-text">
                <div className="set-mrow-name">{t(`modelDefaults.scenarios.${sc}`)}</div>
                <div className="set-mrow-desc">{t(`modelDefaults.description.${sc}`)}</div>
              </div>
              <div className="set-mrow-picker">
                <KeyModelPicker
                  value={valueFor(sc)}
                  onChange={(v) => upsert.mutate({ scenario: sc, ...v })}
                />
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
