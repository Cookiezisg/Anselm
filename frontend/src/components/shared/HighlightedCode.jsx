// HighlightedCode — syntax-highlight a code fence.
//
// Uses lowlight (highlight.js AST output) so the same tokenizer powers
// both this (chat MarkdownView) and the Tiptap editor's code-block
// (extension-code-block-lowlight). One language list + one CSS theme
// across the app; no duplicated style truth.
//
// HighlightedCode —— 用 lowlight 把代码字符串 token 化后渲染。和 Tiptap
// 编辑器共用一个 lowlight 实例，保证 chat / 编辑器渲染规则一致。

import { createElement, useMemo } from "react";
import { lowlight } from "./lowlightInstance.js";

export function HighlightedCode({ source, lang }) {
  const tree = useMemo(() => {
    if (!source) return null;
    try {
      if (lang && lowlight.registered(lang)) return lowlight.highlight(lang, source);
      return lowlight.highlightAuto(source);
    } catch {
      return null;
    }
  }, [source, lang]);

  if (!tree) return source;
  return <>{tree.children.map((c, i) => hastToReact(c, i))}</>;
}

// hast → React. lowlight returns hast nodes — element / text.
// className arrives as an array on properties; join into space-string.
function hastToReact(node, key) {
  if (node.type === "text") return node.value;
  if (node.type !== "element") return null;
  const { tagName, properties = {}, children = [] } = node;
  const className = Array.isArray(properties.className)
    ? properties.className.join(" ")
    : properties.className;
  const props = { key };
  if (className) props.className = className;
  return createElement(tagName, props, ...children.map((c, i) => hastToReact(c, i)));
}
