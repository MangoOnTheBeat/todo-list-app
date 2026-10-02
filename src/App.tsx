import { useEffect } from 'react';
import { MotionConfig } from 'framer-motion';
import { Desktop } from '@/components/shell/Desktop';
import { useDisplaySync } from '@/hooks/useDisplaySync';
import { useMediaClock } from '@/hooks/useMediaClock';
import { startNotificationSimulator } from '@/services/notificationSimulator';
import { useGlobalShortcuts } from '@/hooks/useGlobalShortcuts';
import { useThemeSync } from '@/hooks/useThemeSync';
import { useWindowStore } from '@/system/store/windowStore';

export function App() {
  const { reducedMotion } = useThemeSync();
  useDisplaySync();
  useGlobalShortcuts();
  useMediaClock();

  useEffect(() => startNotificationSimulator(), []);

  // First boot: greet with the Welcome app.
  useEffect(() => {
    const t = setTimeout(() => {
      if (Object.keys(useWindowStore.getState().windows).length === 0) useWindowStore.getState().openApp('welcome');
    }, 450);
    return () => clearTimeout(t);
  }, []);

  return (
    <MotionConfig reducedMotion={reducedMotion ? 'always' : 'user'}>
      <Desktop />
    </MotionConfig>
  );
}
