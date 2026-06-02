// ModelOverrideEditor — KeyModelPicker + save/clear in a floating popover over
// the ChatHeader. Provider-native model options are saved alongside modelId.

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Button } from "@shared/ui/Button";
import type { ModelRef } from "@entities/conversation";
import { useApiKeys } from "@entities/apikey";
import { useModelCapabilities } from "@entities/model-config";
import { KeyModelPicker, ModelOptionsFields, mergeOptionDefaults } from "@features/settings";
import { useConvModelOverride } from "../model/useConvModelOverride";

interface Props {
  conversationId: string;
  current: ModelRef | null;
  onClose: () => void;
}

export function ModelOverrideEditor({ conversationId, current, onClose }: Props) {
  const { t } = useTranslation(["conv", "common"]);
  const setOverride = useConvModelOverride();
  const [pending, setPending] = useState<ModelRef | null>(current);
  const { data: keys = [] } = useApiKeys();
  const { data: caps = [] } = useModelCapabilities();
  const provider = pending ? keys.find((k) => k.id === pending.apiKeyId)?.provider : "";
  const cap = pending ? caps.find((c) => c.provider === provider && c.modelId === pending.modelId) : undefined;
  const optionDescriptors = cap?.options || [];

  const handlePickerChange = (v: { apiKeyId: string; modelId: string }) => {
    const nextProvider = keys.find((k) => k.id === v.apiKeyId)?.provider || "";
    const nextCap = caps.find((c) => c.provider === nextProvider && c.modelId === v.modelId);
    setPending({ apiKeyId: v.apiKeyId, modelId: v.modelId, options: mergeOptionDefaults(nextCap?.options || [], {}) });
  };

  const save = async () => {
    if (!pending) return;
    await setOverride.mutateAsync({ conversationId, override: pending });
    onClose();
  };
  const clear = async () => {
    await setOverride.mutateAsync({ conversationId, override: null });
    onClose();
  };

  return (
    <div className="model-override-editor">
      <div className="moe-title">{t("conv:modelOverride.title")}</div>
      <KeyModelPicker value={pending} onChange={handlePickerChange} />
      {pending && optionDescriptors.length > 0 && (
        <ModelOptionsFields
          descriptors={optionDescriptors}
          value={pending.options}
          onChange={(options) => setPending({ ...pending, options })}
        />
      )}
      <div className="moe-actions">
        <Button variant="ghost" size="sm" onClick={clear} disabled={setOverride.isPending}>
          {t("conv:modelOverride.clear")}
        </Button>
        <Button variant="accent" size="sm" onClick={save} disabled={!pending || setOverride.isPending}>
          {t("common:save")}
        </Button>
      </div>
    </div>
  );
}
