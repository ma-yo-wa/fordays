import Foundation

/// Title → orb hue. Same families as web `src/lib/art.ts`.
/// No match means the id-hash wash in Theme.
enum Art {
  static func hue(for title: String) -> Int? {
    let t = title.lowercased()
    for (words, hue) in families where words.contains(where: { t.contains($0) }) {
      return hue
    }
    return nil
  }

  // rose, coral, peach, gold, olive, sage
  private static let families: [([String], Int)] = [
    (["flight", "fly", "airline", "airport", "boarding", "depart", "arriv"], 2),
    (["hotel", "reservation", "booking", "check-in", "checkin", "airbnb", "room", "suite"], 2),
    (["train", "rail", "via ", "amtrak"], 2),
    (["drive", "road trip", "roadtrip"], 2),
    (["trip", "travel", "vacation", "holiday", "getaway", "abroad"], 2),
    (["beach", "sunset", "ocean", "island", "swim", "mallorca", "ibiza", "hawaii"], 2),
    (["hike", "hiking", "trail", "mountain", "camp", "banff", "cabin"], 4),
    (["kayak", "canoe", "paddle", "river", "boat", "cruise", "harbor", "harbour"], 4),
    (["garden", "plant", "flower", "picnic", "park"], 4),
    (["gym", "workout", "run", "yoga", "training", "climb", "soccer", "football", "match", "pitch", "tennis", "basketball"], 5),
    (["bike", "cycl", "ride"], 5),
    (["dinner", "restaurant", "ramen", "sushi", "food", "brunch", "lunch", "eat", "waffle", "pizza", "taco"], 0),
    (["coffee", "cafe", "espresso"], 0),
    (["cook", "bake", "kitchen", "recipe"], 0),
    (["movie", "film", "cinema", "screening"], 3),
    (["concert", "music", "gig", "festival", "album"], 3),
    (["museum", "gallery", "exhibit"], 3),
    (["read", "book", "library"], 3),
    (["game", "arcade", "board"], 3),
    (["birthday", "anniversary", "celebrat", "wedding"], 1),
    (["dance", "salsa", "club"], 1),
    (["spa", "massage", "rest", "lazy", "sleep"], 1),
  ]

  static func emoji(for title: String?) -> String {
    guard let title = title?.lowercased(), !title.isEmpty else { return "🗓" }
    if title.contains("flight") || title.contains("fly") || title.contains("airline") || title.contains("airport") || title.contains("trip") || title.contains("travel") { return "✈️" }
    if title.contains("hotel") || title.contains("airbnb") || title.contains("booking") || title.contains("room") { return "🏨" }
    if title.contains("train") || title.contains("rail") || title.contains("amtrak") { return "🚆" }
    if title.contains("drive") || title.contains("road") { return "🛣" }
    if title.contains("beach") || title.contains("ocean") || title.contains("sunset") || title.contains("island") { return "🌅" }
    if title.contains("hike") || title.contains("trail") || title.contains("mountain") || title.contains("camp") { return "🏔" }
    if title.contains("kayak") || title.contains("canoe") || title.contains("boat") || title.contains("cruise") { return "🛶" }
    if title.contains("gym") || title.contains("workout") || title.contains("run") || title.contains("training") { return "🏃" }
    if title.contains("bike") || title.contains("ride") || title.contains("cycl") { return "🚲" }
    if title.contains("dinner") || title.contains("restaurant") || title.contains("ramen") || title.contains("sushi") || title.contains("eat") || title.contains("lunch") || title.contains("food") { return "🍜" }
    if title.contains("coffee") || title.contains("cafe") { return "☕" }
    if title.contains("movie") || title.contains("cinema") || title.contains("film") { return "🎞" }
    if title.contains("concert") || title.contains("music") || title.contains("festival") { return "🎶" }
    if title.contains("museum") || title.contains("gallery") { return "🖼" }
    if title.contains("doctor") || title.contains("dentist") || title.contains("clinic") || title.contains("hospital") { return "🩺" }
    return "🗓"
  }
}
