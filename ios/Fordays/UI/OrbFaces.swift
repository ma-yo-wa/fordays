import SwiftUI

struct OrbFaceChip: Identifiable {
  let id: String
  let letter: String
  let them: Bool
}

extension SpaceInfo {
  /// You first, then everyone else, as one letter each. Same as the PWA.
  var faceChips: [OrbFaceChip] {
    let letter = { (name: String) in
      String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
    }
    if !members.isEmpty {
      let isMe = { (id: String) in id.compare(myId, options: .caseInsensitive) == .orderedSame }
      let ordered = members.filter { isMe($0.id) } + members.filter { !isMe($0.id) }
      return ordered.map { OrbFaceChip(id: $0.id, letter: letter($0.name), them: !isMe($0.id)) }
    }
    var list = [OrbFaceChip(id: "me", letter: letter(myName), them: false)]
    if let partner = partnerName, !partner.isEmpty {
      list.append(OrbFaceChip(id: "them", letter: letter(partner), them: true))
    }
    return list
  }

  /// Who's in an Orb, you first: "Just you", "You and Tess", "You, Tess and Kofi".
  var peopleNote: String {
    let others = members
      .filter { $0.id.compare(myId, options: .caseInsensitive) != .orderedSame }
      .map(\.name)
    if others.isEmpty {
      if let partner = partnerName, !partner.isEmpty { return "You and \(partner)" }
      return "Just you"
    }
    let all = ["You"] + others
    return all.dropLast().joined(separator: ", ") + " and " + (all.last ?? "")
  }
}

/// Faces clustered inside an Orb circle: one centred, two side by side,
/// three as two over one, four as a square, and past four the last spot
/// says +N. Same layout as the PWA's OrbFaces.
struct OrbFacesView: View {
  let faces: [OrbFaceChip]
  /// The row-sized cluster used in Settings lists.
  var small = false

  private static let spots: [Int: [(CGFloat, CGFloat)]] = [
    1: [(0, 0)],
    2: [(-1, 0), (1, 0)],
    3: [(-1, -1), (1, -1), (0, 1)],
    4: [(-1, -1), (1, -1), (-1, 1), (1, 1)],
  ]

  private var size: CGFloat { small ? Theme.Spacing.s18 : Theme.TouchTarget.avatarFace }
  private var overlap: CGFloat { small ? Theme.Spacing.xxs : Theme.Spacing.xs }

  var body: some View {
    let spots = Self.spots[min(max(faces.count, 1), 4)] ?? []
    let more = faces.count > 4 ? faces.count - 3 : 0
    let shown = Array(faces.prefix(more > 0 ? 3 : 4))
    let step = (size - overlap) / 2
    return ZStack {
      if more > 0 {
        circle(fill: Theme.fillSecondary) {
          Text("+\(more)").font(small ? .fdMicro : .fdTiny)
        }
        .offset(x: spots[3].0 * step, y: spots[3].1 * step)
      }
      // Drawn last-first so the first face sits on top, like the PWA.
      ForEach(Array(shown.enumerated().reversed()), id: \.element.id) { idx, f in
        circle(fill: Theme.faceColor(for: f.id)) {
          Text(f.letter).font(small ? .fdMicro : .fdCaption.weight(.bold))
        }
        .offset(x: spots[idx].0 * step, y: spots[idx].1 * step)
      }
    }
  }

  private func circle<Label: View>(fill: Color, @ViewBuilder label: () -> Label) -> some View {
    ZStack {
      Circle().fill(fill)
      label()
        .foregroundStyle(Theme.faceInk)
        .offset(y: Theme.Spacing.opticalNudge)
    }
    .frame(width: size, height: size)
    .overlay(
      Circle().stroke(
        Theme.paperWarm,
        lineWidth: small ? Theme.TouchTarget.borderWidth : Theme.TouchTarget.ringWidth
      )
    )
    .fixedSize()
  }
}
