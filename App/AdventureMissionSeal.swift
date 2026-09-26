import SwiftUI

/// Each authored mission has its own short seal name; no two earned stamps
/// collapse into the generic app mark.
struct AdventureMissionSeal: View {
  var name: String
  var size: CGFloat = 90
  var earned = true

  private var inscription: String {
    let letters = Array(name)
    guard letters.count > 2 else { return name }
    let split = (letters.count + 1) / 2
    return String(letters.prefix(split)) + "\n" + String(letters.dropFirst(split))
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 3)
        .fill(earned ? SeekerStyle.red : SeekerStyle.gold.opacity(0.045))
      RoundedRectangle(cornerRadius: 2)
        .strokeBorder(earned ? SeekerStyle.paper.opacity(0.8) : SeekerStyle.gold.opacity(0.6),
          style: StrokeStyle(lineWidth: 1.4, dash: earned ? [] : [4, 3]))
        .padding(size * 0.065)
      Text(inscription)
        .font(SeekerStyle.brush(size * (name.count > 2 ? 0.30 : 0.35)))
        .minimumScaleFactor(0.65).multilineTextAlignment(.center).lineSpacing(1)
        .foregroundStyle(earned ? SeekerStyle.paper : SeekerStyle.ink.opacity(0.33))
        .padding(size * 0.12)
    }
    .frame(width: size, height: size)
    .rotationEffect(.degrees(earned ? -3 : 0))
    .accessibilityLabel("\(name), \(earned ? "earned seal" : "unfilled seal")")
  }
}
