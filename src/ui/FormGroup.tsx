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
  icon?: React.ReactNode;
  destructive?: boolean;
  children?: React.ReactNode;
  onClick?: () => void;
}

export const FormRow: React.FC<FormRowProps> = ({
  label,
  note,
  icon,
  destructive = false,
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
        {icon && (
          <div className={`${s.icon} ${destructive ? s.iconDestructive : ''}`}>
            {icon}
          </div>
        )}
        <div className={s.textStack}>
          <div className={`${s.label} ${destructive ? s.labelDestructive : ''}`}>{label}</div>
          {note && <div className={s.note}>{note}</div>}
        </div>
      </div>
      {children && <div className={s.right}>{children}</div>}
    </div>
  );
};
