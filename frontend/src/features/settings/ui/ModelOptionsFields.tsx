import { Select } from "@shared/ui/Select";
import type { ModelOptionDescriptor, ModelOptions } from "@entities/model-config";

interface Props {
  descriptors: ModelOptionDescriptor[];
  value?: ModelOptions;
  onChange: (next: ModelOptions) => void;
}

export function defaultOptions(descriptors: ModelOptionDescriptor[]): ModelOptions {
  const out: ModelOptions = {};
  for (const d of descriptors) {
    if (d.defaultValue) out[d.key] = d.defaultValue;
  }
  return out;
}

export function mergeOptionDefaults(descriptors: ModelOptionDescriptor[], value?: ModelOptions): ModelOptions {
  return { ...defaultOptions(descriptors), ...(value || {}) };
}

export function ModelOptionsFields({ descriptors, value, onChange }: Props) {
  if (descriptors.length === 0) return null;
  const current = mergeOptionDefaults(descriptors, value);
  return (
    <>
      {descriptors.map((d) => (
        <div className="onb-keyfield" key={d.key}>
          <div className="onb-klabel">{d.label}</div>
          <Select
            options={(d.values || []).map((v) => ({ value: v.value, label: v.label }))}
            value={current[d.key] || d.defaultValue || ""}
            onChange={(v) => onChange({ ...current, [d.key]: v })}
            ariaLabel={d.label}
          />
        </div>
      ))}
    </>
  );
}
