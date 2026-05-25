import { Select } from "../primitives/Select.jsx";

export function ModelSelect({ models, value, onChange, disabled }) {
  return (
    <Select
      options={models}
      value={value}
      onChange={onChange}
      disabled={disabled}
      mono
      placeholder="验证后可选"
      ariaLabel="模型"
    />
  );
}
