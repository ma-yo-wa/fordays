import { useEffect, useState, useRef } from 'react';
import Sheet from './Sheet';
import {
  clearInviteFromUrl,
  extractInviteCode,
  peekInvite,
  type InvitePeek,
} from '../lib/auth';
import { useApp } from '../lib/store';
import { Copy } from '../lib/copy';
import { Button, Input, Card } from '../ui';
import f from './Form.module.css';

interface Props {
  code?: string;
  open: boolean;
  onJoined: () => void;
  onDismiss: () => void;
}

export default function InviteAccept({ code = '', open, onJoined, onDismiss }: Props) {
  const joinOrb = useApp((st) => st.joinOrb);
  const [input, setInput] = useState(code);
  const [peek, setPeek] = useState<InvitePeek | null>(null);
  const [lookingUp, setLookingUp] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const timerRef = useRef<number | null>(null);

  useEffect(() => {
    if (open) {
      setInput(code);
      setError(null);
      setPeek(null);
      setLookingUp(false);
    }
  }, [open, code]);

  useEffect(() => {
    if (!open) return;
    const cleaned = extractInviteCode(input);
    if (!cleaned || cleaned.length < 4) {
      setPeek(null);
      setError(null);
      setLookingUp(false);
      return;
    }

    if (timerRef.current) window.clearTimeout(timerRef.current);

    setLookingUp(true);
    setError(null);

    timerRef.current = window.setTimeout(() => {
      let cancelled = false;
      void peekInvite(cleaned)
        .then((p) => {
          if (cancelled) return;
          setLookingUp(false);
          if (!p) {
            setPeek(null);
            setError(Copy.invite.invalidCode);
            return;
          }
          setPeek(p);
          if (!p.isOpen) {
            setError(Copy.invite.closedOrb);
          }
        })
        .catch((err) => {
          if (!cancelled) {
            setLookingUp(false);
            setPeek(null);
            setError(err instanceof Error ? err.message : Copy.invite.invalidCode);
          }
        });

      return () => {
        cancelled = true;
      };
    }, 250);

    return () => {
      if (timerRef.current) window.clearTimeout(timerRef.current);
    };
  }, [input, open]);

  async function handlePaste() {
    try {
      const text = await navigator.clipboard.readText();
      if (text) setInput(text);
    } catch {
      // Clipboard permissions denied or unsupported
    }
  }

  async function accept() {
    const cleaned = extractInviteCode(input);
    if (!cleaned) return;
    setBusy(true);
    setError(null);
    try {
      await joinOrb(cleaned);
      clearInviteFromUrl();
      onJoined();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Couldn’t join');
    } finally {
      setBusy(false);
    }
  }

  const cleanedCode = extractInviteCode(input);
  const canJoin = !busy && !lookingUp && peek != null && peek.isOpen && cleanedCode.length >= 4;

  return (
    <Sheet
      open={open}
      onClose={() => {
        clearInviteFromUrl();
        onDismiss();
      }}
      heading={peek?.isOpen ? `${peek.inviterName} invited you` : Copy.invite.joinTitle}
    >
      <p className={f.rowNote} style={{ marginTop: 'var(--space-2)' }}>
        {peek?.isOpen
          ? `You’ll join ${peek.inviterName} in this Orb.`
          : Copy.invite.joinSubtitle}
      </p>

      <div style={{ marginTop: 'var(--space-4)' }}>
        <Input
          label={Copy.invite.codeOrLink}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder={Copy.invite.codePlaceholder}
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          enterKeyHint="done"
          clearable={Boolean(input)}
          onClear={() => setInput('')}
        />
        {typeof navigator !== 'undefined' && 'clipboard' in navigator && !input && (
          <Button
            variant="ghost"
            size="sm"
            onClick={() => void handlePaste()}
            style={{ marginTop: 'var(--space-2)' }}
          >
            {Copy.invite.paste}
          </Button>
        )}
      </div>

      {lookingUp && (
        <p className={f.rowNote} style={{ marginTop: 'var(--space-2)' }}>
          {Copy.invite.lookingUp}
        </p>
      )}

      {peek && peek.isOpen && (
        <Card variant="sageWash" padding="sm" style={{ marginTop: 'var(--space-3-5)' }}>
          <div className={f.peekTitle}>
            {peek.inviterName} invited you to {peek.spaceName ? `“${peek.spaceName}”` : 'their Orb'}
          </div>
          <div className={f.peekSub}>
            You’ll be added to this Orb and keep your existing Orbs.
          </div>
        </Card>
      )}

      {error && (
        <p className={f.rowNote} style={{ color: 'var(--rose-ink)', marginTop: 'var(--space-2-5)' }}>
          {error}
        </p>
      )}

      <div className={f.row} style={{ marginTop: 'var(--space-5)' }}>
        <Button
          variant="secondary"
          onClick={() => {
            clearInviteFromUrl();
            onDismiss();
          }}
        >
          {Copy.invite.notNow}
        </Button>
        <Button
          variant="primary"
          loading={busy}
          disabled={!canJoin}
          onClick={() => void accept()}
        >
          {busy ? Copy.invite.joining : Copy.invite.joinAction}
        </Button>
      </div>
    </Sheet>
  );
}
