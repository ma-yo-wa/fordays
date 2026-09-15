import { useEffect, useState } from 'react';
import {
  authConfigured,
  friendlyAuthError,
  MISSING_BACKEND,
  requestPasswordReset,
  signInWithPassword,
  signUpWithPassword,
  updatePassword,
} from '../lib/auth';
import f from './Form.module.css';
import s from './Auth.module.css';

interface Props {
  onSignedIn: () => void | Promise<void>;
  /** Shown when they arrived via invite before signing in. */
  inviterHint?: string | null;
  inviteSpaceName?: string | null;
  /** Open directly on the new-password screen (reset-link session). */
  startInRecovery?: boolean;
}

type Mode = 'signin' | 'signup' | 'forgot' | 'recover' | 'sent';

export default function Auth({
  onSignedIn,
  inviterHint,
  inviteSpaceName,
  startInRecovery,
}: Props) {
  const [mode, setMode] = useState<Mode>(startInRecovery ? 'recover' : 'signin');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (startInRecovery) {
      setMode('recover');
      setError(null);
      setPassword('');
    }
  }, [startInRecovery]);

  async function submit() {
    if (!authConfigured()) {
      setError(MISSING_BACKEND);
      return;
    }

    const clean = email.trim();
    if (mode === 'forgot') {
      setBusy(true);
      setError(null);
      try {
        await requestPasswordReset(clean);
        setMode('sent');
      } catch (err) {
        setError(friendlyAuthError(err));
      } finally {
        setBusy(false);
      }
      return;
    }

    if (mode === 'recover') {
      setBusy(true);
      setError(null);
      try {
        await updatePassword(password);
        await onSignedIn();
      } catch (err) {
        setError(friendlyAuthError(err));
      } finally {
        setBusy(false);
      }
      return;
    }

    if (!clean || !clean.includes('@')) {
      setError('That doesn’t look like an email');
      return;
    }
    if (mode === 'signup' && !name.trim()) {
      setError('Add your name — it shows on your avatar');
      return;
    }
    if (password.length < 6) {
      setError('Password needs at least 6 characters');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (mode === 'signup') await signUpWithPassword(clean, password, name);
      else await signInWithPassword(clean, password);
      await onSignedIn();
    } catch (err) {
      setError(friendlyAuthError(err));
    } finally {
      setBusy(false);
    }
  }

  if (mode === 'sent') {
    return (
      <div className={s.wrap}>
        <h1 className={s.brand}>Fordays</h1>
        <p className={s.lead}>Check your email for a reset link — open it on this phone</p>
        <div className={f.row}>
          <button
            type="button"
            className={`${f.btn} ${f.ghost}`}
            onClick={() => {
              setMode('signin');
              setError(null);
            }}
          >
            Back to sign in
          </button>
        </div>
      </div>
    );
  }

  if (mode === 'recover') {
    return (
      <div className={s.wrap}>
        <h1 className={s.brand}>Fordays</h1>
        <p className={s.lead}>Choose a new password</p>

        <span className={f.label}>New password</span>
        <div className={f.group}>
          <input
            className={f.input}
            type="password"
            autoComplete="new-password"
            placeholder="••••••••"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') void submit();
            }}
          />
        </div>

        <div className={f.row}>
          <button
            type="button"
            className={`${f.btn} ${f.accent}`}
            disabled={busy}
            onClick={() => void submit()}
          >
            {busy ? '…' : 'Save password'}
          </button>
        </div>

        {error && <p className={s.error}>{error}</p>}
      </div>
    );
  }

  if (mode === 'forgot') {
    return (
      <div className={s.wrap}>
        <h1 className={s.brand}>Fordays</h1>
        <p className={s.lead}>We’ll email a link to reset your password</p>

        <span className={f.label}>Email</span>
        <div className={f.group}>
          <input
            className={f.input}
            type="email"
            inputMode="email"
            autoComplete="email"
            autoCapitalize="none"
            spellCheck={false}
            placeholder="you@example.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') void submit();
            }}
          />
        </div>

        <div className={f.row}>
          <button
            type="button"
            className={`${f.btn} ${f.accent}`}
            disabled={busy}
            onClick={() => void submit()}
          >
            {busy ? '…' : 'Send reset link'}
          </button>
        </div>

        <button
          type="button"
          className={s.back}
          onClick={() => {
            setMode('signin');
            setError(null);
          }}
        >
          Back to sign in
        </button>

        {error && <p className={s.error}>{error}</p>}
      </div>
    );
  }

  return (
    <div className={s.wrap}>
      <h1 className={s.brand}>Fordays</h1>
      <p className={s.lead}>
        {inviterHint
          ? mode === 'signup'
            ? inviteSpaceName
              ? `${inviterHint} invited you to “${inviteSpaceName}”`
              : `${inviterHint} invited you to an Orb`
            : inviteSpaceName
              ? `${inviterHint} invited you to “${inviteSpaceName}” — sign in to join`
              : `${inviterHint} invited you — sign in to join`
          : 'Plans, Bucket lists and Memories'}
      </p>

      {mode === 'signup' && (
        <>
          <span className={f.label}>Your name</span>
          <div className={f.group}>
            <input
              className={f.input}
              type="text"
              autoComplete="name"
              autoCapitalize="words"
              placeholder="Aline"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </div>
        </>
      )}

      <span className={f.label}>Email</span>
      <div className={f.group}>
        <input
          className={f.input}
          type="email"
          inputMode="email"
          autoComplete="email"
          autoCapitalize="none"
          spellCheck={false}
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
        />
      </div>

      <span className={f.label}>Password</span>
      <div className={f.group}>
        <input
          className={f.input}
          type="password"
          autoComplete={mode === 'signup' ? 'new-password' : 'current-password'}
          placeholder="••••••••"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') void submit();
          }}
        />
      </div>

      <div className={f.row}>
        <button
          type="button"
          className={`${f.btn} ${f.accent}`}
          disabled={busy}
          onClick={() => void submit()}
        >
          {busy
            ? '…'
            : mode === 'signup'
              ? inviterHint
                ? `Join ${inviterHint}`
                : 'Create account'
              : inviterHint
                ? 'Sign in & join'
                : 'Sign in'}
        </button>
      </div>

      {mode === 'signin' && (
        <button
          type="button"
          className={s.forgot}
          onClick={() => {
            setMode('forgot');
            setError(null);
          }}
        >
          Forgot password?
        </button>
      )}

      <p className={s.alt}>
        {mode === 'signup' ? (
          <>
            Already have an account?{' '}
            <button
              type="button"
              onClick={() => {
                setMode('signin');
                setError(null);
              }}
            >
              Sign in
            </button>
          </>
        ) : (
          <>
            Don’t have an account?{' '}
            <button
              type="button"
              onClick={() => {
                setMode('signup');
                setError(null);
              }}
            >
              Sign up
            </button>
          </>
        )}
      </p>

      {error && <p className={s.error}>{error}</p>}
    </div>
  );
}
