import { AnimatePresence, motion } from 'motion/react';
import { useEffect } from 'react';
import { durationShelf, springActionSheet, yActionSheet } from '../ui/motion';
import s from './ActionSheet.module.css';

export interface ActionSheetAction {
  label: string;
  danger?: boolean;
  disabled?: boolean;
  onClick: () => void | Promise<void>;
}

export interface ActionSheetProps {
  open: boolean;
  title?: string;
  message?: string;
  actions: ActionSheetAction[];
  cancelLabel?: string;
  onCancel: () => void;
}

/**
 * Native iOS Action Sheet (Confirmation Dialog) for destructive or irrevocable
 * decisions (e.g. Leave Orb, Delete, Purge, Discard).
 *
 * Rules:
 * - Locked to the bottom above the home indicator.
 * - Zero grabber bar.
 * - Non-draggable (not a navigation drawer).
 * - Separated Cancel block below actions.
 */
export default function ActionSheet({
  open,
  title,
  message,
  actions,
  cancelLabel = 'Cancel',
  onCancel,
}: ActionSheetProps) {
  useEffect(() => {
    if (!open) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel();
    };
    window.addEventListener('keydown', onKey);
    return () => {
      document.body.style.overflow = prev;
      window.removeEventListener('keydown', onKey);
    };
  }, [open, onCancel]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          className={s.veil}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: durationShelf, ease: 'easeOut' }}
          onClick={(e) => {
            if (e.target === e.currentTarget) onCancel();
          }}
        >
          <motion.div
            className={s.wrap}
            initial={{ y: yActionSheet, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: yActionSheet, opacity: 0 }}
            transition={springActionSheet}
          >
            <div className={s.card}>
              {(title || message) && (
                <>
                  <div className={s.header}>
                    {title && <h3 className={s.title}>{title}</h3>}
                    {message && <p className={s.message}>{message}</p>}
                  </div>
                  <div className={s.divider} />
                </>
              )}

              {actions.map((act, idx) => (
                <div key={act.label + idx}>
                  {idx > 0 && <div className={s.divider} />}
                  <button
                    type="button"
                    className={`${s.actionBtn} ${act.danger ? s.danger : ''}`}
                    disabled={act.disabled}
                    onClick={() => {
                      void act.onClick();
                    }}
                  >
                    {act.label}
                  </button>
                </div>
              ))}
            </div>

            <button
              type="button"
              className={s.cancelBtn}
              onClick={onCancel}
            >
              {cancelLabel}
            </button>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
