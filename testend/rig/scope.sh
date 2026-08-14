#!/usr/bin/env bash
# Shared shell guard for acceptance rig roots. Source this file before any filesystem action.

require_rig_home() {
  if [[ -z "${RIG_HOME:-}" ]]; then
    echo "rig: REFUSED — RIG_HOME must be explicitly exported; refusing the personal default ledger" >&2
    return 2
  fi
  if [[ "$RIG_HOME" != /* ]]; then
    echo "rig: REFUSED — RIG_HOME must be an absolute path, got '$RIG_HOME'" >&2
    return 2
  fi
}
