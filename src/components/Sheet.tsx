import { AnimatePresence, motion, useDragControls } from 'motion/react';
import { useEffect, type ReactNode } from 'react';
import {
  durationSheet,
  durationSheetFade,
  durationSheetSlide,
  easeIos,
  easeSheet,
  sheetDismissVelocity,
  sheetDismissY,
  sheetDragElastic,
} from '../ui/motion';
import s from './Sheet.module.css';

interface Props {
  open: boolean;
  onClose: () => void;
  eyebrow?: string;
  heading?: string;
  children: ReactNode;
}

export default function Sheet({
  open,
  onClose,
  eyebrow,
  heading,
  children,
}: Props) {
  const dragControls = useDragControls();

  // A sheet that leaves the page scrollable behind it feels like a web
  // page, not an app.
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener('keydown', onKey);
    };
  }, [open, onClose]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          className={s.veil}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: durationSheet, ease: easeIos }}
          onClick={(e) => {
            if (e.target === e.currentTarget) onClose();
          }}
        >
          <motion.div
            className={s.sheet}
            initial={{ y: '100%' }}
            animate={{ y: 0 }}
            exit={{ y: '100%' }}
            transition={{
              y: { type: 'tween', duration: durationSheetSlide, ease: easeSheet },
              opacity: { duration: durationSheetFade, ease: easeIos },
            }}
            drag="y"
            dragControls={dragControls}
            dragListener={false}
            dragConstraints={{ top: 0, bottom: 0 }}
            dragElastic={{ top: 0, bottom: sheetDragElastic }}
            onDragEnd={(_, info) => {
              // Flick down, or drag more than a third of the way: dismiss.
              if (info.offset.y > sheetDismissY || info.velocity.y > sheetDismissVelocity) onClose();
            }}
          >
            {/* Only the grabber starts a dismiss drag — scrolling the
                form (icon grids, notes) must not close the sheet. */}
            <div
              className={s.gripHit}
              onPointerDown={(e) => dragControls.start(e)}
              aria-hidden
            >
              <div className={s.grip} />
            </div>
            <div className={s.scroller}>
              {eyebrow && <div className={s.eyebrow}>{eyebrow}</div>}
              {heading && <h3 className={s.heading}>{heading}</h3>}
              {children}
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
