# EDGE-329 · Computer Use input limitation (not a product judgment)

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-035526`
- The real App entered the first shortcut's `Press a new chord…` state and
  displayed the modifier requirement.
- `Super_L+k`, `cmd+k`, `ctrl+k`, `Control_L+k`, and `Super_L+K` were each
  delivered through the available Computer Use bridge but the App continued to
  report `A chord must include a modifier (⌘/Ctrl…)`. The bridge therefore did
  not provide trustworthy modifier flags for this macOS Flutter field.
- The App was closed before `rig-check`; the check correctly failed rather than
  treating the closed window as valid evidence. `rig-down` finalized the session
  and left no process or listener residue.

No EDGE-329 ledger cell was written. This is an observer/input-path limitation;
it is not evidence that the product shortcut recorder passes or fails. A future
physical-input-capable run must verify that the post-recording focus is returned
before this edge can be judged.
