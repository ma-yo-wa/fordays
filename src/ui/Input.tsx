import React, { forwardRef, useState } from 'react';
import s from './Input.module.css';

export interface InputProps
  extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'size'> {
  label?: string;
  hint?: string;
  error?: string;
  clearable?: boolean;
  onClear?: () => void;
  multiline?: boolean;
  rows?: number;
}

export const Input = forwardRef<HTMLInputElement | HTMLTextAreaElement, InputProps>(
  function Input(
    {
      label,
      hint,
      error,
      clearable = false,
      onClear,
      multiline = false,
      rows = 3,
      className = '',
      value,
      onFocus,
      onBlur,
      ...rest
    },
    ref,
  ) {
    const [isFocused, setIsFocused] = useState(false);

    const handleFocus = (
      e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement>,
    ) => {
      setIsFocused(true);
      if (onFocus) {
        (onFocus as React.FocusEventHandler<HTMLInputElement | HTMLTextAreaElement>)(e);
      }
    };

    const handleBlur = (
      e: React.FocusEvent<HTMLInputElement | HTMLTextAreaElement>,
    ) => {
      setIsFocused(false);
      if (onBlur) {
        (onBlur as React.FocusEventHandler<HTMLInputElement | HTMLTextAreaElement>)(e);
      }
    };

    const hasValue = value !== undefined && value !== null && String(value).length > 0;

    const containerClasses = [
      s.container,
      isFocused ? s.containerFocus : '',
      error ? s.containerError : '',
    ]
      .filter(Boolean)
      .join(' ');

    return (
      <div className={`${s.wrapper} ${className}`.trim()}>
        {(label || hint) && (
          <div className={s.labelRow}>
            {label && <span className={s.label}>{label}</span>}
            {hint && <span className={s.hint}>{hint}</span>}
          </div>
        )}
        <div className={containerClasses}>
          {multiline ? (
            <textarea
              ref={ref as React.Ref<HTMLTextAreaElement>}
              className={s.input}
              value={value}
              rows={rows}
              onFocus={handleFocus}
              onBlur={handleBlur}
              {...(rest as React.TextareaHTMLAttributes<HTMLTextAreaElement>)}
            />
          ) : (
            <input
              ref={ref as React.Ref<HTMLInputElement>}
              className={s.input}
              value={value}
              onFocus={handleFocus}
              onBlur={handleBlur}
              {...rest}
            />
          )}
          {clearable && hasValue && (
            <button
              type="button"
              className={s.clearBtn}
              onClick={onClear}
              aria-label="Clear field"
            >
              ×
            </button>
          )}
        </div>
        {error && <span className={s.errorText}>{error}</span>}
      </div>
    );
  },
);
