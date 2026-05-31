# Pass 1 Analysis

## Priority: lazy

### Per-scenario win rate (key metric: Activated correct)

| Scenario | V1-6-groups | V2-11-groups | V3-18-groups | Winner |
|---|---|---|---|---|
| lazy-agent-edit | 0% | 0% | 0% | tie:V1-6-groups,V2-11-groups,V3-18-groups |
| lazy-cron-debug | 0% | 40% | 0% | V2-11-groups |
| lazy-dead-letter | 10% | 0% | 100% | V3-18-groups |
| lazy-handler-try | 0% | 10% | 0% | V2-11-groups |
| lazy-polling-create | 0% | 0% | 0% | tie:V1-6-groups,V2-11-groups,V3-18-groups |
| lazy-workflow-deploy | 0% | 0% | 0% | tie:V1-6-groups,V2-11-groups,V3-18-groups |

### Overall (averaged across scenarios)

| Variant | Avg first-tool % | Avg activated % | Avg args-match % | Avg cost ¥ |
|---|---|---|---|---|
| V1-6-groups | 1.7% | 1.7% | 0.0% | 0.00033 |
| V2-11-groups | 13.3% | 8.3% | 0.0% | 0.00029 |
| V3-18-groups | 30.0% | 16.7% | 0.0% | 0.00036 |

**Pass 1 winner**: `V3-18-groups` (16.7% on activated_correct_rate)

## Priority: tool_desc

### Per-scenario win rate (key metric: First tool correct)

| Scenario | V1-terse | V2-verbose-examples | V3-antipattern | V4-few-shot | Winner |
|---|---|---|---|---|---|
| tooldesc-easy-add | 100% | 100% | 100% | 100% | tie:V1-terse,V2-verbose-examples,V3-antipattern,V4-few-shot |
| tooldesc-easy-time | 100% | 100% | 100% | 90% | tie:V1-terse,V2-verbose-examples,V3-antipattern |
| tooldesc-hard-polling-rss-cursor | 70% | 100% | 70% | 100% | tie:V2-verbose-examples,V4-few-shot |
| tooldesc-medium-polling-gmail | 60% | 90% | 80% | 90% | tie:V2-verbose-examples,V4-few-shot |
| tooldesc-medium-random | 100% | 100% | 100% | 100% | tie:V1-terse,V2-verbose-examples,V3-antipattern,V4-few-shot |
| tooldesc-trap-webhook | 10% | 20% | 60% | 30% | V3-antipattern |

### Overall (averaged across scenarios)

| Variant | Avg first-tool % | Avg activated % | Avg args-match % | Avg cost ¥ |
|---|---|---|---|---|
| V1-terse | 73.3% | 0.0% | 71.7% | 0.00121 |
| V2-verbose-examples | 85.0% | 0.0% | 81.7% | 0.00127 |
| V3-antipattern | 85.0% | 0.0% | 81.7% | 0.00151 |
| V4-few-shot | 85.0% | 0.0% | 81.7% | 0.00122 |

**Pass 1 winner**: `V2-verbose-examples` (81.7% on args_match_rate)

## Priority: schema

### Per-scenario win rate (key metric: First tool correct)

| Scenario | V1-free-json | V2-enum | V3-anyof-strict | Winner |
|---|---|---|---|---|
| schema-edit-bad-op | 0% | 0% | 0% | tie:V1-free-json,V2-enum,V3-anyof-strict |
| schema-edit-code | 0% | 0% | 0% | tie:V1-free-json,V2-enum,V3-anyof-strict |
| schema-edit-description-only | 0% | 30% | 0% | V2-enum |
| schema-edit-kind-to-polling | 0% | 0% | 0% | tie:V1-free-json,V2-enum,V3-anyof-strict |
| schema-edit-multi-ops | 0% | 0% | 0% | tie:V1-free-json,V2-enum,V3-anyof-strict |
| schema-edit-rename | 0% | 90% | 90% | tie:V2-enum,V3-anyof-strict |

### Overall (averaged across scenarios)

| Variant | Avg first-tool % | Avg activated % | Avg args-match % | Avg cost ¥ |
|---|---|---|---|---|
| V1-free-json | 0.0% | 0.0% | 81.7% | 0.00031 |
| V2-enum | 20.0% | 0.0% | 78.3% | 0.00038 |
| V3-anyof-strict | 15.0% | 0.0% | 83.3% | 0.00040 |

**Pass 1 winner**: `V3-anyof-strict` (83.3% on args_match_rate)

## Priority: chain

### Per-scenario win rate (key metric: First tool correct)

| Scenario | V1-raw | V2-inline-plan | V3-system-plan | Winner |
|---|---|---|---|---|
| chain-cel-null-safety | 0% | 0% | 0% | tie:V1-raw,V2-inline-plan,V3-system-plan |
| chain-edit-workflow-5ops | 0% | 0% | 0% | tie:V1-raw,V2-inline-plan,V3-system-plan |
| chain-multi-step-debug | 30% | 10% | 80% | V3-system-plan |
| chain-polling-cursor | 60% | 100% | 50% | V2-inline-plan |

### Overall (averaged across scenarios)

| Variant | Avg first-tool % | Avg activated % | Avg args-match % | Avg cost ¥ |
|---|---|---|---|---|
| V1-raw | 22.5% | 0.0% | 62.5% | 0.00104 |
| V2-inline-plan | 27.5% | 0.0% | 58.3% | 0.00116 |
| V3-system-plan | 32.5% | 0.0% | 55.0% | 0.00103 |

**Pass 1 winner**: `V3-system-plan` (32.5% on first_tool_correct_rate)

---

# Pass 2 Recommendations

## tool_desc
- **tooldesc-easy-add**: V1-terse (100%) vs V2-verbose-examples (100%) — too close, deep-dive both with N=30
- **tooldesc-easy-time**: V1-terse (100%) vs V2-verbose-examples (100%) — too close, deep-dive both with N=30
- **tooldesc-hard-polling-rss-cursor**: V2-verbose-examples (100%) vs V4-few-shot (100%) — too close, deep-dive both with N=30
- **tooldesc-medium-polling-gmail**: V2-verbose-examples (90%) vs V4-few-shot (90%) — too close, deep-dive both with N=30
- **tooldesc-medium-random**: V1-terse (100%) vs V2-verbose-examples (100%) — too close, deep-dive both with N=30
- tooldesc-trap-webhook: V3-antipattern clear winner (60% vs 30%) — confirm with N=30

## schema
- **schema-edit-bad-op**: V1-free-json (0%) vs V2-enum (0%) — too close, deep-dive both with N=30
- **schema-edit-code**: V1-free-json (0%) vs V2-enum (0%) — too close, deep-dive both with N=30
- schema-edit-description-only: V2-enum clear winner (30% vs 0%) — confirm with N=30
- **schema-edit-kind-to-polling**: V1-free-json (0%) vs V2-enum (0%) — too close, deep-dive both with N=30
- **schema-edit-multi-ops**: V1-free-json (0%) vs V2-enum (0%) — too close, deep-dive both with N=30
- **schema-edit-rename**: V2-enum (90%) vs V3-anyof-strict (90%) — too close, deep-dive both with N=30

## lazy
- **lazy-agent-edit**: V1-6-groups (0%) vs V2-11-groups (0%) — too close, deep-dive both with N=30
- lazy-cron-debug: V2-11-groups clear winner (40% vs 0%) — confirm with N=30
- lazy-dead-letter: V3-18-groups clear winner (100% vs 10%) — confirm with N=30
- lazy-handler-try: V2-11-groups leads (10% vs 0%) — N=30 to confirm gap
- **lazy-polling-create**: V1-6-groups (0%) vs V2-11-groups (0%) — too close, deep-dive both with N=30
- **lazy-workflow-deploy**: V1-6-groups (0%) vs V2-11-groups (0%) — too close, deep-dive both with N=30

## chain
- **chain-cel-null-safety**: V1-raw (0%) vs V2-inline-plan (0%) — too close, deep-dive both with N=30
- **chain-edit-workflow-5ops**: V1-raw (0%) vs V2-inline-plan (0%) — too close, deep-dive both with N=30
- chain-multi-step-debug: V3-system-plan clear winner (80% vs 30%) — confirm with N=30
- chain-polling-cursor: V2-inline-plan clear winner (100% vs 60%) — confirm with N=30

