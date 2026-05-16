<script setup lang="ts">
/**
 * AttachedDocsEditor — pick docs to prepend to every system prompt
 * (Phase 5 §14.5c). Mirrors SystemPromptEditor's inline-editor pattern.
 *
 * AttachedDocsEditor —— 选要前置到每轮 system prompt 的 doc（Phase 5
 * §14.5c）。模仿 SystemPromptEditor 内联编辑器模式。
 */
import { onMounted, ref, watch, computed } from 'vue';
import { documentAPI } from '@/api/resources';
import { useConvStore } from '@/stores/conv';
import { useUIStore } from '@/stores/ui';
import type { Document } from '@/types/domain';

const props = defineProps<{ convId: string }>();
const emit = defineEmits<{ close: [] }>();

const conv = useConvStore();
const ui = useUIStore();

const tree = ref<Array<Omit<Document, 'content'>>>([]);
const loading = ref(false);

interface Draft {
  documentId: string;
  includeSubtree?: boolean;
}

const draft = ref<Draft[]>([]);
const dirty = ref(false);

function reloadDraft() {
  const c = conv.list.find((x) => x.id === props.convId);
  draft.value = (c?.attachedDocuments ?? []).map((a) => ({ ...a }));
  dirty.value = false;
}

watch(() => props.convId, reloadDraft, { immediate: true });

onMounted(async () => {
  loading.value = true;
  try {
    tree.value = await documentAPI.tree();
    tree.value.sort((a, b) => (a.path || '').localeCompare(b.path || ''));
  } catch (e) {
    ui.toast('err', `加载文档树失败: ${(e as Error).message}`);
  } finally {
    loading.value = false;
  }
});

const pathById = computed(() => {
  const m = new Map<string, string>();
  for (const d of tree.value) m.set(d.id, d.path || d.name);
  return m;
});

const unselected = computed(() =>
  tree.value.filter((d) => !draft.value.find((a) => a.documentId === d.id)),
);

const totalSize = computed(() => {
  let sum = 0;
  for (const a of draft.value) {
    const d = tree.value.find((x) => x.id === a.documentId);
    if (d) sum += d.sizeBytes ?? 0;
  }
  return sum;
});

function add(id: string) {
  if (!id) return;
  draft.value.push({ documentId: id, includeSubtree: false });
  dirty.value = true;
}

function remove(idx: number) {
  draft.value.splice(idx, 1);
  dirty.value = true;
}

function toggleSubtree(idx: number) {
  draft.value[idx].includeSubtree = !draft.value[idx].includeSubtree;
  dirty.value = true;
}

async function save() {
  await conv.setAttachedDocuments(props.convId, draft.value);
  dirty.value = false;
}

function fmtBytes(n: number) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / 1024 / 1024).toFixed(2)} MB`;
}
</script>

<template>
  <div class="docs-editor">
    <header class="docs-head">
      <strong class="dim small">ATTACHED DOCUMENTS</strong>
      <span class="dim xs">{{ draft.length }} 篇 · {{ fmtBytes(totalSize) }}</span>
      <span v-if="dirty" class="pill warn">modified</span>
      <span class="spacer" />
      <button class="btn ghost sm" :disabled="!dirty" @click="reloadDraft">还原</button>
      <button class="btn primary sm" :disabled="!dirty" @click="save">保存</button>
      <button class="btn ghost sm" @click="emit('close')">关闭</button>
    </header>

    <div v-if="loading" class="dim small">加载文档树中…</div>

    <ul v-if="draft.length > 0" class="chips">
      <li v-for="(a, idx) in draft" :key="a.documentId + idx">
        <span class="mono small">{{ pathById.get(a.documentId) || a.documentId }}</span>
        <label class="subtree-toggle">
          <input
            type="checkbox"
            :checked="!!a.includeSubtree"
            @change="toggleSubtree(idx)"
          />
          <span class="dim xs">含子树</span>
        </label>
        <button class="btn ghost xs" @click="remove(idx)">✕</button>
      </li>
    </ul>

    <div class="add-row">
      <select @change="add(($event.target as HTMLSelectElement).value); ($event.target as HTMLSelectElement).value = ''">
        <option value="">+ 挂载文档…</option>
        <option v-for="d in unselected" :key="d.id" :value="d.id">
          {{ d.path || d.name }}
        </option>
      </select>
      <span class="dim xs">含子树会 live-resolve 跟随文档树变化</span>
    </div>
  </div>
</template>

<style scoped>
.docs-editor {
  background: var(--bg-2);
  border-bottom: 1px solid var(--border-1);
  padding: var(--sp-2) var(--sp-3);
}
.docs-head {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  margin-bottom: var(--sp-2);
}
.spacer { flex: 1; }
.chips {
  list-style: none;
  padding: 0;
  margin: 0 0 var(--sp-2) 0;
  display: flex;
  flex-direction: column;
  gap: var(--sp-1);
}
.chips li {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  background: var(--bg-1);
  border: 1px solid var(--border-1);
  border-radius: var(--radius-sm);
  padding: var(--sp-1) var(--sp-2);
}
.subtree-toggle {
  display: flex;
  align-items: center;
  gap: var(--sp-1);
  cursor: pointer;
}
.add-row {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
}
.add-row select { flex: 1; max-width: 360px; }
</style>
