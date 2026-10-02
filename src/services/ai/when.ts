/**
 * Tiny natural-language date/time parser for assistant commands:
 * "tomorrow at 3pm for 45 minutes", "friday 10:30", "today at noon", "next monday morning".
 */
const DAYS = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];

export interface When {
  start?: Date;
  /** Minutes */
  duration?: number;
  dayOnly?: boolean;
  label?: string;
}

export function parseWhen(text: string, now = new Date()): When {
  const t = text.toLowerCase();
  const out: When = {};
  let day: Date | undefined;
  const base = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  if (/\btoday\b|\btonight\b/.test(t)) day = base;
  else if (/\btomorrow\b/.test(t)) day = new Date(base.getTime() + 86_400_000);
  else {
    const m = t.match(/\b(next\s+)?(sunday|monday|tuesday|wednesday|thursday|friday|saturday)\b/);
    if (m) {
      const target = DAYS.indexOf(m[2]);
      // "monday" on a Monday means next week's.
      const diff = (target - base.getDay() + 7) % 7 || 7;
      day = new Date(base.getTime() + diff * 86_400_000);
    }
  }

  let hour: number | undefined;
  let minute = 0;
  const tm = t.match(/\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/) ?? t.match(/\bat\s+(\d{1,2})(?::(\d{2}))?\b/);
  if (tm) {
    hour = Number(tm[1]);
    minute = Number(tm[2] ?? 0);
    const ap = tm[3];
    if (ap === 'pm' && hour < 12) hour += 12;
    if (ap === 'am' && hour === 12) hour = 0;
    // "at 3" with no am/pm during working hours means 3pm.
    if (!ap && hour >= 1 && hour <= 7) hour += 12;
  } else if (/\bnoon\b|\bmidday\b/.test(t)) hour = 12;
  else if (/\bmorning\b/.test(t)) hour = 9;
  else if (/\bafternoon\b/.test(t)) hour = 14;
  else if (/\bevening\b|\btonight\b/.test(t)) hour = 18;

  if (hour !== undefined) {
    const d = day ?? base;
    out.start = new Date(d.getFullYear(), d.getMonth(), d.getDate(), hour, minute);
    // A bare time that already passed today means tomorrow.
    if (!day && out.start.getTime() < now.getTime()) out.start = new Date(out.start.getTime() + 86_400_000);
  } else if (day) {
    out.start = day;
    out.dayOnly = true;
  }

  const dm = t.match(/\bfor\s+(\d+(?:\.\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m)\b/);
  if (dm) out.duration = Math.round(Number(dm[1]) * (dm[2].startsWith('h') ? 60 : 1));
  else if (/\bfor\s+(an|one)\s+hour\b/.test(t)) out.duration = 60;
  else if (/\bfor\s+half\s+an\s+hour\b/.test(t)) out.duration = 30;

  if (out.start) {
    const sameDay = out.start.toDateString() === now.toDateString();
    const tomorrow = out.start.toDateString() === new Date(base.getTime() + 86_400_000).toDateString();
    const dayLabel = sameDay ? 'today' : tomorrow ? 'tomorrow' : out.start.toLocaleDateString(undefined, { weekday: 'long' });
    out.label = out.dayOnly ? dayLabel : `${dayLabel} at ${out.start.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })}`;
  }
  return out;
}

/** "5 minutes", "1 hour", "90 seconds" → milliseconds. */
export function parseDuration(text: string) {
  const m = text.toLowerCase().match(/(\d+(?:\.\d+)?)\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h)\b/);
  if (!m) return undefined;
  const n = Number(m[1]);
  const u = m[2][0];
  return n * (u === 'h' ? 3_600_000 : u === 'm' ? 60_000 : 1000);
}
