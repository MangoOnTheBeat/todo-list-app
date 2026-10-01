import { useEffect, useState } from 'react';
import { useSystemStore } from '@/system/store/systemStore';

function useMediaQuery(query: string) {
  const [matches, setMatches] = useState(() => window.matchMedia(query).matches);
  useEffect(() => {
    const mq = window.matchMedia(query);
    const on = () => setMatches(mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, [query]);
  return matches;
}

/** Projects system preferences onto <html> as data-attributes and CSS variables. */
export function useThemeSync() {
  const { theme, accentHue, reduceTransparency, reduceMotion, glassIntensity } = useSystemStore();
  const prefersDark = useMediaQuery('(prefers-color-scheme: dark)');
  const prefersLessTransparency = useMediaQuery('(prefers-reduced-transparency: reduce)');
  const prefersLessMotion = useMediaQuery('(prefers-reduced-motion: reduce)');

  const resolved = theme === 'auto' ? (prefersDark ? 'dark' : 'light') : theme;

  useEffect(() => {
    const root = document.documentElement;
    root.dataset.theme = resolved;
    root.dataset.transparency = reduceTransparency || prefersLessTransparency ? 'reduced' : 'full';
    root.dataset.motion = reduceMotion || prefersLessMotion ? 'reduced' : 'full';
    root.style.setProperty('--accent-h', String(accentHue));
    // glassIntensity 0 → frosted/opaque, 1 → very clear.
    root.style.setProperty('--glass-alpha-user', `${Math.round(86 - glassIntensity * 44)}%`);
  }, [resolved, accentHue, reduceTransparency, prefersLessTransparency, reduceMotion, prefersLessMotion, glassIntensity]);

  return { resolvedTheme: resolved, reducedMotion: reduceMotion || prefersLessMotion };
}
