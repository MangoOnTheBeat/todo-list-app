# Aurora Design System (Phase 1 draft)

## Principles

1. **Light passes through.** Surfaces are glass first; opacity rises only where legibility needs it.
2. **Depth is information.** What's focused is closest: brighter, sharper, rimmed in accent.
3. **One physics.** Every motion uses a spring from `system/motion.ts`.
4. **Calm by default.** Colour comes from the wallpaper and a single accent; chrome stays neutral.

## Tokens (`styles/globals.css`)

| Token | Purpose |
| --- | --- |
| `--accent-h` | Accent hue (OKLCH). Accent = `oklch(0.7 0.16 h)` |
| `--glass-tint` / `--glass-alpha` | Material base colour and opacity |
| `--glass-blur` / `--glass-sat` | Backdrop blur radius and saturation boost |
| `--glass-border` / `--glass-highlight` | Hairline edge and top specular line |
| `--text-1/2/3` | Primary / secondary / tertiary text |
| `--shadow-window`, `--shadow-window-idle` | Layered (contact + mid + ambient) shadows |
| `--wall-1…4`, `--wall-base` | Wallpaper colour fields per theme |
| `--radius-window/panel/control` | 18 / 22 / 10 px |

Colours are OKLCH so accent hue changes keep perceived lightness constant across presets.

## Materials

| Class | Use |
| --- | --- |
| `.glass` | Default frosted surface: tint, blur, saturation, hairline, specular edge |
| `.acrylic` | Denser glass for menus, tooltips, HUDs |
| `.glass-sheen` | Adds diagonal reflection + film grain via `::before` |
| `.glass-well` | Recessed region inside glass (inputs, groups) |
| `.window-surface` | Window material with dynamic alpha: focused > unfocused > dragging |

## Motion

| Spring | Stiffness / damping | Use |
| --- | --- | --- |
| `window` | 420 / 36 | Snap, maximize, restore |
| `snappy` | 600 / 34 | Buttons, toggles, pills |
| `panel` | 340 / 32 | Panels and popovers |
| `gentle` | 170 / 26 | Desktop switching |
| `elastic` | 460 / 15 | Dock bounce, HUD, playful moments |

## Iconography

App tiles are 26%-radius squircles with a two-stop 145° gradient, a radial top highlight,
a 1px inner specular line and a glow tinted by the gradient's end stop. Glyphs are Lucide at
1.75 stroke, 50% of tile size, white.

## Typography

Geist (UI) and Geist Mono (keys, figures). 13px for chrome, 15px body, tight tracking on
headings, `tabular-nums` for anything that ticks.

*Full component specs, light/dark examples and do/don't guidance land in Phase 5.*
