# Aurora OS

A concept desktop operating system for the late 2020s, built in the browser: glass materials,
spatial depth, spring physics, and an on-device assistant woven through the shell.

**No build tools?** Open [`aurora-os-preview.html`](aurora-os-preview.html) in any browser.
It is the whole OS in one file.

```bash
npm install
npm run dev           # http://localhost:5173
npm test              # Vitest: AI intents and parsers
npm run build         # typecheck + production bundle
npm run build:single  # one self-contained HTML file (dist-single/)
```

Stack: React 19, TypeScript, Tailwind CSS v4, Framer Motion, Zustand, Vite.

## What's inside

- **Window system**: drag, resize, edge and corner snapping, snap layouts, tear-off,
  tab groups, minimize into the dock, live Overview, virtual desktops, a simulated second
  display, session restore.
- **Shell**: launcher, universal search, notification center with banners, quick settings,
  media controls, magnifying dock with window previews, lock screen.
- **Apps**: Files, Notes, Settings, Calendar, Clock, System Monitor, Task Manager, Horizon
  (browser), Atrium (app store), Resonance (music) and Aurora AI.
- **Aurora AI**: natural-language commands (including chained steps), natural-language
  search, context-aware suggestions, smart notification triage and digest, smart file
  organisation with undo, productivity recommendations, and a voice command framework.

## Documentation

| Deliverable | Where |
| --- | --- |
| Project architecture & folder structure | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| Component breakdown | [docs/ARCHITECTURE.md#component-breakdown](docs/ARCHITECTURE.md#component-breakdown) |
| State management plan | [docs/ARCHITECTURE.md#state-management-plan](docs/ARCHITECTURE.md#state-management-plan) |
| Accessibility | [docs/ACCESSIBILITY.md](docs/ACCESSIBILITY.md) |
| Performance strategy | [docs/PERFORMANCE.md](docs/PERFORMANCE.md) |
| Responsive behaviour | [docs/RESPONSIVE.md](docs/RESPONSIVE.md) |
| Design system | [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) |

## Build phases

| Phase | Subsystem | Status |
| --- | --- | --- |
| 1 | Foundation: tokens, glass materials, window manager, dock, top bar, virtual desktops | ✅ |
| 2 | Shell surfaces: launcher, search, notifications, quick settings, media, Overview, tabs, lock screen | ✅ |
| 3 | Core apps | ✅ |
| 4 | Aurora AI | ✅ |
| 5 | Hardening: accessibility audit, multi-display, session restore, responsive and touch, docs | ✅ |

An original design concept, not affiliated with any operating system vendor.
