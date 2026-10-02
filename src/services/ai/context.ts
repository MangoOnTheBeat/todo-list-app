import { getApp } from '@/system/appRegistry';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppId, WindowState } from '@/system/types';
import { ARTICLE } from '@/apps/browser/article';

export interface Suggestion {
  label: string;
  /** Natural-language prompt the chip sends to the assistant. */
  prompt: string;
}

export interface DesktopContext {
  /** The window the user was last working in (ignores the assistant itself). */
  window?: WindowState;
  appId?: AppId;
  summary: string;
  suggestions: Suggestion[];
}

/**
 * What the user is looking at right now, and what would help. The assistant uses
 * this to resolve "this" ("summarize this", "snap this left") and to offer chips.
 */
export function getContext(): DesktopContext {
  const s = useWindowStore.getState();
  // Walk the z-order from the top, skipping the assistant window.
  let win: WindowState | undefined;
  for (let i = s.order.length - 1; i >= 0; i--) {
    const w = s.windows[s.order[i]];
    if (w && w.appId !== 'assistant' && !w.minimized && w.desktopId === s.activeDesktopId) {
      win = w;
      break;
    }
  }
  const visibleCount = Object.values(s.windows).filter((w) => w.desktopId === s.activeDesktopId && !w.minimized).length;
  const suggestions: Suggestion[] = [];

  switch (win?.appId) {
    case 'files':
      suggestions.push({ label: `Organize ${win.title}`, prompt: `organize ${win.title}` }, { label: 'Large files', prompt: 'find files larger than 50 MB' });
      break;
    case 'notes':
      suggestions.push({ label: 'Summarize this note', prompt: 'summarize this' });
      break;
    case 'browser':
      if (win.title === ARTICLE.title) suggestions.push({ label: 'Summarize this page', prompt: 'summarize this' });
      break;
    case 'calendar':
      suggestions.push({ label: 'Find focus time', prompt: 'find focus time this week' }, { label: "Tomorrow's agenda", prompt: "what's on tomorrow" });
      break;
    case 'music':
      suggestions.push({ label: 'Next track', prompt: 'next song' });
      break;
    case 'monitor':
    case 'tasks':
      suggestions.push({ label: "What's using CPU?", prompt: "what's using the cpu" });
      break;
  }
  if (visibleCount >= 3) suggestions.push({ label: `Tile ${visibleCount} windows`, prompt: 'tile windows' });
  if (win) suggestions.push({ label: `Snap ${getApp(win.appId).name} left`, prompt: 'snap this left' });
  suggestions.push({ label: 'My day', prompt: "what's on today" }, { label: 'Recent PDFs', prompt: 'pdfs from this month' });

  return {
    window: win,
    appId: win?.appId,
    summary: win ? `${getApp(win.appId).name}${win.title !== getApp(win.appId).name ? ` — ${win.title}` : ''}` : 'Desktop',
    suggestions: suggestions.slice(0, 5),
  };
}
