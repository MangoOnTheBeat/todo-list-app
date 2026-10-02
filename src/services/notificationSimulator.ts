import { useNotificationStore } from '@/system/store/notificationStore';

const MIN = 60_000;

/**
 * Seeds a realistic notification backlog and drips a few live ones in over the first
 * minutes, so the shell can be explored without a real event source.
 */
let seeded = false;

export function startNotificationSimulator() {
  const { post } = useNotificationStore.getState();
  const t0 = Date.now();

  // Seed once per page load (React StrictMode mounts effects twice in development).
  if (!seeded) {
    seeded = true;
    post({ appId: 'files', title: 'Download complete', body: 'glass-shaders.zip (88 MB) is in Downloads.', silent: true, time: t0 - 3 * MIN, actions: [{ label: 'Show in Files', open: 'files' }] });
    post({ appId: 'calendar', title: 'Tomorrow · 9:30 AM', body: 'Quarterly planning with the platform team. Room: Atrium 3.', silent: true, time: t0 - 22 * MIN, actions: [{ label: 'Open Calendar', open: 'calendar' }] });
    post({ appId: 'store', title: '3 app updates ready', body: 'Horizon, Resonance and Notes have updates.', priority: 'low', silent: true, time: t0 - 64 * MIN });
  }

  const timers = [
    setTimeout(
      () =>
        post({
          appId: 'calendar',
          title: 'Design review in 15 minutes',
          body: 'Aurora shell walkthrough · Studio B · 4 attendees',
          priority: 'high',
          actions: [{ label: 'Join', open: 'calendar' }, { label: 'Snooze' }],
        }),
      7_000,
    ),
    setTimeout(
      () =>
        post({
          appId: 'assistant',
          title: 'Your morning summary is ready',
          body: '2 meetings, 1 deadline today, and 4 unread threads that mention you.',
          actions: [{ label: 'Read summary', open: 'assistant' }],
        }),
      28_000,
    ),
    setTimeout(
      () =>
        post({
          appId: 'notes',
          title: 'Shared note updated',
          body: 'Mina edited “Offsite Agenda” — added a dinner reservation.',
          priority: 'low',
          actions: [{ label: 'Open', open: 'notes' }],
        }),
      75_000,
    ),
  ];
  return () => timers.forEach(clearTimeout);
}
