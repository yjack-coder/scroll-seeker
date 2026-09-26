import SwiftUI

struct SeekerCompletionView: View {
  var game: SeekerGame
  var chapters: () -> Void
  var explore: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        Text("一卷，五段人生")
          .font(SeekerStyle.brush(32)).padding(.top, 38)
        Text("The scroll remembers you.")
          .font(.system(.title2, design: .serif))
        Text("\(game.chapter?.englishName ?? "The chapter") · Complete")
          .font(.system(.subheadline, design: .serif)).foregroundStyle(SeekerStyle.paper.opacity(0.7))
        HStack(spacing: 18) {
          ForEach(game.foundTargets) { target in
            VStack(spacing: 12) {
              SeekerSeal(size: 42)
              Text(target.chineseName)
                .font(SeekerStyle.brush(15)).lineLimit(2).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            }
          }
        }.padding(.vertical, 18)
        VStack(spacing: 8) {
          Text(duration(game.elapsedSeconds))
            .font(.system(size: 40, weight: .light, design: .serif)).monospacedDigit()
          Text("TIME SPENT LOOKING CLOSELY")
            .font(.system(size: 9, design: .serif)).tracking(2)
        }.foregroundStyle(SeekerStyle.paper)
        Text("What was once ink is alive again.\nThank you for noticing the little things.")
          .font(.system(.body, design: .serif)).italic().lineSpacing(5)
          .multilineTextAlignment(.center).foregroundStyle(SeekerStyle.paper.opacity(0.8))
        VStack(spacing: 12) {
          Button("Choose another chapter", action: chapters)
            .buttonStyle(SeekerActionStyle(secondary: true))
            .background(SeekerStyle.paper, in: RoundedRectangle(cornerRadius: 6))
          Button("Stay a little longer", action: explore)
            .font(.system(.body, design: .serif)).foregroundStyle(SeekerStyle.paper)
            .padding(14)
        }
      }
      .padding(26).frame(maxWidth: 580).frame(maxWidth: .infinity)
    }
    .foregroundStyle(SeekerStyle.paper)
    .background { SilkBackground(dark: true).ignoresSafeArea() }
  }

  private func duration(_ seconds: TimeInterval) -> String {
    let value = Int(max(0, seconds))
    return String(format: "%02d : %02d", value / 60, value % 60)
  }
}
