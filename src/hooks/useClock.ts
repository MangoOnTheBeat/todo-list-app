import { useEffect, useState } from 'react';

/** Current time, re-rendering on the minute boundary (or every second if asked). */
export function useClock(precision: 'minute' | 'second' = 'minute') {
  const [now, setNow] = useState(() => new Date());
  useEffect(() => {
    let t: ReturnType<typeof setTimeout>;
    const tick = () => {
      const d = new Date();
      setNow(d);
      const ms = precision === 'second' ? 1000 - d.getMilliseconds() : 60_000 - (d.getSeconds() * 1000 + d.getMilliseconds());
      t = setTimeout(tick, ms + 5);
    };
    tick();
    return () => clearTimeout(t);
  }, [precision]);
  return now;
}
