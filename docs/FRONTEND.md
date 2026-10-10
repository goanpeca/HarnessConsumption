# SwiftUI conventions

- **One scene:** `MenuBarExtra` with `.window` style; the label is plain monospaced-digit text.
- **Fixed size.** The panel is 360pt wide with 400pt panes; both panes scroll. Never let content
  change the window's height after it opens: macOS keeps the bottom edge fixed on resize, so a
  shorter panel detaches from the menu bar and a taller one slides under it.
  `PanelPinning.swift` re-pins the top edge as a backstop.
- **Tabs** (Usage | Settings) as in the meeting-alarm app; the panel always opens on Usage.
- **State:** `UsageStore` is `@MainActor @Observable`; views read it and call `update(_:)` /
  `setRefreshInterval(_:)`. Views never touch credentials or the network.
- **Filenames:** anything that imports SwiftUI or AppKit is `*View.swift`, `App.swift` or
  `PanelPinning.swift` (enforced by `check-architecture.py`).
- **Verify without screenshots:** `AgentConsumption --dump` prints what the views would show.
