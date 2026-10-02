import type { CalEvent } from '@/system/store/calendarStore';

const HOUR = 3_600_000;
const DAY = 24 * HOUR;

/**
 * Open working-hours gaps (9:00–18:00, Mon–Fri) of at least `minMinutes`, from now onward,
 * capped at two hours each. Used by Calendar's "Find focus time" and the assistant.
 */
export function findFocusSlots(events: CalEvent[], weekStart: number, minMinutes = 90, limit = 4) {
  const out: { start: number; end: number }[] = [];
  const now = Date.now();
  for (let d = 0; d < 5 && out.length < limit; d++) {
    const dayStart = weekStart + d * DAY;
    const open = Math.max(dayStart + 9 * HOUR, Math.ceil(now / (HOUR / 2)) * (HOUR / 2));
    const close = dayStart + 18 * HOUR;
    if (open >= close) continue;
    const busy = events
      .filter((e) => e.end > open && e.start < close)
      .sort((a, b) => a.start - b.start);
    let cursor = open;
    for (const e of [...busy, { start: close, end: close } as CalEvent]) {
      if (e.start - cursor >= minMinutes * 60_000) {
        out.push({ start: cursor, end: Math.min(e.start, cursor + 2 * HOUR) });
        if (out.length >= limit) break;
      }
      cursor = Math.max(cursor, e.end);
    }
  }
  return out;
}

export interface Recommendation {
  id: string;
  title: string;
  body: string;
  action?: { label: string; command: string };
}

/** Heuristic productivity tips from the live desktop state. */
export function recommendations(ctx: { windowCount: number; desktops: number; meetingsToday: number; nextMeetingIn?: number; focusFree: boolean; downloadsCount: number; hour: number }): Recommendation[] {
  const recs: Recommendation[] = [];
  if (ctx.nextMeetingIn !== undefined && ctx.nextMeetingIn < 30) {
    recs.push({ id: 'meeting', title: `Meeting in ${Math.max(1, Math.round(ctx.nextMeetingIn))} min`, body: 'Turn on Do Not Disturb so nothing interrupts the call.', action: { label: 'Turn on DND', command: 'dnd on' } });
  }
  if (ctx.windowCount >= 5 && ctx.desktops === 1) {
    recs.push({ id: 'desktops', title: `${ctx.windowCount} windows on one desktop`, body: 'Tiling or splitting work across desktops keeps context switches cheap.', action: { label: 'Tile windows', command: 'tile windows' } });
  }
  if (ctx.meetingsToday >= 3 && ctx.focusFree) {
    recs.push({ id: 'focus', title: 'Protect some focus time', body: `You have ${ctx.meetingsToday} meetings today. There's still a free 90-minute block this week.`, action: { label: 'Find focus time', command: 'find focus time' } });
  }
  if (ctx.downloadsCount >= 6) {
    recs.push({ id: 'downloads', title: 'Downloads is getting full', body: `${ctx.downloadsCount} files are sitting in Downloads. I can sort them into folders for you.`, action: { label: 'Organize Downloads', command: 'organize downloads' } });
  }
  if (ctx.hour >= 20 || ctx.hour < 6) {
    recs.push({ id: 'night', title: 'It’s getting late', body: 'Night Light warms the display to make it easier on your eyes.', action: { label: 'Turn on Night Light', command: 'night light on' } });
  }
  return recs;
}
