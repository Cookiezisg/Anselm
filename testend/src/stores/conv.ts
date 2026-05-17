/**
 * Conversation store — list (sidebar), selected conv, CRUD ops.
 *
 * Chat message state lives in chat.ts; this store only handles the
 * sidebar list + which conv is selected.
 */

import { defineStore } from 'pinia';
import { ref } from 'vue';
import { convAPI } from '@/api/conversations';
import type { Conversation } from '@/types/domain';
import { useUIStore } from './ui';

export const useConvStore = defineStore('conv', () => {
  const ui = useUIStore();

  const list = ref<Conversation[]>([]);
  const loading = ref(false);
  const selectedId = ref<string | null>(null);
  const filter = ref('');
  const showArchived = ref(false);

  async function refresh() {
    loading.value = true;
    try {
      const page = await convAPI.list(200, filter.value, showArchived.value ? true : undefined);
      list.value = page.items.sort((a, b) => {
        // §15.6 pinned bubbles first; recency within each bucket.
        // §15.6 pinned 浮顶；桶内按 updatedAt/createdAt 倒序。
        if (!!a.pinned !== !!b.pinned) return a.pinned ? -1 : 1;
        return (b.updatedAt || b.createdAt).localeCompare(a.updatedAt || a.createdAt);
      });
    } catch (e) {
      ui.toast('err', `加载对话列表失败: ${(e as Error).message}`);
    } finally {
      loading.value = false;
    }
  }

  async function create(title = '') {
    try {
      const conv = await convAPI.create(title);
      list.value.unshift(conv);
      selectedId.value = conv.id;
      return conv;
    } catch (e) {
      ui.toast('err', `新建对话失败: ${(e as Error).message}`);
      throw e;
    }
  }

  async function rename(id: string, title: string) {
    try {
      const conv = await convAPI.rename(id, title);
      const i = list.value.findIndex((c) => c.id === id);
      if (i >= 0) list.value[i] = conv;
    } catch (e) {
      ui.toast('err', `重命名失败: ${(e as Error).message}`);
    }
  }

  async function setSystemPrompt(id: string, systemPrompt: string) {
    try {
      const conv = await convAPI.setSystemPrompt(id, systemPrompt);
      const i = list.value.findIndex((c) => c.id === id);
      if (i >= 0) list.value[i] = conv;
      ui.toast('ok', 'system prompt 已保存');
    } catch (e) {
      ui.toast('err', `保存失败: ${(e as Error).message}`);
    }
  }

  async function setAttachedDocuments(
    id: string,
    attachedDocuments: Array<{ documentId: string; includeSubtree?: boolean }>,
  ) {
    try {
      const conv = await convAPI.setAttachedDocuments(id, attachedDocuments);
      const i = list.value.findIndex((c) => c.id === id);
      if (i >= 0) list.value[i] = conv;
      ui.toast('ok', '挂载文档已更新');
    } catch (e) {
      ui.toast('err', `保存失败: ${(e as Error).message}`);
    }
  }

  async function remove(id: string) {
    try {
      await convAPI.remove(id);
      list.value = list.value.filter((c) => c.id !== id);
      if (selectedId.value === id) selectedId.value = null;
    } catch (e) {
      ui.toast('err', `删除失败: ${(e as Error).message}`);
    }
  }

  async function setArchived(id: string, archived: boolean) {
    try {
      const conv = await convAPI.setArchived(id, archived);
      // When toggling matches current view, update in-place; otherwise drop it.
      // 切换后若不在当前视图（active vs archived），从列表移除。
      const inView = archived === showArchived.value;
      if (inView) {
        const i = list.value.findIndex((c) => c.id === id);
        if (i >= 0) list.value[i] = conv;
      } else {
        list.value = list.value.filter((c) => c.id !== id);
        if (selectedId.value === id) selectedId.value = null;
      }
      ui.toast('ok', archived ? '对话已归档' : '已恢复对话');
    } catch (e) {
      ui.toast('err', `归档失败: ${(e as Error).message}`);
    }
  }

  async function setModelOverride(
    id: string,
    ref: { provider: string; modelId: string } | null,
  ) {
    try {
      const conv = await convAPI.setModelOverride(id, ref);
      const i = list.value.findIndex((c) => c.id === id);
      if (i >= 0) list.value[i] = conv;
      ui.toast('ok', ref ? `已设置专属模型: ${ref.provider}/${ref.modelId}` : '已恢复全局默认模型');
    } catch (e) {
      ui.toast('err', `模型设置失败: ${(e as Error).message}`);
    }
  }

  async function setPinned(id: string, pinned: boolean) {
    try {
      const conv = await convAPI.setPinned(id, pinned);
      const i = list.value.findIndex((c) => c.id === id);
      if (i >= 0) list.value[i] = conv;
      // Re-sort pinned-first to mirror backend ORDER BY pinned DESC.
      // 客户端再排一次（pinned 优先），与后端 ORDER BY 一致。
      list.value.sort((a, b) => {
        if (!!a.pinned !== !!b.pinned) return a.pinned ? -1 : 1;
        return (b.updatedAt || b.createdAt).localeCompare(a.updatedAt || a.createdAt);
      });
      ui.toast('ok', pinned ? '对话已置顶' : '已取消置顶');
    } catch (e) {
      ui.toast('err', `置顶失败: ${(e as Error).message}`);
    }
  }

  async function duplicate(id: string) {
    // Best-effort: fetch source, create new with copied title + system prompt.
    const src = list.value.find((c) => c.id === id);
    if (!src) return;
    const fresh = await create(`${src.title || '(untitled)'} (copy)`);
    if (src.systemPrompt) {
      await setSystemPrompt(fresh.id, src.systemPrompt);
    }
  }

  function select(id: string | null) {
    selectedId.value = id;
  }

  /** Bump updatedAt on a conv (in-memory) — called when a new message arrives. */
  function touchUpdated(id: string, ts?: string) {
    const i = list.value.findIndex((c) => c.id === id);
    if (i < 0) return;
    list.value[i].updatedAt = ts ?? new Date().toISOString();
    // Re-sort honoring pinned-first (§15.6): unpinned moves to top of unpinned section;
    // pinned stays in pinned section but bubbles within it.
    // 排序按 §15.6：unpinned 浮到 unpinned 段顶；pinned 在 pinned 段内浮顶。
    list.value.sort((a, b) => {
      if (!!a.pinned !== !!b.pinned) return a.pinned ? -1 : 1;
      return (b.updatedAt || b.createdAt).localeCompare(a.updatedAt || a.createdAt);
    });
  }

  function setTitle(id: string, title: string) {
    const i = list.value.findIndex((c) => c.id === id);
    if (i >= 0) list.value[i].title = title;
  }

  function toggleShowArchived() {
    showArchived.value = !showArchived.value;
    return refresh();
  }

  return {
    list, loading, selectedId, filter, showArchived,
    refresh, create, rename, setSystemPrompt, setAttachedDocuments,
    setArchived, setPinned, setModelOverride, toggleShowArchived,
    remove, duplicate, select, touchUpdated, setTitle,
  };
});
