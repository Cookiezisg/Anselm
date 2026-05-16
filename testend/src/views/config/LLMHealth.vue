<script setup lang="ts">
/**
 * LLMHealth — §4.10: aggregate per-provider connectivity status from
 * `/api/v1/api-keys` (test_status + last_tested_at) plus a global
 * metrics bucket showing recent LLM success rate.
 *
 * LLMHealth —— §4.10:从 apikey 的 test_status / last_tested_at 聚合每个
 * provider 的连通状态。
 */
import { onMounted, ref, computed } from 'vue';
import { apikeyAPI } from '@/api/resources';
import { useUIStore } from '@/stores/ui';
import ViewHeader from '@/components/common/ViewHeader.vue';
import { timeAgo } from '@/utils/format';
import type { APIKey } from '@/types/domain';

const keys = ref<APIKey[]>([]);
const loading = ref(false);
const ui = useUIStore();

async function load() {
  loading.value = true;
  try {
    keys.value = await apikeyAPI.list();
  } catch (e) {
    ui.toast('err', `加载 api keys 失败: ${(e as Error).message}`);
  } finally {
    loading.value = false;
  }
}

async function test(id: string) {
  try {
    await apikeyAPI.test(id);
    ui.toast('ok', 'test 完成');
    await load();
  } catch (e) {
    ui.toast('err', `test 失败: ${(e as Error).message}`);
  }
}

onMounted(load);

interface ProviderHealth {
  provider: string;
  total: number;
  ok: number;
  failed: number;
  untested: number;
  lastTestedAt?: string;
  worstStatus: 'ok' | 'failed' | 'pending';
}

const byProvider = computed<ProviderHealth[]>(() => {
  const groups = new Map<string, APIKey[]>();
  for (const k of keys.value) {
    const arr = groups.get(k.provider) ?? [];
    arr.push(k);
    groups.set(k.provider, arr);
  }
  const out: ProviderHealth[] = [];
  for (const [provider, arr] of groups) {
    let ok = 0, failed = 0, untested = 0;
    let lastTestedAt: string | undefined;
    let worstStatus: 'ok' | 'failed' | 'pending' = 'ok';
    for (const k of arr) {
      const s = k.testStatus ?? '';
      if (s === 'ok') ok++;
      else if (s === 'error') {
        failed++;
        worstStatus = 'failed';
      } else {
        untested++;
        if (worstStatus !== 'failed') worstStatus = 'pending';
      }
      if (k.lastTestedAt && (!lastTestedAt || k.lastTestedAt > lastTestedAt)) {
        lastTestedAt = k.lastTestedAt;
      }
    }
    out.push({ provider, total: arr.length, ok, failed, untested, lastTestedAt, worstStatus });
  }
  out.sort((a, b) => a.provider.localeCompare(b.provider));
  return out;
});

function statusClass(s: string) {
  return `pill status-${s}`;
}
</script>

<template>
  <div class="view">
    <ViewHeader
      title="LLM Provider Health"
      :subtitle="`${byProvider.length} provider · ${keys.length} key(s) total`"
    >
      <template #actions>
        <button class="btn ghost sm" :disabled="loading" @click="load">refresh</button>
      </template>
    </ViewHeader>

    <div class="scroll">
      <div v-if="!byProvider.length && loading" class="dim small">加载中…</div>
      <table class="table">
        <thead>
          <tr>
            <th>provider</th>
            <th style="width: 110px">status</th>
            <th style="width: 80px">keys</th>
            <th style="width: 80px">ok</th>
            <th style="width: 80px">failed</th>
            <th style="width: 80px">untested</th>
            <th style="width: 140px">last tested</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="p in byProvider" :key="p.provider">
            <td class="mono">{{ p.provider }}</td>
            <td><span :class="statusClass(p.worstStatus)">{{ p.worstStatus }}</span></td>
            <td>{{ p.total }}</td>
            <td>{{ p.ok }}</td>
            <td>{{ p.failed }}</td>
            <td>{{ p.untested }}</td>
            <td class="dim xs">{{ p.lastTestedAt ? timeAgo(p.lastTestedAt) : '—' }}</td>
            <td>
              <button
                v-for="k in keys.filter((x) => x.provider === p.provider)"
                :key="k.id"
                class="btn ghost xs"
                @click="test(k.id)"
              >test {{ k.displayName || k.id }}</button>
            </td>
          </tr>
          <tr v-if="!loading && byProvider.length === 0">
            <td colspan="8" class="empty-row">No API keys configured.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.view { display: flex; flex-direction: column; height: 100%; }
.scroll { flex: 1; overflow: auto; padding: var(--sp-3); }
.pill.status-ok { background: #10b981; color: white; }
.pill.status-failed { background: #ef4444; color: white; }
.pill.status-pending { background: var(--bg-2); color: var(--fg-2); }
.empty-row { text-align: center; color: var(--fg-3); padding: var(--sp-6) 0; font-style: italic; }
</style>
