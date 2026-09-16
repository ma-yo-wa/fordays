/** Motion tokens. Numbers live here — never inline in components. */

export const easeIos = [0.25, 0.1, 0.25, 1] as const;
export const easeSheet = [0.32, 0.72, 0, 1] as const;

export const springSwitch = { type: 'spring' as const, stiffness: 700, damping: 40 };
export const springSelect = { type: 'spring' as const, stiffness: 520, damping: 38 };
export const springTab = { type: 'spring' as const, stiffness: 480, damping: 38 };
export const springTap = { type: 'spring' as const, stiffness: 600, damping: 30 };
export const springToast = { type: 'spring' as const, stiffness: 420, damping: 34 };
export const springActionSheet = { type: 'spring' as const, damping: 28, stiffness: 380 };

export const durationFade = 0.18;
export const durationShelf = 0.2;
export const durationSheet = 0.24;
export const durationSheetSlide = 0.38;
export const durationSheetFade = 0.22;

export const ySearch = 15;
export const yToast = 12;
export const yToastExit = 8;
export const yActionSheet = 80;

export const scalePressIcon = 0.9;
export const scaleToast = 0.96;

export const sheetDismissY = 140;
export const sheetDismissVelocity = 700;
export const sheetDragElastic = 0.5;
