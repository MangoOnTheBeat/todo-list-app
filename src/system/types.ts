import type { ComponentType, LazyExoticComponent } from 'react';
import type { LucideIcon } from 'lucide-react';

export type AppId =
  | 'welcome'
  | 'files'
  | 'settings'
  | 'calendar'
  | 'clock'
  | 'monitor'
  | 'tasks'
  | 'browser'
  | 'store'
  | 'assistant'
  | 'music'
  | 'notes';

export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Size {
  w: number;
  h: number;
}

/** Named regions a window can be snapped into. Resolved to a Rect against a display's work area. */
export type SnapZone =
  | 'maximize'
  | 'left'
  | 'right'
  | 'top-left'
  | 'top-right'
  | 'bottom-left'
  | 'bottom-right'
  | 'left-third'
  | 'center-third'
  | 'right-third'
  | 'left-two-thirds'
  | 'right-two-thirds';

export type WindowMode = 'normal' | 'maximized' | 'snapped';

export interface WindowState {
  id: string;
  appId: AppId;
  title: string;
  /** Global (virtual-screen) coordinates. */
  rect: Rect;
  /** Size/position to return to when leaving maximized/snapped. */
  restoreRect?: Rect;
  mode: WindowMode;
  snap?: SnapZone;
  minimized: boolean;
  desktopId: string;
  displayId: string;
  /** Windows sharing a groupId render as tabs of one frame (Phase 2). */
  groupId?: string;
  createdAt: number;
  /** Arbitrary launch arguments passed to the app (e.g. a path for Files). */
  args?: Record<string, unknown>;
}

export interface VirtualDesktop {
  id: string;
  name: string;
}

/**
 * A physical (or simulated) monitor. Every window belongs to one display; work areas,
 * snap zones and maximize are computed per display. In the browser there is normally one
 * display (the viewport), but the model supports N — see docs/ARCHITECTURE.md.
 */
export interface Display {
  id: string;
  name: string;
  bounds: Rect;
  primary: boolean;
  scale: number;
}

export interface AppProps {
  windowId: string;
  args?: Record<string, unknown>;
}

export interface AppManifest {
  id: AppId;
  name: string;
  description: string;
  icon: LucideIcon;
  /** Two-stop gradient used for the app tile. */
  gradient: [string, string];
  defaultSize: Size;
  minSize: Size;
  /** Only one instance may exist; launching again focuses it. */
  singleton?: boolean;
  pinned?: boolean;
  /** Build phase in which the real implementation lands (for placeholders). */
  phase: number;
  component: LazyExoticComponent<ComponentType<AppProps>>;
}
