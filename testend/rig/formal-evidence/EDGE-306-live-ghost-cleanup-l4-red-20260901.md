# EDGE-306 导演器清 Live 幽灵：L4 红场与根因

## Red session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-164829`
- data: `/private/tmp/anselm-data-edge306-l4-real-20260901-r5`
- perturbation: `/api/v1/messages/stream` was dropped after 60s and the next connection received HTTP 410
- frame samples: `review/mid/61.png`, `review/mid/75.png`, `review/last-03.png`

## Observed product failure

The real App executed a long chain that created eight documents. Before the gap, `tool_call` close
frames had arrived. The 410 resync REST snapshot therefore contained an assistant still in progress
with completed tool calls but without the tool results, while the tool-result close frames were in the
lost interval. The fresh stream later delivered only the final text close and assistant root close.

After the run completed, the center transcript still showed `Creating document...` rows and the
Activity side-stage still showed eight `Live` rows. The backend database subsequently contained all
completed tool results, so this was a stale frontend projection, not an active backend execution.

## Five-channel diagnosis

- frames: final text was visible while all eight execution rows remained Live.
- backend: no application `WARN`, `ERROR`, `panic`, or `FATAL`; durable tool results were completed.
- SSE: the independent witness recorded tool-call closes before the gap, then final text/root closes after reconnect.
- frontend: the side-stage and transcript retained the stale Live projection.
- LLM wire: the real gateway completion and tool chain completed normally.

This red observation is retained as the stop-and-fix trigger. It is not a pass and is not overwritten by
the fixed evidence.
