# Responsive behaviour

Aurora adapts at three levels: the **display**, the **shell**, and each **app window**.

## Display level

| Condition | Behaviour |
| --- | --- |
| Width < 700px (`COMPACT_W`) | New windows open maximized (with a free-form size remembered for later) |
| Viewport resize | Snapped and maximized windows re-flow to their zone; free windows are clamped so at least 96px stays grabbable |
| Simulated second display (width ≥ 900px) | 60/40 split with a bezel; each display has its own work area, snapping and maximize |

## Shell level

| Element | Wide | Narrow (< 640px) |
| --- | --- | --- |
| Top bar | Focused app name, Overview button, date and time, volume icon | Icons only; time without date; no Overview button |
| Ask Aurora | Orb + label | Orb only (< 768px) |
| Dock | 46px icons, magnifying to 70px | Whole dock scaled to 76% below 560px |
| Panels | Fixed widths (360–640px) | `min(…, 100vw − 20–32px)` so they never overflow |
| Launcher grid | 6 columns | 4 columns |

The page never scrolls horizontally at 390px, which was checked in an automated phone run.

## App level: container queries

Every app root is an `@container`, so layouts respond to the **window's** width. A Files
window tiled into a third of a large screen behaves like Files on a tablet.

| App | Breakpoints |
| --- | --- |
| `AppLayout` | Sidebar shows at ≥ 560px; Settings switches to a chip row below that |
| Files | Search field ≥ 640px; list columns: modified ≥ 520, size ≥ 640, kind ≥ 760 |
| Calendar | 3-day view below 620px, otherwise week; "Find focus time" ≥ 620px |
| Clock | World clock stacks below 620px; city grid has 2 columns from 420px |
| System Monitor | Stat tiles 2 → 4 columns at 640px; charts 1 → 2 columns at 720px |
| Task Manager | GPU ≥ 640, Energy ≥ 720, PID ≥ 800 |
| Atrium | Result grid 1 → 2 → 3 columns at 620 / 960px |
| Horizon | Speed-dial grid 3 → 6 columns at 560px |

## Input

- Pointer events throughout, so mouse, pen and touch share one code path.
- Coarse pointers get 22–28px resize targets that straddle the window edge.
- Title bars and resize handles use `touch-action: none`; lists and content scroll normally.
- Notifications can be swiped away.
