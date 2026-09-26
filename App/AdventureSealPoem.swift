import SwiftUI

struct AdventureSealPoem: View {
  var chinese: String
  var english: String

  var body: some View {
    VStack(spacing: 18) {
      Text(chinese).font(SeekerStyle.brush(29)).lineSpacing(13)
      Text(english).font(.system(.subheadline, design: .serif)).italic().lineSpacing(7)
        .foregroundStyle(SeekerStyle.ink.opacity(0.72))
    }
    .multilineTextAlignment(.center)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.vertical, 18).frame(maxWidth: .infinity)
    .accessibilityElement(children: .combine)
  }
}
