import { useState } from 'react';
import { motion } from 'motion/react';
import { useApp } from '../lib/store';
import { Copy } from '../lib/copy';
import f from './Form.module.css';
import s from './Auth.module.css';

export default function OrbSetup() {
  const completeFirstOrb = useApp((st) => st.completeFirstOrb);
  const toast = useApp((st) => st.toast);
  const [withPeople, setWithPeople] = useState(false);
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);

  const placeholder = withPeople
    ? Copy.orbs.crewPlaceholder
    : Copy.orbs.personalPlaceholder;

  async function continueSetup() {
    setBusy(true);
    try {
      await completeFirstOrb(name, withPeople);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t save this Orb');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className={s.wrap}>
      <h1 className={s.brand}>{Copy.orbs.setupTitle}</h1>
      <p className={s.lead}>{Copy.orbs.setupLead}</p>

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
              layoutId="orb-setup-kind-knob"
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
              layoutId="orb-setup-kind-knob"
              className={f.segmentKnob}
              transition={{ type: 'spring', stiffness: 520, damping: 38 }}
            />
          )}
          <span className={f.segmentLabel}>{Copy.orbs.withPeople}</span>
        </button>
      </div>

      <span className={f.label}>{Copy.orbs.orbName}</span>
      <div className={f.group}>
        <input
          className={f.input}
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
        <button
          type="button"
          className={`${f.btn} ${f.accent}`}
          disabled={busy}
          onClick={() => void continueSetup()}
        >
          {busy ? '…' : Copy.orbs.continue}
        </button>
      </div>
    </div>
  );
}
