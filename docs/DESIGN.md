# Visual design

Native macOS look: system fonts, system accent color, SF Symbols. Secondary text uses `.secondary`;
the settings summary uses `.tertiary`. No custom palette, so light and dark mode and the user's
accent just work.

## Usage levels

A window's level comes from `UsageWindow.level(pace:)` in `ConsumptionKit`:

| Level | Color | Symbol | Meaning |
|---|---|---|---|
| good | system green | `checkmark.circle.fill` | At or under the even pace |
| watch | system orange | `exclamationmark.triangle.fill` | Up to 10 points over pace |
| critical | system red | `exclamationmark.octagon.fill` | More than 10 points over, or under 10% left |

Windows with no reset date fall back to percent left (orange under 25%, red under 10%).

## Accessibility

- Colors are the system accent colors (`controlAccentGreenColor`, `controlAccentOrangeColor`,
  `controlAccentRedColor`), the same swatches System Settings > Appearance > Color shows. They are
  dynamic (red darkens in light mode). AppKit doesn't expose them in the public Swift API, so they
  are looked up by selector, falling back to `NSColor.systemGreen`, `.systemOrange`, `.systemRed`.
  Contrast against a light background can be under 3:1, so the symbol, status word and pace tick
  carry the meaning.
- Color is never the only signal: every row shows the level's symbol and a status word ("On pace",
  "Ahead of pace", "Well over pace", "Almost out"), and the bar has a tick at the even-pace position.
- Status text stays in the primary or secondary text color; color is only on the bar and symbol.
- Each usage row is one VoiceOver element with a spoken summary (percent left, status, reset, per-day
  share). The bar itself is hidden from VoiceOver.
- The menu bar readout stays plain, template-colored text.
