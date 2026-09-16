import React from 'react';
import s from './FormGroup.module.css';

export interface FormGroupProps extends React.HTMLAttributes<HTMLDivElement> {
  header?: React.ReactNode;
  footer?: React.ReactNode;
  children: React.ReactNode;
}

export const FormGroup: React.FC<FormGroupProps> = ({
  header,
  footer,
  children,
  className = '',
  ...rest
}) => {
  return (
    <div className={`${s.wrapper} ${className}`.trim()} {...rest}>
      {header && <div className={s.header}>{header}</div>}
      <div className={s.group}>{children}</div>
      {footer && <div className={s.footer}>{footer}</div>}
    </div>
  );
};

export interface FormRowProps extends React.HTMLAttributes<HTMLDivElement> {
  label: React.ReactNode;
  note?: React.ReactNode;
  children?: React.ReactNode;
  onClick?: () => void;
}

export const FormRow: React.FC<FormRowProps> = ({
  label,
  note,
  children,
  onClick,
  className = '',
  ...rest
}) => {
  const isInteractive = Boolean(onClick);

  return (
    <div
      className={`${s.row} ${isInteractive ? s.rowInteractive : ''} ${className}`.trim()}
      onClick={onClick}
      role={isInteractive ? 'button' : undefined}
      tabIndex={isInteractive ? 0 : undefined}
      {...rest}
    >
      <div className={s.left}>
        <div className={s.label}>{label}</div>
        {note && <div className={s.note}>{note}</div>}
      </div>
      {children && <div className={s.right}>{children}</div>}
    </div>
  );
};
