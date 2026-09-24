export const MONTHS = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
export const MON3 = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
export const DAYS = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];
export const DAYS3 = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export function mediumDate(dateISO: string): string {
  const d = parseISO(dateISO);
  return `${DAYS3[d.getDay()]}, ${MON3[d.getMonth()]} ${d.getDate()}`;
}

export const pad = (n: number) => String(n).padStart(2, '0');

/** Local-date ISO (YYYY-MM-DD). Deliberately not toISOString(), which
 *  converts to UTC and can hand back yesterday. */
export function iso(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function todayISO(): string {
  return iso(new Date());
}

/** Parse YYYY-MM-DD as a *local* date, not UTC midnight. */
export function parseISO(s: string): Date {
  const [y, m, d] = s.slice(0, 10).split('-').map(Number);
  return new Date(y ?? 1970, (m ?? 1) - 1, d ?? 1);
}

/** The date half of a stored date_time. */
export function dtDate(v: string | null): string | null {
  return v ? v.slice(0, 10) : null;
}

/** The time half, or null when the plan is all-day. */
export function dtTime(v: string | null): string | null {
  if (!v || v.length <= 10) return null;
  return v.slice(11, 16);
}

export function addDays(n: number, from = new Date()): string {
  const d = new Date(from);
  d.setDate(d.getDate() + n);
  return iso(d);
}

/** Next Saturday. Never today, so "this weekend" always points forward. */
export function nextSaturday(): string {
  const offset = (6 - new Date().getDay() + 7) % 7 || 7;
  return addDays(offset);
}

/** 18:30 -> "6:30 PM" */
export function pretty(time: string): string {
  const [hRaw, m] = time.split(':').map(Number);
  const h = hRaw ?? 0;
  const suffix = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 === 0 ? 12 : h % 12;
  return `${h12}:${pad(m ?? 0)} ${suffix}`;
}

/** 18:30 -> "6:30 pm" — the agenda sets time lowercase, so it recedes
 *  behind the title instead of competing with it. */
export function prettyLower(time: string): string {
  return pretty(time).replace('AM', 'am').replace('PM', 'pm');
}

/**
 * Apple Calendar's Next Half-Hour Rule for default start time:
 * - Never schedules in the past or mid-minute.
 * - Always rounds up to the next clean half-hour block (:00 or :30).
 * - Cutoff buffer: if the current minute is exactly on a half-hour mark
 *   (e.g. 10:00 or 10:30), it assumes a typing buffer is needed and pushes
 *   forward by 30 minutes (e.g. 10:00 -> 10:30, 10:30 -> 11:00).
 * - Returns 24h "HH:MM".
 */
export function defaultAppleStartTime(now = new Date()): string {
  const currentH = now.getHours();
  const currentM = now.getMinutes();
  let h = currentH;
  let m = 0;
  if (currentM < 30) {
    m = 30;
  } else {
    h = h + 1;
    m = 0;
  }
  // Past 11:30 pm the next half-hour is tomorrow; stay on this day.
  if (h > 23) return '23:59';
  return `${pad(h)}:${pad(m)}`;
}

/**
 * Apple Calendar's standard 1-hour duration rule:
 * Defaults end time to 1 hour after the start time.
 */
export function defaultAppleEndTime(fromTime: string): string {
  if (!fromTime) return defaultAppleStartTime();
  const [hStr, mStr] = fromTime.split(':');
  const h = parseInt(hStr || '0', 10);
  const m = parseInt(mStr || '0', 10);
  const endH = h + 1;
  // An hour past 11 pm would wrap to the small hours and read as backwards.
  if (endH > 23) return '23:59';
  return `${pad(endH)}:${pad(m)}`;
}

/** Every date an event touches, so a multi-day booking appears on each
 *  day it actually covers rather than only the one it starts on. */
export function spanDays(startsAt: string, endsAt: string): string[] {
  const from = parseISO(startsAt);
  const to = parseISO(endsAt);
  const out: string[] = [];
  const cur = new Date(from);
  // Guard against a malformed feed handing us a decade-long event.
  for (let i = 0; cur <= to && i < 400; i++) {
    out.push(iso(cur));
    cur.setDate(cur.getDate() + 1);
  }
  return out.length ? out : [iso(from)];
}

/** "8:10 am – 3:45 pm" on one day; "Aug 30 at 9:00 am – Sep 3 at 5:00 am"
 *  when it crosses midnight. */
export function formatRange(
  startsAt: string,
  endsAt: string,
  allDay: boolean,
): string {
  const sDate = dtDate(startsAt) as string;
  const eDate = dtDate(endsAt) as string;
  const sTime = dtTime(startsAt);
  const eTime = dtTime(endsAt);
  const sameDay = sDate === eDate;

  if (allDay) {
    if (sameDay) return 'All day';
    return `${shortDate(sDate)} – ${shortDate(eDate)}`;
  }
  if (sameDay) {
    return `${sTime ? prettyLower(sTime) : ''}${eTime ? ` – ${prettyLower(eTime)}` : ''}`;
  }
  const left = `${shortDate(sDate)}${sTime ? ` at ${prettyLower(sTime)}` : ''}`;
  const right = `${shortDate(eDate)}${eTime ? ` at ${prettyLower(eTime)}` : ''}`;
  return `${left} – ${right}`;
}

/** Compose a plan’s when: day + optional From / Until + optional multi-day end.
 *  Nothing is required past the day. Until may be set without From. */
export function composeWhen(input: {
  date: string;
  from?: string;
  until?: string;
  endDate?: string | null;
}): { date_time: string; ends_at: string | null } {
  let from = (input.from ?? '').trim();
  let until = (input.until ?? '').trim();
  const endDate =
    input.endDate && input.endDate > input.date ? input.endDate : null;

  // Same-day window typed backwards — swap quietly.
  if (!endDate && from && until && until < from) {
    const tmp = from;
    from = until;
    until = tmp;
  }

  const date_time = from ? `${input.date}T${from}` : input.date;

  if (endDate) {
    return { date_time, ends_at: until ? `${endDate}T${until}` : endDate };
  }
  if (until) {
    return { date_time, ends_at: `${input.date}T${until}` };
  }
  return { date_time, ends_at: null };
}

/** How a plan reads on its own detail screen: the full day spelled out,
 *  a span when it has one, and times only when they were set. */
export function describePlan(
  dateTime: string,
  endsAt: string | null,
): string {
  const start = parseISO(dateTime);
  const sTime = dtTime(dateTime);
  const long = (d: Date) =>
    d.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' });

  if (endsAt) {
    const sDate = dtDate(dateTime) as string;
    const eDate = dtDate(endsAt) as string;
    const eTime = dtTime(endsAt);
    const end = parseISO(endsAt);

    if (eDate !== sDate) {
      const nights = Math.round((+end - +start) / 86400000);
      const left = sTime ? `${long(start)} at ${pretty(sTime)}` : long(start);
      const right = eTime ? `${long(end)} at ${pretty(eTime)}` : long(end);
      return `${left} – ${right} · ${nights} night${nights === 1 ? '' : 's'}`;
    }

    if (sTime && eTime) return `${long(start)}, ${pretty(sTime)} – ${pretty(eTime)}`;
    if (eTime && !sTime) return `${long(start)} until ${pretty(eTime)}`;
    if (sTime) return `${long(start)} at ${pretty(sTime)}`;
  }

  return sTime ? `${long(start)} at ${pretty(sTime)}` : `${long(start)}, all day`;
}

/** Anticipation copy for a plan’s date: Today, Tomorrow, In 2 days… */
export function relativeDay(dateISO: string, from = todayISO()): string {
  const start = parseISO(from.slice(0, 10));
  const target = parseISO(dateISO.slice(0, 10));
  const days = Math.round((+target - +start) / 86400000);

  if (days === 0) return 'Today';
  if (days === 1) return 'Tomorrow';
  if (days === -1) return 'Yesterday';
  if (days > 1 && days < 14) return `In ${days} days`;
  if (days >= 14 && days < 60) {
    const weeks = Math.round(days / 7);
    return weeks <= 1 ? `In ${days} days` : `In ${weeks} weeks`;
  }
  if (days < -1 && days > -14) return `${Math.abs(days)} days ago`;
  return shortDate(dateISO);
}

/** "3 minutes ago", "yesterday", "12 Mar" — precise while it's fresh and
 *  vague once it stops mattering, which is how people talk about time. */
export function timeAgo(stamp: string): string {
  const then = new Date(stamp);
  const mins = Math.floor((Date.now() - +then) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} hr ago`;
  const days = Math.floor(hours / 24);
  if (days === 1) return 'yesterday';
  if (days < 7) return `${days} days ago`;
  return `${MON3[then.getMonth()]} ${then.getDate()}`;
}

/** "2026-09-03" -> "Sep 3" */
export function shortDate(dateISO: string): string {
  const d = parseISO(dateISO);
  return `${MON3[d.getMonth()]} ${d.getDate()}`;
}

export function describeDT(v: string): string {
  const date = parseISO(v);
  const t = dtTime(v);
  const day = `${DAYS[date.getDay()]}, ${MON3[date.getMonth()]} ${date.getDate()}`;
  return t ? `${day} at ${pretty(t)}` : day;
}

/** Localizes UTC timestamp strings that Postgres triggers bake into audit log details
 *  (e.g. "set it for Sep 07, 2026 at 01:00 AM" -> "set it for Sep 6, 2026 at 9:00 pm"). */
export function localizeAuditDetails(details: string): string {
  if (!details) return details;
  return details.replace(
    /\b([A-Z][a-z]{2})\s+(\d{1,2}),\s+(\d{4})\s+at\s+(\d{1,2}):(\d{2})\s+(AM|PM)\b/g,
    (match, mon, day, year, hourStr, minStr, ampm) => {
      let hour = parseInt(hourStr, 10);
      if (ampm === 'PM' && hour < 12) hour += 12;
      if (ampm === 'AM' && hour === 12) hour = 0;
      const monthIdx = MON3.indexOf(mon);
      if (monthIdx === -1) return match;
      const utcDate = new Date(
        Date.UTC(parseInt(year, 10), monthIdx, parseInt(day, 10), hour, parseInt(minStr, 10))
      );
      if (isNaN(utcDate.getTime())) return match;
      const localYear = utcDate.getFullYear();
      const localMon = MON3[utcDate.getMonth()];
      const localDay = utcDate.getDate();
      const localH = utcDate.getHours();
      const localM = utcDate.getMinutes();

      if (localH === 0 && localM === 0) {
        return `${localMon} ${localDay}, ${localYear}`;
      }

      const localHH = String(localH).padStart(2, '0');
      const localMM = String(localM).padStart(2, '0');
      const timeStr = prettyLower(`${localHH}:${localMM}`);
      return `${localMon} ${localDay}, ${localYear} at ${timeStr}`;
    }
  );
}

/** Cells for a month grid, padded to whole weeks. */
export interface DayCell {
  label: number | '';
  date: string | null;
  outside: boolean;
}

export function monthGrid(cursor: Date): DayCell[] {
  const y = cursor.getFullYear();
  const m = cursor.getMonth();
  const start = new Date(y, m, 1).getDay();
  const dim = new Date(y, m + 1, 0).getDate();
  const dimPrev = new Date(y, m, 0).getDate();

  const cells: DayCell[] = [];
  for (let i = 0; i < start; i++) {
    cells.push({ label: dimPrev - start + 1 + i, date: null, outside: true });
  }
  for (let d = 1; d <= dim; d++) {
    cells.push({ label: d, date: iso(new Date(y, m, d)), outside: false });
  }
  while (cells.length % 7) cells.push({ label: '', date: null, outside: true });
  return cells;
}

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

export function formatSearchDate(dayStr: string): string {
  const d = parseISO(dayStr.slice(0, 10));
  const weekday = WEEKDAYS[d.getDay()];
  const month = MONTHS_SHORT[d.getMonth()];
  const day = d.getDate();
  const year = d.getFullYear();
  const currentYear = new Date().getFullYear();
  if (year !== currentYear) {
    return `${weekday} – ${month} ${day}, ${year}`;
  }
  return `${weekday} – ${month} ${day}`;
}

export function formatUpNext(
  dateISO: string,
  from = todayISO(),
): { countdown: string; dateFormatted: string } {
  const target = parseISO(dateISO.slice(0, 10));
  const start = parseISO(from);
  const days = Math.round((target.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
  const weekday = WEEKDAYS[target.getDay()];
  const month = MONTHS_SHORT[target.getMonth()];
  const day = target.getDate();
  const year = target.getFullYear();
  const yearSuffix = year !== new Date().getFullYear() ? `, ${year}` : '';

  let countdown = 'Upcoming';
  if (days === 1) countdown = 'Tomorrow';
  else if (days > 1) countdown = `In ${days} days`;

  const dateFormatted = `${weekday}, ${month} ${day}${yearSuffix}`;
  return { countdown, dateFormatted };
}
