import { useTranslation } from "react-i18next";
import { Select } from "@shared/ui/Select";

export function ModelSelect({ models, value, onChange, disabled }) {
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
