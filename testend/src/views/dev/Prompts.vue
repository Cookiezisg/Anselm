<script setup lang="ts">
/**
 * Prompts inventory view — §18.1.
 *
 * One-stop audit of every LLM-facing prompt the backend ships:
 *  - tool descriptions (33+ system tools)
 *  - chat-system static segments (base, multi-agent forging)
 *  - internal-llm prompts (catalog generator, contextmgr compact, web summary)
 *  - subagent system prompts (Explore / Plan / general-purpose)
 *
 * Reads GET /api/v1/dev/prompts; filter + click-to-expand.
 */
import { computed, onMounted, ref } from 'vue';
import { getJSON } from '@/api/client';

interface PromptEntry {
  name: string;
  category: string;
  description: string;
  content: string;
  length: number;
  tokensEst: number;
  source: string;
}

const entries = ref<PromptEntry[]>([]);
const loading = ref(false);
const err = ref('');
const search = ref('');
const expanded = ref<Record<string, boolean>>({});
const categoryFilter = ref('');

async function refresh() {
  loading.value = true;
  err.value = '';
  try {
    const r = await getJSON<{ count: number; entries: PromptEntry[] }>(
      '/api/v1/dev/prompts',
    );
    entries.value = r.entries;
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(refresh);

const filtered = computed(() => {
  let out = entries.value;
  if (categoryFilter.value) out = out.filter((e) => e.category === categoryFilter.value);
  const q = search.value.trim().toLowerCase();
  if (q) {
    out = out.filter(
      (e) =>
        e.name.toLowerCase().includes(q) ||
        e.description.toLowerCase().includes(q) ||
        e.content.toLowerCase().includes(q),
    );
  }
  return out;
});

const categories = computed(() => {
  const s = new Set<string>();
  for (const e of entries.value) s.add(e.category);
  return [...s].sort();
});

const stats = computed(() => {
  const buckets: Record<string, { count: number; totalTokens: number }> = {};
  for (const e of entries.value) {
    if (!buckets[e.category]) buckets[e.category] = { count: 0, totalTokens: 0 };
    buckets[e.category].count++;
    buckets[e.category].totalTokens += e.tokensEst;
  }
  return buckets;
});

function toggle(id: string) {
  expanded.value[id] = !expanded.value[id];
}

function lengthClass(len: number) {
  if (len < 50) return 'too-short';
  if (len > 800) return 'too-long';
  return '';
}
</script>

<template>
  <div class="view">
    <header class="view-header">
      <div>
        <h2>Prompts inventory <span class="dim sm">(§18.1)</span></h2>
        <p class="sub dim sm">
          每个 LLM-facing prompt 一站式 audit。后端共 {{ entries.length }} 条。
        </p>
      </div>
      <div class="actions">
        <input v-model="search" class="search" placeholder="filter name / desc / content…" />
        <select v-model="categoryFilter" class="sm">
          <option value="">all categories</option>
          <option v-for="c in categories" :key="c" :value="c">{{ c }}</option>
        </select>
        <button class="btn ghost sm" :disabled="loading" @click="refresh">
          {{ loading ? '...' : '↻ refresh' }}
        </button>
      </div>
    </header>

    <div v-if="err" class="error">⨯ {{ err }}</div>

    <div class="stats">
      <div v-for="(s, cat) in stats" :key="cat" class="stat-box">
        <span class="stat-cat">{{ cat }}</span>
        <span class="stat-count">{{ s.count }}</span>
        <span class="stat-tokens dim sm">~{{ s.totalTokens }} tok</span>
      </div>
    </div>

    <div class="scroll">
      <div v-for="e in filtered" :key="e.name" class="entry">
        <div class="entry-header" @click="toggle(e.name)">
          <span class="caret">{{ expanded[e.name] ? '▾' : '▸' }}</span>
          <span class="name mono">{{ e.name }}</span>
          <span class="cat pill" :class="`cat-${e.category}`">{{ e.category }}</span>
          <span class="length" :class="lengthClass(e.length)">
            {{ e.length }} ch · ~{{ e.tokensEst }} tok
          </span>
          <span class="desc dim sm ellipsis">{{ e.description }}</span>
        </div>
        <div v-if="expanded[e.name]" class="entry-body">
          <div class="source dim xs mono">📁 {{ e.source }}</div>
          <pre class="content">{{ e.content }}</pre>
        </div>
      </div>
      <div v-if="!loading && filtered.length === 0" class="empty">No matches.</div>
    </div>
  </div>
</template>

<style scoped>
.view {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: var(--sp-3);
  gap: var(--sp-2);
}

.view-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: var(--sp-3);
}

.view-header h2 {
  margin: 0;
  font-size: var(--fs-md);
}

.view-header .sub {
  margin-top: 2px;
}

.actions {
  display: flex;
  gap: var(--sp-1);
  align-items: center;
}

.search {
  width: 260px;
  font-size: var(--fs-sm);
  padding: 4px 8px;
}

.stats {
  display: flex;
  gap: var(--sp-2);
  flex-wrap: wrap;
}

.stat-box {
  display: flex;
  flex-direction: column;
  padding: 6px 10px;
  border: 1px solid var(--border-1);
  border-radius: var(--radius-sm);
  background: var(--bg-1);
  min-width: 100px;
}

.stat-cat {
  font-size: 10px;
  text-transform: uppercase;
  color: var(--fg-2);
  letter-spacing: 0.05em;
}

.stat-count {
  font-size: var(--fs-md);
  font-weight: 600;
}

.stat-tokens {
  font-size: 10px;
}

.scroll {
  flex: 1;
  overflow-y: auto;
  border: 1px solid var(--border-1);
  border-radius: var(--radius-sm);
}

.entry {
  border-bottom: 1px solid var(--border-1);
}

.entry:last-child {
  border-bottom: none;
}

.entry-header {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: 8px var(--sp-2);
  cursor: pointer;
  font-size: var(--fs-sm);
}

.entry-header:hover {
  background: var(--bg-hover);
}

.caret {
  width: 14px;
  color: var(--fg-3);
}

.name {
  min-width: 220px;
  font-weight: 500;
}

.cat {
  font-size: 10px;
  padding: 2px 6px;
}

.cat-tool {
  background: var(--accent-bg);
  color: var(--accent);
}

.cat-chat-system {
  background: color-mix(in srgb, var(--status-ok) 20%, transparent);
  color: var(--status-ok);
}

.cat-subagent {
  background: color-mix(in srgb, var(--status-warn) 20%, transparent);
  color: var(--status-warn);
}

.cat-internal-llm {
  background: color-mix(in srgb, var(--fg-3) 30%, transparent);
  color: var(--fg-2);
}

.length {
  font-family: var(--font-mono);
  font-size: 10px;
  color: var(--fg-3);
  min-width: 120px;
}

.length.too-short {
  color: var(--status-warn);
}

.length.too-long {
  color: var(--status-err);
}

.desc {
  flex: 1;
}

.ellipsis {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 400px;
}

.entry-body {
  padding: 8px var(--sp-3) var(--sp-3) 32px;
  background: var(--bg-2);
}

.source {
  margin-bottom: 6px;
}

.content {
  white-space: pre-wrap;
  word-break: break-word;
  font-size: var(--fs-xs);
  background: var(--bg-1);
  padding: var(--sp-2);
  border-radius: var(--radius-sm);
  max-height: 400px;
  overflow-y: auto;
}

.empty {
  padding: var(--sp-6);
  text-align: center;
  color: var(--fg-3);
  font-style: italic;
}

.error {
  background: var(--status-err-bg);
  color: var(--status-err);
  padding: var(--sp-2);
  border-radius: var(--radius-sm);
}
</style>
