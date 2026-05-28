// ModelOverrideEditor — KeyModelPicker + save/clear in a floating popover
// over the ChatHeader. Save sets the (apiKeyId, modelId) pair; Clear sends
// null so backend falls back to dialogue default.
//
// 弹出式编辑器;KeyModelPicker + 保存/清除。Save 写 pair;Clear 写 null,
// 后端落回 dialogue default。

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Button } from "@shared/ui/Button";
import type { ModelRef } from "@entities/conversation";
import { KeyModelPicker } from "@features/settings";
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
      <KeyModelPicker value={pending} onChange={setPending} />
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
