# Accessibility

## Audit

axe-core 4.x was run against the running app in light and dark themes, in four states:
the Welcome window; Files, Settings, Calendar and Task Manager open together; the Aurora AI
panel; and Quick Settings. After fixes, **all 8 runs report zero violations**, including
colour contrast.

Fixed during the audit:

| Issue | Fix |
| --- | --- |
| Files grid used `grid`/`gridcell` without rows | Icon view is a `listbox` of `option`s; list view is a real `<table>` |
| Icon-only segmented options had no name | `Segmented` accepts `ariaLabel` per option |
| Several windows produced duplicate `complementary` landmarks | App sidebars are plain containers |
| Scrollable shortcut list wasn't keyboard-reachable | Focusable, with a label |
| `role="dialog"` on `<aside>` | Assistant panel uses a `div` |
| White text on the bright dark-mode accent (2.8:1) | New `--color-accent-fill` step (L 0.52) for every filled control that carries text or icons |

## Structure and semantics

- Each window is a non-modal `role="dialog"` labelled by its title (or the active tab).
  Minimized windows, hidden tabs and inactive desktops are `inert` and `aria-hidden`.
- System panels are labelled dialogs. Search and the Launcher are combobox + listbox
  pairs with `aria-activedescendant`.
- Tabs use `tablist`/`tab`. Settings toggles are `switch`es. Theme, accent and wallpaper
  pickers are `radiogroup`s. Sortable table headers expose `aria-sort`.
- Charts are `role="img"` with a text summary (current value and peak). Process details are
  also available as a table in Task Manager.

## Keyboard

- Every control is reachable and has a visible accent focus ring (`:focus-visible`).
- System shortcuts avoid browser-reserved combinations and are listed in Welcome and
  Settings → Keyboard: Search `Ctrl K`, Aurora AI `Ctrl J`, voice `Ctrl Alt V`, Launcher
  `Ctrl Alt A`, Overview `Ctrl Alt ↑`, Notifications `Ctrl Alt N`, Quick settings `Ctrl Alt Q`,
  Lock `Ctrl Alt L`, desktops `Ctrl Alt ←/→`, snapping `Ctrl Shift ←/→/↑/↓`, cycle windows
  `` Alt ` ``, close `Ctrl Shift X`.
- Window shortcuts are ignored while typing in inputs.
- Focus moves into a window when it is activated; closing a panel returns focus to the
  control that opened it; Escape closes the open panel, Overview, menus and popovers.
- In-app: Files (arrow keys, Enter, F2, Delete, Space for Quick Look, Ctrl+A), Horizon
  (Ctrl+T, Ctrl+L, Ctrl+Shift+W), context menus (arrow keys and Enter).

## Announcements

A polite live region (`Announcer`) narrates window events: opened, closed, minimized,
snapped or maximized, moved to another desktop or display. Desktop switches and assistant
replies are announced through their own live regions.

## Preferences

- Follows `prefers-reduced-motion`, `prefers-reduced-transparency` and `prefers-color-scheme`.
  In-app overrides are in Settings → Accessibility and Appearance.
- Reduce motion: springs become instant transitions, and the wallpaper, visualiser and
  typing effect stop.
- Reduce transparency: glass becomes 94% opaque with no blur.
- Status is never colour alone: time-sensitive notifications carry a text label, the
  temperature warning has an icon and text, and the dock shows focus with indicator width
  as well as colour.
- Touch: resize targets grow to 22–28px on coarse pointers, and title bars use
  `touch-action: none` so dragging doesn't scroll the page.

## Known gaps

- Windows can be moved and resized with the keyboard only through snapping, not by
  arbitrary amounts.
- Voice input depends on the browser's speech recognition. Where it's unavailable, sample
  phrases show the flow, but there is no on-device speech engine.
- Contrast over the live wallpaper depends on the wallpaper. The defaults were checked;
  user-tuned glass clarity at the extremes can reduce it.
