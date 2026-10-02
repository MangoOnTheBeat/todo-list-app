import type { AppId } from '@/system/types';

/**
 * Smart notification triage. Re-ranks incoming notifications by urgency, routes
 * low-value ones to a quiet bundle (no banner), and writes a digest of the backlog.
 */
export type Priority = 'low' | 'normal' | 'high';

export interface TriageInput {
  appId: AppId;
  title: string;
  body: string;
  priority: Priority;
}

export interface Triage {
  priority: Priority;
  /** Collapse into the "Low priority" bundle and skip the banner. */
  bundle: boolean;
  reason?: string;
}

export function triage(n: TriageInput): Triage {
  const text = `${n.title} ${n.body}`.toLowerCase();
  const soon = text.match(/\bin (\d+) (minutes?|mins?)\b/);
  if (soon && Number(soon[1]) <= 30) return { priority: 'high', bundle: false, reason: 'Starts soon' };
  if (/\b(timer|alarm)\b.*\b(done|finished)\b|\bsecurity\b|\bbattery (low|critical)\b/.test(text)) return { priority: 'high', bundle: false, reason: 'Needs attention' };
  if (n.appId === 'store' || /\bupdates?\b|\bnewsletter\b|\bpromo/.test(text)) return { priority: 'low', bundle: true, reason: 'Can wait' };
  if (/\b(edited|updated|shared|liked|commented)\b/.test(text) && n.priority !== 'high') return { priority: 'low', bundle: true, reason: 'Activity' };
  return { priority: n.priority, bundle: n.priority === 'low' };
}

export function digest(items: { appId: AppId; title: string; priority: Priority; read: boolean }[], appName: (id: AppId) => string) {
  const urgent = items.filter((n) => n.priority === 'high');
  const normal = items.filter((n) => n.priority === 'normal');
  const low = items.filter((n) => n.priority === 'low');
  const lines: string[] = [];
  if (urgent.length) lines.push(`${urgent.length === 1 ? 'One thing needs' : `${urgent.length} things need`} you soon: ${urgent.map((n) => n.title).join('; ')}.`);
  if (normal.length) lines.push(`${normal.length} worth a look, from ${[...new Set(normal.map((n) => appName(n.appId)))].join(', ')}.`);
  if (low.length) lines.push(`${low.length} low-priority ${low.length === 1 ? 'update' : 'updates'} bundled below.`);
  return lines;
}
