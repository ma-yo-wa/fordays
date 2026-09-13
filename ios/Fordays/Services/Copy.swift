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
  }

  enum Composer {
    static let newPlan = "New plan"
    static let newIdea = "New bucket-list idea"
    static let editPlan = "Edit plan"
    static let editIdea = "Edit idea"
    static let multiDayPrompt = "Runs more than one day?"
    static let notesHint = "— optional"
    static let coverHint = "— optional"
  }

  enum Availability {
    static let title = "Availability"
    static let googleCalendar = "Google Calendar"
    static let makePlan = "Make it a plan"
    static let makePlanShort = "Make plan"
    static let convertToPlan = "Copy to shared plan"
    static let busy = "Busy"
    static let busyPrivate = "Busy only — the title stays private"
    static func notSharedPlan(_ owner: String) -> String {
      "From \(owner) calendar — not a shared plan"
    }
    static func importedFoot(_ owner: String) -> String {
      "Imported events aren’t plans — they just show what’s already on \(owner) calendar"
    }
    static let sharedTitle = "Shared with this Orb"
    static let privateTitle = "Private to you"
    static let shareWithOrb = "Share with this Orb"
    static let makePrivate = "Make private"
    static let sharedWithOrbDesc = "Others in this Orb can see this context on their day agenda."
    static let privateDesc = "Only you can see this. Private to you."
    static func sharedBy(_ owner: String) -> String {
      "Shared by \(owner)"
    }
    static func sharedByDesc(_ owner: String) -> String {
      "\(owner) shared this context with the Orb."
    }
    static let noConflicts = "No other plans or shared context on this day"
  }
}
