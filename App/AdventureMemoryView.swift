import SwiftUI

struct AdventureMemoryView: View {
  var game: AdventureGame
  var painting: ScrollArchive
  var posture: AdventurePostureStore

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 18) {
          Text("同一山水，不同年歲").font(SeekerStyle.brush(30))
          Text("The same place. A different age.").font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
          HStack(alignment: .top, spacing: 16) {
            AdventureMemoryPage(title: "那一年", subtitle: "Then", stage: .child, isFuture: false,
              point: CGPoint(x: game.heroX, y: game.heroY), height: max(250, geometry.size.height * 0.60))
            AdventureMemoryPage(title: game.stage == .child ? "未來" : "此刻", subtitle: game.stage == .child ? "One day" : "Now",
              stage: game.stage == .child ? .scholar : game.stage, isFuture: game.stage == .child,
              point: CGPoint(x: game.heroX, y: game.heroY), height: max(250, geometry.size.height * 0.60))
          }
          Text(game.stage == .child ? "Somewhere in the unwritten years, another Xiao An is waiting." : "The child is still here, in every step you take.")
            .font(.system(.footnote, design: .serif)).italic().multilineTextAlignment(.center)
          Button("Open to continue", systemImage: "chevron.right") { posture.set(.open) }
            .buttonStyle(SeekerActionStyle()).frame(maxWidth: 380)
        }.padding(18).frame(maxWidth: .infinity)
      }
    }
    .background { SilkBackground().ignoresSafeArea() }.foregroundStyle(SeekerStyle.ink)
  }
}

private struct AdventureMemoryPage: View {
  var title: String
  var subtitle: String
  var stage: AdventureStage
  var isFuture: Bool
  var point: CGPoint
  var height: CGFloat

  var body: some View {
    VStack(spacing: 9) {
      Text(title).font(SeekerStyle.brush(30))
      Text(subtitle).font(.system(.subheadline, design: .serif))
      GeometryReader { geometry in
        let heroHeight = min(82, max(48, geometry.size.height * 0.19))
        WorldPaintingCrop(center: point, anchor: UnitPoint(x: 0.5, y: 0.72),
          heroStage: stage, heroHeight: heroHeight,
          heroOpacity: isFuture ? 0.26 : 1, heroSaturation: isFuture ? 0 : 1)
      }
      .frame(height: height).clipShape(RoundedRectangle(cornerRadius: 6))
      .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(SeekerStyle.gold.opacity(0.4), lineWidth: 1) }
      .accessibilityLabel("\(subtitle): Xiao An as \(stage.englishName), at the same place in the world painting\(isFuture ? ", an imagined future" : "")")
    }.frame(maxWidth: .infinity)
  }
}
