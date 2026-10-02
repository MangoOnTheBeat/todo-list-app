# Aurora OS

A concept desktop operating system UI for the late 2020s: glass materials, spatial depth,
spring physics and an AI layer woven through the shell. Built with React 19, TypeScript,
Tailwind CSS v4, Framer Motion and Zustand.

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # typecheck + production bundle
npm run build:single  # everything in one self-contained HTML file (dist-single/)
```

No build tools? Open [`aurora-os-preview.html`](aurora-os-preview.html) in any browser.

## Build phases

| Phase | Subsystem | Status |
| --- | --- | --- |
| 1 | Foundation: design tokens, glass materials, window manager, dock, top bar, virtual desktops | ✅ |
| 2 | Shell surfaces: launcher, search, notification center, quick settings, media controls, overview & window previews, tab grouping, lock screen | ✅ |
| 3 | Core apps: Files, Settings, Calendar, Clock, System Monitor, Task Manager, Browser, App Store, Notes | ⏳ |
| 4 | AI layer: assistant, natural-language search, context actions, smart notifications & file organisation, voice | ⏳ |
| 5 | Hardening: accessibility audit, performance, responsive/touch, multi-display simulation, final docs | ⏳ |

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md).
