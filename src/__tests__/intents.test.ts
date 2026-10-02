import { beforeEach, describe, expect, it } from 'vitest';
import { execute, interpret } from '@/services/ai/intents';
import { parseWhen, parseDuration } from '@/services/ai/when';
import { fileQuery } from '@/services/ai/fileQuery';
import { useCalendarStore } from '@/system/store/calendarStore';
import { useSystemStore } from '@/system/store/systemStore';
import { useWindowStore } from '@/system/store/windowStore';
import { useNotificationStore } from '@/system/store/notificationStore';

const id = (t: string) => interpret(t)?.intent.id;

describe('intent recognition', () => {
  it.each([
    ['open calendar', 'open'],
    ['please launch the browser', 'open'],
    ['turn on dark mode', 'theme'],
    ['switch to light theme', 'theme'],
    ['set the accent colour to mint', 'accent'],
    ['make the accent pink', 'accent'],
    ['change wallpaper to dusk', 'wallpaper'],
    ['turn on do not disturb', 'toggle'],
    ['turn off animations', 'toggle'],
    ['set brightness to 40%', 'level'],
    ['mute', 'level'],
    ['tile windows', 'tile'],
    ['show desktop', 'show-desktop'],
    ['snap calendar left', 'snap'],
    ['maximize this', 'snap'],
    ['go to desktop 2', 'desktop'],
    ['new desktop', 'desktop'],
    ["what's on tomorrow", 'agenda'],
    ["what's my next meeting", 'agenda'],
    ['schedule focus time tomorrow at 2pm for 90 minutes', 'schedule'],
    ['add lunch with sam friday at 1pm', 'schedule'],
    ['find focus time this week', 'focus-time'],
    ['find pdfs from last month', 'find-files'],
    ['photos larger than 5 mb', 'find-files'],
    ['organize downloads', 'organize'],
    ['take a note buy oat milk', 'note'],
    ['set a timer for 5 minutes', 'timer'],
    ['play halcyon drive', 'media'],
    ['next song', 'media'],
    ['pause the music', 'media'],
    ["what's using the cpu", 'system'],
    ['how much memory is free', 'system'],
    ['summarize this', 'summarize'],
    ['hello', 'greet'],
    ['what can you do', 'help'],
    ['lock the screen', 'lock'],
  ])('“%s” → %s', (text, expected) => {
    expect(id(text)).toBe(expected);
  });

  it('returns null for nonsense', () => {
    expect(interpret('purple monkey dishwasher')).toBeNull();
  });
});

describe('execution', () => {
  beforeEach(() => {
    useWindowStore.setState({ windows: {}, order: [], focusedId: null });
  });

  it('changes settings through the system store', () => {
    execute('turn on dark mode');
    expect(useSystemStore.getState().theme).toBe('dark');
    execute('accent ember');
    expect(useSystemStore.getState().accentHue).toBe(35);
    execute('volume 25%');
    expect(useSystemStore.getState().volume).toBeCloseTo(0.25);
  });

  it('runs chained commands in order', () => {
    execute('open notes and snap it left');
    const wins = Object.values(useWindowStore.getState().windows);
    expect(wins).toHaveLength(1);
    expect(wins[0].appId).toBe('notes');
    expect(wins[0].snap).toBe('left');
  });

  it('creates calendar events from natural language', () => {
    const before = useCalendarStore.getState().events.length;
    const reply = execute('schedule focus time tomorrow at 2pm for 90 minutes');
    const events = useCalendarStore.getState().events;
    expect(events).toHaveLength(before + 1);
    const ev = events[events.length - 1];
    expect(ev.calendar).toBe('focus');
    expect((ev.end - ev.start) / 60000).toBe(90);
    expect(new Date(ev.start).getHours()).toBe(14);
    expect(reply.text).toMatch(/Focus time/);
  });

  it('derives sensible event titles', () => {
    execute('schedule lunch with sam friday at 1pm');
    let ev = useCalendarStore.getState().events.at(-1)!;
    expect(ev.title).toBe('Lunch with Sam');
    expect(ev.calendar).toBe('personal');
    execute('add a design sync tomorrow at 11am');
    ev = useCalendarStore.getState().events.at(-1)!;
    expect(ev.title).toBe('Sync');
    execute('book a call with jordan lee monday at 4pm for 30 minutes');
    ev = useCalendarStore.getState().events.at(-1)!;
    expect(ev.title).toBe('Call with Jordan Lee');
    expect((ev.end - ev.start) / 60000).toBe(30);
  });

  it('toggles do not disturb', () => {
    execute('turn on dnd');
    expect(useNotificationStore.getState().dnd).toBe(true);
    execute('turn off do not disturb');
    expect(useNotificationStore.getState().dnd).toBe(false);
  });
});

describe('search ranking', () => {
  it('ranks apps above name-alike files and answers structured file questions', async () => {
    const { search } = await import('@/services/search');
    expect(search('Task Manager').top?.title).toBe('Task Manager');
    expect(search('System Monitor').top?.title).toBe('System Monitor');
    const pdfs = search('pdfs from this month');
    expect(pdfs.flat.some((r) => r.kind === 'ai' && /\.pdf$/i.test(r.title))).toBe(true);
    expect(search('12*7').top?.title).toBe('= 84');
  });
});

describe('parsers', () => {
  const now = new Date(2026, 9, 2, 10, 0); // Fri 2 Oct 2026, 10:00
  it('parses relative days and times', () => {
    const w = parseWhen('tomorrow at 3:30pm for 45 minutes', now);
    expect(w.start?.getDate()).toBe(3);
    expect(w.start?.getHours()).toBe(15);
    expect(w.start?.getMinutes()).toBe(30);
    expect(w.duration).toBe(45);
  });
  it('treats a bare afternoon hour as pm and weekday names as the next occurrence', () => {
    const w = parseWhen('monday at 3', now);
    expect(w.start?.getDay()).toBe(1);
    expect(w.start?.getHours()).toBe(15);
  });
  it('parses durations', () => {
    expect(parseDuration('10 minutes')).toBe(600_000);
    expect(parseDuration('1.5 hours')).toBe(5_400_000);
  });
  it('answers structured file queries', () => {
    const r = fileQuery('pdfs');
    expect(r?.files.length).toBeGreaterThan(0);
    expect(r?.files.every((f) => f.kind === 'pdf')).toBe(true);
    const big = fileQuery('files larger than 50 mb');
    expect(big?.files.every((f) => (f.size ?? 0) >= 50 * 1024 ** 2)).toBe(true);
    const named = fileQuery('invoices');
    expect(named?.files.some((f) => /invoice/i.test(f.name))).toBe(true);
  });
});
