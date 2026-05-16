<script setup lang="ts">
/**
 * Usage — §4.9: wraps /api/v1/usage so you can see token / cost spend
 * per period or per conversation, broken down by (provider, model).
 *
 * Usage —— §4.9:展示 /api/v1/usage 数据。
 */
import { onMounted, ref } from 'vue';
import { usageAPI, type UsageResponse } from '@/api/misc';
import { useUIStore } from '@/stores/ui';
import ViewHeader from '@/components/common/ViewHeader.vue';

type Period = 'day' | 'week' | 'month' | 'all';
const period = ref<Period>('week');
const data = ref<UsageResponse | null>(null);
const loading = ref(false);
const ui = useUIStore();

async function load() {
  loading.value = true;
  try {
    data.value = await usageAPI.forPeriod(period.value);
  } catch (e) {
    ui.toast('err', `加载 usage 失败: ${(e as Error).message}`);
  } finally {
    loading.value = false;
  }
}

onMounted(load);

function fmtUsd(n: number) {
  if (n === 0) return '$0';
  if (n < 0.01) return `$${(n * 1000).toFixed(2)}/k`;
  return `$${n.toFixed(4)}`;
}
function fmtTokens(n: number) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return String(n);
}
</script>

<template>
  <div class="view">
    <ViewHeader
      title="Usage"
      :subtitle="data ? `${fmtTokens(data.totalTokens)} tokens · ${fmtUsd(data.costEstimateUsd)} (rough)` : 'loading...'"
    >
      <template #actions>
        <select v-model="period" @change="load">
          <option value="day">today</option>
          <option value="week">past 7 days</option>
          <option value="month">past 30 days</option>
          <option value="all">all time</option>
        </select>
        <button class="btn ghost sm" :disabled="loading" @click="load">refresh</button>
      </template>
    </ViewHeader>

    <div class="scroll">
      <div v-if="!data && loading" class="dim small">加载中…</div>
      <div v-else-if="data">
        <p class="dim small">{{ data.note }}</p>

        <table class="table">
          <thead>
            <tr>
              <th>provider · model</th>
              <th style="width: 120px">input</th>
              <th style="width: 120px">output</th>
              <th style="width: 120px">total</th>
              <th style="width: 110px">cost</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="m in data.byModel" :key="`${m.provider}-${m.modelId}`">
              <td class="mono">{{ m.provider }} / {{ m.modelId }}</td>
              <td>{{ fmtTokens(m.inputTokens) }}</td>
              <td>{{ fmtTokens(m.outputTokens) }}</td>
              <td>{{ fmtTokens(m.totalTokens) }}</td>
              <td>
                {{ fmtUsd(m.costEstimateUsd) }}
                <span v-if="!m.costKnown" class="dim xs"> (model not in registry)</span>
              </td>
            </tr>
            <tr v-if="data.byModel.length === 0">
              <td colspan="5" class="empty-row">No usage in this period.</td>
            </tr>
          </tbody>
          <tfoot v-if="data.byModel.length > 0">
            <tr>
              <th>total</th>
              <th>{{ fmtTokens(data.inputTokens) }}</th>
              <th>{{ fmtTokens(data.outputTokens) }}</th>
              <th>{{ fmtTokens(data.totalTokens) }}</th>
              <th>{{ fmtUsd(data.costEstimateUsd) }}</th>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  </div>
</template>

<style scoped>
.view { display: flex; flex-direction: column; height: 100%; }
.scroll { flex: 1; overflow: auto; padding: var(--sp-3); }
select { padding: var(--sp-1); }
tfoot th { background: var(--bg-1); }
.empty-row { text-align: center; color: var(--fg-3); padding: var(--sp-6) 0; font-style: italic; }
</style>
