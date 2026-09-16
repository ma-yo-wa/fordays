import { useState } from 'react';
import { motion } from 'motion/react';
import { Copy } from '../lib/copy';
import { Button, Input } from '../ui';
import f from './Form.module.css';
import s from './Auth.module.css';

interface Props {
  knobId: string;
  initialWithPeople?: boolean;
  onSubmit: (name: string, withPeople: boolean) => Promise<void>;
}

export default function OrbKindForm({ knobId, initialWithPeople = false, onSubmit }: Props) {
  const [withPeople, setWithPeople] = useState(initialWithPeople);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);

  const placeholder = withPeople
    ? Copy.orbs.crewPlaceholder
    : Copy.orbs.personalPlaceholder;

  async function continueSetup() {
    if (busy || !name.trim()) return;
    setBusy(true);
    try {
      await onSubmit(name, withPeople);
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <div className={`${f.segmented} ${s.kinds}`} role="tablist" aria-label="Who this Orb is for">
        <button
          type="button"
          role="tab"
          aria-selected={!withPeople}
          className={`${f.segment} ${!withPeople ? f.segmentOn : ''}`}
          onClick={() => setWithPeople(false)}
        >
          {!withPeople && (
            <motion.span
              layoutId={knobId}
              className={f.segmentKnob}
              transition={{ type: 'spring', stiffness: 520, damping: 38 }}
            />
          )}
          <span className={f.segmentLabel}>{Copy.orbs.justYou}</span>
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={withPeople}
          className={`${f.segment} ${withPeople ? f.segmentOn : ''}`}
          onClick={() => setWithPeople(true)}
        >
          {withPeople && (
            <motion.span
              layoutId={knobId}
              className={f.segmentKnob}
              transition={{ type: 'spring', stiffness: 520, damping: 38 }}
            />
          )}
          <span className={f.segmentLabel}>{Copy.orbs.withSomeone || Copy.orbs.withPeople}</span>
        </button>
      </div>

      <div style={{ marginTop: 20 }}>
        <Input
          label={Copy.orbs.orbName}
          type="text"
          autoComplete="off"
          autoCapitalize="words"
          placeholder={placeholder}
          value={name}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') void continueSetup();
          }}
        />
      </div>

      <div className={f.row}>
        <Button
          variant="primary"
          loading={busy}
          disabled={busy || !name.trim()}
          onClick={() => void continueSetup()}
        >
          {withPeople
            ? Copy.orbs.invitePerson
            : Copy.orbs.startPlanning}
        </Button>
      </div>
    </>
  );
}
