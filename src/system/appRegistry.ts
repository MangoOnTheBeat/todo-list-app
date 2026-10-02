import { lazy } from 'react';
import {
  Activity,
  CalendarDays,
  Clock,
  FolderOpen,
  Globe,
  ListChecks,
  Music,
  Orbit,
  Settings,
  ShoppingBag,
  Sparkles,
  StickyNote,
} from 'lucide-react';
import type { AppId, AppManifest } from './types';

// Apps are code-split: an app's bundle loads the first time a window for it opens.
const Welcome = lazy(() => import('@/apps/welcome/WelcomeApp'));
const Placeholder = lazy(() => import('@/apps/placeholder/PlaceholderApp'));
const FilesApp = lazy(() => import('@/apps/files/FilesApp'));
const NotesApp = lazy(() => import('@/apps/notes/NotesApp'));
const SettingsApp = lazy(() => import('@/apps/settings/SettingsApp'));
const CalendarApp = lazy(() => import('@/apps/calendar/CalendarApp'));
const ClockApp = lazy(() => import('@/apps/clock/ClockApp'));
const MonitorApp = lazy(() => import('@/apps/monitor/MonitorApp'));
const TasksApp = lazy(() => import('@/apps/tasks/TasksApp'));
const BrowserApp = lazy(() => import('@/apps/browser/BrowserApp'));
const StoreApp = lazy(() => import('@/apps/store/StoreApp'));
const MusicApp = lazy(() => import('@/apps/music/MusicApp'));

const manifests: AppManifest[] = [
  {
    id: 'welcome',
    name: 'Welcome',
    description: 'A tour of Aurora OS.',
    icon: Orbit,
    gradient: ['oklch(0.78 0.14 200)', 'oklch(0.6 0.22 290)'],
    defaultSize: { w: 860, h: 660 },
    minSize: { w: 420, h: 320 },
    singleton: true,
    pinned: true,
    phase: 1,
    component: Welcome,
  },
  {
    id: 'files',
    name: 'Files',
    description: 'Browse, tag and auto-organise your files.',
    icon: FolderOpen,
    gradient: ['oklch(0.82 0.14 230)', 'oklch(0.6 0.18 255)'],
    defaultSize: { w: 900, h: 580 },
    minSize: { w: 480, h: 320 },
    pinned: true,
    phase: 3,
    component: FilesApp,
  },
  {
    id: 'browser',
    name: 'Horizon',
    description: 'A calm, tab-grouped web browser.',
    icon: Globe,
    gradient: ['oklch(0.8 0.14 180)', 'oklch(0.58 0.16 220)'],
    defaultSize: { w: 1040, h: 680 },
    minSize: { w: 480, h: 320 },
    pinned: true,
    phase: 3,
    component: BrowserApp,
  },
  {
    id: 'assistant',
    name: 'Aurora AI',
    description: 'Your on-device desktop assistant.',
    icon: Sparkles,
    gradient: ['oklch(0.78 0.16 330)', 'oklch(0.58 0.22 285)'],
    defaultSize: { w: 520, h: 640 },
    minSize: { w: 380, h: 420 },
    singleton: true,
    pinned: true,
    phase: 4,
    component: Placeholder,
  },
  {
    id: 'calendar',
    name: 'Calendar',
    description: 'Your schedule, with focus time protected.',
    icon: CalendarDays,
    gradient: ['oklch(0.8 0.15 25)', 'oklch(0.62 0.21 15)'],
    defaultSize: { w: 900, h: 620 },
    minSize: { w: 480, h: 380 },
    singleton: true,
    pinned: true,
    phase: 3,
    component: CalendarApp,
  },
  {
    id: 'notes',
    name: 'Notes',
    description: 'Quick glass notes.',
    icon: StickyNote,
    gradient: ['oklch(0.9 0.14 95)', 'oklch(0.75 0.16 65)'],
    defaultSize: { w: 620, h: 480 },
    minSize: { w: 320, h: 260 },
    pinned: true,
    phase: 3,
    component: NotesApp,
  },
  {
    id: 'music',
    name: 'Resonance',
    description: 'Music and media.',
    icon: Music,
    gradient: ['oklch(0.76 0.18 350)', 'oklch(0.56 0.22 15)'],
    defaultSize: { w: 820, h: 560 },
    minSize: { w: 420, h: 360 },
    singleton: true,
    pinned: true,
    phase: 2,
    component: MusicApp,
  },
  {
    id: 'clock',
    name: 'Clock',
    description: 'World clock, timers and focus sessions.',
    icon: Clock,
    gradient: ['oklch(0.45 0.03 270)', 'oklch(0.25 0.03 270)'],
    defaultSize: { w: 640, h: 480 },
    minSize: { w: 360, h: 320 },
    singleton: true,
    phase: 3,
    component: ClockApp,
  },
  {
    id: 'monitor',
    name: 'System Monitor',
    description: 'Live CPU, memory, GPU and network.',
    icon: Activity,
    gradient: ['oklch(0.82 0.16 155)', 'oklch(0.58 0.15 175)'],
    defaultSize: { w: 820, h: 560 },
    minSize: { w: 480, h: 360 },
    singleton: true,
    phase: 3,
    component: MonitorApp,
  },
  {
    id: 'tasks',
    name: 'Task Manager',
    description: 'Processes, windows and startup apps.',
    icon: ListChecks,
    gradient: ['oklch(0.78 0.12 250)', 'oklch(0.5 0.12 265)'],
    defaultSize: { w: 820, h: 560 },
    minSize: { w: 480, h: 360 },
    singleton: true,
    phase: 3,
    component: TasksApp,
  },
  {
    id: 'store',
    name: 'Atrium',
    description: 'Discover apps and extensions.',
    icon: ShoppingBag,
    gradient: ['oklch(0.8 0.14 280)', 'oklch(0.55 0.2 300)'],
    defaultSize: { w: 1000, h: 660 },
    minSize: { w: 520, h: 400 },
    singleton: true,
    pinned: true,
    phase: 3,
    component: StoreApp,
  },
  {
    id: 'settings',
    name: 'Settings',
    description: 'Appearance, displays, AI and privacy.',
    icon: Settings,
    gradient: ['oklch(0.7 0.02 270)', 'oklch(0.45 0.03 270)'],
    defaultSize: { w: 880, h: 600 },
    minSize: { w: 520, h: 400 },
    singleton: true,
    pinned: true,
    phase: 3,
    component: SettingsApp,
  },
];

const byId = new Map(manifests.map((m) => [m.id, m]));

export function getApp(id: AppId): AppManifest {
  const app = byId.get(id);
  if (!app) throw new Error(`Unknown app: ${id}`);
  return app;
}

export const allApps = manifests;
export const pinnedApps = manifests.filter((m) => m.pinned);
