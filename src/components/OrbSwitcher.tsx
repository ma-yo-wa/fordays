import { useEffect, useState } from 'react';
import Sheet from './Sheet';
import OrbKindForm from './OrbKindForm';
import OrbFaces, { orbFaceChips } from './OrbFaces';
import { useApp, spaceOrbName } from '../lib/store';
import type { SpaceInfo } from '../lib/auth';
import { Copy } from '../lib/copy';
import { ActionRow, FormGroup, FormRow } from '../ui';
import f from './Form.module.css';
import ui from './Settings.module.css';
import auth from './Auth.module.css';

/* The drawer behind the Orb name: switch Orbs, start or join one, and a
   way into this Orb's settings. Everything else lives in Settings. */
export default function OrbSwitcher() {
  const open = useApp((st) => st.switcherOpen);
  const setOpen = useApp((st) => st.setSwitcherOpen);
  const space = useApp((st) => st.space);
  const spaces = useApp((st) => st.spaces);
  const switchToSpace = useApp((st) => st.switchToSpace);
  const addSpace = useApp((st) => st.addSpace);
  const openOrbSettings = useApp((st) => st.openOrbSettings);
  const setJoinOrbOpen = useApp((st) => st.setJoinOrbOpen);
  const toast = useApp((st) => st.toast);

  const [making, setMaking] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!open) setMaking(false);
  }, [open]);

  const allOrbs = spaces.length ? spaces : space ? [space] : [];
  const activeOrbs = allOrbs.filter((s) => !s.frozen);

  async function pick(next: SpaceInfo) {
    if (busy) return;
    setOpen(false);
    if (next.id === space?.id) return;
    setBusy(true);
    try {
      await switchToSpace(next.id);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t switch');
    } finally {
      setBusy(false);
    }
  }

  async function make(name: string, withPeople: boolean) {
    if (busy) return;
    setBusy(true);
    try {
      await addSpace(name, withPeople);
      setOpen(false);
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Couldn’t make an Orb');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Sheet
      open={open}
      onClose={() => setOpen(false)}
      heading={making ? Copy.orbs.startNew : Copy.orbs.yourOrbs}
    >
      {making ? (
        <div>
          <button type="button" className={ui.navBack} onClick={() => setMaking(false)}>
            ← {Copy.orbs.yourOrbs}
          </button>
          <p className={auth.lead}>{Copy.orbs.setupLead}</p>
          <OrbKindForm knobId="orb-switcher-kind-knob" onSubmit={make} />
        </div>
      ) : (
        <>
          {space?.frozen && (
            <div className={ui.frozenBanner}>
              <p className={ui.frozenBannerText}>{Copy.orbs.viewingFrozenBanner}</p>
              {activeOrbs[0] && (
                <button
                  type="button"
                  className={ui.frozenBannerBtn}
                  onClick={() => void pick(activeOrbs[0]!)}
                >
                  {Copy.orbs.switchBackToActive}
                </button>
              )}
            </div>
          )}

          <div className={`${ui.orbGrid} ${ui.switcherGrid}`}>
            {activeOrbs.map((orb) => {
              const on = orb.id === space?.id;
              return (
                <button
                  key={orb.id}
                  type="button"
                  className={`${ui.orbTile} ${on ? ui.orbTileOn : ''}`}
                  disabled={busy}
                  aria-current={on ? 'true' : undefined}
                  title={spaceOrbName(orb) || undefined}
                  onClick={() => void pick(orb)}
                >
                  <span className={ui.orbCircle}>
                    <OrbFaces faces={orbFaceChips(orb)} />
                  </span>
                  <span className={ui.orbTileName}>{spaceOrbName(orb) || ' '}</span>
                </button>
              );
            })}
          </div>

          {space && (
            <FormGroup className={ui.section}>
              <FormRow
                label={`${spaceOrbName(space) || Copy.orbs.thisOrb} settings`}
                onClick={() => openOrbSettings(space.id)}
              >
                <span className={f.hint}>›</span>
              </FormRow>
            </FormGroup>
          )}

          <div className={ui.section}>
            <ActionRow
              icon="+"
              label={Copy.orbs.startNew}
              note={Copy.orbs.startNewNote}
              onClick={() => setMaking(true)}
            />
            <ActionRow
              icon="→"
              label={Copy.orbs.joinWithCode}
              note={Copy.orbs.joinWithCodeNote}
              onClick={() => {
                setOpen(false);
                setJoinOrbOpen(true);
              }}
            />
          </div>
        </>
      )}
    </Sheet>
  );
}
