import {
  Calculator,
  Contrast,
  Grid2x2,
  Layers,
  LayoutGrid,
  Lock,
  Minimize2,
  Moon,
  MoonStar,
  Palette,
  Pause,
  Plus,
  SkipForward,
  Sparkles,
  Target,
  Wind,
  BellOff,
  FileText,
  FileImage,
  FileAudio,
  FileVideo,
  FileCode,
  FileArchive,
  Folder,
  Sheet,
  Presentation,
  type LucideIcon,
} from 'lucide-react';
import { allApps, getApp } from '@/system/appRegistry';
import { ACCENT_PRESETS, useSystemStore } from '@/system/store/systemStore';
import { isHiddenTab, useWindowStore } from '@/system/store/windowStore';
import { commands } from '../commands';
import { allFiles, recentFiles } from '@/system/store/fileStore';
import { appForFile, relativeTime, type FileKind } from '../vfs';
import { bestScore } from './fuzzy';
import type { SearchProvider, SearchResult } from './types';

const open = (appId: Parameters<ReturnType<typeof useWindowStore.getState>['openApp']>[0], args?: Record<string, unknown>) =>
  useWindowStore.getState().openApp(appId, { args });

export const fileIcon: Record<FileKind, LucideIcon> = {
  folder: Folder,
  document: FileText,
  pdf: FileText,
  image: FileImage,
  audio: FileAudio,
  video: FileVideo,
  code: FileCode,
  archive: FileArchive,
  spreadsheet: Sheet,
  presentation: Presentation,
};

const appsProvider: SearchProvider = {
  id: 'app',
  label: 'Apps',
  search: (q) =>
    allApps
      .map((a) => ({
        id: `app:${a.id}`,
        kind: 'app' as const,
        title: a.name,
        subtitle: a.description,
        appId: a.id,
        // Small boost so an app beats a same-named file.
        score: bestScore(q, a.name, a.id) * 1.15 + bestScore(q, a.description) * 0.3,
        run: () => open(a.id),
      }))
      .filter((r) => r.score > 0),
};

const windowsProvider: SearchProvider = {
  id: 'window',
  label: 'Open windows',
  search: (q) => {
    const s = useWindowStore.getState();
    return Object.values(s.windows)
      .map((w) => {
        const desk = s.desktops.find((d) => d.id === w.desktopId)?.name;
        return {
          id: `win:${w.id}`,
          kind: 'window' as const,
          title: w.title,
          subtitle: `${getApp(w.appId).name} · ${desk}${w.minimized ? ' · minimised' : ''}${isHiddenTab(s, w) ? ' · tab' : ''}`,
          appId: w.appId,
          score: bestScore(q, w.title, getApp(w.appId).name) * 0.9,
          run: () => {
            const st = useWindowStore.getState();
            if (w.desktopId !== st.activeDesktopId) st.switchDesktop(w.desktopId);
            st.focusWindow(w.id);
          },
        };
      })
      .filter((r) => r.score > 0);
  },
};

interface ActionDef {
  title: string;
  keywords: string;
  icon: LucideIcon;
  run: () => void;
}

const actions: ActionDef[] = [
  { title: 'Show overview', keywords: 'expose mission all windows previews', icon: LayoutGrid, run: commands.overview },
  { title: 'Tile windows', keywords: 'arrange layout split organise organize', icon: Grid2x2, run: commands.tileWindows },
  { title: 'Minimize all windows', keywords: 'show desktop hide clear', icon: Minimize2, run: commands.minimizeAll },
  { title: 'New desktop', keywords: 'virtual workspace space add', icon: Plus, run: commands.newDesktop },
  { title: 'Toggle dark mode', keywords: 'theme light appearance night', icon: Moon, run: commands.toggleDarkMode },
  { title: 'Toggle Do Not Disturb', keywords: 'dnd silence mute notifications quiet', icon: BellOff, run: commands.toggleDnd },
  { title: 'Toggle Focus mode', keywords: 'concentrate deep work', icon: Target, run: commands.toggleFocusMode },
  { title: 'Toggle Night Light', keywords: 'warm blue light eyes', icon: MoonStar, run: commands.toggleNightLight },
  { title: 'Play / pause music', keywords: 'media resume stop song', icon: Pause, run: commands.playPause },
  { title: 'Next track', keywords: 'skip song media', icon: SkipForward, run: commands.nextTrack },
  { title: 'Lock screen', keywords: 'sleep away security', icon: Lock, run: commands.lock },
  { title: 'Ask Aurora AI', keywords: 'assistant help question chat', icon: Sparkles, run: () => open('assistant') },
];

const actionsProvider: SearchProvider = {
  id: 'action',
  label: 'Actions',
  search: (q) =>
    actions
      .map((a) => ({
        id: `act:${a.title}`,
        kind: 'action' as const,
        title: a.title,
        icon: a.icon,
        score: Math.max(bestScore(q, a.title), bestScore(q, a.keywords) * 0.7),
        run: a.run,
      }))
      .filter((r) => r.score > 0),
  suggest: () =>
    actions.slice(0, 4).map((a) => ({ id: `act:${a.title}`, kind: 'action' as const, title: a.title, icon: a.icon, score: 0, run: a.run })),
};

const settingsProvider: SearchProvider = {
  id: 'setting',
  label: 'Settings',
  search: (q) => {
    const sys = useSystemStore.getState();
    const toggles: SearchResult[] = [
      { id: 'set:motion', kind: 'setting', title: `Reduce motion: ${sys.reduceMotion ? 'On' : 'Off'}`, icon: Wind, score: bestScore(q, 'reduce motion animation accessibility'), run: () => sys.set('reduceMotion', !sys.reduceMotion) },
      { id: 'set:transp', kind: 'setting', title: `Reduce transparency: ${sys.reduceTransparency ? 'On' : 'Off'}`, icon: Contrast, score: bestScore(q, 'reduce transparency glass blur accessibility'), run: () => sys.set('reduceTransparency', !sys.reduceTransparency) },
      { id: 'set:mag', kind: 'setting', title: `Dock magnification: ${sys.dockMagnification ? 'On' : 'Off'}`, icon: Layers, score: bestScore(q, 'dock magnification zoom icons'), run: () => sys.set('dockMagnification', !sys.dockMagnification) },
    ];
    const accents: SearchResult[] = ACCENT_PRESETS.map((p) => ({
      id: `set:accent:${p.name}`,
      kind: 'setting',
      title: `Accent colour: ${p.name}`,
      icon: Palette,
      score: Math.max(bestScore(q, `accent ${p.name}`), bestScore(q, 'colour color theme') * 0.6),
      run: () => sys.setAccentHue(p.hue),
    }));
    return [...toggles, ...accents].filter((r) => r.score > 0);
  },
};

const filesProvider: SearchProvider = {
  id: 'file',
  label: 'Files',
  search: (q) =>
    allFiles()
      .map((f) => ({
        id: `file:${f.id}`,
        kind: 'file' as const,
        title: f.name,
        subtitle: `${(f.path ?? '').replace(/\/[^/]+$/, '')} · ${relativeTime(f.modified)}`,
        icon: fileIcon[f.kind],
        score: Math.max(bestScore(q, f.name), ...(f.tags ?? []).map((t) => bestScore(q, t) * 0.6)) * 0.85,
        run: () => open(f.kind === 'folder' ? 'files' : appForFile(f.kind), f.kind === 'folder' ? { folderId: f.id } : { fileId: f.id }),
      }))
      .filter((r) => r.score > 0),
  suggest: () =>
    recentFiles(4).map((f) => ({
      id: `file:${f.id}`,
      kind: 'file' as const,
      title: f.name,
      subtitle: relativeTime(f.modified),
      icon: fileIcon[f.kind],
      score: 0,
      run: () => open(appForFile(f.kind), { fileId: f.id }),
    })),
};

/** Inline calculator: only digits, operators and parentheses ever reach evaluation. */
const calcProvider: SearchProvider = {
  id: 'calc',
  label: 'Calculator',
  search: (q) => {
    const expr = q.replace(/×/g, '*').replace(/÷/g, '/').replace(/\^/g, '**');
    if (!/^[\d\s+\-*/().%]+$/.test(expr) || !/\d\s*[+\-*/%^]/.test(expr)) return [];
    try {
      const value = Function(`"use strict"; return (${expr});`)() as number;
      if (typeof value !== 'number' || !Number.isFinite(value)) return [];
      const text = Number.isInteger(value) ? String(value) : value.toPrecision(10).replace(/\.?0+$/, '');
      return [
        {
          id: 'calc',
          kind: 'calc',
          title: `= ${text}`,
          subtitle: 'Press Enter to copy',
          icon: Calculator,
          score: 200,
          run: () => navigator.clipboard?.writeText(text).catch(() => {}),
        },
      ];
    } catch {
      return [];
    }
  },
};

export const providers: SearchProvider[] = [calcProvider, appsProvider, windowsProvider, actionsProvider, settingsProvider, filesProvider];
