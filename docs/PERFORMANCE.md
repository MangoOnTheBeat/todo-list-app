# Performance

## Budget and results

Production build (`npm run build`), gzip sizes:

| Chunk | gzip | Loaded |
| --- | --- | --- |
| `index` (React, shell, stores, search) | 105 KB | at startup |
| `motion` (Framer Motion) | 40 KB | at startup |
| CSS (Tailwind, tokens, materials) | 12 KB | at startup |
| `intents` (Aurora AI engine + parsers) | 12 KB | at startup (separate chunk for caching; search depends on it) |
| Each app | 2–8 KB (Files is largest at 7.7 KB) | first time its window opens |

The standalone preview (`npm run build:single`) inlines every chunk into one HTML file:
about 770 KB (about 230 KB gzipped). It trades lazy loading for a single file that opens
anywhere.

## Strategy

**Rendering**

- Window geometry is in motion values applied as transforms (`x`, `y`), with width and
  height springing only on snap or maximize. Dragging and resizing cause **no React
  re-renders**; one store commit happens on pointer-up.
- Dock magnification derives each icon's size from one pointer motion value through a
  spring. Icons are scaled with a transform from a fixed-size tile, so there is no
  re-layout per frame.
- `Window` is memoised and subscribes only to its own slice of state.
- The wallpaper moves four blurred fields with CSS keyframes on `transform`, which run on
  the compositor. They pause under reduced motion.

**Glass cost control**

- `backdrop-filter` is the most expensive effect. Hidden desktops are `visibility: hidden`,
  so their glass isn't composited, and hidden tabs and minimized windows are not hit-tested.
- Filters are used only during open, minimize and close transitions and removed with
  `transitionEnd`. A lingering filter would also stop child glass from blurring.
- Reduce transparency removes blur everywhere.

**Work only when needed**

- Apps are `React.lazy` chunks.
- The telemetry sampler is reference-counted: it runs only while System Monitor or Task
  Manager is mounted.
- The media clock ticks only while playing. The visualiser's `requestAnimationFrame` loop
  stops shortly after pause.
- Search runs through `useDeferredValue`, so typing stays responsive. Providers are
  synchronous and local (no index needed for a few hundred items).
- Resize handling is coalesced with `requestAnimationFrame`.

**State**

- Stores are split by how often they change, so opening a panel doesn't re-render windows.
- Persistence is limited to small slices: preferences, notes and session layout.

## How to measure

- React Profiler: dragging a window should show no commits until release.
- Chrome Performance panel: watch for layout events during drag (there should be none) and
  for compositor time from stacked `backdrop-filter`s with many windows open.
- `npm run build` prints chunk sizes; keep the startup total (about 170 KB gzip today) under 200 KB.

## Future work

- Virtualise very long lists (Files, Task Manager) if datasets grow past a few hundred rows.
- Offload search ranking and the intent engine to a Web Worker if a model-backed
  interpreter is introduced.
