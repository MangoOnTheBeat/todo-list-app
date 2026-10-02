# Aurora OS — Architecture

## Folder structure

```
src/
├─ main.tsx, App.tsx          Entry; App wires global hooks + MotionConfig
├─ system/                    The "kernel" of the shell — no JSX besides lazy app imports
│  ├─ types.ts                WindowState, Display, VirtualDesktop, AppManifest, SnapZone…
│  ├─ appRegistry.ts          App manifests (icon, gradient, sizes, lazy component)
│  ├─ layout.ts               Shell metrics, work-area + clamping math
│  ├─ snap.ts                 Zone → rect resolution, edge detection, layout templates
│  ├─ motion.ts               Spring vocabulary shared by every animation
│  ├─ dockRegistry.ts         Dock icon geometry for minimize targets
│  └─ store/
│     ├─ windowStore.ts       Window manager state + actions (Zustand)
│     └─ systemStore.ts       User preferences, persisted to localStorage
├─ components/
│  ├─ shell/                  Desktop, Wallpaper, WindowLayers, TopBar, Dock, DesktopHUD
│  ├─ window/                 Window, TitleBar, ResizeHandles, SnapPreview, SnapLayoutsFlyout
│  └─ ui/                     Primitives: AppIcon, GlassButton (more in Phase 2)
├─ apps/                      One folder per app; default export receives AppProps
├─ hooks/                     useThemeSync, useDisplaySync, useGlobalShortcuts, useClock
├─ services/
│  ├─ commands.ts             System verbs (tile, lock, toggle DND…) shared by search, panels, AI
│  ├─ search/                 Provider-based search: fuzzy ranking, top hit, grouped sections
│  ├─ vfs.ts                  In-memory file tree (search, recents; Files app in Phase 3)
│  └─ notificationSimulator.ts  Seeds a backlog and drips live notifications
├─ styles/globals.css         Tokens, materials, wallpaper keyframes
└─ assets/
```

`system/` never imports from `components/`; components read the system through stores and
pure functions. That keeps the window manager testable without a DOM and lets any surface
(dock, launcher, AI assistant) drive windows through the same actions.

## Component breakdown (Phase 1)

| Component | Responsibility |
| --- | --- |
| `Desktop` | Z-ordered scene: wallpaper → window layers → chrome → overlays |
| `Wallpaper` | Pure-CSS animated aurora; compositor-only, paused under reduced motion |
| `WindowLayers` | One layer per virtual desktop; slides + recedes on switch, `inert` when hidden |
| `Window` | Geometry in motion values; drag, resize, tear-off, snap, minimize-to-dock, focus |
| `TitleBar` | Drag handle, double-click maximize, window controls, snap-layouts trigger |
| `SnapLayoutsFlyout` | Template grid (halves, 2/3+1/3, thirds, quarters) |
| `SnapPreview` | Accent glass ghost showing the landing zone while dragging |
| `Dock` | Magnifying dock, running/focused indicators, launch bounce, minimize targets |
| `TopBar` | Focused app, virtual-desktop switcher, status cluster + clock |
| `DesktopHUD` | Transient desktop-switch indicator + live-region announcement |

## State management plan

**Zustand**, split by rate-of-change and persistence needs:

| Store | Holds | Persisted |
| --- | --- | --- |
| `windowStore` | windows, z-order, focus, desktops, displays, snap preview | Phase 5 (session restore) |
| `systemStore` | theme, accent, transparency, motion, glass clarity, dock prefs | ✅ localStorage |
| `shellStore` | open panel, overview, lock | — |
| `notificationStore` | notifications, banner queue, Do Not Disturb | — |
| `mediaStore` | simulated media session: track, position, likes | — |
| `aiStore` (P4) | conversation, suggestions, context snapshot | partial |

Rules:

1. **High-frequency state never goes through React.** Drag/resize write to Framer Motion
   values; only the final rect is committed. Dock magnification is a motion-value pipeline.
2. **One write path for geometry.** Every rect change (drag commit, snap, maximize, display
   resize) goes through the store; `Window` springs its motion values to whatever the store says.
3. **Fine-grained selectors.** Components subscribe to the slice they render
   (`s.windows[id]`, `s.focusedId === id`); `Window` is memoised on `id/depth/zIndex`.
4. **Actions are the API.** Dock, keyboard shortcuts and (later) the AI assistant all call
   the same `openApp / focusWindow / snapWindow…` — the assistant gets window control for free.

## Window system

- **Coordinates** are global virtual-screen pixels. Each window has a `displayId`; work areas,
  snap zones and maximize resolve against that display.
- **Modes**: `normal | maximized | snapped` plus an orthogonal `minimized` flag, so restoring
  from the dock returns a window to its tiled position. `restoreRect` remembers the free-form
  rect; snapped→snapped keeps the original.
- **Tear-off**: dragging a tiled window morphs it back to `restoreRect` size while keeping the
  grab point proportionally under the cursor.
- **Focus & depth**: `order` is the z-stack. Depth (distance from top) drives a subtle
  scale-down and lower glass opacity; the focused window gets an accent rim + glow.
- **Virtual desktops**: windows carry `desktopId`; layers stay mounted so app state survives
  switching. Removing a desktop migrates its windows to the neighbour.
- **Minimize**: the window's `transform-origin` is moved onto its dock icon, then it scales
  and blurs into it — a genie-like effect at transform-only cost.

## Multi-monitor architecture

`Display { id, bounds, primary, scale }` lives in the window store. Today `useDisplaySync`
maps the viewport to the primary display. A host with several screens (e.g. the Window
Management API `getScreenDetails()`, or an Electron/Tauri shell) would publish one `Display`
per screen through `setDisplayBounds`; `displayAt()` routes drag snapping to the display
under the pointer, and `setDisplayBounds` re-flows tiled windows when a display changes.
Phase 5 adds a simulated dual-display mode to exercise this path in the browser.

## Keyboard shortcuts

Chosen to avoid browser-reserved combos. See `useGlobalShortcuts.ts` (`SHORTCUTS`) — also
shown in the Welcome app.

## Performance strategy (Phase 1 measures)

- Geometry via transforms (`x/y`), springs on motion values: no layout thrash, no re-renders mid-gesture.
- Apps are `React.lazy` chunks; first paint ships only the shell (Welcome is ~2.5 kB gz).
- Wallpaper is CSS keyframes on `transform` only.
- `filter: blur()` is used only during open/minimize transitions and removed via
  `transitionEnd`, because a lingering filter on an ancestor disables child `backdrop-filter`.
- Hidden desktops are `visibility: hidden` so their glass isn't composited.

## Accessibility (Phase 1 measures)

- Windows are `role="dialog"` (non-modal) labelled by their title; minimized/hidden content is `inert`.
- Every control has an accessible name; dock items expose running/focused state via `aria-pressed`.
- Focus moves into a window when it is activated; global shortcuts skip editable targets.
- Desktop switches are announced via a polite live region.
- Honors `prefers-reduced-motion` and `prefers-reduced-transparency` (and in-app overrides);
  reduced motion swaps springs for instant transitions and freezes the wallpaper.

## Phase 2 — shell surfaces

| Surface | Entry points | Notes |
| --- | --- | --- |
| Launcher | Aurora mark, `Ctrl Alt A` | Rises from the dock; typing switches the grid to search results |
| Search | Magnifier, `Ctrl K` | Combobox with grouped results and a single top hit; inline calculator |
| Notification center | Clock, `Ctrl Alt N` | Month view, notifications grouped by app, DND toggle, swipe to dismiss |
| Banners | — | Max three, auto-retire after 6 s (paused on hover); DND holds all but time-sensitive |
| Quick settings | Status icons, `Ctrl Alt Q` | Toggles, brightness/volume, now-playing card |
| Overview | Grid button, `Ctrl Alt ↑` | The real windows animate into a grid, so previews are live; desktop strip on top |
| Dock previews | Hover a running app | Mini frames at each window's aspect ratio; click to jump, × to close |
| Tab groups | Drag a window onto another's title bar | Tabs share one frame; drag a tab downward to detach |
| Lock screen | Launcher/Quick settings, `Ctrl Alt L` | Clock, unread count, media controls; any key or click unlocks |

**One panel at a time.** `shellStore.panel` is a single value, so opening one surface closes
the other; a transparent catcher behind the panel closes it on outside click, and Escape is
handled centrally.

**Overview without duplication.** Rather than rendering thumbnails, `useOverviewSlots`
computes a grid (choosing the column count that maximises average scale) and each `Window`
animates its inner layer to `{dx, dy, scale}`. Previews are therefore live, and apps don't
mount twice.

**Tab groups keep app state.** Every member stays mounted; non-selected tabs are
`visibility: hidden` and `inert`. Switching tabs hands the frame geometry to the new tab.
Grouping only targets the top-most window under the pointer.

**Search providers** (`services/search/providers.ts`) each return scored results; the engine
merges them, promotes the best as the top hit and caps each section at five. The AI phase
adds a natural-language provider without changing the UI.
