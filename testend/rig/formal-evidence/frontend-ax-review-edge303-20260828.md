classification: tooling-ax-tree
status: reviewed

# EDGE-303 frontend AXTree review

Session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-035907` contains only the known Flutter macOS accessibility bridge race:

`Failed to update ui::AXTree, error: 99/163 will not be in the tree and is not the new root`

The messages appeared while Computer Use refreshed the accessibility tree during rapid transcript/sidebar changes. The same session's screenshot recorder remained attached to the Anselm window, the App process stayed alive, and the visual state was independently inspected. There were no `Unhandled exception`, `FlutterError`, `Dart Error/Exception`, `RenderFlex`, or panic lines. This is classified as observer/engine churn, not an application runtime failure; the rig's exact-pattern allowlist is unchanged.
