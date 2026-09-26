import SwiftUI
import UIKit

struct AdventureRewardView: View {
  var archive: AdventureArchive
  var mission: AdventureMission
  var stage: AdventureStage
  var onContinue: () -> Void
  private var poems: AdventurePoemStore { .shared }
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var stamped = false

  var body: some View {
    ScrollView {
      VStack(spacing: 22) {
        VStack(spacing: 19) {
          AdventureMissionSeal(name: mission.sealName, size: 112)
            .scaleEffect(stamped || reduceMotion ? 1 : 1.9)
            .rotationEffect(.degrees(stamped || reduceMotion ? 0 : -8))
            .opacity(stamped || reduceMotion ? 1 : 0)
          VStack(spacing: 6) {
            Text(mission.chineseName).font(SeekerStyle.brush(31))
            Text(mission.englishName).font(.system(.title3, design: .serif))
          }
        }.multilineTextAlignment(.center)
        AdventureSealPoem(chinese: poems.poem(for: mission).chinese, english: poems.poem(for: mission).english)
        AdventureRewardScene(missionID: mission.id, stage: stage)
        AdventureEarnedItems(archive: archive, reward: mission.reward)
        Text("A new seal in your album. A memory in your story journal.")
          .font(.system(.footnote, design: .serif)).italic().foregroundStyle(.secondary)
      }
      .padding(25).padding(.top, 14)
      .frame(maxWidth: 620).frame(maxWidth: .infinity)
    }
    .background { SilkBackground().ignoresSafeArea() }
    .foregroundStyle(SeekerStyle.ink)
    .safeAreaInset(edge: .bottom) {
      Button("Continue the story", action: onContinue)
        .buttonStyle(SeekerActionStyle())
        .padding(.horizontal, 24).padding(.vertical, 14)
        .frame(maxWidth: 620).frame(maxWidth: .infinity)
        .background(SeekerStyle.paper)
    }
    .sensoryFeedback(.impact(weight: .medium, intensity: 0.45), trigger: stamped)
    .onAppear {
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.42)) { stamped = true }
    }
    .task(id: mission.id) { await poems.prepare(for: mission) }
  }
}

private struct AdventureRewardScene: View {
  var missionID: String
  var stage: AdventureStage
  @State private var image: UIImage?

  private var artworkName: String? {
    switch missionID {
    case "m1": "donkeys"
    case "m4": "rainbow_bridge"
    case "a1": "scaffold_tower"
    case "a2", "b2", "b5": "city_gate"
    case "a3": "camels"
    case "a4": "wine_shop_sign"
    case "a5", "b4": "sedan_chair"
    case "b1": "cargo_boat"
    case "b3": "ox_cart"
    default: nil
    }
  }

  var body: some View {
    VStack(spacing: 11) {
      if let image {
        Image(uiImage: image).resizable().scaledToFit()
          .frame(maxWidth: 360)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.5), lineWidth: 1) }
          .accessibilityLabel("A color interpretation of the scene Xiao An discovered")
        Text("The scene come to life")
          .font(.system(.subheadline, design: .serif)).italic()
        Text("A historical color interpretation, shown only in this story card.")
          .font(.system(.caption2, design: .serif)).foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      } else {
        AdventureHeroSprite(stage: stage, height: 164)
          .frame(maxWidth: .infinity).padding(.vertical, 18)
          .background(SeekerStyle.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
      }
    }
    .frame(maxWidth: .infinity)
    .task(id: missionID) {
      image = nil
      guard let artworkName,
        let url = ScrollArchive.resourceURL(for: "colorized/\(artworkName)_color.png")
      else { return }
      image = UIImage(contentsOfFile: url.path)
    }
  }
}

private struct AdventureEarnedItems: View {
  var archive: AdventureArchive
  var reward: AdventureReward

  var body: some View {
    VStack(alignment: .leading, spacing: 17) {
      Text("所得 · A kindness remembered").font(.system(.headline, design: .serif))
      if let coins = reward.coins, coins > 0 {
        HStack(spacing: 12) {
          ZStack {
            Circle().fill(SeekerStyle.gold).frame(width: 29, height: 29)
            Rectangle().fill(SeekerStyle.paper).frame(width: 8, height: 8)
          }.accessibilityHidden(true)
          Text("+\(coins) copper coins")
            .font(.system(.title3, design: .serif).weight(.medium))
        }
      }
      if let gearID = reward.gear {
        let gear = archive.gear.first { $0.id == gearID }
        VStack(alignment: .leading, spacing: 5) {
          Text(gear?.name ?? gearID.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(.title3, design: .serif))
          if let effect = gear?.effect {
            Text(effect).font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
          }
        }
      }
      if let item = reward.item {
        Text(item == "soy_sauce" ? "醬油 · A bottle of soy sauce for Mother" : item.replacingOccurrences(of: "_", with: " ").capitalized)
          .font(.system(.title3, design: .serif))
      }
      if let title = reward.title {
        Text(title).font(SeekerStyle.brush(29)).foregroundStyle(SeekerStyle.red)
      }
    }
    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
    .background(SeekerStyle.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.35), lineWidth: 1) }
  }
}
