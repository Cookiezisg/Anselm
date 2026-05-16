<script setup lang="ts">
/**
 * Documents — Notion-style markdown tree library (Phase 5 §14).
 *
 * V1 smoke layer: flat table with create / edit / delete / move
 * actions; full Notion tree + Monaco editor lands in §14.5.
 *
 * Documents —— Notion-style markdown 文档树（Phase 5 §14）。
 * V1 烟雾层：扁平表 + create/edit/delete/move；完整 Notion 树 + Monaco
 * 编辑器在 §14.5 落地。
 */
import { onMounted, ref, computed } from 'vue';
import { documentAPI } from '@/api/resources';
import { useUIStore } from '@/stores/ui';
import ViewHeader from '@/components/common/ViewHeader.vue';
import { timeAgo } from '@/utils/format';
import type { Document } from '@/types/domain';

const ui = useUIStore();
const items = ref<Document[]>([]);
const loading = ref(false);
const err = ref<string | null>(null);

const showAdd = ref(false);
const editing = ref<Document | null>(null);
const moving = ref<Document | null>(null);

interface DraftDoc {
  name: string;
  parentId: string;
  description: string;
  content: string;
  tags: string;
}

const draft = ref<DraftDoc>({
  name: '',
  parentId: '',
  description: '',
  content: '',
  tags: '',
});

const moveTarget = ref<string>('');

const rootCount = computed(
  () => items.value.filter((d) => !d.parentId).length,
);
const totalBytes = computed(() =>
  items.value.reduce((sum, d) => sum + (d.sizeBytes ?? 0), 0),
);

async function refresh() {
  loading.value = true;
  err.value = null;
  try {
    // V1 uses tree endpoint (no content) for a flat overview.
    // V1 用 tree 端点拉(不含 content),给扁平 overview。
    const tree = await documentAPI.tree();
    items.value = tree as Document[];
    items.value.sort((a, b) => a.path.localeCompare(b.path));
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(refresh);

function startAdd() {
  editing.value = null;
  draft.value = { name: '', parentId: '', description: '', content: '', tags: '' };
  showAdd.value = true;
}

async function startEdit(d: Document) {
  editing.value = d;
  // Fetch full content (tree response is content-less).
  // 取完整 content(tree 不含)。
  try {
    const full = await documentAPI.get(d.id);
    draft.value = {
      name: full.name,
      parentId: full.parentId ?? '',
      description: full.description,
      content: full.content,
      tags: (full.tags ?? []).join(', '),
    };
    showAdd.value = true;
  } catch (e) {
    ui.toast('err', (e as Error).message);
  }
}

async function save() {
  try {
    const tags = draft.value.tags
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean);
    if (editing.value) {
      await documentAPI.update(editing.value.id, {
        name: draft.value.name,
        description: draft.value.description,
        content: draft.value.content,
        tags,
      });
      ui.toast('ok', `document updated: ${draft.value.name}`);
    } else {
      await documentAPI.create({
        name: draft.value.name,
        parentId: draft.value.parentId || null,
        description: draft.value.description,
        content: draft.value.content,
        tags,
      });
      ui.toast('ok', `document created: ${draft.value.name}`);
    }
    showAdd.value = false;
    editing.value = null;
    await refresh();
  } catch (e) {
    ui.toast('err', (e as Error).message);
  }
}

async function doDelete(d: Document) {
  const childCount = items.value.filter((x) => x.path.startsWith(d.path + '/')).length;
  const msg =
    childCount > 0
      ? `Delete "${d.name}" and its ${childCount} descendant(s)?`
      : `Delete "${d.name}"?`;
  if (!confirm(msg)) return;
  try {
    const res = await documentAPI.remove(d.id);
    ui.toast('ok', `deleted ${res.deletedCount} doc(s)`);
    await refresh();
  } catch (e) {
    ui.toast('err', (e as Error).message);
  }
}

function startMove(d: Document) {
  moving.value = d;
  moveTarget.value = d.parentId ?? '';
}

async function doMove() {
  if (!moving.value) return;
  try {
    await documentAPI.move(moving.value.id, {
      parentId: moveTarget.value || null,
    });
    ui.toast('ok', `moved ${moving.value.name}`);
    moving.value = null;
    await refresh();
  } catch (e) {
    ui.toast('err', (e as Error).message);
  }
}

function indentFor(path: string) {
  // Slashes in path = depth; first char is leading "/".
  // path 中 "/" 数 = 深度;首字符是前导 "/"。
  const depth = (path.match(/\//g) ?? []).length - 1;
  return Math.max(0, depth) * 16;
}

function moveCandidates(d: Document) {
  // Exclude self and descendants from move targets.
  // 排除自己及后裔作为可选父级。
  return items.value.filter(
    (x) => x.id !== d.id && !x.path.startsWith(d.path + '/'),
  );
}

function fmtBytes(n: number) {
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)} KB`;
  return `${(n / 1024 / 1024).toFixed(2)} MB`;
}
</script>

<template>
  <div class="view">
    <ViewHeader
      title="Documents"
      :subtitle="`${items.length} docs · ${rootCount} root · ${fmtBytes(totalBytes)} total · V1 flat (Notion tree in §14.5)`"
    >
      <template #actions>
        <button class="btn primary sm" @click="startAdd">+ New</button>
        <button class="btn ghost sm" :disabled="loading" @click="refresh">refresh</button>
      </template>
    </ViewHeader>

    <section v-if="showAdd" class="add-form">
      <h4>{{ editing ? `Edit ${editing.name}` : 'New document' }}</h4>

      <label class="field-label">name</label>
      <input v-model="draft.name" placeholder="e.g. API spec" />

      <label class="field-label">parent</label>
      <select v-model="draft.parentId" :disabled="!!editing">
        <option value="">(root)</option>
        <option v-for="d in items" :key="d.id" :value="d.id">{{ d.path }}</option>
      </select>

      <label class="field-label">description</label>
      <input v-model="draft.description" placeholder="One-line summary (shown in catalog)" />

      <label class="field-label">tags</label>
      <input v-model="draft.tags" placeholder="comma, separated, tags" />

      <label class="field-label">content</label>
      <textarea v-model="draft.content" rows="12" placeholder="markdown body…"></textarea>

      <button class="btn primary" @click="save" :disabled="!draft.name">
        {{ editing ? 'Save' : 'Create' }}
      </button>
      <button class="btn ghost" @click="showAdd = false">Cancel</button>
    </section>

    <section v-if="moving" class="add-form">
      <h4>Move {{ moving.name }}</h4>
      <label class="field-label">new parent</label>
      <select v-model="moveTarget">
        <option value="">(root)</option>
        <option v-for="d in moveCandidates(moving)" :key="d.id" :value="d.id">{{ d.path }}</option>
      </select>
      <button class="btn primary" @click="doMove">Move</button>
      <button class="btn ghost" @click="moving = null">Cancel</button>
    </section>

    <div class="scroll">
      <div v-if="err" class="error">⨯ {{ err }}</div>
      <table class="table">
        <thead>
          <tr>
            <th style="width: 40%">path</th>
            <th>description</th>
            <th style="width: 100px">size</th>
            <th style="width: 110px">updated</th>
            <th style="width: 280px"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="d in items" :key="d.id">
            <td>
              <div class="mono" :style="{ paddingLeft: indentFor(d.path) + 'px' }">
                <span class="dim xs" v-if="d.parentId">↳ </span>{{ d.name }}
              </div>
              <div class="dim xs" :style="{ paddingLeft: indentFor(d.path) + 'px' }">
                {{ d.path }}
              </div>
            </td>
            <td class="dim small">{{ d.description || '—' }}</td>
            <td class="dim xs">{{ fmtBytes(d.sizeBytes ?? 0) }}</td>
            <td class="dim xs">{{ timeAgo(d.updatedAt) }}</td>
            <td>
              <button class="btn ghost sm" @click="startEdit(d)">edit</button>
              <button class="btn ghost sm" @click="startMove(d)">move</button>
              <button class="btn danger sm" @click="doDelete(d)">delete</button>
              <button class="btn ghost sm" @click="ui.showRaw(d.name, d)">raw</button>
            </td>
          </tr>
          <tr v-if="!loading && items.length === 0">
            <td colspan="5" class="empty-row">
              No documents yet. Click + New to create one.
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.view { display: flex; flex-direction: column; height: 100%; }
.scroll { flex: 1; overflow: auto; padding: 0 var(--sp-3) var(--sp-3); }
.add-form {
  background: var(--bg-1);
  border-bottom: 1px solid var(--border-1);
  padding: var(--sp-3);
  display: grid;
  grid-template-columns: 140px 1fr;
  gap: var(--sp-1) var(--sp-2);
  align-items: start;
}
.add-form h4 { grid-column: 1 / -1; margin: 0 0 var(--sp-2); }
.add-form input, .add-form select, .add-form textarea { width: 100%; }
.add-form button { grid-column: 2; justify-self: start; margin-top: var(--sp-2); }
.add-form button + button { margin-left: var(--sp-2); }
.field-label { font-size: var(--fs-xs); color: var(--fg-2); justify-self: end; text-align: right; padding-top: 6px; }
.empty-row { text-align: center; color: var(--fg-3); padding: var(--sp-6) 0; font-style: italic; }
.error { background: var(--status-err-bg); color: var(--status-err); padding: var(--sp-2); border-radius: var(--radius-sm); }
</style>
