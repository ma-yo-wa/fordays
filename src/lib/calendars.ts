/** Where an imported overlay row came from. Orb plans are not this. */
export type CalendarSource = 'google' | 'apple' | 'outlook';

export interface ImportedCalendar {
  id: string;
  summary: string;
  primary: boolean;
  /** owner | writer | reader — used to group “Mine” vs “Other”. */
  accessRole: 'owner' | 'writer' | 'reader' | string;
}

export function isCalendarSource(v: unknown): v is CalendarSource {
  return v === 'google' || v === 'apple' || v === 'outlook';
}
