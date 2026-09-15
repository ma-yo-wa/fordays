# Product rules

Living decisions. Taste and language stay in local `ETHOS.md`. This file is the law both clients follow.

When we decide something, add it here in the matching section — not only in chat.

---

## Orbs

An Orb is **the notebook for a specific we** (including a we of one). Plans belong to the notebook, not to whoever tapped save.

Someday / Plans / Memories **are** that notebook. Everyone has at least one **live** Orb.

**Notebook isolation**: Plans stay strictly in the notebook where they were created. No cross-Orb bleeding. Plans from your Personal Orb or another Orb never appear as phantom availability lines or ghost dots in your other Orbs. To see your personal plans, switch to Personal.

**Enforced Personal Orb**: Every user always has a Personal Orb as their permanent anchor. You can rename it, but you cannot delete your Personal Orb. It is your home base.

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

Over a sheet, use a **stacked confirm sheet** (PWA) or iOS **confirmationDialog**: the question, one destructive action, Stay / Keep as cancel. Same pattern as Start a new one / Join — not a centered alert on a sheet, not a form group.

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

Default when-flow:

1. **Day** — required once it’s a plan
2. **From** — optional
3. **Until** — optional

Multi-day only after **Runs more than one day?** Then **Ends on**. Until is the time on that last day (still optional). Never block save because Until or Ends on is empty.

Say plan / day — not event, schedule, or calendar.

---

## Memories

Plans whose day has passed. Look back, not a third kind of object.

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

## Calendars

**External calendars** lists the overlays: **Google** and **Outlook** on the web; **Apple Calendar** (and Outlook under it) on iPhone. Outlook is always in that list — not hidden until a key exists.

Google / Microsoft / Unsplash / Giphy / VAPID keys are deploy env. Never a key field in Settings.

---

## Invite

Link or code for **this** Orb. Share sheet / copy URL.

- **New user via invite**: signs up and lands straight in the invited Orb. No setup interstitial. Their Personal Orb is minted in the background.
- **Existing user via invite**: tapping an invite link or accepting a code joins the Orb immediately and switches to it with a clean confirmation toast (`Joined “Orb Name”`).
- Manual join via code remains available in Settings (`Join with a code`).
- No username directory. No required Contacts.

---

## Auth

Sign in first. Sign up is a link. Name placeholder **Aline**. No Mayowa in app copy.
