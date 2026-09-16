# Product rules

Living decisions. Taste and language stay in local `ETHOS.md`. This file is the law both clients follow.

When we decide something, add it here in the matching section — not only in chat.

---

## Orbs

An Orb is **the notebook for a specific we** (including a we of one). Plans belong to the notebook, not to whoever tapped save.

Someday / Plans / Memories **are** that notebook. Everyone has at least one **live** Orb.

**Notebook isolation**: Plans stay strictly in the notebook where they were created. No cross-Orb bleeding. Plans from your Personal Orb or another Orb never appear as phantom availability lines or ghost dots in your other Orbs. To see your personal plans, switch to Personal. External calendar events (Google / Apple / Outlook) live only in Personal and never appear in shared Orbs.

**Enforced Personal Orb**: Every user always has a Personal Orb as their permanent anchor. You can rename it, but you cannot delete your Personal Orb. It is your home base.

**Personal Orb is strictly solo**:
- An Orb is the notebook for a specific we. Personal is a we of one.
- You cannot invite anyone into your Personal Orb. It has no `+ Invite` button in Settings.
- When you want to plan with someone, you create a shared Orb (`With someone`).
- This guarantees private plans, doctor appointments, surprises, and personal bucket items never accidentally leak to a partner or group. Personal remains an untouchable private capsule.

**Moving active items from Personal to Shared (`Do with...`)**:
- Plans and Someday items created in Personal can be moved into a shared Orb (`Do with [Partner Name / Space Name]`).
- Moving is strictly one-way from Personal to Shared (you can gift an idea to a relationship, but you cannot steal a plan from a shared group into your private notebook).
- Type parity: Someday moves directly to Someday; Plans move directly to Plans (retaining their date, time, location, notes, and cover).
- When moved, the item leaves Personal and appears in the target Orb with a clean confirmation toast (`Moved to Aline’s Someday` / `Moved to Aline’s Plans`).

**Orb** = the notebook. **Faces** = people in *this* space (two: rose / sage; many: names + initials). Not a hue per person or per space.

A name is **required** for Just you and With people. Placeholder in the field (`Personal` / `Aline’s Crew`) is only an example — never saved, never shown as the title. Unnamed legacy Orbs (Fordays / Someday / blank) stay untitled: empty field, no caption on the tile, faces already say who. When they name it, that word sits **under the circle** and **beside This Orb** (label semibold faint, name regular ink). Never title an Orb with a person’s name.

Several Orbs are normal: Personal, Portugal, siblings. Each is solo, two, or many.

Do **not** type Orbs as Work / Personal / Travel. Names are free. Categories are not.

### First Orb & Signup

- Every user has a **Personal Orb**.
- **Fresh sign-up**: Prompts `Your first Orb` with `[ Just you | With someone ]`.
  - **Just you**: Names their personal space (placeholder example `Personal`). Button says **Start planning**. Lands in Plans.
  - **With someone**: Names the shared space (placeholder example `Aline’s Crew`). Button says **Invite your person**. Pops the native share sheet immediately with the invite link. Behind the scenes, their permanent **Personal** notebook is already minted and waiting in their Orb switcher.
- **Invite sign-up**: Someone arriving via an invite link signs up and lands **directly in the invited Orb**. No setup interstitial, no asking them to configure a personal space first. Behind the scenes, their Personal notebook is already minted and waiting in their Orb switcher.
- Blank name is not allowed when creating an Orb. Continue stays off until they type one.
- Placeholder is example only (`Personal` / `Aline’s Crew`). Do not write it into the row.
- Sign-in lands in their last active Orb and never asks for setup again.

### Settings

One sheet, two bands — not two Settings screens.

- **Your Orbs** — all notebooks. Grid, +, Past Orbs. Switch and create.
- **This Orb** — the open notebook. If it has a name, that name sits beside the label in a lighter weight. The field is the name (placeholder still the example). People / invite / remove, Leave or Delete. No “Orb actions” heading.

You / calendars / notifications / sign out are you, not a notebook.

### Start a new one

Same questions as first signup, in a sheet. Cancel returns to Start / Join. Join with a code stays its own path (link or code for *this* Orb — no directory, no Contacts).

### Admin and members

- **Admin** is whoever **started** that Orb (signup mint, or Start a new one). You are admin of your Personal notebook.
- People who **join** are **members**. They can leave. They cannot Remove anyone.
- If the last admin leaves a we, the person who’s been in **longest** becomes admin so the group isn’t stuck.
- No “make admin” control.
- **Two people:** no Remove. Admin doesn’t show up.
- **Many:** only that starter (or whoever got promoted) may Remove. Remove does not delete the notebook. The removed person gets a frozen copy.

### Leave, delete, Past Orbs

- **Leave** — anyone in a we. You’re out. Others keep the **live** notebook. You keep a **frozen copy** of what was already there. New plans after you leave are not on your copy.
- **Delete this Orb** — only when you’re **alone** in it (solo, or last member). Soft-delete → Past Orbs. Lives at the bottom of **This Orb**. Confirm before delete.
- **Personal Orb cannot be deleted.** You always keep your personal home base.
- **No delete-for-everyone** while someone else is still in.
- **Last live notebook** — cannot delete. Always keep at least one live Orb.
- **Delete permanently** — Past Orbs only. That copy is gone for you. Does not un-delete their live we.
- Rejoin a we you left: **invite**, not Restore. No Restore in the UI.

### Decided, not built yet

- Cap **5 live Orbs** (joins count). Past Orbs do not count. No paywall copy yet. Enforce on the server when we ship it.
- Reuse an empty Personal notebook instead of minting another blank one.

---

## Confirms

Never expand Stay / Delete as grouped list rows in the page. That is not a confirm.

Always use an **Action Sheet** (`<ActionSheet>` on PWA, `.confirmationDialog` on iOS): the question, one destructive action, and a separated Cancel capsule. Zero grabber bars, completely non-draggable. Same pattern as Leave / Delete Orb — not a centered alert on a sheet, not a form group.

---

## Someday

The dock place **without a day**. Not ideas, bucket, wishlist, or todos.

You add *to* Someday. You don’t add “a someday.” Don’t name the card.

Empty: the line only. Plus adds. No empty CTA.

Plus is **one action everywhere**: add to this Orb, then plan or Someday. Same door on every tab. Do not make plus mean something else on Someday.

---

## Plans

A plan has a **day**. Soft blanks are valid.

The app **opens here**. Someday and Memories stay in the dock; this is the default page.

Empty: the line only. Plus adds. No empty CTA.

- **Single Dot Style (One Dot, Pink Solid `●`)**:
  - Only one dot style exists in this app: the solid pink dot (`●`).
  - There are no hollow ring dots (`○`) and no black selection dots. External events and app plans are all plans — just created differently.
  - A dot simply means something is happening on that day.
  - Capped at 3 dots total per day cell (`...` heat map shorthand) without numbers cluttering the cell.
- **External Events are Plans (No Extra Setup)**:
  - In a shared Orb (with a partner or group), external calendar events never appear. Shared Orbs are pure notebooks of what you plan together.
  - External events (Google / Apple / Outlook) live in your Personal Orb alongside personal plans, tagged simply with their source (`Google`, `Apple`, or `Outlook`).
  - **First-class plans, no difference**: A massage appointment, hotel booking, or workout is a plan. There is no second-class setup or modal barrier.
  - **Cover Art**: Displayed with the signature Fordays gradient orb wash (matching native plans without photos), completely replacing emoji glyphs.
  - **Agenda Cards**: Rendered as identical floating tactile cards with cover art wash, title, time range, location link (📍), owner face, and a quiet source capsule (`Google`, `Apple`, `Outlook`).
  - **Detail Sheet**: Features the signature gradient cover header, title, time range, tappable location to Apple Maps, and source badge.
  - **No "Share with the Orb" / Lock Chrome**: Zero "Share with the Orb" buttons, zero privacy locks, and zero "Make private" toggles. External events whisper ambiently as `Busy ([time])` to partners in shared Orbs for conflict awareness without exposing details.
  - **Do with [Partner / Space]**: Just like any personal plan, an external plan in Personal can be brought into a shared Orb via `Do with [Partner]` with a single tap, creating a live shared plan in that notebook.
- **Frosted Shelf Header (Approach A)**:
  - The sticky top header provides a spacious frosted shelf (~56pt min-height) with a generous 14pt cushion directly below the Orb selector pill (`Alowa ∨`).
  - At rest, weekday headers (`S M T W T F S`) sit 16pt below the bar for calm, unhurried breathing room.
  - On scroll, content passes smoothly under the frosted glass material (`blur(30px)`) and subtle hairline, rather than crashing immediately into the bottom edge of the pill.
- **Up Next (Anticipation)**:
  - When **Today** has nothing planned, the screen doesn't stay dead air.
  - The empty state message (`Nothing planned between you and Aline today`) is kept tight and compact rather than consuming half the screen.
  - Below it, surface an **Up next** section showing the plans for the next upcoming date with events (and only that next day).
  - The `Up next` header matches the typography of `Today` (clean ink title, zero pill/tag badges).
  - Anticipation subhead: `[In X days / Tomorrow] · [Weekday, Month Day]`, with countdown prominent in rose ink, bullet separator `·`, and zero brackets.
  - Tapping an upcoming card opens its Detail sheet directly.
  - Selecting any other future or past day on the grid displays only that specific day's agenda.
- **No creating plans in the past**:
  - Creating a new plan strictly looks forward. The date picker in Composer locks to `>= today`, with past dates muted and disabled.
  - Plans in the past are Memories. Editing an existing memory via "Change the day" in Detail remains allowed to correct historical typos.

Default when-flow:

1. **Starts** — unified date pill + optional time pill. No bloated quick chips (`Today / Tomorrow / This weekend`). Opens on the focused date; tapping the date capsule reveals the clean month grid matching the Plans page calendar (exact same DOW header, circular date cells, and rose today highlight).
2. **Next Half-Hour Rule**: Default start times never schedule in the past or mid-minute. Always rounds up to the next clean half-hour block (:00 or :30). If opened on a half-hour mark (e.g. 10:00 or 10:30), it assumes a typing buffer is needed and pushes forward by 30 minutes (e.g. 10:00 -> 10:30, 10:30 -> 11:00). Default end time follows Apple's standard 1-hour duration rule (e.g. 11:00 AM -> 12:00 PM).
3. **Clean time selection + tap-to-type**:
   - *Native iOS*: `CompactTimePicker` (`UIDatePicker` in `.compact` style with `minuteInterval = 5`), giving the authentic 5-minute rolling wheel and numeric keypad for exact minutes.
   - *PWA*: Notion / Apple Web style clean scrollable list in 30-minute steps. Starts shows times; Ends shows times paired with human relative durations (`30 minutes`, `1 hour`, `1.5 hours`...). Auto-scrolls directly to the selected time on open. Custom minute input available on demand without visual noise.
   - *Calendar Grid*: Clean month grid matching the Plans page (borderless rose chevrons, no gray button circles, solid rose circle for selected day with zero border rings).
4. **From & Until** — soft blanks are valid. `Until` is revealed on demand via `+ Add end time` without forcing a duration.
5. **Multi-day** — only after **Runs more than one day?** Then **Ends** row appears with end date and optional until time. Never block save because Until or Ends is empty.

Say plan / day — not event, schedule, or calendar.

---

## Memories

Plans whose day has passed. Look back, not a third kind of object.

- **Permanent lived history**: Memories cannot be moved back to Someday / bucket list. You cannot unlive an experience.
- **Do again**: Tapping **Do again** lets you repeat a great experience without altering history. Prompts **Make it a plan** (opens Composer prefilled with the title, notes, location, and cover to pick an upcoming date) or **Add to Someday** (places a fresh copy into Someday). The original memory stays 100% frozen in history.
- **Actions on a Memory**: Only **Do again**, **Change the day** (to fix typos in the past), and **Delete** (if an event never happened) are allowed. Never show **Back to Someday** or **Suggest a date** on a memory.
- **Audit history localization**: History entries stored in the database by server triggers must be localized to the user's device timezone so times like 9:00 PM EST never display as 01:00 AM UTC.

---

## Covers

One picture on a plan. The person picks it. Never auto-assign from the title.

- **GIFs** — a Giphy `https` URL in `image_url`
- **Stills** — an Unsplash `https` URL
- **Photos** — a compressed JPEG stored *in* `image_url` as a `data:` URL (the notebook row, not a files bucket)

Fordays is not a photo host. Gallery photos live on the plan so the we can see them. Warm the first six covers (one screen). The rest lazy-load as you scroll. Device keeps at most those six — not a library of 80.

No picture: art family → orb hue. No match → id-hash wash.

Keys for Giphy and Unsplash are deploy env. Never a key field in the app.

---

## Location

An optional place on a plan or idea.

- **Placement**: Sits quietly before Notes (`Location — optional`).
- **Free Autocomplete**:
  - *Native iOS*: Apple MapKit (`MKLocalSearchCompleter`) provides POIs, addresses, and venues for free with zero API keys.
  - *PWA*: Photon (OpenStreetMap) provides fast global address/venue autocomplete with zero API keys.
  - *Free text is valid*: People can type custom place nicknames ("Aline's rooftop", "Picnic spot") without being forced to pick an address.
- **Tappable to Maps**: When set, tapping the location in Detail view opens Apple Maps (`https://maps.apple.com/?q=...`) directly on iOS and falls back cleanly to maps on web/other platforms.

---

## Calendars

**External calendars** lists the overlays: **Google** and **Outlook** on the web; **Apple Calendar** (and Outlook under it) on iPhone. Outlook is always in that list — not hidden until a key exists.

Google / Microsoft / Unsplash / Giphy / VAPID keys are deploy env. Never a key field in Settings.

---

## The Whisper (Availability Context)

When composing a plan, ambient availability context appears quietly below the date and time fields.

- **Calm ambient context, never a gatekeeper**: The Whisper never blocks saving. The action button is always active and one tap ("Make it a plan"). There are zero warning dialogs, confirmation prompts, or "Proceed anyway?" modals. Overlaps are informative, not blockers (e.g. joining a Netflix party while traveling in France, skipping a workout for drinks, or joining dinner 30 minutes late).
- **Universal Ambient Availability (Personal Plans)**:
  - Personal timed plans automatically whisper as `[Name] · Busy ([time])` into all your shared Orbs.
  - Strict privacy: titles, locations, and descriptions remain 100% private in Personal; shared Orbs only see `Busy` and the time window.
  - Ambient availability requires zero toggles or manual sharing for native plans.
- **Imported External Calendars (Apple, Google, Outlook)**:
  - Your own imported calendar events whisper to you for self-awareness without needing to be shared.
  - Partner external calendar events whisper only when explicitly shared with the Orb. If shared with title, the title is shown (`Aline · Dinner (6:00 – 8:30 pm)`). If shared as busy only (null title), it displays as `Busy` (`Aline · Busy (6:00 – 8:30 pm)`). If unshared, it remains completely private and silent.
- **Transparent time ranges**: Show concrete ranges (`6:00 – 8:30 pm` or `All day`) rather than ambiguous statements like "busy until 8:30 pm".
- **Intelligent time-aware filtering**:
  - *Date-only plan (no From/Until)*: Whispers events scheduled across that day so members see open pockets before picking a time.
  - *Plan with From time*: Filters out events that ended before the plan starts. Never assume an artificial meeting duration: when `Until` is blank, active and later events from `From` onward are surfaced directly so people can process the information and judge for themselves. If `Until` is explicitly specified, events beyond that window are excluded.
  - *Multiple overlaps*: If up to 2 events overlap, both are shown concisely (`Aline · 6:00 – 8:30 pm · Remi · All day`). If 3 or more overlap, it provides a quiet summary count (`3 overlapping events at this time` or `3 shared events on this day`).

---

## Invite

Link or code for **this** Orb. Share sheet / copy URL.

- **No invite on Personal Orb**: An invite link or code is generated only for shared Orbs. Personal Orb has no invite door; to plan with someone, create a shared Orb.
- **New user via invite**: signs up and lands straight in the invited Orb. No setup interstitial. Their Personal Orb is minted in the background.
- **Existing user via invite**: tapping an invite link or accepting a code joins the Orb immediately and switches to it with a clean confirmation toast (`Joined “Orb Name”`).
- Manual join via code remains available in Settings (`Join with a code`).
- No username directory. No required Contacts.

---

## Auth

Sign in first. Sign up is a link. Name placeholder **Aline**. No Mayowa in app copy.

---

## Notifications & Deep Linking

- **Direct card destination**: Tapping a notification on lock screen or banner slides up that exact plan or bucket card immediately. It never just dumps the user on the home screen.
- **Orb-aware context**: If the plan belongs to another Orb (e.g. you're looking at Personal, but a notification arrives from your shared Orb with Aline), the app switches directly into that Orb before presenting the card.
- **Context underneath**: The screen behind the sheet aligns with the card:
  - *Plan on the calendar*: Switches to the Calendar tab and focuses on the plan’s date and month so dismissing the sheet leaves you looking at it in context.
  - *Someday / Bucket item*: Switches to the Someday tab.
- **Deleted/missing fallback**: If a plan was deleted or modified prior to tapping, a calm toast (`That plan is no longer here`) appears instead of crashing or showing a blank card.
- **Parity**: Works identically on PWA (via Service Worker `notificationclick` message passing and URL query params `?a=&s=`) and native iOS (via `UNUserNotificationCenterDelegate` and `onOpenURL`).

---

## Sheets & Confirmations

- **Never stack sheets.** A Sheet (`<Sheet>` in PWA, `.sheet` in SwiftUI) is a draggable drawer with a grabber bar for primary destinations (Settings, Composer, Detail, Add). Stacking a sheet on top of another sheet creates double grabber bars, conflicting gestures, and visual clutter.
- **In-sheet sub-views**: Multi-step flows within a sheet (e.g. Settings → Another Orb → Your Orb; Settings → Past Orbs; Settings → Import calendars) navigate in-place inside that single sheet with a `← Back` button. The sheet retains its single top grabber bar.
- **Confirmations & destructive choices**: Never use a Sheet for confirmation (Leave Orb, Delete Orb, Remove member, Purge, Discard). Always use an **Action Sheet** (`<ActionSheet>` in PWA, `.confirmationDialog` in SwiftUI).
  - Anchored to the bottom of the screen above the safe area / home indicator.
  - Zero grabber bars, completely non-draggable.
  - Two-capsule geometry: content capsule with title/message/action(s), separated by 8px from an independent Cancel capsule below.

---

## Unified Search

A quiet search across the entire active notebook.

- **Notebook-scoped**: Searching strictly respects Orb isolation. Searching in Personal only searches Personal; searching in Aline only searches that shared Orb.
- **Unified across the three spaces**: Rather than separate search bars in each tab, one unified search checks **Plans**, **Someday**, and **Memories** simultaneously.
- **Fields matched**: Searches `title`, `location`, and `description` (notes). Matches are case-insensitive.
- **Top Bar Entry**: A magnifying glass `🔍` icon sits quietly on the trailing side of the top bar across all tabs (on Plans, alongside the month chevrons). Search is locked to the trailing margin so it never shifts horizontally between views.
- **Results Presentation**:
  - Grouped into three calm sections if matches exist: **Plans** (with upcoming date, time, location), **Someday** (with notes preview, location), and **Memories** (with historical date, location).
  - Tapping any result closes search and opens the card's **Detail sheet** directly.
  - When the query is empty, surfaces calm suggestions: **Upcoming Plans** and **Recent in Someday** so the overlay is never an empty void.
  - No matches shows `No results for “{query}”`.
- **Safe-area & Multiple Exit Paths**: Fully padded below the hardware safe-area (`--safe-t`, Dynamic Island / notch). Accessible Back (`←`) button, Cancel button, and Escape key provide effortless dismissal.
- **Parity**: Identical design, groupings, and behavior on PWA and iOS.

---

## Local-First & Optimistic UI (Phase 1)

Fordays operates local-first on the client so the notebook feels like paper — instant, calm, and zero-wait.

- **0ms Cold Start (Disk Snapshot)**:
  - Both clients synchronously hydrate the last active Orb, spaces list, and activities from local snapshot storage (`localStorage` on PWA, atomic disk JSON in `Caches/` on iOS) at frame 0.
  - Returning users never see a white screen or blocking loading spinner on launch. The notebook and month agenda render immediately.
  - Auth verification and server sync run quietly in the background without layout shifts or jumpy refetches.
- **Instant Optimistic Mutations**:
  - *Create*: When saving a plan or Someday item, an optimistic card is created and placed into the notebook immediately (0ms). The composer sheet dismisses without waiting for the server roundtrip.
  - *Edit / Patch*: Changing title, location, notes, date, or cover applies to the view and local cache in 0ms.
  - *Move (`Do with...`)*: Moving a personal plan or Someday item removes it from the current Orb immediately and presents a confirmation toast.
  - *Delete*: Tapping delete removes the card from view instantly with zero delay.
- **Server Reconciliation & Rollback**:
  - Mutations execute against Supabase in the background. On success, temporary optimistic IDs reconcile cleanly with server rows.
  - If a network error or server constraint occurs, the local state and snapshot roll back to the previous backup, and a calm toast explains the issue.
- **Parity**: Identical local hydration keys, optimistic lifecycle, and failure rollbacks across PWA and iOS.

---

## Visual Craft & Rhythm

Fordays feels like a warm personal capsule and stationery, never a corporate calendar or spreadsheet.

- **Razor-Thin Plans Divider**: A crisp, delicate hairline subtly divides the calendar month grid from the daily agenda section on both PWA and iOS (`border-top: var(--hairline-w) solid var(--hairline)` on PWA, `Theme.hairline` on iOS), providing clear visual grounding without visual clutter.
- **Curved Sticky Top Shelf on Scroll**:
  - *At rest (scroll offset = 0)*: The top bar is 100% transparent. The ambient Orb background gradient flows uninterrupted from top to bottom.
  - *On scroll (scroll offset > 0)*: A frosted sticky shelf (`.ultraThinMaterial` / `backdrop-filter`) smoothly fades in with a continuous bottom curved corner radius (`UnevenRoundedRectangle(bottomLeadingRadius: Theme.Spacing.xl, bottomTrailingRadius: Theme.Spacing.xl)` on iOS, `border-bottom-left-radius: var(--space-6); border-bottom-right-radius: var(--space-6);` on PWA) and subtle elevation.
  - No straight horizontal bottom edge across the screen; the curved corners give the sticky canopy an organic, stationery-like contour.
- **Identical Top Padding Rhythm across Plans, Bucket, and Memories**:
  - The navbar height (`Theme.TouchTarget.navBar` / 56px) and content top margin (`Theme.Spacing.row` / 14px) are completely uniform across all three views (Plans, Someday, Memories).
  - No bloated large-title headers or mismatched offsets in Bucket or Memories; content in all tabs starts at the exact same vertical baseline.
- **Static, Rock-Solid Top Bar Controls (No Animations)**:
  - The top bar title is centered and static (no opacity/offset animations when switching tabs, scrolling, or navigating months).
  - Trailing calendar controls (`Today`, `<`, `>`) and the locked Search icon (`🔍`) sit reliably with zero jumping or sliding animations.
- **Stable Top Bar Geometry**:
  - The month title on Plans is dead-centered in the viewport (using a `ZStack` on iOS / 3-column grid on PWA) so it never shifts or wobbles when moving between months or when the `Today` pill appears.
  - The Search action button (`🔍`) is locked to the trailing margin across all tabs.
- **Ambient Orb Background Gradient (Dual Parity)**:
  - Both iOS (`OrbBackground`) and PWA (`global.css`) render the signature 4-layer ambient radial gradient over `Theme.paper`:
    1. Rose bloom behind the top masthead.
    2. Soft sage bloom at top-right.
    3. Soft sage bloom at mid-left.
    4. Peach bloom pooling at bottom center.
  - The background is never flat beige.
- **Tactile Cards for Plans & Agenda**:
  - On both clients, plans and external events in the agenda are presented as individual floating tactile cards (`background: var(--paper-warm)`, `border-radius: var(--r-md)`, `padding: var(--space-3-5)`, `var(--space-2-5)` spacing, subtle elevation) rather than flat divider-separated rows.

---

## Design System Tokens & Zero Dangling Numbers

Hard requirement across Fordays (PWA and iOS). Agents must follow this; do not ship a literal and “tokenise later.”

**Zero magic numbers in views.** Never hardcode padding, margin, gap, width, height, corner radius, font size, color opacity, border width, scale, or animation duration in a screen, component, or stylesheet. The only files that may contain those literals are the token sources:

- PWA: `src/styles/tokens.css`, `src/ui/motion.ts`
- iOS: `ios/Fordays/Theme/Theme.swift`

If a value does not exist yet, add the token on **both** clients first, then reference it. Prefer the 4pt aliases for new work. Do not invent a one-off pixel in a view to make something “look right on this monitor.”

### Scale (named aliases)

- **Concentric radii**: `Theme.radiusXs` (4), `Theme.radiusSm` (8), `Theme.controlRadius` (12), `Theme.radiusMd` (14), `Theme.cardRadius` (20), `Theme.sheetRadius` (38), `Theme.capsuleRadius` (999) / `--r-xs` … `--r-capsule`.
- **Harmonic spacing** (4pt base, Weber expansion). Named aliases: `xxs` 2, `xs` 4, `sm` 8, `md` 12, `row` 14, `base` 16, `lg` 20, `xl` 24, `xxl` 32, `xxxl` 40, `huge` 56. Half-steps (`s6` / `--space-1-5`, etc.) exist only for shipped UI — new work snaps to the aliases or gets a semantic name (`--h-cover`, `Theme.TouchTarget.thumb`).
- **Type**: Apple ramp via `Font.fd*` / `--t-*`. Never `.font(.system(size: 12))` or `font-size: 15px` in a view. SwiftUI Dynamic Type (`.headline`, `.body`, `.caption`) is allowed because it is a system token.
- **Tints**: `Theme.hairline`, `Theme.separator`, `Theme.fillQuaternary` / `Tertiary` / `Secondary`, `Theme.veil`, `Theme.scrim`, `Theme.paperTranslucent`, `Theme.roseGlow` — never `Theme.ink.opacity(0.05)`.
- **Touch / chrome**: `Theme.TouchTarget.min` 44, `control` 36, `navBar` 56, `pill` 28, plus avatars, covers, thumbs in that enum / `--h-*` `--size-*`.
- **Motion**: `Theme.Motion.*` / `src/ui/motion.ts` / `--scale-press` `--duration-*`.

### Exceptions

Vector glyph paths (`TabIcons.swift`, SVG `d`), CSS `@media` (must match `--bp-gate`), product counts (7 days, 5-minute picker, 3-face cap), and z-index derived from a list index. Ambient orb washes live inside `OrbBackground` / `tokens.css` as the token itself.

Agent rule: `.cursor/rules/no-dangling-numbers.mdc`.


