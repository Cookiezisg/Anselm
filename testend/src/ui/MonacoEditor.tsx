import Editor, { type OnMount } from "@monaco-editor/react";
import { useCallback } from "react";

export interface MonacoProps {
  value: string;
  onChange?: (v: string) => void;
  language?: "sql" | "json" | "typescript" | "python" | "markdown" | "plaintext";
  height?: number | string;
  readOnly?: boolean;
  onMount?: OnMount;
}

export function MonacoEditor({
  value, onChange, language = "plaintext",
  height = 240, readOnly = false, onMount,
}: MonacoProps) {
  const handleChange = useCallback((v: string | undefined) => onChange?.(v ?? ""), [onChange]);
  return (
    <Editor
      height={height}
      language={language}
      value={value}
      onChange={handleChange}
      onMount={onMount}
      options={{
        readOnly,
        minimap: { enabled: false },
        fontSize: 13,
        fontFamily: "var(--mono)",
        scrollBeyondLastLine: false,
        wordWrap: "on",
        renderLineHighlight: "none",
        lineNumbers: "on",
        folding: false,
        glyphMargin: false,
      }}
      theme="vs-dark"
    />
  );
}
