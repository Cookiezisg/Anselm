<script setup lang="ts">
/**
 * SystemPromptPreview — §18.2.
 *
 * Modal that fetches the assembled system prompt for the current conv,
 * shows each section collapsible, plus the raw assembled string toggle.
 */
import { computed, onMounted, ref } from 'vue';
import { convAPI } from '@/api/conversations';

const props = defineProps<{ convId: string }>();
const emit = defineEmits<{ close: [] }>();

interface PreviewSection {
  name: string;
  content: string;
}

const sections = ref<PreviewSection[]>([]);
const assembled = ref('');
const totalLen = ref(0);
const totalTokens = ref(0);
const loading = ref(false);
const err = ref('');
const showRaw = ref(false);
const expanded = ref<Record<string, boolean>>({});

async function refresh() {
  loading.value = true;
  err.value = '';
  try {
    const r = await convAPI.systemPromptPreview(props.convId);
    sections.value = r.sections;
    assembled.value = r.assembled;
    totalLen.value = r.totalLength;
    totalTokens.value = r.totalTokensEst;
    // expand all by default — user just opened it to see contents.
    expanded.value = Object.fromEntries(r.sections.map((s) => [s.name, true]));
  } catch (e) {
    err.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(refresh);

function toggle(name: string) {
  expanded.value[name] = !expanded.value[name];
}

const sectionStats = computed(() =>
  sections.value.map((s) => ({
    name: s.name,
    chars: s.content.length,
    tokens: Math.ceil(s.content.length / 4),
  })),
);
</script>

<template>
  <div class="spp-modal">
    <header class="spp-header">
      <div>
        <strong>System prompt 预览</strong>
        <span class="dim sm">— 这是实际发给 LLM 的（§18.2）</span>
      </div>
      <div class="actions">
        <button class="btn ghost xs" @click="showRaw = !showRaw">
          {{ showRaw ? 'show sections' : 'show raw' }}
        </button>
        <button class="btn ghost xs" :disabled="loading" @click="refresh">↻</button>
        <button class="btn ghost xs" @click="emit('close')">✕</button>
      </div>
    </header>

    <div v-if="err" class="error">⨯ {{ err }}</div>

    <div class="spp-stats dim sm">
      Total: <strong>{{ totalLen }}</strong> chars · ~<strong>{{ totalTokens }}</strong> tokens
      · <strong>{{ sections.length }}</strong> sections
    </div>

    <div v-if="!showRaw" class="spp-body scroll">
      <div v-for="s in sections" :key="s.name" class="section">
        <div class="section-head" @click="toggle(s.name)">
          <span class="caret">{{ expanded[s.name] ? '▾' : '▸' }}</span>
          <span class="section-name mono">{{ s.name }}</span>
          <span class="section-stat dim xs">
            {{ s.content.length }} ch · ~{{ Math.ceil(s.content.length / 4) }} tok
          </span>
        </div>
        <pre v-if="expanded[s.name]" class="section-content">{{ s.content }}</pre>
      </div>
    </div>

    <div v-else class="spp-body scroll">
      <pre class="raw">{{ assembled }}</pre>
    </div>
  </div>
</template>

<style scoped>
.spp-modal {
  position: fixed;
  inset: 5% 5% 5% 5%;
  background: var(--bg-1);
  border: 1px solid var(--border-2);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-2);
  z-index: 200;
  display: flex;
  flex-direction: column;
  max-width: 1100px;
  margin: 0 auto;
}

.spp-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--sp-2) var(--sp-3);
  border-bottom: 1px solid var(--border-1);
}

.actions {
  display: flex;
  gap: 4px;
}

.spp-stats {
  padding: var(--sp-1) var(--sp-3);
  border-bottom: 1px solid var(--border-1);
  background: var(--bg-2);
}

.spp-body {
  flex: 1;
  overflow-y: auto;
  padding: var(--sp-2);
}

.section {
  border: 1px solid var(--border-1);
  border-radius: var(--radius-sm);
  margin-bottom: var(--sp-2);
  background: var(--bg-2);
}

.section-head {
  display: flex;
  align-items: center;
  gap: var(--sp-2);
  padding: 6px var(--sp-2);
  cursor: pointer;
  font-size: var(--fs-sm);
}

.section-head:hover {
  background: var(--bg-hover);
}

.caret {
  width: 12px;
  color: var(--fg-3);
}

.section-name {
  font-weight: 500;
  flex: 1;
}

.section-content,
.raw {
  white-space: pre-wrap;
  word-break: break-word;
  font-size: var(--fs-xs);
  padding: var(--sp-2);
  background: var(--bg-1);
  margin: 0;
  font-family: var(--font-mono);
}

.error {
  background: var(--status-err-bg);
  color: var(--status-err);
  padding: var(--sp-2);
}
</style>
