# Aurora OS — Architecture

Aurora OS is a desktop-environment concept that runs entirely in the browser. It has no
backend: every "system" (files, calendar, telemetry, media, AI) is a local, deterministic
model behind the same interfaces a real platform would provide.

## Folder structure

```
src/
├─ main.tsx, App.tsx            Entry. App wires global hooks and MotionConfig.
├─ system/                      The core shell. Stores, models and pure geometry; no UI.
│  ├─ types.ts                  WindowState, Display, VirtualDesktop, AppManifest, SnapZone…
│  ├─ appRegistry.ts            App manifests: icon, gradient, sizes, singleton, lazy component
│  ├─ layout.ts                 Shell metrics, per-display work areas, clamping, display lookup
│  ├─ snap.ts                   Zone → rect, edge/corner detection, snap-layout templates
│  ├─ overview.ts               Exposé grid solver for Overview
│  ├─ motion.ts                 Spring vocabulary shared by every animation
│  ├─ dockRegistry.ts           Dock icon geometry (minimize targets)
│  └─ store/                    Zustand stores (see "State management")
├─ services/                    Domain logic used by several surfaces
│  ├─ commands.ts               System verbs (tile, lock, toggle DND…) shared by UI, search, AI
│  ├─ search/                   Provider-based universal search + fuzzy ranking
│  ├─ ai/                       Aurora AI: intents, parsers, context, organiser, triage, voice
│  ├─ vfs.ts                    Virtual file-system model, seed data and helpers
│  ├─ metrics.ts                Simulated hardware telemetry (ref-counted sampler)
│  └─ notificationSimulator.ts  Seeds a backlog and drips live notifications
├─ components/
│  ├─ shell/                    Desktop, TopBar, Dock, panels, Overview, lock screen, displays…
│  ├─ window/                   Window, TitleBar (+tabs), ResizeHandles, snap preview & flyout
│  ├─ assistant/                Assistant chat/panel, voice HUD, context nudge, orb
│  └─ ui/                       AppKit, AppIcon, charts, context menu, slider, media card…
├─ apps/                        One folder per app; default export receives AppProps
├─ hooks/                       Theme, display, clock, shortcuts, media clock, search controller
├─ styles/globals.css           Tokens, materials, wallpaper variants, touch rules
├─ assets/                      Logo
└─ __tests__/                   Vitest suites (AI intents and parsers)
```

**Dependency direction.** `system/` never imports from `components/` or `apps/`.
`services/` may use `system/` stores. Components read state through stores and act through
store actions or `services/commands`. The window manager can therefore be tested without a
DOM, and any surface (dock, keyboard, search, AI) drives windows through the same actions.

## Component breakdown

### Shell (`components/shell`)

| Component | Responsibility |
| --- | --- |
| `Desktop` | Scene graph. Windows span the virtual screen; system chrome sits in a box the size of the primary display |
| `Wallpaper` | Animated aurora built from CSS keyframes that only move transforms. Five variants via `[data-wallpaper]` |
| `WindowLayers` | One layer per virtual desktop: slides and recedes on switch, and is `inert` when hidden. Computes Overview slots |
| `TopBar` | Launcher, focused app, search, Overview, desktop switcher, Ask Aurora, status icons, clock |
| `Dock` / `DockPreviews` | Distance-based magnification, running indicators, launch bounce, live window previews |
| `ShellPanels` | Hosts one panel at a time and a click-away catcher, and returns focus to the opener |
| `Launcher` / `SearchOverlay` | App grid with recent files / universal search (combobox) |
| `NotificationCenter` / `Toasts` / `NotificationCard` | Calendar header, AI digest, grouped and bundled notifications, swipeable banners |
| `QuickSettings` | Connectivity toggles, modes, brightness and volume, media card |
| `Overview` | Dimmed backdrop, desktop strip and captions. The windows themselves are the previews |
| `LockScreen` | Glass lock screen with clock, unread count and media controls |
| `SecondaryDisplays` | Bezel and status strip for each extra display |
| `DesktopHUD` / `Announcer` | Desktop-switch indicator; screen-reader live narration |
| `DisplayFilters` | Brightness and Night Light overlays |

### Window system (`components/window`)

| Component | Responsibility |
| --- | --- |
| `Window` | Geometry in motion values; drag, resize, tear-off, snapping, merging into tabs, minimize into the dock, Overview transform |
| `TitleBar` | Drag handle, double-click to maximize, controls, tab strip, drop target for grouping |
| `SnapLayoutsFlyout` / `SnapPreview` | Layout templates; accent-coloured preview of where the window will land |
| `ResizeHandles` | Eight edges, enlarged for coarse pointers |

### Apps (`apps/`)

| App | Highlights |
| --- | --- |
| Files | Places, tags, trash; grid/list; multi-select; F2 rename; drag-to-move; Quick Look; **AI Organize** panel with undo |
| Notes | Locally persisted notes, pinning, search; opens documents from Files; **Summarize** |
| Settings | Appearance, wallpapers, displays (incl. simulated second display), desktop & dock, notifications, Aurora AI, accessibility, keyboard, about |
| Calendar | Week view (3-day on narrow windows) and month view, quick create, event details, **Find focus time** |
| Clock | World clock with analog dials, timer, stopwatch with laps, focus sessions that toggle DND |
| System Monitor | Stat tiles, CPU/memory/network area charts with hover, per-core bars, top processes |
| Task Manager | Sortable process table grouped by kind, End task (closes the window), startup apps |
| Horizon | Tabs, history, address bar with search fallback, bookmarks, reader view, built-in pages |
| Atrium | Featured carousel, categories, search, install progress, updates, detail pages |
| Resonance | Library, likes, generative cover art, canvas visualiser, transport and volume |
| Aurora AI | The assistant as a window (shares its conversation with the panel) |

### Aurora AI (`services/ai`, `components/assistant`)

```
typed text ─┐                 ┌─ intents.ts ── interpret() ─▶ Intent.match → params
voice ──────┼─▶ respond() ─▶  │               execute()   ─▶ Intent.run   → AiReply { text, cards, actions }
search ─────┘                 └─ clauses()  splits "open X and snap it left" into steps
                                    │
             uses ─▶ when.ts (dates) · fileQuery.ts (NL file filters) · context.ts ("this")
                     organizer.ts · productivity.ts · text.ts (summaries) · commands.ts · stores
```

- **Intent engine** (`intents.ts`): about 30 intents in priority order, covering apps, windows,
  desktops, settings, calendar queries and creation, file search and organisation, notes,
  timers, media, system insight, summaries, tips and help. Every action uses existing store
  actions, so the UI reflects it immediately, and most replies offer **Undo**. The engine is
  deterministic; a language model could replace `interpret()` without touching any intent.
- **Context** (`context.ts`): the top-most non-assistant window. It resolves "this" and
  produces suggestion chips such as "Summarize this page" or "Organize Downloads".
- **Natural-language search**: an `ai` search provider turns a sentence into one
  "do it" result, or answers structured file questions inline.
- **Smart notifications** (`notifications.ts`): triage re-ranks urgency, bundles low-value
  items (no banner) and writes the digest shown in the notification center.
- **Smart file organisation** (`organizer.ts`): rule-based planner. Each group has a reason
  and a confidence, nothing moves until you confirm, and changes can be undone.
- **Productivity** (`productivity.ts`): free focus blocks and context-driven recommendations.
- **Voice** (`voice.ts`): a source-agnostic controller. It uses the Web Speech API when the
  browser has it, and a simulated source that "speaks" sample phrases everywhere else.
  Both feed the same `respond()` pipeline.

## State management plan

Zustand stores, split by how often they change and whether they persist:

| Store | Holds | Persisted |
| --- | --- | --- |
| `windowStore` | windows, z-order, focus, desktops, tab groups, displays, snap/group targets | session (windows, desktops, groups) |
| `systemStore` | theme, accent, wallpaper, glass, motion, device toggles, AI prefs, dual display | ✅ |
| `shellStore` | open panel, Overview, lock, search seed | — |
| `notificationStore` | notifications, banner queue, DND (with triage on `post`) | — |
| `fileStore` | virtual file tree (flat map with parent ids) | — |
| `calendarStore` | events (seeded relative to the current week) | — |
| `notesStore` | notes | ✅ |
| `mediaStore` | simulated media session | — |
| `aiStore` | conversation, thinking flag, voice state and transcript | — |
| `metrics` (service) | telemetry history and processes; the sampler runs only while consumed | — |

Rules:

1. **High-frequency values never go through React.** Drag and resize write to Framer Motion
   values, dock magnification is a motion-value pipeline, and the visualiser draws on canvas.
2. **One write path for geometry.** Every rect change goes through the store; `Window`
   springs to whatever the store says.
3. **Fine-grained selectors.** Components subscribe to the slice they render; `Window` is
   memoised on `id / depth / zIndex / overview`.
4. **Actions are the API.** Dock, keyboard, search and AI call the same store actions and
   `commands`, so behaviour is identical whichever way a request arrives.
5. **Persistence is opt-in and fails softly.** `persist` swallows storage errors, so private
   windows and sandboxed previews still run.

## Window system

- **Coordinates** are global virtual-screen pixels. Each window has a `displayId`. Work areas,
  snap zones and maximize are resolved against that display.
- **Modes** are `normal | maximized | snapped`, plus an independent `minimized` flag.
  `restoreRect` remembers the free-form rect.
- **Tear-off**: dragging a tiled window returns it to its `restoreRect` size, keeping the
  grab point under the cursor.
- **Tabs**: drop a window onto another window's title bar (only the top-most window under
  the pointer counts). Every tab stays mounted; hidden tabs are `visibility: hidden` and
  `inert`. Dragging a tab downward detaches it.
- **Overview**: `overviewLayout` picks the grid that maximises average scale, and each
  window animates its inner layer to `{dx, dy, scale}`. The previews are live, and no app
  mounts twice.
- **Virtual desktops**: windows carry `desktopId`; layers stay mounted. Removing a desktop
  moves its windows to the neighbouring one.

## Multi-monitor

`Display { id, bounds, primary, scale }` lives in the window store. `useDisplaySync`
publishes the display set:

- one display (the viewport) by default;
- with **Settings → Displays → Simulate a second display**, a 60/40 split with a bezel.

`setDisplays` reassigns windows whose display disappeared and re-flows the rest.
`displayAt()` routes snapping to the display under the pointer, and `commitRect()` moves a
window to the display that holds its centre. Secondary displays have their own work area
(no dock, a slim status strip). A real host would call `setDisplays` from the Window
Management API (`getScreenDetails()`) or a native shell.

## Testing

`npm test` runs Vitest on jsdom: recognition for 36 phrasings, execution against real
stores (settings, chained window commands, calendar creation, DND), title extraction, and
the date, duration and file-query parsers.
