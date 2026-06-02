// ModelDefaultsSection — 3 scenario cards (dialogue/utility/agent) inside
// SettingsModal. Each card collapses to a one-line summary and expands to an
// onboarding-style picker: provider grid (configured-only) + (key, model)
// two-field. Selection is strict cascade — pick provider auto-selects first
// key + first model; pick key auto-selects first model; pick model just saves.
//
// 设置弹窗的"模型默认"区段;3 个 scenario 各自一个可展开卡片。收起时只
// 显厂商色块 + 模型名;展开后复用 onboarding 模型步的双列网格 + 双字段。
// 严格级联:选厂商自动落到第一个 key + 模型;选 key 自动落到第一个模型。

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Icon } from "@shared/ui/Icon";
import { Select } from "@shared/ui/Select";
import { useApiKeys, type ApiKey } from "@entities/apikey";
import {
  useModelConfigs,
  useModelCapabilities,
  useProviders,
  useUpsertModelConfig,
  type ModelCapability,
  type ModelConfig,
  type ModelOptions,
  type Scenario,
} from "@entities/model-config";
import { LLM_HINTS } from "@shared/lib/onboarding-strings";
import { ModelOptionsFields, mergeOptionDefaults } from "./ModelOptionsFields.tsx";

const SCENARIOS: Scenario[] = ["dialogue", "utility", "agent"];

interface Props {
  open: boolean;
  onToggle: () => void;
}

export function ModelDefaultsSection({ open, onToggle }: Props) {
  const { t } = useTranslation("settings");
  const { data: configs = [] } = useModelConfigs();
  const { data: keys = [] } = useApiKeys();
  const { data: providers = [] } = useProviders();
  const { data: capabilities = [] } = useModelCapabilities();
  const upsert = useUpsertModelConfig();
  const [expandedSc, setExpandedSc] = useState<Scenario | null>("dialogue");

  // Only verified keys with ≥1 discovered model are pickable; otherwise the
  // resulting (key, model) pair has nothing to select.
  //
  // 已验证且有模型的 key 才进 picker;否则下游选不出 model。
  const verifiedKeys = keys.filter(
    (k) => k.testStatus === "ok" && (k.modelsFound?.length || 0) > 0,
  );
  // Providers that have ≥1 verified key; preserves first-key-seen order so
  // the grid feels stable across re-renders.
  const seen = new Set<string>();
  const configuredProviders: string[] = [];
  for (const k of verifiedKeys) {
    if (!seen.has(k.provider)) {
      seen.add(k.provider);
      configuredProviders.push(k.provider);
    }
  }
  const providerDisplay = (name: string) =>
    providers.find((p) => p.name === name)?.displayName || name;

  const cfgFor = (sc: Scenario) => configs.find((c) => c.scenario === sc);

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
          {verifiedKeys.length === 0 ? (
            <div className="set-sec-empty">{t("modelDefaults.noKeys")}</div>
          ) : (
            <div className="set-mc-list">
              {SCENARIOS.map((sc) => (
                <ScenarioCard
                  key={sc}
                  scenario={sc}
                  config={cfgFor(sc)}
                  verifiedKeys={verifiedKeys}
                  configuredProviders={configuredProviders}
                  providerDisplay={providerDisplay}
                  capabilities={capabilities}
                  isOpen={expandedSc === sc}
                  onToggle={() => setExpandedSc(expandedSc === sc ? null : sc)}
                  onChange={(apiKeyId, modelId, options) =>
                    upsert.mutate({ scenario: sc, apiKeyId, modelId, options })
                  }
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

interface ScenarioCardProps {
  scenario: Scenario;
  config: ModelConfig | undefined;
  verifiedKeys: ApiKey[];
  configuredProviders: string[];
  providerDisplay: (name: string) => string;
  capabilities: ModelCapability[];
  isOpen: boolean;
  onToggle: () => void;
  onChange: (apiKeyId: string, modelId: string, options?: ModelOptions) => void;
}

function ScenarioCard({
  scenario, config, verifiedKeys, configuredProviders, providerDisplay,
  capabilities, isOpen, onToggle, onChange,
}: ScenarioCardProps) {
  const { t } = useTranslation("settings");
  const currentKey = config ? verifiedKeys.find((k) => k.id === config.apiKeyId) : undefined;
  const currentProvider = currentKey?.provider || "";
  const summaryHint = (LLM_HINTS as Record<string, { abbr: string; color: string }>)[currentProvider];
  const currentCapability = capabilities.find((v) => v.provider === currentProvider && v.modelId === config?.modelId);

  const pickProvider = (provider: string) => {
    const firstKey = verifiedKeys.find((k) => k.provider === provider);
    if (!firstKey) return;
    const firstModel = capabilities.find((v) => v.provider === provider);
    if (!firstModel) return;
    onChange(firstKey.id, firstModel.modelId, mergeOptionDefaults(firstModel.options || [], {}));
  };

  const pickKey = (keyId: string) => {
    const k = verifiedKeys.find((kk) => kk.id === keyId);
    if (!k) return;
    const firstModel = capabilities.find((v) => v.provider === k.provider);
    if (!firstModel) return;
    onChange(keyId, firstModel.modelId, mergeOptionDefaults(firstModel.options || [], {}));
  };

  const pickModel = (modelId: string) => {
    if (!config) return;
    const cap = capabilities.find((v) => v.provider === currentProvider && v.modelId === modelId);
    onChange(config.apiKeyId, modelId, mergeOptionDefaults(cap?.options || [], {}));
  };

  const keysForProvider = verifiedKeys.filter((k) => k.provider === currentProvider);
  const modelsForProvider = capabilities.filter((v) => v.provider === currentProvider);

  return (
    <div className={"set-mc" + (isOpen ? " is-open" : "")}>
      <div className="set-mc-head" onClick={onToggle}>
        <div className="set-mc-text">
          <div className="set-mc-name">{t(`modelDefaults.scenarios.${scenario}`)}</div>
          <div className="set-mc-desc">{t(`modelDefaults.description.${scenario}`)}</div>
        </div>
        <div className="set-mc-summary">
          {config && summaryHint ? (
            <>
              <span className="set-pchip" style={{ background: summaryHint.color }}>{summaryHint.abbr}</span>
              <span className="set-mtag">{currentCapability?.displayName || config.modelId}</span>
            </>
          ) : (
            <span className="set-mc-notset">{t("modelDefaults.notSet")}</span>
          )}
        </div>
        <Icon.ChevronRight className={"set-mc-chev icon" + (isOpen ? " is-open" : "")} />
      </div>
      {isOpen && (
        <div className="set-mc-body">
          <div className="onb-grid">
            {configuredProviders.map((p) => {
              const h = (LLM_HINTS as Record<string, { abbr: string; color: string }>)[p]
                || { abbr: p.slice(0, 2).toUpperCase(), color: "#6b6459" };
              const isActive = currentProvider === p;
              const keyCount = verifiedKeys.filter((k) => k.provider === p).length;
              return (
                <button
                  key={p}
                  type="button"
                  className={"onb-prov" + (isActive ? " is-active" : "")}
                  onClick={() => pickProvider(p)}
                >
                  <span className="onb-pchip" style={{ background: h.color }}>{h.abbr}</span>
                  <span style={{ minWidth: 0 }}>
                    <span className="onb-pname">{providerDisplay(p)}</span>
                    <span className="onb-pdesc" style={{ display: "block" }}>
                      {t("modelDefaults.providerSub", { count: keyCount })}
                    </span>
                  </span>
                </button>
              );
            })}
          </div>

          {currentKey && config && (
            <>
              <div className="onb-twofield">
                <div className="onb-keyfield" style={{ flex: 1.3 }}>
                  <div className="onb-klabel">{t("modelDefaults.keyLabel")}</div>
                  <Select
                    options={keysForProvider.map((k) => ({
                      value: k.id,
                      label: `${k.displayName || providerDisplay(k.provider)}  ·  ${k.keyMasked}`,
                    }))}
                    value={config.apiKeyId}
                    onChange={pickKey}
                    ariaLabel={t("modelDefaults.keyLabel")}
                  />
                </div>
                <div className="onb-keyfield" style={{ flex: 1 }}>
                  <div className="onb-klabel">{t("modelDefaults.modelLabel")}</div>
                  <Select
                    options={modelsForProvider.map((v) => ({ value: v.modelId, label: v.displayName }))}
                    value={config.modelId}
                    onChange={pickModel}
                    mono
                    ariaLabel={t("modelDefaults.modelLabel")}
                  />
                </div>
              </div>
              {currentCapability && currentCapability.options.length > 0 && (
                <div className="onb-twofield">
                  <ModelOptionsFields
                    descriptors={currentCapability.options}
                    value={config.options}
                    onChange={(options) => onChange(config.apiKeyId, config.modelId, options)}
                  />
                </div>
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}
