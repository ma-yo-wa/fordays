import { useState } from 'react';
import Sheet from './Sheet';
import { inviteUrl, isHomeSoloName } from '../lib/auth';
import { useApp } from '../lib/store';
import { Copy, formatCopy } from '../lib/copy';
import { Button, Input, Pill } from '../ui';
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
    (isHomeSoloName(space.name, space.myName) || soloOrbs.length <= 1)
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
        // Saved once: clearing the field means a second Share doesn't add it again.
        setFirst('');
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
      <p className={f.rowNote} style={{ marginTop: 'var(--space-2)' }}>
        {Copy.invite.subtitle}
      </p>

      {code && (
        <div className={f.codeBox}>
          <div className={f.codeInfo}>
            <span className={f.codeLabel}>{Copy.invite.orbCodeLabel}</span>
            <span className={f.codeValue}>{code}</span>
          </div>
          <Pill variant="neutral" size="sm" onClick={() => void copyCodeOnly()}>
            {Copy.invite.copyCode}
          </Pill>
        </div>
      )}

      <div style={{ marginTop: 'var(--space-4)' }}>
        <Input
          label={Copy.invite.ideaLabel}
          hint={Copy.invite.ideaHint}
          value={first}
          onChange={(e) => setFirst(e.target.value)}
          placeholder="Kayak the Grand River"
          enterKeyHint="done"
        />
      </div>

      <div className={f.row}>
        <Button variant="secondary" fullWidth onClick={onClose}>
          {Copy.invite.notNow}
        </Button>
        <Button
          variant="primary"
          fullWidth
          loading={busy}
          disabled={busy}
          onClick={() => void share()}
        >
          {Copy.invite.shareInvite}
        </Button>
      </div>
    </Sheet>
  );
}
