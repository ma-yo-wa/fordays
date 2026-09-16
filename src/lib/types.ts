import type { CalendarSource } from './calendars';
import { todayISO } from './date';

export type { CalendarSource };

/* The whole model. One table serves both concepts: `date_time` being
   null is what makes an activity an Idea rather than a Plan. There is no
   type column and no status column, because there is no state to track
   beyond "does it have a date". */

export interface Activity {
  id: string;
  space_id?: string;
  title: string;
  description: string | null;
  location?: string | null;
  image_url: string | null;
  created_by: string;
  /** null => bucket-list item. Set => plan on the calendar. */
  date_time: string | null;
  /** When a plan runs past one day. null means it starts and ends the
   *  same day, which is almost everything, so it stays out of the way. */
  ends_at: string | null;
  all_day: boolean;
  /** Pending when-suggestion from one of you. Cleared on accept/dismiss
   *  / cancel / a direct date change. One at a time — not a thread. */
  suggested_date_time: string | null;
  suggested_ends_at: string | null;
  suggested_all_day: boolean;
  suggested_by: string | null;
  suggested_at: string | null;
  /** Optional why, travels with the suggestion. */
  suggested_note: string | null;
  created_at: string;
  updated_at?: string;
}

export type ActionType =
  | 'created'
  | 'scheduled'
  | 'rescheduled'
  | 'unscheduled'
  | 'edited'
  | 'deleted'
  | 'suggested'
  | 'suggestion_accepted'
  | 'suggestion_dismissed';

export interface WhenSuggestion {
  date_time: string;
  ends_at?: string | null;
  note?: string | null;
}

export interface AuditLog {
  id: string;
  activity_id: string;
  space_id?: string;
  user_id: string;
  action_type: ActionType;
  details: string;
  timestamp: string;
}

/* Imported calendar events. Overlaid, never merged into activities — a
   work meeting is not a thing you two agreed to do.

   `title` is nullable on purpose: it's how "share that I'm busy" and
   "share what I'm doing" stay one shape instead of two features. When
   it's null the row renders as Busy and the time is all anyone sees. */
export interface ExternalEvent {
  id: string;
  /** Whose calendar it came from. '0' | '1' locally, a profile uuid live. */
  ownerId: string;
  title: string | null;
  location: string | null;
  /** Local ISO: "YYYY-MM-DD" when all-day, else "YYYY-MM-DDTHH:MM". */
  startsAt: string;
  endsAt: string;
  allDay: boolean;
  calendar: string;
  /** google when missing — rows saved before migration 014. */
  source?: CalendarSource;
  sharedWithSpace?: boolean;
}

export interface Partner {
  id: string;
  name: string;
  color: string;
}

export interface PlanDraft {
  title?: string;
  notes?: string;
  location?: string;
  cover?: string | null;
  date?: string;
  from?: string;
  until?: string;
  endDate?: string | null;
  multiDay?: boolean;
}

export function planDraftFromExternal(e: ExternalEvent): PlanDraft {
  const startDate = e.startsAt.slice(0, 10);
  const rawEnd = e.endsAt ? e.endsAt.slice(0, 10) : null;
  const isMulti = Boolean(rawEnd && rawEnd > startDate);
  const startTime = e.allDay ? '' : (e.startsAt.length > 10 ? e.startsAt.slice(11, 16) : '');
  const endTime = e.allDay ? '' : (e.endsAt && e.endsAt.length > 10 ? e.endsAt.slice(11, 16) : '');

  return {
    title: e.title ?? '',
    location: e.location ?? '',
    notes: '',
    date: startDate,
    from: startTime,
    until: endTime,
    endDate: isMulti ? rawEnd : null,
    multiDay: isMulti,
  };
}

/** Whether an external event is ongoing today or upcoming (not already in the past). */
export function isExternalFutureOrToday(e: ExternalEvent, today?: string): boolean {
  const day = today ?? todayISO();
  const last = (e.endsAt || e.startsAt).slice(0, 10);
  return last >= day;
}

/* One nullable column is still the whole distinction — a bucket-list item
   becomes a plan the moment it gets a date, with nothing to migrate. */
export const isPlan = (a: Activity): boolean => Boolean(a.date_time);
export const isBucketItem = (a: Activity): boolean => !a.date_time;
export const isMultiDay = (a: Activity): boolean =>
  a.date_time !== null && a.ends_at !== null && a.ends_at.slice(0, 10) !== a.date_time.slice(0, 10);

/** Plans whose last day is before today — lived, not upcoming. */
export function isMemory(a: Activity, today?: string): boolean {
  if (!a.date_time) return false;
  const day = today ?? todayISO();
  const lastDay = (a.ends_at ?? a.date_time).slice(0, 10);
  return lastDay < day;
}
