# EDGE-317 · 选区跨块缝隙

## Formal session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-235053`
- Workspace: `ws_89eb5841c48ec008`
- Fixture document: `doc_763d224956e3eecd`
- App binary: clean macOS debug build from `mise exec -- flutter build macos --debug -t lib/main.dart`
- Recording: `screen.mov`, `424.336667s`; the recorder covered the Anselm window only and `rig-check` passed before and after the interaction.

## Product path

The fixture was created through the local API with this exact Markdown:

```markdown
第一段落，用于跨块选择。

## 第二段落，选区要穿过块间留白。

第三段落，终点落在这里。
```

Computer Use opened the document from Library, moved to another Library resource, reopened the fixture, and then selected from the first paragraph across all three blocks using a real focused click followed by three `Shift+Down` key events. The reopened document showed the same title, path, 41-character content summary, three rendered blocks, and the normal selection toolbar.

## Visual result

- Before the fix, the real App showed white gaps between selected blocks. That red observation is retained in the earlier exploratory sessions and was not counted as green.
- The fixed clean binary defers selection-layer rebuilding when selection changes during Flutter persistent frame callbacks, coalesces the rebuild to the next frame, and paints the independent gap overlay as `Color.alphaBlend(selection, surface)` so the overlay is visibly identical to the selected text surface.
- Final selected frame: `evidence/edge317-cross-block-selection-reopened-selected.jpeg`.
- The final frame shows continuous blue selection through the paragraph padding, equal-height bands, a natural final-line width, and a stable toolbar. Pixel sampling of the inter-block bridge in the clean final frame gave the stable blended color approximately `(0.804, 0.875, 0.969)`, matching the selected text fill; there is no white inter-block gap.
- The same cross-node geometry is locked by `frontend/test/core/editor/an_editor_selection_test.dart`: a three-node selection produces two positive-height bridge rectangles.

## Reopen and truth checks

After leaving and reopening the document, the real App rendered all three blocks without stale or missing content. `GET /api/v1/documents/doc_763d224956e3eecd` returned `200`; its `data.content` matched the fixture byte-for-byte, with `sizeBytes=124`, path `/EDGE-317 正式多块选区夹具`, and no unexpected mutation.

## Five-channel close

- Channel 1: macOS recorder attributed to the Anselm window, no external overlay.
- Channel 2: backend PID `14409` owned port `:8742`; backend journal contained no application `WARN`, `ERROR`, `panic`, or `fatal` line.
- Channel 3: `ssetap` PID `14466` connected to messages, notifications, and entities; the session recorded the expected `notifications` durable `seq=16` document-created signal and no fabricated chat/entity mutation.
- Channel 4: direct Flutter App PID `14921`; frontend journal contained no Flutter, Dart, RenderFlex, RenderBox, Unhandled, or Exception application error. The remaining IMK and Caps Lock lines are macOS host noise.
- Channel 5: `llmtap` PID `14384`; managed gateway proof challenge, install, and models requests all returned `200`. This deterministic Library path did not require a chat completion, so none is claimed.
- `rig-check` passed with all five channels physically observing; `rig-down` finalized the session and left no managed process running.

## Verdict input

This evidence supports level 2 only: the real App behavior is true through the five-channel cross-check. It does not claim latency, beauty, or discovery levels beyond the focused visual observation and the applicable C1 geometry law.
