# Fordays — product backlog

**Fordays** — *Plans for days.*

Product ethos (simplicity, when-fields, language): [`ETHOS.md`](./ETHOS.md).

Palette is the **orb** (rose → coral → peach → green): rose = Plan, sage = Idea. Pastels never take white text — ink on fills. See `src/styles/tokens.css` / `ios/Fordays/Theme/Theme.swift`.

Private shared planning for two people: dated **plans**, undated ideas in the **bucket**.

---

## Product backlog

| # | Idea | Status |
|---|------|--------|
| 1 | Plan reminders (day-of / day-before) | Planned |
| 2 | Notification tap → open that plan | Planned (PWA gap; do in RN) |
| 3 | Multiple shared spaces (many 2-person spaces) | Planned |
| 4 | Celebrate lock-in (sound / effect when bucket → plan) | Planned |
| 5 | Space colors | Planned (with #3) |
| 6 | Revisit invite flow (may be broken / not seamless) | Ported — keep testing |
| 7 | Local ideas near you (opt-in suggestions → save into bucket) | Idea — later; not a home feed; keep intimate |
| — | Cross-space “All” calendar + busy-only privacy | Design agreed |

## Privacy (multi-space)

You only see full plan details in spaces you’re in. Other people’s other spaces: busy time at most, never titles / notes / who.

---

## React Native / Expo — remaining build work

Done: auth, calendar/bucket, create/detail/suggest, settings, invites, realtime, covers, audit, busy overlay.

| # | Item | Notes |
|---|------|--------|
| 1 | Native push (APNs + FCM) | Preference UI in Settings; needs Expo tokens + backend |
| 2 | Google Calendar OAuth in-app | Busy overlay reads synced events; connect still via web |
| 3 | Photo covers (`expo-image-picker`) | Icons + Giphy work; photos tab pending package install |
| 4 | Reminders + notif deep-link + multi-space | Same as product items above |
