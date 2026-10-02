import { ARTICLE, ARTICLE_TEXT } from '@/apps/browser/article';
import { allApps, getApp } from '@/system/appRegistry';
import { CALENDARS, eventsOnDay, startOfWeek, useCalendarStore } from '@/system/store/calendarStore';
import { allFiles, childrenOf, ROOT_ID, useFileStore } from '@/system/store/fileStore';
import { LIBRARY, currentTrack, formatTime, useMediaStore } from '@/system/store/mediaStore';
import { useNotesStore } from '@/system/store/notesStore';
import { useNotificationStore } from '@/system/store/notificationStore';
import { useShellStore } from '@/system/store/shellStore';
import { ACCENT_PRESETS, useSystemStore, WALLPAPERS, type WallpaperId } from '@/system/store/systemStore';
import { isHiddenTab, useWindowStore } from '@/system/store/windowStore';
import { useAiStore, type AiReply } from '@/system/store/aiStore';
import type { AppId, SnapZone } from '@/system/types';
import { commands } from '../commands';
import { snapshot, TOTAL_MEM_GB } from '../metrics';
import { formatBytes } from '../vfs';
import { getContext } from './context';
import { fileQuery } from './fileQuery';
import { apply as applyOrganize, plan as planOrganize } from './organizer';
import { findFocusSlots, recommendations } from './productivity';
import { summarize } from './text';
import { parseDuration, parseWhen } from './when';

/**
 * Aurora AI's command engine. Each intent recognises a family of phrasings, extracts
 * parameters, and returns a reply (text + optional cards + follow-up actions) after
 * performing the action through the same stores and `commands` the UI uses.
 *
 * It is deliberately deterministic and on-device. A language model could replace
 * `interpret()` (text → intent + params) without touching any intent's `run`.
 */

type Params = Record<string, string | number | boolean | undefined>;

export interface Intent {
  id: string;
  /** Short present-tense description for search previews, e.g. "Open Calendar". */
  describe: (p: Params) => string;
  match: (t: string) => Params | null;
  run: (p: Params) => AiReply;
}

const APP_ALIASES: [RegExp, AppId][] = [
  [/\b(files?|finder|explorer|folders?)\b/, 'files'],
  [/\b(browser|web|horizon|internet)\b/, 'browser'],
  [/\b(music|resonance|songs?|player)\b/, 'music'],
  [/\b(settings|preferences|control panel)\b/, 'settings'],
  [/\b(calendar|schedule|agenda)\b/, 'calendar'],
  [/\b(clock|timer|stopwatch|alarm)\b/, 'clock'],
  [/\b(system monitor|monitor|performance)\b/, 'monitor'],
  [/\b(task manager|processes|tasks)\b/, 'tasks'],
  [/\b(store|atrium|app store)\b/, 'store'],
  [/\b(notes?|notepad)\b/, 'notes'],
  [/\b(welcome|tour)\b/, 'welcome'],
];

function findApp(t: string): AppId | undefined {
  for (const [re, id] of APP_ALIASES) if (re.test(t)) return id;
  return allApps.find((a) => t.includes(a.name.toLowerCase()))?.id;
}

/** "this"/"it" → the focused window; otherwise a named app's top window. */
function targetWindow(t: string) {
  const s = useWindowStore.getState();
  const app = /\b(this|it|current|window)\b/.test(t) ? undefined : findApp(t);
  if (app) {
    for (let i = s.order.length - 1; i >= 0; i--) {
      const w = s.windows[s.order[i]];
      if (w.appId === app) return w;
    }
    return undefined;
  }
  return getContext().window;
}

const on = (t: string) => !/\b(off|disable|stop|deactivate)\b/.test(t);
const fmtTime = (d: number) => new Date(d).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
const open = (id: AppId, args?: Record<string, unknown>) => useWindowStore.getState().openApp(id, { args });

const intents: Intent[] = [
  /* ───────── Help & greetings ───────── */
  {
    id: 'help',
    describe: () => 'Show what Aurora AI can do',
    match: (t) => (/^(help|what can you do|commands|how do i use you)\b/.test(t) ? {} : null),
    run: () => ({
      text: 'I can drive the whole desktop. A few things to try:',
      cards: [
        {
          type: 'bullets',
          items: [
            '“Open Calendar and snap it left”',
            '“Schedule focus time tomorrow at 2pm for 90 minutes”',
            '“Find PDFs from last month” or “photos larger than 5 MB”',
            '“Organize Downloads”',
            '“Summarize this” while a note or article is in front',
            '“Turn on dark mode”, “accent mint”, “wallpaper dusk”',
            '“What\'s using the CPU?”, “Set a timer for 10 minutes”',
          ],
        },
      ],
    }),
  },
  {
    id: 'greet',
    describe: () => 'Brief me on my day',
    match: (t) => (/^(hi|hello|hey|good (morning|afternoon|evening)|morning|brief me|my day|what'?s (up|new))\b/.test(t) ? {} : null),
    run: () => {
      const now = new Date();
      const today = eventsOnDay(useCalendarStore.getState().events, now).filter((e) => e.end > now.getTime());
      const unread = useNotificationStore.getState().items.filter((n) => !n.read).length;
      const part = now.getHours() < 12 ? 'Good morning' : now.getHours() < 18 ? 'Good afternoon' : 'Good evening';
      const next = today[0];
      return {
        text: `${part}. ${today.length ? `You have ${today.length} more ${today.length === 1 ? 'event' : 'events'} today${next ? `, starting with ${next.title} at ${fmtTime(next.start)}` : ''}.` : 'Your calendar is clear for the rest of today.'} ${unread ? `${unread} unread ${unread === 1 ? 'notification' : 'notifications'}.` : ''}`.trim(),
        cards: today.length ? [{ type: 'events', events: today.slice(0, 4) }] : undefined,
        actions: [{ label: 'Open Calendar', run: () => open('calendar') }],
      };
    },
  },

  /* ───────── Summaries (context-aware) ───────── */
  {
    id: 'summarize',
    describe: () => `Summarize ${getContext().summary}`,
    match: (t) => (/\b(summari[sz]e|tl;?dr|sum up|key points)\b/.test(t) ? { notes: /\bnotes\b/.test(t) } : null),
    run: (p) => {
      if (p.notes) {
        const notes = useNotesStore.getState().notes;
        return { text: `Here's the gist of your ${notes.length} notes:`, cards: [{ type: 'bullets', items: notes.map((n) => `${n.title || 'Untitled'}: ${summarize(n.body, 1)[0]}`) }] };
      }
      const ctx = getContext();
      const w = ctx.window;
      if (w?.appId === 'browser' && w.title === ARTICLE.title) return { text: `Summary of “${ARTICLE.title}”:`, cards: [{ type: 'bullets', items: summarize(ARTICLE_TEXT, 4) }] };
      if (w?.appId === 'notes') {
        const fileId = w.args?.fileId as string | undefined;
        const file = fileId ? useFileStore.getState().nodes[fileId] : undefined;
        const note = useNotesStore.getState().notes.find((n) => n.title === w.title);
        const body = file?.content ?? note?.body;
        if (body !== undefined) return { text: `Summary of “${w.title}”:`, cards: [{ type: 'bullets', items: summarize(`${w.title}. ${body}`) }] };
      }
      if (w?.appId === 'files') {
        const nodes = useFileStore.getState().nodes;
        const folder = Object.values(nodes).find((n) => n.kind === 'folder' && n.name === w.title) ?? nodes[ROOT_ID];
        const kids = childrenOf(nodes, folder.id);
        const size = kids.reduce((a, k) => a + (k.size ?? 0), 0);
        const biggest = [...kids].sort((a, b) => (b.size ?? 0) - (a.size ?? 0))[0];
        return { text: `${folder.name} holds ${kids.length} items (${formatBytes(size)}).${biggest?.size ? ` The largest is ${biggest.name} at ${formatBytes(biggest.size)}.` : ''}`, actions: [{ label: `Organize ${folder.name}`, run: () => open('files', { folderId: folder.id }) }] };
      }
      return { text: 'Bring a note, an article in Horizon, or a folder in Files to the front and ask again — I summarise whatever you are looking at.' };
    },
  },

  /* ───────── Calendar ───────── */
  {
    id: 'focus-time',
    describe: () => 'Find free focus blocks this week',
    match: (t) => (/\b(find|free|any)\b.*\b(focus|time|slot|gap)\b|\bwhen am i free\b/.test(t) && !/\b(schedule|add|book|block)\b/.test(t) ? {} : null),
    run: () => {
      const events = useCalendarStore.getState().events;
      const slots = findFocusSlots(events, startOfWeek(new Date()).getTime());
      if (!slots.length) return { text: 'Your working hours are fully booked for the rest of the week. Next week has room.' };
      return {
        text: `I found ${slots.length} open blocks of 90 minutes or more. Want me to protect one?`,
        actions: slots.slice(0, 3).map((s, i) => ({
          label: `${new Date(s.start).toLocaleDateString(undefined, { weekday: 'short' })} ${fmtTime(s.start)}`,
          primary: i === 0,
          run: () => {
            useCalendarStore.getState().add({ title: 'Focus time', start: s.start, end: s.end, calendar: 'focus' });
            useNotificationStore.getState().post({ appId: 'calendar', title: 'Focus time booked', body: `${new Date(s.start).toLocaleDateString(undefined, { weekday: 'long' })} ${fmtTime(s.start)}–${fmtTime(s.end)}`, priority: 'low' });
          },
        })),
      };
    },
  },
  {
    id: 'schedule',
    describe: (p) => `Add “${p.title}” ${p.label ?? ''}`.trim(),
    match: (t) => {
      if (!/\b(schedule|add|book|create|block|put)\b/.test(t) || !/\b(meeting|event|call|focus|lunch|appointment|time|with|today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday|\d\s*(am|pm))\b/.test(t)) return null;
      const w = parseWhen(t);
      if (!w.start) return null;
      const STOP = /\b(today|tomorrow|tonight|on|at|for|next|this|from|monday|tuesday|wednesday|thursday|friday|saturday|sunday|morning|afternoon|evening|noon|\d).*$/;
      const withWho = t.match(/\bwith\s+([a-z]+(?:\s[a-z]+)?)/)?.[1]?.replace(STOP, '').trim();
      const focus = /\bfocus\b/.test(t);
      const noun = t.match(/\b(lunch|dinner|coffee|breakfast|call|sync|interview|review|demo|standup|stand-up|1:1|workout|gym|meeting)\b/)?.[1];
      const cap = (x: string) => x.charAt(0).toUpperCase() + x.slice(1);
      const who = withWho ? withWho.replace(/\b\w/g, (c) => c.toUpperCase()) : '';
      let title = focus ? 'Focus time' : noun ? `${cap(noun)}${who ? ` with ${who}` : ''}` : who ? `Meeting with ${who}` : '';
      if (!title) {
        const m = t.match(/\b(?:schedule|add|book|create|put)\s+(?:a\s+|an\s+)?(.+?)\s+(?:today|tomorrow|on|at|next|this|for|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/);
        title = cap((m?.[1] ?? 'New event').replace(/^(meeting|event)$/, 'meeting'));
      }
      const start = w.dayOnly ? new Date(w.start.getFullYear(), w.start.getMonth(), w.start.getDate(), 10) : w.start;
      return { title, start: start.getTime(), duration: w.duration ?? (focus ? 90 : 60), label: w.label, calendar: focus ? 'focus' : /\blunch|dinner|gym|yoga|run\b/.test(t) ? 'personal' : 'work' };
    },
    run: (p) => {
      const start = Number(p.start);
      const end = start + Number(p.duration) * 60_000;
      const cal = p.calendar as keyof typeof CALENDARS;
      const clash = useCalendarStore.getState().events.find((e) => e.start < end && e.end > start);
      const id = useCalendarStore.getState().add({ title: String(p.title), start, end, calendar: cal });
      return {
        text: `Added “${p.title}” ${p.label}, ${p.duration} minutes, on your ${CALENDARS[cal].name} calendar.${clash ? ` Heads up: it overlaps “${clash.title}”.` : ''}`,
        cards: [{ type: 'events', events: useCalendarStore.getState().events.filter((e) => e.id === id) }],
        actions: [
          { label: 'Undo', run: () => useCalendarStore.getState().remove(id) },
          { label: 'Open Calendar', run: () => open('calendar') },
        ],
      };
    },
  },
  {
    id: 'agenda',
    describe: (p) => `Show your agenda for ${p.label}`,
    match: (t) => {
      if (!/\b(what'?s on|agenda|schedule|calendar|meetings?|events?|busy|plans?|next meeting|am i free)\b/.test(t) || /\b(open|launch|snap|move|put|maximi[sz]e|minimi[sz]e|close)\b/.test(t)) return null;
      if (/\bnext (meeting|event)\b|\bwhat'?s next\b/.test(t)) return { next: true, label: 'next' };
      const w = parseWhen(t);
      const d = w.start ?? new Date();
      return { day: new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime(), label: w.label?.replace(/ at .*/, '') ?? 'today', at: w.dayOnly ? undefined : w.start?.getTime() };
    },
    run: (p) => {
      const events = useCalendarStore.getState().events;
      if (p.next) {
        const next = events.filter((e) => e.start > Date.now()).sort((a, b) => a.start - b.start)[0];
        if (!next) return { text: 'Nothing else on your calendar.' };
        const mins = Math.round((next.start - Date.now()) / 60_000);
        return { text: `Next up: ${next.title}, ${mins < 60 ? `in ${mins} minutes` : `${new Date(next.start).toLocaleDateString(undefined, { weekday: 'long' })} at ${fmtTime(next.start)}`}${next.location ? ` in ${next.location}` : ''}.`, cards: [{ type: 'events', events: [next] }] };
      }
      const list = eventsOnDay(events, new Date(Number(p.day)));
      if (p.at) {
        const at = Number(p.at);
        const busy = list.find((e) => e.start <= at && e.end > at);
        return { text: busy ? `No — you're in “${busy.title}” then (${fmtTime(busy.start)}–${fmtTime(busy.end)}).` : `Yes, you're free at ${fmtTime(at)}.` };
      }
      return list.length
        ? { text: `${list.length} ${list.length === 1 ? 'event' : 'events'} ${p.label}:`, cards: [{ type: 'events', events: list }] }
        : { text: `Nothing on ${p.label}. Enjoy the open calendar.` };
    },
  },

  /* ───────── Files ───────── */
  {
    id: 'organize',
    describe: (p) => `Organize ${p.folder}`,
    match: (t) => {
      if (!/\b(organi[sz]e|tidy|clean up|sort out|declutter)\b/.test(t)) return null;
      const nodes = useFileStore.getState().nodes;
      const named = Object.values(nodes).find((n) => n.kind === 'folder' && !n.trashed && t.includes(n.name.toLowerCase()));
      const ctx = getContext().window;
      const fromCtx = ctx?.appId === 'files' ? Object.values(nodes).find((n) => n.kind === 'folder' && n.name === ctx.title) : undefined;
      const folder = named ?? fromCtx ?? Object.values(nodes).find((n) => n.name === 'Downloads' && n.parentId === ROOT_ID)!;
      return { folderId: folder.id, folder: folder.name };
    },
    run: (p) => {
      const groups = planOrganize(String(p.folderId));
      if (!groups.length) return { text: `${p.folder} already looks tidy — nothing worth moving.` };
      const count = groups.reduce((a, g) => a + g.files.length, 0);
      return {
        text: `I can move ${count} files in ${p.folder} into ${groups.length} folders. Nothing moves until you say so.`,
        cards: [{ type: 'bullets', items: groups.map((g) => `${g.folder} — ${g.reason} (${Math.round(g.confidence * 100)}% sure)`) }],
        actions: [
          {
            label: `Move ${count} files`,
            primary: true,
            run: () => {
              const undo = applyOrganize(String(p.folderId), groups);
              useNotificationStore.getState().post({ appId: 'files', title: `Organized ${p.folder}`, body: `Moved ${count} files into ${groups.length} folders.`, priority: 'low', silent: true });
              respondInChat({ text: `Done — ${p.folder} is organized.`, actions: [{ label: 'Undo', run: undo }, { label: 'Show in Files', run: () => open('files', { folderId: p.folderId }) }] });
            },
          },
          { label: 'Review in Files', run: () => open('files', { folderId: p.folderId }) },
        ],
      };
    },
  },
  {
    id: 'find-files',
    describe: (p) => `Find ${p.description}`,
    match: (t) => {
      if (!/\b(find|show|search|where|list|look for|get)\b|\b(pdfs?|photos?|images?|documents?|spreadsheets?|files?)\b/.test(t)) return null;
      if (/\b(open|launch|start)\b/.test(t) && findApp(t)) return null;
      const q = fileQuery(t.replace(/\b(find|show|search|where|list|look for|get|are|is|my)\b/g, ' '));
      return q ? { description: q.description, query: t } : null;
    },
    run: (p) => {
      const q = fileQuery(String(p.query).replace(/\b(find|show|search|where|list|look for|get|are|is|my)\b/g, ' '))!;
      if (!q.files.length) return { text: `I couldn't find any ${q.description}.` };
      const total = q.files.reduce((a, f) => a + (f.size ?? 0), 0);
      return { text: `${q.files.length} ${q.description} (${formatBytes(total)}):`, cards: [{ type: 'files', files: q.files.slice(0, 8) }] };
    },
  },

  /* ───────── Notes & timers ───────── */
  {
    id: 'note',
    describe: (p) => `Save a note: “${p.body}”`,
    match: (t) => {
      const m = t.match(/^(?:take a note|note|make a note|remember(?: to)?|jot down|write down)[:,]?\s+(?:that\s+)?(.+)/);
      return m ? { body: m[1] } : null;
    },
    run: (p) => {
      const store = useNotesStore.getState();
      const id = store.create();
      const body = String(p.body);
      store.update(id, { title: body.length > 40 ? `${body.slice(0, 40)}…` : body.charAt(0).toUpperCase() + body.slice(1), body: body.charAt(0).toUpperCase() + body.slice(1) });
      return { text: 'Saved to Notes.', actions: [{ label: 'Open Notes', run: () => open('notes') }, { label: 'Undo', run: () => useNotesStore.getState().remove(id) }] };
    },
  },
  {
    id: 'timer',
    describe: (p) => `Set a ${p.label} timer`,
    match: (t) => {
      if (!/\b(timer|remind me in|countdown)\b/.test(t)) return null;
      const ms = parseDuration(t);
      return ms ? { ms, label: t.match(/(\d+(?:\.\d+)?)\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?|[smh])\b/)![0] } : null;
    },
    run: (p) => {
      const ms = Number(p.ms);
      setTimeout(() => useNotificationStore.getState().post({ appId: 'clock', title: 'Timer done', body: `Your ${p.label} timer from Aurora AI has finished.`, priority: 'high' }), ms);
      return { text: `Timer set for ${p.label}. I'll notify you when it's done — even with Do Not Disturb on.` };
    },
  },

  /* ───────── Media ───────── */
  {
    id: 'media',
    describe: (p) => (p.track ? `Play “${p.track}”` : String(p.verb)),
    match: (t) => {
      const track = LIBRARY.find((x) => t.includes(x.title.toLowerCase()) || t.includes(x.artist.toLowerCase()));
      if (track && /\bplay\b/.test(t)) return { track: track.title, index: LIBRARY.indexOf(track), verb: 'Play' };
      if (/\b(what'?s|what is) (playing|this song)\b/.test(t)) return { verb: 'Now playing' };
      if (/\b(next|skip)\b.*\b(song|track)?\b/.test(t) && /\b(song|track|music|next|skip)\b/.test(t) && !/\bmeeting|event\b/.test(t)) return { verb: 'Next track' };
      if (/\b(previous|last|back)\b.*\b(song|track)\b/.test(t)) return { verb: 'Previous track' };
      if (/\b(pause|stop)\b.*\b(music|song|playback|it)?\b/.test(t) && /\b(music|song|playback|pause)\b/.test(t)) return { verb: 'Pause' };
      if (/\b(play|resume)\b/.test(t) && /\b(music|song|something|playback|resume)\b/.test(t)) return { verb: 'Play' };
      return null;
    },
    run: (p) => {
      const m = useMediaStore.getState();
      if (p.verb === 'Now playing') {
        const tr = currentTrack(m);
        return { text: `${m.playing ? 'Playing' : 'Paused on'} “${tr.title}” by ${tr.artist}, ${formatTime(m.position)} of ${formatTime(tr.duration)}.` };
      }
      if (p.index !== undefined) useMediaStore.setState({ index: Number(p.index), position: 0, playing: true });
      else if (p.verb === 'Next track') m.next();
      else if (p.verb === 'Previous track') m.prev();
      else if (p.verb === 'Pause') m.pause();
      else m.play();
      const tr = currentTrack(useMediaStore.getState());
      return { text: p.verb === 'Pause' ? 'Paused.' : `Playing “${tr.title}” by ${tr.artist}.`, actions: [{ label: 'Open Resonance', run: () => open('music') }] };
    },
  },

  /* ───────── Settings ───────── */
  {
    id: 'theme',
    describe: (p) => `Switch to ${p.mode} mode`,
    match: (t) => {
      const m = t.match(/\b(dark|light)\s*(mode|theme)?\b/);
      if (!m || !/\b(mode|theme|turn|switch|go|make|use|enable|set)\b/.test(t)) return null;
      const mode = on(t) ? m[1] : m[1] === 'dark' ? 'light' : 'dark';
      return { mode };
    },
    run: (p) => {
      useSystemStore.getState().setTheme(p.mode as 'dark' | 'light');
      return { text: `Switched to ${p.mode} mode.`, actions: [{ label: 'Follow the system instead', run: () => useSystemStore.getState().setTheme('auto') }] };
    },
  },
  {
    id: 'accent',
    describe: (p) => `Set the accent colour to ${p.name}`,
    match: (t) => {
      if (!/\b(accent|colou?r|highlight)\b/.test(t)) return null;
      const alias: Record<string, string> = { purple: 'Aurora', violet: 'Aurora', blue: 'Lagoon', teal: 'Lagoon', cyan: 'Lagoon', green: 'Mint', yellow: 'Citrine', gold: 'Citrine', orange: 'Ember', red: 'Ember', pink: 'Rose' };
      const preset = ACCENT_PRESETS.find((p) => t.includes(p.name.toLowerCase())) ?? ACCENT_PRESETS.find((p) => Object.entries(alias).some(([k, v]) => v === p.name && t.includes(k)));
      return preset ? { name: preset.name, hue: preset.hue } : null;
    },
    run: (p) => {
      const prev = useSystemStore.getState().accentHue;
      useSystemStore.getState().setAccentHue(Number(p.hue));
      return { text: `Accent colour is now ${p.name}.`, actions: [{ label: 'Undo', run: () => useSystemStore.getState().setAccentHue(prev) }] };
    },
  },
  {
    id: 'wallpaper',
    describe: (p) => `Change the wallpaper to ${p.name}`,
    match: (t) => {
      if (!/\b(wallpaper|background)\b/.test(t)) return null;
      const w = WALLPAPERS.find((x) => t.includes(x.id)) ?? (/\b(change|next|another|different)\b/.test(t) ? WALLPAPERS[(WALLPAPERS.findIndex((x) => x.id === useSystemStore.getState().wallpaper) + 1) % WALLPAPERS.length] : undefined);
      return w ? { id: w.id, name: w.name } : null;
    },
    run: (p) => {
      useSystemStore.getState().set('wallpaper', p.id as WallpaperId);
      return { text: `Wallpaper changed to ${p.name}.` };
    },
  },
  {
    id: 'toggle',
    describe: (p) => `Turn ${p.on ? 'on' : 'off'} ${p.label}`,
    match: (t) => {
      const map: [RegExp, string, string][] = [
        [/\b(do not disturb|dnd|silence|mute notifications)\b/, 'dnd', 'Do Not Disturb'],
        [/\bfocus mode\b/, 'focus', 'Focus mode'],
        [/\bnight ?light|blue light\b/, 'nightLight', 'Night Light'],
        [/\breduce(d)? motion|animations?\b/, 'reduceMotion', 'Reduce motion'],
        [/\breduce(d)? transparency|glass\b/, 'reduceTransparency', 'Reduce transparency'],
        [/\bwi-?fi\b/, 'wifi', 'Wi-Fi'],
        [/\bbluetooth\b/, 'bluetooth', 'Bluetooth'],
        [/\bairplane|flight mode\b/, 'airplane', 'Airplane mode'],
        [/\bmagnification\b/, 'dockMagnification', 'Dock magnification'],
      ];
      const hit = map.find(([re]) => re.test(t));
      if (!hit || !/\b(on|off|enable|disable|turn|toggle|start|stop|activate|deactivate|switch)\b/.test(t)) return null;
      // "turn off animations" means reduce motion ON.
      const invert = hit[1] === 'reduceMotion' && /\banimations?\b/.test(t);
      return { key: hit[1], label: hit[2], on: invert ? !on(t) : on(t) };
    },
    run: (p) => {
      const val = Boolean(p.on);
      if (p.key === 'dnd') useNotificationStore.getState().setDnd(val);
      else if (p.key === 'focus') {
        useSystemStore.getState().set('focusMode', val);
        useNotificationStore.getState().setDnd(val);
      } else useSystemStore.getState().set(p.key as 'nightLight', val);
      return { text: `${p.label} is ${val ? 'on' : 'off'}.` };
    },
  },
  {
    id: 'level',
    describe: (p) => `Set ${p.label} to ${p.pct}%`,
    match: (t) => {
      const what = /\bbrightness|brighter|dimmer|dim\b/.test(t) ? 'brightness' : /\bvolume|louder|quieter|mute|unmute\b/.test(t) ? 'volume' : null;
      if (!what) return null;
      const cur = useSystemStore.getState()[what];
      let pct = Number(t.match(/(\d{1,3})\s*%?/)?.[1]);
      if (Number.isNaN(pct)) {
        if (/\bunmute\b/.test(t)) pct = 60;
        else if (/\bmute\b/.test(t)) pct = 0;
        else if (/\b(up|louder|brighter|increase|raise)\b/.test(t)) pct = Math.round(cur * 100) + 20;
        else if (/\b(down|quieter|dimmer|dim|decrease|lower)\b/.test(t)) pct = Math.round(cur * 100) - 20;
        else return null;
      }
      pct = Math.max(what === 'brightness' ? 30 : 0, Math.min(100, pct));
      return { key: what, pct, label: what };
    },
    run: (p) => {
      useSystemStore.getState().set(p.key as 'volume', Number(p.pct) / 100);
      return { text: `${String(p.label).charAt(0).toUpperCase() + String(p.label).slice(1)} set to ${p.pct}%.` };
    },
  },

  /* ───────── Windows & desktops ───────── */
  {
    id: 'tile',
    describe: () => 'Tile the windows on this desktop',
    match: (t) => (/\b(tile|arrange|organi[sz]e|tidy)\b.*\bwindows?\b|\bside by side\b/.test(t) ? {} : null),
    run: () => {
      commands.tileWindows();
      return { text: 'Windows tiled. Drag any one off its slot to free it again.' };
    },
  },
  {
    id: 'show-desktop',
    describe: () => 'Minimize all windows',
    match: (t) => (/\b(minimi[sz]e all|show (the )?desktop|hide (all|everything)|clear (the )?screen)\b/.test(t) ? {} : null),
    run: () => {
      commands.minimizeAll();
      return { text: 'Everything is minimized. Click an app in the dock to bring it back.' };
    },
  },
  {
    id: 'close-all',
    describe: () => 'Close all windows on this desktop',
    match: (t) => (/\bclose (all|every|everything)\b/.test(t) ? {} : null),
    run: () => {
      const s = useWindowStore.getState();
      const ids = Object.values(s.windows).filter((w) => w.desktopId === s.activeDesktopId && w.appId !== 'assistant').map((w) => w.id);
      ids.forEach((id) => s.closeWindow(id));
      return { text: `Closed ${ids.length} ${ids.length === 1 ? 'window' : 'windows'}.` };
    },
  },
  {
    id: 'overview',
    describe: () => 'Show all windows',
    match: (t) => (/\b(overview|show (all|me all) windows|expos[eé]|mission control|all my windows)\b/.test(t) ? {} : null),
    run: () => {
      useShellStore.getState().setOverview(true);
      return { text: 'Here are all your windows. Pick one, or press Escape.' };
    },
  },
  {
    id: 'desktop',
    describe: (p) => (p.move ? `Move ${p.app} to desktop ${p.n}` : p.n ? `Go to desktop ${p.n}` : 'Create a new desktop'),
    match: (t) => {
      if (!/\b(desktop|workspace|space)\b/.test(t)) return null;
      const n = Number(t.match(/\b(\d)\b/)?.[1] ?? NaN);
      const words = ['one', 'two', 'three', 'four', 'five'];
      const wn = words.findIndex((w) => new RegExp(`\\b${w}\\b`).test(t)) + 1;
      const num = Number.isNaN(n) ? wn || undefined : n;
      if (/\bmove|send|put\b/.test(t)) {
        const w = targetWindow(t);
        return w && num ? { move: true, n: num, windowId: w.id, app: getApp(w.appId).name } : null;
      }
      if (/\bnew|add|create|another\b/.test(t)) return {};
      return num ? { n: num } : null;
    },
    run: (p) => {
      const s = useWindowStore.getState();
      if (!p.n) {
        s.addDesktop();
        return { text: `Created ${useWindowStore.getState().desktops.at(-1)!.name}.` };
      }
      while (useWindowStore.getState().desktops.length < Number(p.n)) useWindowStore.getState().addDesktop();
      const desk = useWindowStore.getState().desktops[Number(p.n) - 1];
      if (p.move) {
        useWindowStore.getState().moveWindowToDesktop(String(p.windowId), desk.id);
        useWindowStore.getState().switchDesktop(desk.id);
        useWindowStore.getState().focusWindow(String(p.windowId));
        return { text: `Moved ${p.app} to ${desk.name}.` };
      }
      useWindowStore.getState().switchDesktop(desk.id);
      return { text: `Switched to ${desk.name}.` };
    },
  },
  {
    id: 'snap',
    describe: (p) => `${p.zone === 'maximize' ? 'Maximize' : `Snap to the ${p.zone}`} ${p.app}`,
    match: (t) => {
      const zone: SnapZone | undefined = /\bmaximi[sz]e|full ?screen|bigger\b/.test(t)
        ? 'maximize'
        : /\b(snap|move|put|dock)\b/.test(t) && /\bleft\b/.test(t)
          ? 'left'
          : /\b(snap|move|put|dock)\b/.test(t) && /\bright\b/.test(t)
            ? 'right'
            : undefined;
      if (!zone) return null;
      const w = targetWindow(t);
      const app = findApp(t);
      return { zone, windowId: w?.id, appId: app, app: w ? getApp(w.appId).name : app ? getApp(app).name : 'the window' };
    },
    run: (p) => {
      let id = p.windowId ? String(p.windowId) : undefined;
      if (!id && p.appId) id = open(p.appId as AppId);
      if (!id) return { text: 'Open a window first.' };
      useWindowStore.getState().snapWindow(id, p.zone as SnapZone);
      useWindowStore.getState().focusWindow(id);
      return { text: `${p.zone === 'maximize' ? 'Maximized' : `Snapped ${p.app} to the ${p.zone}`}${p.zone === 'maximize' ? ` ${p.app}` : ''}.` };
    },
  },
  {
    id: 'minimize',
    describe: (p) => `Minimize ${p.app}`,
    match: (t) => {
      if (!/\bminimi[sz]e|hide\b/.test(t)) return null;
      const w = targetWindow(t);
      return w ? { windowId: w.id, app: getApp(w.appId).name } : null;
    },
    run: (p) => {
      useWindowStore.getState().minimizeWindow(String(p.windowId));
      return { text: `Minimized ${p.app}.` };
    },
  },
  {
    id: 'close',
    describe: (p) => `Close ${p.app}`,
    match: (t) => {
      if (!/^(close|quit|exit|kill|end)\b/.test(t)) return null;
      const w = targetWindow(t);
      return w ? { windowId: w.id, app: getApp(w.appId).name } : null;
    },
    run: (p) => {
      useWindowStore.getState().closeWindow(String(p.windowId));
      return { text: `Closed ${p.app}.` };
    },
  },
  {
    id: 'lock',
    describe: () => 'Lock the screen',
    match: (t) => (/\b(lock (the )?(screen|computer|desktop)|lock it|lock up)\b|^lock$/.test(t) ? {} : null),
    run: () => {
      setTimeout(commands.lock, 600);
      return { text: 'Locking…' };
    },
  },

  /* ───────── System insight ───────── */
  {
    id: 'system',
    describe: (p) => `Check ${p.what}`,
    match: (t) => {
      if (/\b(cpu|processor|slow|lag|using|hogging|fan)\b/.test(t) && /\b(what|why|which|who|how|show|check)\b/.test(t)) return { what: 'cpu' };
      if (/\b(memory|ram)\b/.test(t)) return { what: 'memory' };
      if (/\b(battery|charge|power)\b/.test(t) && /\b(how|what|status|left|level)\b/.test(t)) return { what: 'battery' };
      if (/\b(storage|disk|space)\b/.test(t) && /\b(how|what|left|free|full)\b/.test(t)) return { what: 'storage' };
      return null;
    },
    run: (p) => {
      if (p.what === 'battery') return { text: 'Battery is at 82% with about 5 hours 40 minutes left at the current load.' };
      if (p.what === 'storage') {
        const used = allFiles().reduce((a, f) => a + (f.size ?? 0), 0);
        return { text: `612 GB free of 1 TB. Your home folder uses ${formatBytes(used)}; Downloads is the largest folder.`, actions: [{ label: 'Find large files', run: () => respond('find files larger than 50 MB', 'text') }] };
      }
      const m = snapshot();
      if (p.what === 'memory') {
        const mem = m.mem[m.mem.length - 1];
        const top = [...m.procs].sort((a, b) => b.mem - a.mem).slice(0, 4);
        return { text: `${mem.toFixed(1)} GB of ${TOTAL_MEM_GB} GB in use (${Math.round((mem / TOTAL_MEM_GB) * 100)}%). Biggest users:`, cards: [{ type: 'procs', procs: top }], actions: [{ label: 'Open Task Manager', run: () => open('tasks') }] };
      }
      const cpu = m.cpu[m.cpu.length - 1];
      const top = [...m.procs].sort((a, b) => b.cpu - a.cpu).slice(0, 4);
      return {
        text: `CPU is at ${Math.round(cpu)}%${cpu < 40 ? ' — plenty of headroom' : ''}. Top processes right now:`,
        cards: [{ type: 'procs', procs: top }],
        actions: [{ label: 'Open System Monitor', run: () => open('monitor') }],
      };
    },
  },
  {
    id: 'tips',
    describe: () => 'Suggest ways to work better',
    match: (t) => (/\b(tips?|suggestions?|recommend|productiv|help me focus|improve)\b/.test(t) ? {} : null),
    run: () => {
      const tips = currentRecommendations();
      return tips.length ? { text: 'A few things that could help right now:', cards: [{ type: 'tips', tips }] } : { text: "Everything looks in good shape. I'll speak up if something changes." };
    },
  },

  /* ───────── Apps (last: most generic) ───────── */
  {
    id: 'open',
    describe: (p) => `Open ${getApp(p.app as AppId).name}`,
    match: (t) => {
      if (!/\b(open|launch|start|run|show|go to|bring up)\b/.test(t)) return null;
      const app = findApp(t);
      return app ? { app } : null;
    },
    run: (p) => {
      const id = open(p.app as AppId);
      useWindowStore.getState().focusWindow(id);
      return { text: `Opened ${getApp(p.app as AppId).name}.` };
    },
  },
];

export function currentRecommendations() {
  const s = useWindowStore.getState();
  const now = new Date();
  const events = useCalendarStore.getState().events;
  const today = eventsOnDay(events, now);
  const next = events.filter((e) => e.start > now.getTime()).sort((a, b) => a.start - b.start)[0];
  const nodes = useFileStore.getState().nodes;
  const downloads = Object.values(nodes).find((n) => n.name === 'Downloads' && n.parentId === ROOT_ID);
  return recommendations({
    windowCount: Object.values(s.windows).filter((w) => w.desktopId === s.activeDesktopId && !w.minimized && !isHiddenTab(s, w)).length,
    desktops: s.desktops.length,
    meetingsToday: today.filter((e) => e.calendar === 'work').length,
    nextMeetingIn: next && eventsOnDay([next], now).length ? (next.start - now.getTime()) / 60_000 : undefined,
    focusFree: findFocusSlots(events, startOfWeek(now).getTime()).length > 0,
    downloadsCount: downloads ? childrenOf(nodes, downloads.id).filter((n) => n.kind !== 'folder').length : 0,
    hour: now.getHours(),
  });
}

/** Run a recommendation's command phrase. */
export function runCommand(phrase: string) {
  respond(phrase, 'text');
}

/** Split "open calendar and snap it left" into clauses that each resolve to an intent. */
function clauses(text: string) {
  return text
    .split(/\s*(?:,\s*then\s+|\s+and then\s+|\s+then\s+|\s+and\s+(?=(?:open|launch|snap|move|play|turn|set|close|maximi[sz]e|minimi[sz]e|tile|show|switch|go)\b)|;\s*)/)
    .map((c) => c.trim())
    .filter(Boolean);
}

export function normalizeText(text: string) {
  return text
    .toLowerCase()
    .replace(/[’']/g, "'")
    .replace(/[^\w\s:%'.\-@]/g, ' ')
    // Politeness and wake words only at the edges, so "what can you do" survives.
    .replace(/^(?:hey aurora|ok aurora|aurora)[,\s]+/, '')
    .replace(/^(?:please|could you|can you|would you|will you)\s+/, '')
    .replace(/\s+(?:please|for me|thanks|thank you)$/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export function interpret(text: string): { intent: Intent; params: Params } | null {
  const t = normalizeText(text);
  if (!t) return null;
  for (const intent of intents) {
    const params = intent.match(t);
    if (params) return { intent, params };
  }
  return null;
}

/** Interpret and execute. Multi-step commands run in order and their replies are merged. */
export function execute(text: string): AiReply {
  const parts = clauses(normalizeText(text));
  const replies: AiReply[] = [];
  for (const part of parts) {
    const hit = interpret(part);
    if (!hit) {
      replies.push(fallback(part));
      break;
    }
    replies.push(hit.intent.run(hit.params));
  }
  if (replies.length === 1) return replies[0];
  return {
    text: replies.map((r) => r.text).join(' '),
    cards: replies.flatMap((r) => r.cards ?? []),
    actions: replies.flatMap((r) => r.actions ?? []),
  };
}

function fallback(t: string): AiReply {
  return {
    text: `I'm not sure how to “${t}” yet. Try “help” to see what I can do, or search for it:`,
    actions: [{ label: `Search “${t}”`, run: () => useShellStore.getState().openSearch(t) }],
  };
}

/* Chat plumbing lives here so intents can post follow-ups (e.g. after an action button). */

export function respondInChat(reply: AiReply) {
  useAiStore.getState().push({ role: 'assistant', ...reply });
}

/** Full round-trip: record the user's message, "think" briefly, run, and reply. */
export function respond(text: string, via: 'voice' | 'text' | 'search' = 'text') {
  const store = useAiStore.getState();
  if (!useSystemStore.getState().aiEnabled) {
    store.push({ role: 'assistant', text: 'Aurora AI is turned off. You can turn it back on in Settings → Aurora AI.', actions: [{ label: 'Open Settings', run: () => open('settings', { section: 'ai' }) }] });
    return;
  }
  store.push({ role: 'user', text, via });
  store.setThinking(true);
  // A short beat so replies feel considered rather than instantaneous.
  setTimeout(() => {
    let reply: AiReply;
    try {
      reply = execute(text);
    } catch (err) {
      reply = { text: `Something went wrong while doing that (${(err as Error).message}).` };
    }
    useAiStore.getState().setThinking(false);
    respondInChat(reply);
  }, 420);
}
