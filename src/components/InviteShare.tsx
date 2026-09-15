import { useState } from 'react';
import Sheet from './Sheet';
import { inviteUrl } from '../lib/auth';
import { useApp } from '../lib/store';
import { Copy, formatCopy } from '../lib/copy';
import f from './Form.module.css';

interface Props {
  open: boolean;
  code: string;
  onClose: () => void;
}

export default function InviteShare({ open, code, onClose }: Props) {
  const create = useApp((st) => st.create);
  const toast = useApp((st) => st.toast);
  const space = useApp((st) => st.space);
  const spaces = useApp((st) => st.spaces);
  const [first, setFirst] = useState('');
  const [busy, setBusy] = useState(false);
  const link = inviteUrl(code);

  const allOrbs = spaces.length ? spaces : space ? [space] : [];
  const soloOrbs = allOrbs.filter((s) => !s.frozen && (s.members ?? []).length <= 1);
  const isPersonal = Boolean(
    space &&
    (space.members ?? []).length <= 1 &&
    (space.name.trim().toLowerCase() === 'personal' || soloOrbs.length <= 1)
  );

  if (isPersonal) {
    return null;
  }

  async function share() {
    setBusy(true);
    try {
      const idea = first.trim();
      if (idea) {
        await create({
          title: idea,
          description: null,
          date_time: null,
          ends_at: null,
        });
      }

      const text = idea
        ? formatCopy(Copy.invite.shareWithIdea, { idea, link }) + ` (code: ${code})`
        : formatCopy(Copy.invite.shareSolo, { link }) + ` (code: ${code})`;

      if (navigator.share) {
        await navigator.share({ title: 'Fordays', text, url: link });
      } else {
        await navigator.clipboard.writeText(text);
        toast(Copy.invite.linkCopied);
      }
      onClose();
    } catch (err) {
      // User cancelled the share sheet — not an error.
      if (err instanceof Error && err.name === 'AbortError') return;
      toast(err instanceof Error ? err.message : 'Couldn’t share');
    } finally {
      setBusy(false);
    }
  }

  async function copyCodeOnly() {
    try {
      await navigator.clipboard.writeText(code);
      toast(Copy.invite.codeCopied);
    } catch {
      toast('Couldn’t copy code');
    }
  }

  return (
    <Sheet open={open} onClose={onClose} heading={Copy.invite.title}>
      <p className={f.rowNote} style={{ marginTop: 8 }}>
        {Copy.invite.subtitle}
      </p>

      {code && (
        <div className={f.codeBox}>
          <div className={f.codeInfo}>
            <span className={f.codeLabel}>{Copy.invite.orbCodeLabel}</span>
            <span className={f.codeValue}>{code}</span>
          </div>
          <button type="button" className={f.copyPill} onClick={() => void copyCodeOnly()}>
            {Copy.invite.copyCode}
          </button>
        </div>
      )}

      <span className={f.label} style={{ marginTop: 16 }}>
        {Copy.invite.ideaLabel}{' '}
        <span className={f.hint}>{Copy.invite.ideaHint}</span>
      </span>
      <div className={f.group}>
        <input
          className={f.input}
          value={first}
          onChange={(e) => setFirst(e.target.value)}
          placeholder="Kayak the Grand River"
          enterKeyHint="done"
        />
      </div>

      <div className={f.row}>
        <button type="button" className={`${f.btn} ${f.ghost}`} onClick={onClose}>
          {Copy.invite.notNow}
        </button>
        <button
          type="button"
          className={`${f.btn} ${f.accent}`}
          disabled={busy}
          onClick={() => void share()}
        >
          {busy ? '…' : Copy.invite.shareInvite}
        </button>
      </div>
    </Sheet>
  );
}
