import { motion } from 'framer-motion';

/** The assistant's mark: a slowly turning conic "aurora" sphere. Pulses while active. */
export function AuroraOrb({ size = 28, active = false, className = '' }: { size?: number; active?: boolean; className?: string }) {
  return (
    <motion.span
      aria-hidden
      className={`relative inline-block shrink-0 rounded-full ${className}`}
      style={{ width: size, height: size }}
      animate={active ? { scale: [1, 1.12, 1] } : { scale: 1 }}
      transition={active ? { duration: 1.2, repeat: Infinity, ease: 'easeInOut' } : { duration: 0.3 }}
    >
      <motion.span
        className="absolute inset-0 rounded-full"
        style={{ background: 'conic-gradient(from 0deg, oklch(0.8 0.14 200), var(--color-accent), oklch(0.75 0.18 340), oklch(0.85 0.12 160), oklch(0.8 0.14 200))', filter: `blur(${size / 14}px)` }}
        animate={{ rotate: 360 }}
        transition={{ duration: active ? 3 : 10, repeat: Infinity, ease: 'linear' }}
      />
      <span className="absolute inset-[18%] rounded-full" style={{ background: 'radial-gradient(circle at 35% 30%, oklch(1 0 0 / 0.95), oklch(1 0 0 / 0.25) 45%, transparent 70%)' }} />
    </motion.span>
  );
}
