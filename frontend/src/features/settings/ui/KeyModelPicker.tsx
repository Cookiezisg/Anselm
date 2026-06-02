// KeyModelPicker — dropdown of (api_key, model) combos grouped by key.
// Shared by ModelDefaultsSection (3 scenario rows) and the per-conv
// ModelOverrideEditor. Filters to verified keys so users only see usable
// combos; emits the pair via onChange.
//
// (api_key, model) 组合下拉,按 key 分组。
// ModelDefaultsSection 与对话级 ModelOverrideEditor 共用;只展示已验证 key。

import { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { Select } from "@shared/ui/Select";
import { useApiKeys } from "@entities/apikey";
import { useModelCapabilities, type ModelOptions } from "@entities/model-config";

interface KeyModelPickerProps {
  value: { apiKeyId: string; modelId: string; options?: ModelOptions } | null;
  onChange: (v: { apiKeyId: string; modelId: string; options?: ModelOptions }) => void;
  disabled?: boolean;
}

// Encode (apiKeyId, modelId) as a single Select option value; Select itself
// only carries string values.
//
// 把 (apiKeyId, modelId) 编码成单一 string,适配 Select 的纯字符串值。
const SEP = "::";
const encode = (apiKeyId: string, modelId: string) => `${apiKeyId}${SEP}${modelId}`;
const decode = (s: string): { apiKeyId: string; modelId: string } | null => {
  const i = s.indexOf(SEP);
  if (i < 0) return null;
  return { apiKeyId: s.slice(0, i), modelId: s.slice(i + SEP.length) };
};

export function KeyModelPicker({ value, onChange, disabled }: KeyModelPickerProps) {
  const { t } = useTranslation("settings");
  const { data: keys = [] } = useApiKeys();
  const { data: caps = [] } = useModelCapabilities();

  // Verified keys with at least one discovered model; otherwise the option
  // group would be empty.
  //
  // 已验证且有模型的 key;否则分组里没有选项。
  const verified = keys.filter((k) => k.testStatus === "ok" && (k.modelsFound?.length || 0) > 0);

  const options = useMemo(() => {
    const out: Array<{ value: string; label: string }> = [];
    for (const k of verified) {
      const header = `${k.displayName || k.provider} · ${k.provider} · ${k.keyMasked}`;
      for (const m of caps.filter((c) => c.provider === k.provider)) {
        out.push({ value: encode(k.id, m.modelId), label: `${header}  —  ${m.displayName || m.modelId}` });
      }
    }
    return out;
  }, [verified, caps]);

  if (verified.length === 0) {
    return (
      <Select
        options={[]}
        value=""
        onChange={() => {}}
        disabled
        placeholder={t("modelDefaults.noKeys")}
        ariaLabel={t("modelDefaults.selectModel")}
      />
    );
  }

  return (
    <Select
      options={options}
      value={value ? encode(value.apiKeyId, value.modelId) : ""}
      onChange={(v) => {
        const decoded = decode(v);
        if (decoded) onChange({ ...decoded, options: {} });
      }}
      disabled={disabled}
      placeholder={t("modelDefaults.selectModel")}
      ariaLabel={t("modelDefaults.selectModel")}
      mono
    />
  );
}
