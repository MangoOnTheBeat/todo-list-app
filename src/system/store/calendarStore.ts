import { create } from 'zustand';
import { uid } from '../ids';

export type CalendarId = 'work' | 'personal' | 'focus' | 'health';

export const CALENDARS: Record<CalendarId, { name: string; hue: number }> = {
  work: { name: 'Work', hue: 255 },
  personal: { name: 'Personal', hue: 155 },
  focus: { name: 'Focus time', hue: 295 },
  health: { name: 'Health', hue: 25 },
};

export interface CalEvent {
  id: string;
  title: string;
  start: number;
  end: number;
  calendar: CalendarId;
  location?: string;
  notes?: string;
}

const HOUR = 3_600_000;

/** Start of the Monday of the week containing `d`. */
export function startOfWeek(d: Date) {
  const x = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  x.setDate(x.getDate() - ((x.getDay() + 6) % 7));
  return x;
}

function seed(): CalEvent[] {
  const mon = startOfWeek(new Date()).getTime();
  const at = (day: number, hour: number, dur: number, title: string, calendar: CalendarId, location?: string): CalEvent => ({
    id: uid('ev'),
    title,
    calendar,
    location,
    start: mon + day * 24 * HOUR + hour * HOUR,
    end: mon + day * 24 * HOUR + (hour + dur) * HOUR,
  });
  return [
    at(0, 9.5, 0.5, 'Team stand-up', 'work', 'Studio B'),
    at(0, 10, 2, 'Deep work: window manager', 'focus'),
    at(0, 13, 1, 'Lunch with Priya', 'personal', 'Harbour Café'),
    at(1, 9.5, 0.5, 'Team stand-up', 'work', 'Studio B'),
    at(1, 11, 1.5, 'Design review: shell', 'work', 'Atrium 3'),
    at(1, 17.5, 1, 'Climbing', 'health', 'Boulder Lab'),
    at(2, 9.5, 0.5, 'Team stand-up', 'work', 'Studio B'),
    at(2, 14, 2, 'Focus block', 'focus'),
    at(3, 9.5, 0.5, 'Team stand-up', 'work', 'Studio B'),
    at(3, 10, 1, 'Quarterly planning', 'work', 'Atrium 3'),
    at(3, 15, 1, '1:1 with Jordan', 'work'),
    at(4, 9.5, 0.5, 'Team stand-up', 'work', 'Studio B'),
    at(4, 12, 1, 'Yoga', 'health'),
    at(4, 16, 1, 'Demo day', 'work', 'Main hall'),
    at(5, 10, 2, 'Farmers market', 'personal'),
  ];
}

interface CalendarStore {
  events: CalEvent[];
  add: (e: Omit<CalEvent, 'id'>) => string;
  update: (id: string, patch: Partial<CalEvent>) => void;
  remove: (id: string) => void;
}

export const useCalendarStore = create<CalendarStore>()((set) => ({
  events: seed(),
  add: (e) => {
    const id = uid('ev');
    set((s) => ({ events: [...s.events, { ...e, id }] }));
    return id;
  },
  update: (id, patch) => set((s) => ({ events: s.events.map((e) => (e.id === id ? { ...e, ...patch } : e)) })),
  remove: (id) => set((s) => ({ events: s.events.filter((e) => e.id !== id) })),
}));

export function eventsOnDay(events: CalEvent[], day: Date) {
  const s = new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime();
  const e = s + 24 * HOUR;
  return events.filter((ev) => ev.start < e && ev.end > s).sort((a, b) => a.start - b.start);
}

export function calColor(id: CalendarId, alpha = 1) {
  return `oklch(0.66 0.15 ${CALENDARS[id].hue} / ${alpha})`;
}
