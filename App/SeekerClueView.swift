import SwiftUI

struct SeekerClueView: View {
  var game: SeekerGame
  var open: () -> Void

  var body: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 18) {
          HStack {
            Text(game.chapter?.chineseName ?? "汴河").font(SeekerStyle.brush(25))
            Rectangle().fill(SeekerStyle.gold.opacity(0.45)).frame(height: 1)
            Text("\(game.foundCount) / \(game.chapterTargets.count) FOUND")
              .font(.system(size: 10, weight: .medium, design: .serif)).tracking(1.4)
          }
          .foregroundStyle(SeekerStyle.gold)

          if let target = game.currentTarget {
            VStack(spacing: 16) {
              Text("尋  ·  SEEK").font(.system(.caption2, design: .serif)).tracking(4).foregroundStyle(SeekerStyle.gold)
              BrassMagnifier(target: target, diameter: min(216, max(140, geometry.size.height * 0.27)))
                .padding(.bottom, 6)
              VStack(spacing: 8) {
                Text(target.chineseName).font(SeekerStyle.brush(35))
                Text(target.englishName).font(.system(.title3, design: .serif))
              }
              .foregroundStyle(SeekerStyle.ink)
              Text("Somewhere in the scroll,\na small story is waiting.")
                .font(.system(.subheadline, design: .serif)).italic()
                .multilineTextAlignment(.center).foregroundStyle(SeekerStyle.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background { SilkBackground() }
            .overlay { Rectangle().strokeBorder(SeekerStyle.gold.opacity(0.45), lineWidth: 1).padding(8) }
          } else {
            VStack(spacing: 18) {
              SeekerSeal(size: 62)
              Text("Every story, discovered.").font(.system(.title2, design: .serif))
              Text("Unfold to revisit the living scroll.").font(.system(.body, design: .serif))
            }.frame(maxWidth: .infinity).padding(.vertical, 60)
          }

          Button(action: open) {
            HStack {
              Text("展開畫卷").font(SeekerStyle.brush(23))
              Spacer()
              Text("Unfold to search").font(.system(.subheadline, design: .serif))
              Image(systemName: "arrow.left.and.right")
            }
          }.buttonStyle(SeekerActionStyle())
          Text("Read from right to left, as the painter intended.")
            .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.gold)
        }
        .padding(24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
      }
    }
    .background { SilkBackground().ignoresSafeArea() }
  }
}
