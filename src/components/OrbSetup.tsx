import { useApp } from '../lib/store';
import { Copy } from '../lib/copy';
import OrbKindForm from './OrbKindForm';
import s from './Auth.module.css';

export default function OrbSetup() {
  const completeFirstOrb = useApp((st) => st.completeFirstOrb);
  const toast = useApp((st) => st.toast);

  return (
    <div className={s.wrap}>
      <h1 className={s.brand}>{Copy.orbs.setupTitle}</h1>
      <p className={s.lead}>{Copy.orbs.setupLead}</p>
      <OrbKindForm
        knobId="orb-setup-kind-knob"
        onSubmit={async (name, withPeople) => {
          try {
            await completeFirstOrb(name, withPeople);
          } catch (err) {
            toast(err instanceof Error ? err.message : 'Couldn’t save this Orb');
          }
        }}
      />
    </div>
  );
}
