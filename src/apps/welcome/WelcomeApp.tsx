import { motion } from 'framer-motion';
import { Moon, Sun, SunMoon } from 'lucide-react';
import clsx from 'clsx';
import { AppIcon } from '@/components/ui/AppIcon';
import { GlassButton } from '@/components/ui/GlassButton';
import { SHORTCUTS } from '@/hooks/useGlobalShortcuts';
import { allApps } from '@/system/appRegistry';
import { springs } from '@/system/motion';
import { ACCENT_PRESETS, useSystemStore, type ThemePref } from '@/system/store/systemStore';
import { useWindowStore } from '@/system/store/windowStore';
import type { AppProps } from '@/system/types';

const stagger = { animate: { transition: { staggerChildren: 0.05, delayChildren: 0.1 } } };
const item = { initial: { opacity: 0, y: 14 }, animate: { opacity: 1, y: 0, transition: springs.panel } };

export default function WelcomeApp(_: AppProps) {
  const { theme, setTheme, accentHue, setAccentHue, glassIntensity, set } = useSystemStore();
  const openApp = useWindowStore((s) => s.openApp);

  return (
    <motion.div variants={stagger} initial="initial" animate="animate" className="h-full overflow-y-auto px-8 pb-8 pt-2">
      <motion.header variants={item} className="mb-7">
        <p className="text-xs font-medium uppercase tracking-[0.2em] text-accent">Phase 1 · Foundation</p>
        <h1
          className="mt-2 bg-clip-text text-4xl font-semibold tracking-tight text-transparent"
          style={{ backgroundImage: 'linear-gradient(100deg, var(--text-1) 30%, var(--color-accent) 70%, oklch(0.8 0.15 200))' }}
        >
          Welcome to Aurora
        </h1>
        <p className="mt-2 max-w-xl text-[15px] leading-relaxed text-fg-muted">
          A spatial, glass-first desktop. Windows are physical objects: grab one and fling it toward an edge to snap it,
          drag it off again to tear it free, or spread work across virtual desktops.
        </p>
      </motion.header>

      <div className="grid gap-5 md:grid-cols-[1.15fr_1fr]">
        <motion.section variants={item} className="glass-well p-5" aria-labelledby="w-appearance">
          <h2 id="w-appearance" className="text-sm font-semibold">Appearance</h2>

          <div className="mt-4 flex gap-1 rounded-xl p-1 glass-well" role="radiogroup" aria-label="Theme">
            {(
              [
                ['light', Sun, 'Light'],
                ['dark', Moon, 'Dark'],
                ['auto', SunMoon, 'Auto'],
              ] as [ThemePref, typeof Sun, string][]
            ).map(([value, Icon, label]) => (
              <button
                key={value}
                role="radio"
                aria-checked={theme === value}
                onClick={() => setTheme(value)}
                className={clsx(
                  'relative flex h-9 flex-1 items-center justify-center gap-2 rounded-lg text-[13px] font-medium',
                  theme === value ? 'text-fg' : 'text-fg-muted hover:text-fg',
                )}
              >
                {theme === value && (
                  <motion.span layoutId="welcome-theme" transition={springs.snappy} className="glass absolute inset-0 rounded-lg" />
                )}
                <Icon className="relative size-4" />
                <span className="relative">{label}</span>
              </button>
            ))}
          </div>

          <p className="mt-5 text-xs font-medium text-fg-subtle">Accent</p>
          <div className="mt-2 flex gap-2.5" role="radiogroup" aria-label="Accent colour">
            {ACCENT_PRESETS.map((p) => (
              <motion.button
                key={p.hue}
                role="radio"
                aria-checked={accentHue === p.hue}
                aria-label={p.name}
                title={p.name}
                whileHover={{ scale: 1.15 }}
                whileTap={{ scale: 0.9 }}
                transition={springs.elastic}
                onClick={() => setAccentHue(p.hue)}
                className="size-7 rounded-full"
                style={{
                  background: `oklch(0.7 0.16 ${p.hue})`,
                  boxShadow:
                    accentHue === p.hue
                      ? `0 0 0 2px var(--glass-tint), 0 0 0 4px oklch(0.7 0.16 ${p.hue}), 0 0 16px oklch(0.7 0.16 ${p.hue})`
                      : 'inset 0 1px 0 oklch(1 0 0 / 0.4)',
                }}
              />
            ))}
          </div>

          <label className="mt-5 block text-xs font-medium text-fg-subtle" htmlFor="w-glass">
            Glass clarity
          </label>
          <input
            id="w-glass"
            type="range"
            min={0}
            max={1}
            step={0.01}
            value={glassIntensity}
            onChange={(e) => set('glassIntensity', Number(e.target.value))}
            className="mt-2 w-full accent-[var(--color-accent)]"
          />
        </motion.section>

        <motion.section variants={item} className="glass-well p-5" aria-labelledby="w-keys">
          <h2 id="w-keys" className="text-sm font-semibold">Window shortcuts</h2>
          <dl className="mt-3 space-y-2">
            {SHORTCUTS.map((s) => (
              <div key={s.keys} className="flex items-center justify-between gap-3 text-[13px]">
                <dt className="text-fg-muted">{s.action}</dt>
                <dd className="flex gap-1">
                  {s.keys.split(' ').map((k) => (
                    <kbd key={k} className="glass rounded-md px-1.5 py-0.5 font-mono text-[11px] text-fg">
                      {k}
                    </kbd>
                  ))}
                </dd>
              </div>
            ))}
          </dl>
        </motion.section>
      </div>

      <motion.section variants={item} className="mt-5" aria-labelledby="w-apps">
        <div className="mb-3 flex items-center justify-between">
          <h2 id="w-apps" className="text-sm font-semibold">Try the window system</h2>
          <GlassButton size="sm" tone="accent" onClick={() => ['files', 'browser', 'notes'].forEach((id) => openApp(id as never))}>
            Open three windows
          </GlassButton>
        </div>
        <div className="grid grid-cols-4 gap-2 sm:grid-cols-6">
          {allApps
            .filter((a) => a.id !== 'welcome')
            .map((a) => (
              <motion.button
                key={a.id}
                whileHover={{ y: -3 }}
                whileTap={{ scale: 0.94 }}
                transition={springs.snappy}
                onClick={() => openApp(a.id)}
                className="flex flex-col items-center gap-1.5 rounded-xl p-2 hover:bg-[color-mix(in_oklab,var(--text-1)_6%,transparent)]"
              >
                <AppIcon appId={a.id} size={40} />
                <span className="w-full truncate text-center text-[11px] text-fg-muted">{a.name}</span>
              </motion.button>
            ))}
        </div>
      </motion.section>
    </motion.div>
  );
}
