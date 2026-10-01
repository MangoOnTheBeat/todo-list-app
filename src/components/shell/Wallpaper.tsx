/**
 * Generative "aurora" wallpaper: four large blurred colour fields drifting on long,
 * de-synchronised loops over a deep base, plus a faint grain. Pure CSS — it runs on the
 * compositor and costs nothing on the main thread. Colours come from theme tokens.
 */
export function Wallpaper() {
  const blob = 'aurora-blob absolute rounded-full will-change-transform';
  return (
    <div aria-hidden className="absolute inset-0 overflow-hidden" style={{ background: 'var(--wall-base)' }}>
      <div className="absolute inset-[-20%]" style={{ filter: 'blur(90px) saturate(130%)' }}>
        <div
          className={blob}
          style={{ left: '5%', top: '0%', width: '55%', height: '60%', background: 'var(--wall-1)', animation: 'aurora-drift-a 38s ease-in-out infinite' }}
        />
        <div
          className={blob}
          style={{ right: '0%', top: '10%', width: '50%', height: '65%', background: 'var(--wall-2)', animation: 'aurora-drift-b 46s ease-in-out infinite' }}
        />
        <div
          className={blob}
          style={{ left: '30%', bottom: '0%', width: '50%', height: '50%', background: 'var(--wall-3)', animation: 'aurora-drift-c 54s ease-in-out infinite' }}
        />
        <div
          className={blob}
          style={{ left: '0%', bottom: '5%', width: '35%', height: '40%', background: 'var(--wall-4)', animation: 'aurora-drift-b 62s ease-in-out infinite reverse' }}
        />
      </div>
      {/* Soft vignette for depth, then grain to kill banding in the gradients. */}
      <div className="absolute inset-0" style={{ background: 'radial-gradient(120% 90% at 50% 30%, transparent 50%, oklch(0 0 0 / 0.22))' }} />
      <div
        className="absolute inset-0 opacity-[0.07] mix-blend-overlay"
        style={{
          backgroundImage:
            "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='220' height='220'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.8' numOctaves='3' stitchTiles='stitch'/></filter><rect width='100%' height='100%' filter='url(%23n)'/></svg>\")",
        }}
      />
    </div>
  );
}
