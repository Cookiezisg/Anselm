<script setup lang="ts">
/**
 * ModelOverrideEditor — chat header popover for §12.3 per-conv model override.
 *
 * Lists (provider, modelId) options sourced from the user's configured API
 * keys (tested ok). "Use global default" clears the override.
 *
 * Backend validates that the chosen provider has an api-key → 422
 * PROVIDER_HAS_NO_KEY otherwise.
 */
import { computed, onMounted, ref } from 'vue';
import { useConvStore } from '@/stores/conv';
import { apikeyAPI } from '@/api/resources';
import type { APIKey } from '@/types/domain';

const props = defineProps<{ convId: string }>();
const emit = defineEmits<{ close: [] }>();

const conv = useConvStore();
const apikeys = ref<APIKey[]>([]);
const loading = ref(false);

const current = computed(() => conv.list.find((c) => c.id === props.convId));

interface Option {
  provider: string;
  modelId: string;
  apiFormat?: string;
}

const options = computed<Option[]>(() => {
  const out: Option[] = [];
  for (const k of apikeys.value) {
    if (k.testStatus !== 'ok') continue;
    const models = k.modelsFound ?? [];
    for (const m of models) {
      out.push({ provider: k.provider, modelId: m, apiFormat: k.apiFormat });
    }
  }
  return out;
});

onMounted(async () => {
  loading.value = true;
  try {
    apikeys.value = await apikeyAPI.list();
  } finally {
    loading.value = false;
  }
});

async function pick(opt: Option) {
  await conv.setModelOverride(props.convId, { provider: opt.provider, modelId: opt.modelId });
  emit('close');
}

async function clearOverride() {
  await conv.setModelOverride(props.convId, null);
  emit('close');
}

function isCurrent(opt: Option): boolean {
  const ov = current.value?.modelOverride;
  return !!ov && ov.provider === opt.provider && ov.modelId === opt.modelId;
}
</script>

<template>
  <div class="model-override-editor">
    <header class="moe-header">
      <strong>专属模型</strong>
      <button class="btn ghost xs" @click="emit('close')">✕</button>
    </header>

    <div class="moe-body scroll">
      <button
        class="moe-row default"
        :class="{ active: !current?.modelOverride }"
        @click="clearOverride"
      >
        <span class="moe-row-main">使用全局默认（按 scenario 配置）</span>
        <span v-if="!current?.modelOverride" class="moe-check">✓</span>
      </button>

      <div v-if="loading" class="dim sm">加载中…</div>
      <div v-else-if="options.length === 0" class="dim sm">
        没有可用模型——先在 <em>/config/apikeys</em> 加 key 并 :test 一下，再回这里
      </div>

      <button
        v-for="opt in options"
        :key="`${opt.provider}|${opt.modelId}`"
        class="moe-row"
        :class="{ active: isCurrent(opt) }"
        @click="pick(opt)"
      >
        <span class="moe-row-main">
          <span class="mono">{{ opt.provider }}</span>
          <span class="moe-sep">/</span>
          <span>{{ opt.modelId }}</span>
        </span>
        <span v-if="isCurrent(opt)" class="moe-check">✓</span>
      </button>
    </div>

    <footer class="moe-footer">
      <span class="dim xs">
        切换后下一次发送即生效；老消息历史不变。
      </span>
    </footer>
  </div>
</template>

<style scoped>
.model-override-editor {
  border-bottom: 1px solid var(--border-1);
  background: var(--bg-2);
  max-height: 300px;
  display: flex;
  flex-direction: column;
}

.moe-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--sp-2) var(--sp-3);
  border-bottom: 1px solid var(--border-1);
  font-size: var(--fs-sm);
}

.moe-body {
  flex: 1;
  overflow-y: auto;
  padding: var(--sp-1) 0;
}

.moe-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 8px var(--sp-3);
  font-size: var(--fs-sm);
  text-align: left;
  background: transparent;
  border: none;
  cursor: pointer;
  color: var(--fg-1);
}

.moe-row:hover {
  background: var(--bg-hover);
}

.moe-row.active {
  background: var(--bg-active);
  color: var(--accent);
}

.moe-row.default {
  border-bottom: 1px dashed var(--border-1);
  font-style: italic;
}

.moe-row-main {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 4px;
}

.moe-sep {
  color: var(--fg-3);
  margin: 0 4px;
}

.moe-check {
  color: var(--accent);
  font-weight: 600;
  margin-left: var(--sp-2);
}

.moe-footer {
  padding: var(--sp-2) var(--sp-3);
  border-top: 1px solid var(--border-1);
}
</style>
