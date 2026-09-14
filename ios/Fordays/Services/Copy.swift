import Foundation

/// Canonical product copy inherited from `shared/copy.json`.
/// Single source of truth across Web PWA, iOS, and future Android.
enum Copy {
  enum Orbs {
    static let soloLabel = "Just you"
    static let onePerson = "1 person"
    static func peopleCount(_ count: Int) -> String { "\(count) people" }
    static let createOrb = "Create Orb"
    static let createOrbSub = "Start solo, or invite"
    static let joinOrb = "Join an Orb"
    static let joinOrbSub = "Enter code or link"
    static let descriptor = "An Orb is your personal or shared capsule to plan, dream, and look back."
    static let frozenNotice = "This is a copy from when you left — you can look, not change"
    static let leaveAction = "Leave this Orb"
    static let deleteSoloAction = "Delete this Orb"
    static let deleteSoloConfirm = "Delete this Orb? You’ll keep a frozen copy so nothing here is lost."
    static let leaveSharedConfirm = "They keep the live Orb. You get a frozen copy of what’s already here."
    static func removeConfirm(name: String) -> String {
      "Remove \(name)? They get a copy of what was already here. This Orb stays live for everyone else."
    }
    static let pastOrbs = "Past Orbs"
    static let pastOrbsSub = "Orbs you’ve left or set aside"
    static let frozenSnapshot = "Frozen snapshot"
    static let viewingFrozenBanner = "Viewing a past Orb — you can look back, but plans are frozen"
    static let switchBackToActive = "Switch back to active Orb"
    static let restoreOrb = "Restore Orb"
    static let deletePermanent = "Delete permanently"
    static let deletePermanentConfirm = "Permanently delete this Orb? All past plans here will be purged forever."
  }

  enum Plans {
    static let emptyToday = "Nothing planned today"
    static let emptyDay = "Nothing planned this day"
    static func emptyTodayPartner(_ partner: String) -> String {
      "Nothing planned between you and \(partner) today"
    }
    static func emptyDayPartner(_ partner: String) -> String {
      "Nothing planned between you and \(partner) this day"
    }
    static let emptyTogether = "Nothing planned together"
    static let emptyFrozen = "A copy from when you left"
  }

  enum Tabs {
    static let ideas = "Someday"
    static let plans = "Plans"
    static let memories = "Memories"
  }

  enum Ideas {
    static let emptySolo = "Things you want to do, before they have a day"
    static let emptyShared = "Things you want to do together, before they have a day"
    static let emptyFrozen = "A copy of this list from when you left"
    static let addFirst = "Add the first one"
    static let inList = "In Someday"
    static let backTo = "Back to Someday"
    static let backIn = "Back in Someday"
    static let added = "Added to Someday"
    static let addOptionNote = "Something you want to do, with no date yet."
  }

  enum Invite {
    static let title = "Invite someone"
    static let subtitle = "They get their own login, then land in this Orb with you. Send them the invite link."
    static let ideaLabel = "One thing you want to do"
    static let ideaHint = "— optional, but nicer than an empty Orb"
    static func shareSolo(link: String) -> String {
      "Join my Orb on Fordays: \(link)"
    }
    static func shareWithIdea(idea: String, link: String) -> String {
      "I added “\(idea)” to an Orb for us — join here: \(link)"
    }
    static let joinTitle = "Join an Orb"
    static let joinSubtitle = "Enter an invite code or paste an invite link to join someone’s Orb."
    static let codeOrLink = "Invite code or link"
    static let codePlaceholder = "e.g. e4f9b2c1 or paste link"
    static let paste = "Paste"
    static let joinAction = "Join Orb"
    static let joining = "Joining…"
    static let lookingUp = "Looking up Orb…"
    static let invalidCode = "No open Orb found for that code or link."
    static func joinedSuccess(_ orb: String) -> String {
      "Joined \(orb)"
    }
    static let orbCodeLabel = "Orb code"
    static let copyCode = "Copy code"
    static let codeCopied = "Code copied"
    static let linkCopied = "Invite link copied"
    static let shareInvite = "Share invite"
    static let notNow = "Not now"
  }

  enum Composer {
    static let newPlan = "New plan"
    static let newIdea = "Someday"
    static let editPlan = "Edit plan"
    static let editIdea = "Someday"
    static let addPlan = "Add plan"
    static let addIdea = "Add to Someday"
    static let multiDayPrompt = "Runs more than one day?"
    static let notesHint = "— optional"
    static let coverHint = "— optional"
  }

  enum Availability {
    static let title = "From your calendar"
    static let googleCalendar = "Google Calendar"
    static let outlookCalendar = "Outlook Calendar"
    static let appleCalendar = "Apple Calendar"
    static let google = "Google"
    static let apple = "Apple"
    static let outlook = "Outlook"
    static let onlyYou = "Only you"
    static let pickerLead = "Your main calendar is picked. That’s usually where appointments land. You can choose another."
    static let makePlan = "Make it a plan"
    static let makePlanShort = "Make plan"
    static let convertToPlan = "Make it a plan"
    static let busy = "Busy"
    static let busyPrivate = "Just show busy — they won’t see the title"
    static func notSharedPlan(_ owner: String) -> String {
      "From \(owner) calendar — not an Orb plan"
    }
    static func importedFoot(_ owner: String) -> String {
      "This lives on \(owner) calendar. Cancel or change it there."
    }
    static let sharedTitle = "Shared with this Orb"
    static let privateTitle = "Only you can see this"
    static let shareWithOrb = "Share with the Orb"
    static let makePrivate = "Only you"
    static let sharedWithOrbDesc = "They’ll see this on the day — a flight, an appointment, or just so they know."
    static let privateDesc = "Private to you. Share it if you want them to know."
    static func sharedBy(_ owner: String) -> String {
      "Shared by \(owner)"
    }
    static func sharedByDesc(_ owner: String) -> String {
      "\(owner) wanted you to see this."
    }
    static let noConflicts = "Nothing else on this day"
    static let settingsNoteIos = "Calendars already on this iPhone — including Google, if it’s in the Calendar app. Don’t see it? iPhone Settings → Calendar → Accounts → Add Account → Google, then come back and refresh."
    static let settingsNoteWeb = "Google here. On iPhone, Fordays reads the Calendar app instead — add Gmail there if those days should show, so they don’t land twice."
  }
}
