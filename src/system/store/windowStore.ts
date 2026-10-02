import { create } from 'zustand';
import { getApp } from '../appRegistry';
import { clampToDisplay, workArea } from '../layout';
import { zoneRect } from '../snap';
import { uid } from '../ids';
import type { AppId, Display, Rect, SnapZone, VirtualDesktop, WindowState } from '../types';

export interface SnapPreview {
  zone: SnapZone;
  rect: Rect;
}

interface OpenOptions {
  args?: Record<string, unknown>;
  desktopId?: string;
  displayId?: string;
  rect?: Partial<Rect>;
}

export interface WindowGroup {
  id: string;
  /** Tab order. */
  ids: string[];
  activeId: string;
}

export interface WindowStore {
  windows: Record<string, WindowState>;
  /** Z-order, bottom → top. A window's stacking depth is its distance from the end. */
  order: string[];
  focusedId: string | null;
  desktops: VirtualDesktop[];
  activeDesktopId: string;
  /** -1 / +1 for the last desktop switch, so the transition knows which way to slide. */
  switchDirection: number;
  displays: Display[];
  snapPreview: SnapPreview | null;
  groups: Record<string, WindowGroup>;
  /** Window whose title bar a dragged window is hovering (drop → group as tabs). */
  groupTarget: string | null;

  openApp: (appId: AppId, opts?: OpenOptions) => string;
  closeWindow: (id: string) => void;
  focusWindow: (id: string) => void;
  minimizeWindow: (id: string) => void;
  restoreWindow: (id: string) => void;
  toggleMaximize: (id: string) => void;
  snapWindow: (id: string, zone: SnapZone) => void;
  /** Commit a free-form rect after a drag/resize; leaves maximized/snapped mode. */
  commitRect: (id: string, rect: Rect) => void;
  setTitle: (id: string, title: string) => void;
  setSnapPreview: (preview: SnapPreview | null) => void;
  cycleFocus: (dir: 1 | -1) => void;

  addDesktop: () => void;
  removeDesktop: (id: string) => void;
  switchDesktop: (id: string) => void;
  switchDesktopRelative: (dir: 1 | -1) => void;
  moveWindowToDesktop: (windowId: string, desktopId: string) => void;

  setDisplayBounds: (displayId: string, bounds: Rect) => void;

  setGroupTarget: (id: string | null) => void;
  /** Drop `sourceId` onto `targetId`'s frame as a new tab. */
  groupWindows: (sourceId: string, targetId: string) => void;
  /** Pull a tab out of its group into its own window at `rect`. */
  detachFromGroup: (id: string, rect?: Partial<Rect>) => void;
}

const PRIMARY = 'display-primary';

const initialDisplay: Display = {
  id: PRIMARY,
  name: 'Built-in Display',
  bounds: { x: 0, y: 0, w: window.innerWidth, h: window.innerHeight },
  primary: true,
  scale: window.devicePixelRatio || 1,
};

const firstDesktop: VirtualDesktop = { id: 'desk-1', name: 'Desktop 1' };

type GroupsSlice = Pick<WindowStore, 'groups'>;

/** A grouped window that is not the selected tab: mounted (keeps state) but not shown. */
export function isHiddenTab(s: GroupsSlice, w: WindowState) {
  return !!w.groupId && s.groups[w.groupId]?.activeId !== w.id;
}

/** Top-most visible window on a desktop, for focus hand-off. */
function topVisible(s: Pick<WindowStore, 'order' | 'windows'> & Partial<GroupsSlice>, desktopId: string, exclude?: string) {
  const groups = s.groups ?? {};
  for (let i = s.order.length - 1; i >= 0; i--) {
    const w = s.windows[s.order[i]];
    if (w && w.id !== exclude && w.desktopId === desktopId && !w.minimized && !isHiddenTab({ groups }, w)) return w.id;
  }
  return null;
}

/** Make `id` the visible tab of its group; it inherits the frame of the previous tab. */
function activateTab(s: Pick<WindowStore, 'windows' | 'groups'>, id: string) {
  const win = s.windows[id];
  const group = win?.groupId ? s.groups[win.groupId] : undefined;
  if (!group || group.activeId === id) return null;
  const prev = s.windows[group.activeId];
  return {
    windows: {
      ...s.windows,
      [id]: { ...win, rect: prev.rect, mode: prev.mode, snap: prev.snap, restoreRect: prev.restoreRect, minimized: false, desktopId: prev.desktopId },
    },
    groups: { ...s.groups, [group.id]: { ...group, activeId: id } },
  };
}

function displayOf(s: Pick<WindowStore, 'displays'>, id: string) {
  return s.displays.find((d) => d.id === id) ?? s.displays[0];
}

export const useWindowStore = create<WindowStore>()((set, get) => ({
  windows: {},
  order: [],
  focusedId: null,
  desktops: [firstDesktop],
  activeDesktopId: firstDesktop.id,
  switchDirection: 1,
  displays: [initialDisplay],
  snapPreview: null,
  groups: {},
  groupTarget: null,

  openApp(appId, opts = {}) {
    const s = get();
    const app = getApp(appId);

    if (app.singleton) {
      const existing = Object.values(s.windows).find((w) => w.appId === appId);
      if (existing) {
        if (existing.desktopId !== s.activeDesktopId) get().switchDesktop(existing.desktopId);
        get().focusWindow(existing.id);
        return existing.id;
      }
    }

    const desktopId = opts.desktopId ?? s.activeDesktopId;
    const display = displayOf(s, opts.displayId ?? PRIMARY);
    const wa = workArea(display);
    const w = Math.min(app.defaultSize.w, wa.w);
    const h = Math.min(app.defaultSize.h, wa.h);
    // Cascade new windows so they never land exactly on top of each other.
    const siblings = Object.values(s.windows).filter((x) => x.desktopId === desktopId).length;
    const offset = (siblings % 6) * 28;
    const rect = clampToDisplay(
      {
        // Keep the whole window inside the work area, even on narrow screens.
        x: Math.min(Math.max(wa.x, wa.x + (wa.w - w) / 2 + offset - 70), wa.x + wa.w - w),
        y: Math.min(wa.y + Math.max(0, (wa.h - h) / 2 - 30) + offset, wa.y + wa.h - h),
        w,
        h,
        ...opts.rect,
      },
      display,
    );

    const id = uid(appId);
    const win: WindowState = {
      id,
      appId,
      title: app.name,
      rect,
      mode: 'normal',
      minimized: false,
      desktopId,
      displayId: display.id,
      createdAt: Date.now(),
      args: opts.args,
    };
    set({ windows: { ...s.windows, [id]: win }, order: [...s.order, id], focusedId: id });
    return id;
  },

  closeWindow(id) {
    set((s) => {
      const win = s.windows[id];
      if (!win) return s;
      let { [id]: _removed, ...windows } = s.windows;
      let groups = s.groups;
      let order = s.order.filter((x) => x !== id);
      let focusedId = s.focusedId;

      const group = win.groupId ? s.groups[win.groupId] : undefined;
      if (group) {
        const ids = group.ids.filter((x) => x !== id);
        const idx = group.ids.indexOf(id);
        const nextActive = group.activeId === id ? ids[Math.min(idx, ids.length - 1)] : group.activeId;
        // The neighbouring tab takes over the frame.
        if (group.activeId === id) {
          windows = { ...windows, [nextActive]: { ...windows[nextActive], rect: win.rect, mode: win.mode, snap: win.snap, restoreRect: win.restoreRect, minimized: win.minimized } };
          order = [...order.filter((x) => x !== nextActive), nextActive];
          if (s.focusedId === id) focusedId = nextActive;
        }
        if (ids.length === 1) {
          const { [group.id]: _g, ...rest } = s.groups;
          groups = rest;
          windows = { ...windows, [ids[0]]: { ...windows[ids[0]], groupId: undefined } };
        } else {
          groups = { ...s.groups, [group.id]: { ...group, ids, activeId: nextActive } };
        }
      }
      if (focusedId === id) focusedId = topVisible({ order, windows, groups }, win.desktopId);
      return { windows, order, focusedId, groups };
    });
  },

  focusWindow(id) {
    set((s) => {
      const win = s.windows[id];
      if (!win) return s;
      const tab = activateTab(s, id);
      const windows = tab?.windows ?? s.windows;
      const alreadyTop = s.order[s.order.length - 1] === id;
      return {
        focusedId: id,
        order: alreadyTop ? s.order : [...s.order.filter((x) => x !== id), id],
        windows: windows[id].minimized ? { ...windows, [id]: { ...windows[id], minimized: false } } : windows,
        groups: tab?.groups ?? s.groups,
      };
    });
  },

  minimizeWindow(id) {
    set((s) => {
      const win = s.windows[id];
      if (!win) return s;
      const windows = { ...s.windows, [id]: { ...win, minimized: true } };
      return { windows, focusedId: s.focusedId === id ? topVisible({ order: s.order, windows, groups: s.groups }, win.desktopId) : s.focusedId };
    });
  },

  restoreWindow(id) {
    get().focusWindow(id);
  },

  toggleMaximize(id) {
    const win = get().windows[id];
    if (!win) return;
    if (win.mode === 'maximized') {
      const display = displayOf(get(), win.displayId);
      const rect = win.restoreRect ?? zoneRect('maximize', display);
      set((s) => ({
        windows: { ...s.windows, [id]: { ...win, mode: 'normal', snap: undefined, rect, restoreRect: undefined } },
      }));
    } else {
      get().snapWindow(id, 'maximize');
    }
  },

  snapWindow(id, zone) {
    set((s) => {
      const win = s.windows[id];
      if (!win) return s;
      const display = displayOf(s, win.displayId);
      return {
        windows: {
          ...s.windows,
          [id]: {
            ...win,
            mode: zone === 'maximize' ? 'maximized' : 'snapped',
            snap: zone,
            rect: zoneRect(zone, display),
            // Only remember a free-form rect; snapping snapped→snapped keeps the original.
            restoreRect: win.mode === 'normal' ? win.rect : win.restoreRect,
            minimized: false,
          },
        },
      };
    });
  },

  commitRect(id, rect) {
    set((s) => {
      const win = s.windows[id];
      if (!win) return s;
      const display = displayOf(s, win.displayId);
      return {
        windows: {
          ...s.windows,
          [id]: { ...win, rect: clampToDisplay(rect, display), mode: 'normal', snap: undefined, restoreRect: undefined },
        },
      };
    });
  },

  setTitle(id, title) {
    set((s) => (s.windows[id] ? { windows: { ...s.windows, [id]: { ...s.windows[id], title } } } : s));
  },

  setSnapPreview(snapPreview) {
    set({ snapPreview });
  },

  cycleFocus(dir) {
    const s = get();
    const candidates = s.order.filter((id) => s.windows[id].desktopId === s.activeDesktopId && !isHiddenTab(s, s.windows[id]));
    if (candidates.length < 2) return;
    // Cycle through the z-stack: +1 brings the bottom-most up, -1 sends the top to the back.
    if (dir === 1) {
      get().focusWindow(candidates[0]);
    } else {
      const top = candidates[candidates.length - 1];
      const order = [top, ...s.order.filter((x) => x !== top)];
      set({ order });
      const next = topVisible({ order, windows: s.windows, groups: s.groups }, s.activeDesktopId);
      if (next) get().focusWindow(next);
    }
  },

  addDesktop() {
    set((s) => {
      const n = s.desktops.length + 1;
      const desk = { id: uid('desk'), name: `Desktop ${n}` };
      return { desktops: [...s.desktops, desk], activeDesktopId: desk.id, switchDirection: 1, focusedId: null };
    });
  },

  removeDesktop(id) {
    set((s) => {
      if (s.desktops.length <= 1) return s;
      const idx = s.desktops.findIndex((d) => d.id === id);
      const desktops = s.desktops.filter((d) => d.id !== id);
      const fallback = desktops[Math.max(0, idx - 1)];
      // Windows on a removed desktop migrate to its neighbour rather than closing.
      const windows = Object.fromEntries(
        Object.entries(s.windows).map(([wid, w]) => [wid, w.desktopId === id ? { ...w, desktopId: fallback.id } : w]),
      );
      const activeDesktopId = s.activeDesktopId === id ? fallback.id : s.activeDesktopId;
      return { desktops, windows, activeDesktopId, switchDirection: -1 };
    });
  },

  switchDesktop(id) {
    set((s) => {
      if (id === s.activeDesktopId) return s;
      const from = s.desktops.findIndex((d) => d.id === s.activeDesktopId);
      const to = s.desktops.findIndex((d) => d.id === id);
      if (to < 0) return s;
      return {
        activeDesktopId: id,
        switchDirection: to > from ? 1 : -1,
        focusedId: topVisible(s, id),
      };
    });
  },

  switchDesktopRelative(dir) {
    const s = get();
    const idx = s.desktops.findIndex((d) => d.id === s.activeDesktopId);
    const next = s.desktops[idx + dir];
    if (next) get().switchDesktop(next.id);
  },

  moveWindowToDesktop(windowId, desktopId) {
    set((s) => {
      const win = s.windows[windowId];
      if (!win) return s;
      // A tab group travels together.
      const ids = win.groupId ? s.groups[win.groupId].ids : [windowId];
      const windows = { ...s.windows };
      for (const id of ids) windows[id] = { ...windows[id], desktopId };
      return {
        windows,
        focusedId: ids.includes(s.focusedId ?? '') ? topVisible({ order: s.order, windows, groups: s.groups }, s.activeDesktopId) : s.focusedId,
      };
    });
  },

  setGroupTarget(groupTarget) {
    if (get().groupTarget !== groupTarget) set({ groupTarget });
  },

  groupWindows(sourceId, targetId) {
    set((s) => {
      const source = s.windows[sourceId];
      const target = s.windows[targetId];
      if (!source || !target || sourceId === targetId) return s;
      let groups = { ...s.groups };
      let windows = { ...s.windows };

      // If the dragged window was itself grouped, it leaves that group first.
      if (source.groupId && groups[source.groupId]) {
        const old = groups[source.groupId];
        const rest = old.ids.filter((x) => x !== sourceId);
        if (rest.length === 1) {
          delete groups[old.id];
          windows[rest[0]] = { ...windows[rest[0]], groupId: undefined };
        } else groups[old.id] = { ...old, ids: rest, activeId: old.activeId === sourceId ? rest[0] : old.activeId };
      }

      const groupId = target.groupId ?? uid('group');
      const existing = groups[groupId];
      const ids = existing ? [...existing.ids, sourceId] : [targetId, sourceId];
      groups[groupId] = { id: groupId, ids, activeId: sourceId };
      windows[targetId] = { ...windows[targetId], groupId };
      windows[sourceId] = {
        ...source,
        groupId,
        rect: target.rect,
        mode: target.mode,
        snap: target.snap,
        restoreRect: target.restoreRect,
        desktopId: target.desktopId,
        displayId: target.displayId,
        minimized: false,
      };
      return { groups, windows, groupTarget: null, focusedId: sourceId, order: [...s.order.filter((x) => x !== sourceId), sourceId] };
    });
  },

  detachFromGroup(id, rect) {
    set((s) => {
      const win = s.windows[id];
      const group = win?.groupId ? s.groups[win.groupId] : undefined;
      if (!win || !group) return s;
      const ids = group.ids.filter((x) => x !== id);
      let groups = { ...s.groups };
      const windows = { ...s.windows };
      const base = win.mode === 'normal' ? win.rect : (win.restoreRect ?? win.rect);
      const display = displayOf(s, win.displayId);
      windows[id] = {
        ...win,
        groupId: undefined,
        mode: 'normal',
        snap: undefined,
        restoreRect: undefined,
        rect: clampToDisplay({ ...base, x: base.x + 36, y: base.y + 36, ...rect }, display),
      };
      if (group.activeId === id) {
        // Remaining tab takes the original frame.
        windows[ids[0]] = { ...windows[ids[0]], rect: win.rect, mode: win.mode, snap: win.snap, restoreRect: win.restoreRect };
      }
      if (ids.length === 1) {
        delete groups[group.id];
        windows[ids[0]] = { ...windows[ids[0]], groupId: undefined };
      } else {
        groups[group.id] = { ...group, ids, activeId: group.activeId === id ? ids[0] : group.activeId };
      }
      return { windows, groups, focusedId: id, order: [...s.order.filter((x) => x !== id), id] };
    });
  },

  setDisplayBounds(displayId, bounds) {
    set((s) => {
      const displays = s.displays.map((d) => (d.id === displayId ? { ...d, bounds } : d));
      const display = displays.find((d) => d.id === displayId)!;
      // Re-flow windows on this display: snapped/maximized follow their zone, others are clamped.
      const windows = Object.fromEntries(
        Object.entries(s.windows).map(([id, w]) => {
          if (w.displayId !== displayId) return [id, w];
          const rect = w.snap ? zoneRect(w.snap, display) : clampToDisplay(w.rect, display);
          return [id, { ...w, rect }];
        }),
      );
      return { displays, windows };
    });
  },
}));

/** Selector helpers kept here so components share memo-friendly selectors. */
export const selectFocusedApp = (s: WindowStore) => (s.focusedId ? s.windows[s.focusedId]?.appId ?? null : null);
