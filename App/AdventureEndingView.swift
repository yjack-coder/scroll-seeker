import SwiftUI

struct AdventureEndingView: View {
  var act: AdventureAct
  var onContinue: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false

  private var earnedTitle: String? {
    act.missions.compactMap(\.reward.title).last
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        Text(act.stage == .child ? "醬油帶回了家" : "一段人生，寫入畫中")
          .font(SeekerStyle.brush(35)).multilineTextAlignment(.center)
        Text(act.stage == .child ? "Home, with the soy sauce" : "A life written into the scroll")
          .font(.system(.title2, design: .serif)).multilineTextAlignment(.center)

        HStack(alignment: .bottom, spacing: 30) {
          AdventureHeroSprite(stage: act.stage, height: 180)
          if act.stage == .child {
            VStack(spacing: 8) {
              Text("娘").font(SeekerStyle.brush(49))
                .frame(width: 79, height: 95)
                .foregroundStyle(SeekerStyle.paper)
                .background(SeekerStyle.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
              Text("Mother").font(.system(.caption, design: .serif))
            }.padding(.bottom, 13)
          } else {
            SeekerSeal(size: 64).padding(.bottom, 23).accessibilityHidden(true)
          }
        }
        .padding(.vertical, 17).frame(maxWidth: .infinity)
        .background(SeekerStyle.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .opacity(appeared || reduceMotion ? 1 : 0)

        VStack(spacing: 19) {
          if let earnedTitle {
            Text(earnedTitle).font(SeekerStyle.brush(33)).foregroundStyle(SeekerStyle.red)
              .multilineTextAlignment(.center)
          }
          if act.stage == .child {
            Text("「安兒回來了。」\n“There you are, An.”")
              .font(.system(.title3, design: .serif)).multilineTextAlignment(.center).lineSpacing(6)
          }
          Text(act.outro ?? act.ending ?? act.name)
            .font(.system(.body, design: .serif)).multilineTextAlignment(.center).lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
          if act.stage == .child {
            Rectangle().fill(SeekerStyle.gold.opacity(0.45)).frame(width: 64, height: 1)
            Text("歲月流轉 · Years pass…").font(SeekerStyle.brush(27))
            Text("The Rainbow Bridge is waiting. So is the life you will choose.")
              .font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
              .multilineTextAlignment(.center).lineSpacing(4)
          }
        }
      }
      .padding(28).padding(.top, 16).frame(maxWidth: 620).frame(maxWidth: .infinity)
    }
    .background { SilkBackground().ignoresSafeArea() }
    .foregroundStyle(SeekerStyle.ink)
    .safeAreaInset(edge: .bottom) {
      Button(act.stage == .child ? "See where life leads" : "Carry the story home", action: onContinue)
        .buttonStyle(SeekerActionStyle())
        .padding(.horizontal, 24).padding(.vertical, 14)
        .frame(maxWidth: 620).frame(maxWidth: .infinity)
        .background(SeekerStyle.paper)
    }
    .onAppear {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { appeared = true }
    }
  }
}
