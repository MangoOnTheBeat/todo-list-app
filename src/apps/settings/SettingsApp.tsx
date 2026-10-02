import { useState } from 'react';
import { motion } from 'framer-motion';
import { Accessibility, Bell, Info, Keyboard, LayoutDashboard, Monitor, Moon, Palette, Sparkles, Sun, SunMoon } from 'lucide-react';
import clsx from 'clsx';
import { AppLayout, SidebarItem, SidebarSection, Toggle } from '@/components/ui/AppKit';
import { AppIcon } from '@/components/ui/AppIcon';
import { Slider } from '@/components/ui/Slider';
import { SHORTCUTS } from '@/hooks/useGlobalShortcuts';
import { allApps } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { useNotificationStore } from '@/system/store/notificationStore';
import { ACCENT_PRESETS, useSystemStore, WALLPAPERS, type ThemePref } from '@/system/store/systemStore';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppProps } from '@/system/types';

type Section = 'appearance' | 'display' | 'desktop' | 'notifications' | 'ai' | 'accessibility' | 'keyboard' | 'about';

const SECTIONS: { id: Section; label: string; icon: typeof Palette }[] = [
  { id: 'appearance', label: 'Appearance', icon: Palette },
  { id: 'display', label: 'Displays', icon: Monitor },
  { id: 'desktop', label: 'Desktop & Dock', icon: LayoutDashboard },
  { id: 'notifications', label: 'Notifications', icon: Bell },
  { id: 'ai', label: 'Aurora AI', icon: Sparkles },
  { id: 'accessibility', label: 'Accessibility', icon: Accessibility },
  { id: 'keyboard', label: 'Keyboard', icon: Keyboard },
  { id: 'about', label: 'About', icon: Info },
];

export default function SettingsApp({ windowId, args }: AppProps) {
  const [section, setSection] = useState<Section>((args?.section as Section) ?? 'appearance');
  const current = SECTIONS.find((s) => s.id === section)!;

  const sidebar = (
    <SidebarSection>
      {SECTIONS.map((s) => (
        <SidebarItem key={s.id} layoutGroup={`settings-${windowId}`} icon={s.icon} label={s.label} active={section === s.id} onClick={() => setSection(s.id)} />
      ))}
    </SidebarSection>
  );

  return (
    <AppLayout sidebar={sidebar} sidebarWidth={200}>
      {/* Narrow windows: sections become a scrolling chip row. */}
      <nav aria-label="Settings sections" className="flex shrink-0 gap-1 overflow-x-auto border-b hairline px-3 py-2 @[560px]:hidden">
        {SECTIONS.map((s) => (
          <button key={s.id} onClick={() => setSection(s.id)} className={clsx('shrink-0 rounded-full px-3 py-1 text-xs font-medium', section === s.id ? 'bg-accent-fill text-white' : 'glass-well text-fg-muted')}>
            {s.label}
          </button>
        ))}
      </nav>
      <motion.div key={section} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} transition={springs.panel} className="min-h-0 flex-1 overflow-y-auto px-6 pb-8 pt-5">
        <h1 className="mb-5 text-xl font-semibold tracking-tight">{current.label}</h1>
        <div className="max-w-2xl space-y-5">
          {section === 'appearance' && <AppearanceSection />}
          {section === 'display' && <DisplaySection />}
          {section === 'desktop' && <DesktopSection />}
          {section === 'notifications' && <NotificationsSection />}
          {section === 'ai' && <AISection />}
          {section === 'accessibility' && <AccessibilitySection />}
          {section === 'keyboard' && <KeyboardSection />}
          {section === 'about' && <AboutSection />}
        </div>
      </motion.div>
    </AppLayout>
  );
}

function Group({ title, children, footer }: { title?: string; children: React.ReactNode; footer?: string }) {
  return (
    <section>
      {title && <h2 className="mb-2 px-1 text-xs font-semibold uppercase tracking-[0.1em] text-fg-subtle">{title}</h2>}
      <div className="glass-well divide-y divide-[var(--glass-border)] overflow-hidden rounded-2xl">{children}</div>
      {footer && <p className="mt-1.5 px-1 text-[11px] leading-relaxed text-fg-subtle">{footer}</p>}
    </section>
  );
}

function Row({ label, detail, children, htmlFor }: { label: string; detail?: string; children: React.ReactNode; htmlFor?: string }) {
  return (
    <div className="flex min-h-12 items-center gap-4 px-4 py-2.5">
      <div className="min-w-0 flex-1">
        <label htmlFor={htmlFor} className="block text-[13px] font-medium">
          {label}
        </label>
        {detail && <p className="text-[11px] leading-snug text-fg-subtle">{detail}</p>}
      </div>
      {children}
    </div>
  );
}

function PrefToggle({ k, label, detail }: { k: 'reduceMotion' | 'reduceTransparency' | 'dockMagnification' | 'nightLight' | 'aiEnabled' | 'aiSmartNotifications' | 'aiSuggestions' | 'aiVoice' | 'dualDisplay' | 'focusMode'; label: string; detail?: string }) {
  const value = useSystemStore((s) => s[k]);
  const set = useSystemStore((s) => s.set);
  const id = `pref-${k}`;
  return (
    <Row label={label} detail={detail} htmlFor={id}>
      <Toggle id={id} label={label} checked={value} onChange={(v) => set(k, v)} />
    </Row>
  );
}

function AppearanceSection() {
  const { theme, setTheme, accentHue, setAccentHue, glassIntensity, wallpaper, set } = useSystemStore();
  return (
    <>
      <Group title="Theme">
        <div className="grid grid-cols-3 gap-3 p-4">
          {(
            [
              ['light', Sun, 'Light'],
              ['dark', Moon, 'Dark'],
              ['auto', SunMoon, 'Automatic'],
            ] as [ThemePref, typeof Sun, string][]
          ).map(([value, Icon, label]) => (
            <button key={value} onClick={() => setTheme(value)} aria-pressed={theme === value} className="group text-center">
              <span
                className={clsx('relative block aspect-[4/3] overflow-hidden rounded-xl border-2 transition-colors', theme === value ? 'border-accent' : 'border-transparent group-hover:border-[var(--glass-border)]')}
                style={{
                  background:
                    value === 'light'
                      ? 'linear-gradient(135deg, oklch(0.92 0.05 220), oklch(0.88 0.07 300))'
                      : value === 'dark'
                        ? 'linear-gradient(135deg, oklch(0.32 0.08 220), oklch(0.25 0.1 300))'
                        : 'linear-gradient(135deg, oklch(0.92 0.05 220) 50%, oklch(0.25 0.1 300) 50%)',
                }}
              >
                <span className={clsx('absolute inset-x-3 bottom-3 top-4 rounded-md border', value === 'dark' ? 'border-white/15 bg-white/10' : 'border-white/60 bg-white/50')} />
              </span>
              <span className="mt-1.5 flex items-center justify-center gap-1 text-xs font-medium">
                <Icon className="size-3" />
                {label}
              </span>
            </button>
          ))}
        </div>
      </Group>

      <Group title="Accent colour">
        <div className="flex flex-wrap gap-3 p-4" role="radiogroup" aria-label="Accent colour">
          {ACCENT_PRESETS.map((p) => (
            <button key={p.hue} role="radio" aria-checked={accentHue === p.hue} onClick={() => setAccentHue(p.hue)} className="flex flex-col items-center gap-1.5">
              <span
                className="size-8 rounded-full transition-shadow"
                style={{
                  background: `oklch(0.66 0.16 ${p.hue})`,
                  boxShadow: accentHue === p.hue ? `0 0 0 2px var(--glass-tint), 0 0 0 4px oklch(0.66 0.16 ${p.hue})` : 'inset 0 1px 0 oklch(1 0 0 / 0.4)',
                }}
              />
              <span className="text-[11px] text-fg-muted">{p.name}</span>
            </button>
          ))}
        </div>
      </Group>

      <Group title="Wallpaper">
        <div className="grid grid-cols-2 gap-3 p-4 sm:grid-cols-5" role="radiogroup" aria-label="Wallpaper">
          {WALLPAPERS.map((w) => (
            <button key={w.id} role="radio" aria-checked={wallpaper === w.id} onClick={() => set('wallpaper', w.id)} className="text-center">
              <span className={clsx('block aspect-video rounded-lg border-2 transition-colors', wallpaper === w.id ? 'border-accent' : 'border-transparent')} style={{ background: w.preview }} />
              <span className="mt-1 block text-[11px] font-medium">{w.name}</span>
            </button>
          ))}
        </div>
      </Group>

      <Group title="Glass" footer="Clearer glass shows more of what's behind a window. Focused windows are always a little more solid than background ones.">
        <div className="px-4 py-3">
          <p className="mb-2 text-[13px] font-medium">Clarity</p>
          <Slider label="Glass clarity" icon={Palette} value={glassIntensity} onChange={(v) => set('glassIntensity', v)} />
        </div>
        <PrefToggle k="reduceTransparency" label="Reduce transparency" detail="Replace glass with solid surfaces" />
      </Group>
    </>
  );
}

function DisplaySection() {
  const { brightness, set } = useSystemStore();
  const displays = useWindowStore((s) => s.displays);
  return (
    <>
      <Group title="Arrangement">
        <div className="flex items-end justify-center gap-3 p-6">
          {displays.map((d) => (
            <div key={d.id} className="text-center">
              <div className={clsx('grid place-items-center rounded-lg border-2 text-[11px] font-medium', d.primary ? 'border-accent bg-accent-soft' : 'border-[var(--glass-border)] glass-well')} style={{ width: Math.max(90, d.bounds.w / 9), height: Math.max(56, d.bounds.h / 9) }}>
                {d.bounds.w} × {d.bounds.h}
              </div>
              <p className="mt-1.5 text-xs">{d.name}</p>
            </div>
          ))}
        </div>
      </Group>
      <Group footer="Splits this screen into two displays so you can try moving windows between monitors. Each display gets its own work area, snapping and maximize.">
        <PrefToggle k="dualDisplay" label="Simulate a second display" />
      </Group>
      <Group title="Brightness">
        <div className="px-4 py-3">
          <Slider label="Brightness" icon={Sun} value={brightness} min={0.3} onChange={(v) => set('brightness', v)} />
        </div>
        <PrefToggle k="nightLight" label="Night Light" detail="Warmer colours to reduce blue light in the evening" />
      </Group>
    </>
  );
}

function DesktopSection() {
  const desktops = useWindowStore((s) => s.desktops);
  const { addDesktop, removeDesktop } = useWindowStore.getState();
  return (
    <>
      <Group title="Dock">
        <PrefToggle k="dockMagnification" label="Magnify icons on hover" />
      </Group>
      <Group title="Session" footer="Aurora restores your windows, desktops and tab groups when you come back.">
        <Row label="Start fresh" detail="Close every window and remove extra desktops">
          <button onClick={() => useWindowStore.getState().resetSession()} className="rounded-lg bg-[color-mix(in_oklab,var(--text-1)_9%,transparent)] px-3 py-1.5 text-xs font-medium hover:bg-[color-mix(in_oklab,var(--text-1)_15%,transparent)]">
            Reset desktop
          </button>
        </Row>
      </Group>
      <Group title="Virtual desktops" footer="Ctrl + Alt + ← / → switches desktops. Add Shift to take the focused window with you.">
        {desktops.map((d) => (
          <Row key={d.id} label={d.name}>
            {desktops.length > 1 && (
              <button onClick={() => removeDesktop(d.id)} className="text-xs text-fg-muted hover:text-fg">
                Remove
              </button>
            )}
          </Row>
        ))}
        <div className="px-4 py-2.5">
          <button onClick={addDesktop} className="text-[13px] font-medium text-accent">
            Add desktop
          </button>
        </div>
      </Group>
    </>
  );
}

function NotificationsSection() {
  const { dnd, setDnd } = useNotificationStore();
  return (
    <>
      <Group footer="Time-sensitive notifications, like a meeting about to start, still break through.">
        <Row label="Do Not Disturb" detail="Hold banners; notifications still collect in the center" htmlFor="pref-dnd">
          <Toggle id="pref-dnd" label="Do Not Disturb" checked={dnd} onChange={setDnd} />
        </Row>
        <PrefToggle k="focusMode" label="Focus mode" detail="Do Not Disturb plus a quieter dock" />
      </Group>
      <Group title="Apps">
        {allApps
          .filter((a) => a.id !== 'welcome')
          .map((a) => (
            <Row key={a.id} label={a.name} detail="Banners and sounds">
              <AppIcon appId={a.id} size={24} />
            </Row>
          ))}
      </Group>
    </>
  );
}

function AISection() {
  return (
    <>
      <div className="flex items-start gap-3 rounded-2xl bg-accent-soft p-4">
        <Sparkles className="mt-0.5 size-5 shrink-0 text-accent" />
        <p className="text-[13px] leading-relaxed">
          Aurora AI runs on this device. It reads window titles, file names and your calendar to make suggestions, and nothing leaves the machine.
        </p>
      </div>
      <Group>
        <PrefToggle k="aiEnabled" label="Aurora AI" detail="Assistant, natural-language search and smart actions" />
        <PrefToggle k="aiSmartNotifications" label="Smart notifications" detail="Rank by urgency, bundle low-priority items, and summarise the backlog" />
        <PrefToggle k="aiSuggestions" label="Proactive suggestions" detail="Context-aware actions and productivity tips" />
        <PrefToggle k="aiVoice" label="Voice commands" detail="Push-to-talk with Ctrl + Alt + V where speech recognition is available" />
      </Group>
    </>
  );
}

function AccessibilitySection() {
  return (
    <Group footer="Aurora also follows your operating system's reduced-motion and reduced-transparency settings.">
      <PrefToggle k="reduceMotion" label="Reduce motion" detail="Replace springs with instant transitions and pause the wallpaper" />
      <PrefToggle k="reduceTransparency" label="Reduce transparency" detail="Solid surfaces instead of glass" />
      <PrefToggle k="dockMagnification" label="Dock magnification" />
    </Group>
  );
}

function KeyboardSection() {
  return (
    <Group>
      {SHORTCUTS.map((s) => (
        <Row key={s.keys} label={s.action}>
          <span className="flex gap-1">
            {s.keys.split(' ').map((k) => (
              <kbd key={k} className="glass rounded-md px-1.5 py-0.5 font-mono text-[11px]">
                {k}
              </kbd>
            ))}
          </span>
        </Row>
      ))}
    </Group>
  );
}

function AboutSection() {
  return (
    <>
      <div className="flex items-center gap-4 p-2">
        <AppIcon appId="welcome" size={64} />
        <div>
          <p className="text-lg font-semibold tracking-tight">Aurora OS</p>
          <p className="text-xs text-fg-subtle">Version 1.0 “Borealis” · Concept build</p>
        </div>
      </div>
      <Group>
        {[
          ['Processor', 'Aurora N3 · 8 cores'],
          ['Memory', '32 GB unified'],
          ['Graphics', 'Integrated, 16-core'],
          ['Storage', '1 TB · 612 GB free'],
          ['Display', `${window.innerWidth} × ${window.innerHeight} @ ${window.devicePixelRatio}x`],
        ].map(([k, v]) => (
          <Row key={k} label={k}>
            <span className="text-[13px] text-fg-muted">{v}</span>
          </Row>
        ))}
      </Group>
      <p className="px-1 text-[11px] text-fg-subtle">Built with React, TypeScript, Tailwind CSS and Framer Motion. A design concept — not affiliated with any operating system vendor.</p>
    </>
  );
}
