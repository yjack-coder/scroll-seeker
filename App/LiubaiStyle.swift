import SwiftUI

enum LiubaiStyle {
  static let paper = Color(red: 0.965, green: 0.951, blue: 0.912)
  static let ink = Color(red: 0.19, green: 0.22, blue: 0.21)
  static let muted = Color(red: 0.43, green: 0.44, blue: 0.39)
  static let red = Color(red: 0.65, green: 0.22, blue: 0.17)
  static let rule = Color(red: 0.76, green: 0.73, blue: 0.65)
  static let jade = Color(red: 0.35, green: 0.43, blue: 0.38)

  static func serif(_ size: CGFloat) -> Font {
    .system(size: size, weight: .regular, design: .serif)
  }

  static func brush(_ size: CGFloat) -> Font {
    .custom("STKaiti", size: size, relativeTo: .title)
  }
}

struct ChopSeal: View {
  var text = "留白"
  var size: CGFloat = 36

  var body: some View {
    Text(text)
      .font(LiubaiStyle.brush(size * 0.42))
      .lineSpacing(0)
      .foregroundStyle(LiubaiStyle.paper)
      .frame(width: size, height: size)
      .background(LiubaiStyle.red, in: RoundedRectangle(cornerRadius: 2))
      .overlay {
        RoundedRectangle(cornerRadius: 1)
          .strokeBorder(LiubaiStyle.paper.opacity(0.65), lineWidth: 0.8)
          .padding(3)
      }
      .rotationEffect(.degrees(-2))
      .accessibilityLabel(text == "留白" ? "Liubai seal" : text)
  }
}

struct InkButtonStyle: ButtonStyle {
  var filled = true

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.subheadline, design: .serif).weight(.medium))
      .tracking(0.5)
      .foregroundStyle(filled ? LiubaiStyle.paper : LiubaiStyle.ink)
      .padding(.horizontal, 22)
      .frame(minHeight: 50)
      .frame(maxWidth: .infinity)
      .background(
        filled ? LiubaiStyle.red : LiubaiStyle.rule.opacity(0.12),
        in: RoundedRectangle(cornerRadius: 5)
      )
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

struct JournalBrand: View {
  var body: some View {
    HStack(spacing: 11) {
      ChopSeal(size: 34)
      VStack(alignment: .leading, spacing: 2) {
        Text("留白  Liubai").font(LiubaiStyle.serif(21))
        Text("A LANDSCAPE OF THE HEART")
          .font(.system(size: 8, weight: .medium)).tracking(2)
          .foregroundStyle(LiubaiStyle.muted)
      }
      Spacer()
    }
    .foregroundStyle(LiubaiStyle.ink)
    .accessibilityElement(children: .combine)
  }
}
