import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import {
  clearInviteFromUrl,
  joinInvite,
  peekInvite,
  type InvitePeek,
} from '../lib/auth';
import f from './Form.module.css';

interface Props {
  code: string;
  open: boolean;
  onJoined: () => void;
  onDismiss: () => void;
}

export default function InviteAccept({ code, open, onJoined, onDismiss }: Props) {
  const [peek, setPeek] = useState<InvitePeek | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!open || !code) return;
    let cancelled = false;
    setError(null);
    setPeek(null);
    void peekInvite(code)
      .then((p) => {
        if (cancelled) return;
        if (!p) {
          setError('That invite isn’t valid. Ask for a fresh link.');
          return;
        }
        setPeek(p);
      })
      .catch((err) => {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Couldn’t look up that invite');
        }
      });
    return () => {
      cancelled = true;
    };
  }, [open, code]);

  async function accept() {
    setBusy(true);
    setError(null);
    try {
      await joinInvite(code);
      clearInviteFromUrl();
      onJoined();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Couldn’t join');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Sheet
      open={open}
      onClose={() => {
        clearInviteFromUrl();
        onDismiss();
      }}
      heading={peek ? `${peek.inviterName} invited you` : 'Join a space'}
    >
      <p className={f.rowNote} style={{ marginTop: 8 }}>
        {peek?.isOpen === false
          ? 'This space is closed'
          : peek
            ? `You’ll share this notebook with ${peek.inviterName}`
            : 'Looking up the invite…'}
      </p>
      <div className={f.row}>
        <button
          type="button"
          className={`${f.btn} ${f.ghost}`}
          onClick={() => {
            clearInviteFromUrl();
            onDismiss();
          }}
        >
          Not now
        </button>
        <button
          type="button"
          className={`${f.btn} ${f.accent}`}
          disabled={busy || !peek?.isOpen}
          onClick={() => void accept()}
        >
          {busy ? 'Joining…' : 'Join'}
        </button>
      </div>

      {error && (
        <p className={f.rowNote} style={{ color: 'var(--rose-ink)', marginTop: 12 }}>
          {error}
        </p>
      )}
    </Sheet>
  );
}
