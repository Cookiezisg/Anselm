import { useTranslation } from "react-i18next";
import { Select } from "@shared/ui/Select";

export function ModelSelect({ models, value, onChange, disabled }: {
  models: Array<string | { value: string; label?: string }>;
  value: string;
  onChange: (v: string) => void;
  disabled?: boolean;
}) {
  const { t } = useTranslation("settings");
  return (
    <Select
      options={models}
      value={value}
      onChange={onChange}
      disabled={disabled}
      mono
      placeholder={t("model.placeholder")}
      ariaLabel={t("model.ariaLabel")}
    />
  );
}
