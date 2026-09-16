import { AnimatePresence, motion } from 'motion/react';
import { useApp } from '../lib/store';
import { scaleToast, springToast, yToast, yToastExit } from '../ui/motion';
import s from './Toasts.module.css';

export default function Toasts() {
  const toasts = useApp((st) => st.toasts);

  return (
    <div className={s.wrap} role="status" aria-live="polite">
      <AnimatePresence initial={false}>
        {toasts.map((t) => (
          <motion.div
            key={t.id}
            className={s.toast}
            initial={{ opacity: 0, y: yToast, scale: scaleToast }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: yToastExit, scale: scaleToast }}
            transition={springToast}
          >
            {t.text}
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
