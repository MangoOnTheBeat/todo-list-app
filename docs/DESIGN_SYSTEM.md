# Aurora Design System

## Principles

1. **Light passes through.** Surfaces are glass first. Opacity rises only where legibility
   needs it, so app content sits on a denser layer than window chrome.
2. **Depth is information.** The focused window is closest: brighter, sharper and rimmed in
   accent light. Background windows recede in scale and opacity.
3. **One physics.** Every motion uses a spring from `system/motion.ts`.
4. **Calm by default.** Colour comes from the wallpaper and a single accent; chrome stays neutral.
5. **Assist, never surprise.** AI proposes and explains. Nothing changes without consent,
   and changes can be undone.

## Tokens (`src/styles/globals.css`)

| Token | Light | Dark | Purpose |
| --- | --- | --- | --- |
| `--accent-h` | 275 | 275 | Accent hue (user-selectable presets) |
| `--accent-l` | 0.56 | 0.70 | Accent lightness; darker in light mode so white text clears 4.5:1 |
| `--color-accent` | `oklch(L 0.16 H)` | ← | Accent text, focus rings, indicators, glows |
| `--color-accent-fill` | `oklch(0.52 0.17 H)` | ← | Filled buttons and chips that carry white text (≥ 4.5:1 in both themes) |
| `--glass-tint` | near-white | deep indigo | Material base colour |
| `--glass-alpha` | 58% | 52% | Material opacity (windows use `--glass-alpha-user`, set by Glass clarity) |
| `--glass-blur` / `--glass-sat` | 28px / 180% | ← | Backdrop blur and saturation boost |
| `--glass-border` / `--glass-highlight` | white 55% / 75% | white 12% / 16% | Hairline edge, top specular line |
| `--app-surface` | tint 62% | ← | Content layer inside windows |
| `--text-1/2/3` | ink ramp | paper ramp | Primary / secondary / tertiary text |
| `--shadow-window[-idle]` | layered | deeper | Contact + mid + ambient shadow stack |
| `--wall-1…4`, `--wall-base` | per wallpaper | per wallpaper | Aurora, Dusk, Lagoon, Bloom, Graphite |
| `--series-1/2` | `#2a78d6` / `#eb6834` | `#3987e5` / `#d95926` | Validated two-series chart colours |
| `--radius-window/panel/control` | 18 / 22 / 10 px | ← | Corner radii |

Colours are OKLCH, so changing the accent hue keeps perceived lightness constant. Theme is
`[data-theme]` on `<html>` (light, dark, or auto from the OS). `[data-transparency=reduced]`
swaps glass for solid surfaces.

## Materials

| Class | Use |
| --- | --- |
| `.glass` | Default frosted surface: tint, blur, saturation, hairline, specular edge |
| `.acrylic` | Denser glass (78%, 40px) for menus, tooltips, panels and HUDs |
| `.glass-sheen` | Diagonal reflection plus film grain via `::before` |
| `.glass-well` | Recessed region inside glass (inputs, groups, cards) |
| `.window-surface` | Dynamic alpha: focused > unfocused (−12%) > dragging (−20%), animated via `@property` |

## Motion

| Spring | Stiffness / damping | Use |
| --- | --- | --- |
| `window` | 420 / 36 | Snap, maximize, restore, Overview |
| `snappy` | 600 / 34 | Buttons, toggles, active pills (`layoutId`) |
| `panel` | 340 / 32 | Panels, popovers, page transitions |
| `gentle` | 170 / 26 | Desktop switching, lock screen |
| `elastic` | 460 / 15 | Dock bounce, HUDs, notifications landing |

Signature motions:

- **Lean**: a dragged window tilts up to 2.2° with horizontal velocity, then springs upright.
- **Genie minimize**: the window's transform origin moves onto its dock icon before it scales away.
- **Materialise**: windows open from 90% scale with a 10px blur. The blur is removed with
  `transitionEnd`, because a leftover filter would disable glass inside the window.
- **Depth switch**: the outgoing desktop slides out and shrinks to 90%.
- Under reduced motion, springs become instant and the wallpaper and visualiser stop.

## Typography

Geist for UI and Geist Mono for keys and figures (from Google Fonts, with system fallbacks).
13px chrome, 15px body, `tracking-tight` headings, uppercase 11px section labels with
0.1–0.16em tracking, and `tabular-nums` for anything that changes or lines up.

## Iconography

App tiles are 26%-radius squircles with a two-stop 145° gradient, a radial top highlight, a
1px inner specular line and a glow tinted by the gradient's end colour. Glyphs are Lucide
icons at 1.75 stroke, sized to half the tile, in white. File glyphs use one hue per file
kind; image files get generative thumbnails.

## Components (`components/ui`)

| Component | Notes |
| --- | --- |
| `AppKit` | `AppLayout` (sidebar + content, container-query collapse), `SidebarItem` (shared `layoutId` pill), `Toolbar`, `ToolButton`, `Segmented`, `SearchField`, `Toggle`, `EmptyState` |
| `GlassButton` | default / accent / danger tones with elastic press |
| `Slider` | Pill slider built on a native range input |
| `ToggleTile` | Quick Settings tile (`role="switch"`) |
| `ContextMenu` | Portal menu, viewport-clamped, arrow-key navigation |
| `SearchResults` | Grouped results with a top hit, used by Search and the Launcher |
| `charts` | `AreaChart` (one axis, 2px line, hover crosshair), `BarStrip`, `Sparkline` |
| `CoverArt`, `EqBars`, `MediaCard` | Media visuals and controls |

## Data visualisation

One y-axis per chart; a single series uses the accent colour and has no legend box. Two
series use the validated reference pair (`--series-1/2`, colour-blind and contrast checks
pass in both themes) with a legend that shows live values. Grid lines are hairline dashes;
the latest point is emphasised; text always uses text tokens. Status (temperature warning)
uses an icon and a label, never colour alone.

## Layout and responsive behaviour

See [RESPONSIVE.md](RESPONSIVE.md). In short: shell metrics live in `system/layout.ts`,
apps respond to their window's width through container queries, and displays narrower than
700px open windows maximized.

## Do / don't

- **Do** raise opacity, not blur, when glass sits over busy content.
- **Do** keep one accent; status colours are reserved and always come with a label.
- **Don't** put `filter` on an ancestor of glass at rest. It disables `backdrop-filter`.
- **Don't** animate layout properties for gestures. Use transforms through motion values.
