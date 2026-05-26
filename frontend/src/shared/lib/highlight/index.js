// Shared lowlight instance. createLowlight(common) registers 36 popular
// languages (python/js/ts/go/sql/bash/json/yaml/html/css/md/diff/...).
// Both HighlightedCode (chat MarkdownView) and DocEditor's
// CodeBlockLowlight pull this exact instance so language coverage and
// future custom registrations stay in one place.
//
// 共享 lowlight 实例；HighlightedCode + Tiptap CodeBlockLowlight 共用。

import { createLowlight, common } from "lowlight";

export const lowlight = createLowlight(common);
