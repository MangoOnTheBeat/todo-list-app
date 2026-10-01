import clsx from 'clsx';
import { motion, type HTMLMotionProps } from 'framer-motion';
import { springs } from '@/system/motion';

type Props = HTMLMotionProps<'button'> & { tone?: 'default' | 'accent' | 'danger'; size?: 'sm' | 'md' };

/** Pressable glass control with elastic press feedback. */
export function GlassButton({ className, tone = 'default', size = 'md', ...rest }: Props) {
  return (
    <motion.button
      whileHover={{ scale: 1.03 }}
      whileTap={{ scale: 0.95 }}
      transition={springs.snappy}
      className={clsx(
        'inline-flex items-center justify-center gap-2 rounded-[var(--radius-control)] font-medium outline-none transition-colors',
        size === 'sm' ? 'h-8 px-3 text-[13px]' : 'h-10 px-4 text-sm',
        tone === 'default' && 'glass-well text-fg hover:bg-[color-mix(in_oklab,var(--text-1)_10%,transparent)]',
        tone === 'accent' &&
          'bg-accent text-white shadow-[0_6px_20px_-6px_var(--color-accent),inset_0_1px_0_oklch(1_0_0/0.35)] hover:brightness-110',
        tone === 'danger' && 'bg-[oklch(0.62_0.2_25)] text-white hover:brightness-110',
        className,
      )}
      {...rest}
    />
  );
}
