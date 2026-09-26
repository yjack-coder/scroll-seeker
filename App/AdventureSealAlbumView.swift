import SwiftUI

struct AdventureSealAlbumView: View {
  var game: AdventureGame
  var isPro: Bool
  var onPaywall: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var selectedMission: AdventureMission?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          VStack(alignment: .leading, spacing: 8) {
            Text("一事一印，一路一生。").font(SeekerStyle.brush(29))
            Text("A seal for each kindness. A life across the scroll.")
              .font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
            Text("\(game.completedMissionIDs.intersection(Set(game.archive.allMissions.map(\.id))).count) of \(game.archive.allMissions.count) seals collected")
              .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.red)
          }
          ForEach(game.archive.acts) { act in
            AdventureSealAlbumSection(act: act, completed: game.completedMissionIDs,
              locked: !act.free && !isPro) { mission in
                if !act.free && !isPro { onPaywall() }
                else if game.completedMissionIDs.contains(mission.id) { selectedMission = mission }
              }
          }
        }
        .padding(22).frame(maxWidth: 850).frame(maxWidth: .infinity)
      }
      .background { SilkBackground().ignoresSafeArea() }
      .foregroundStyle(SeekerStyle.ink)
      .navigationTitle("印譜 · Seal album").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
      }
    }
    .sheet(item: $selectedMission) { mission in
      AdventureSealMemory(mission: mission)
    }
  }
}

private struct AdventureSealAlbumSection: View {
  var act: AdventureAct
  var completed: Set<String>
  var locked: Bool
  var onSelect: (AdventureMission) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Text(act.name).font(.system(.title3, design: .serif))
        Spacer(minLength: 8)
        if locked { Label("Pro", systemImage: "lock").font(.caption).foregroundStyle(SeekerStyle.red) }
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 118, maximum: 185), spacing: 12)], spacing: 14) {
        ForEach(act.missions) { mission in
          let earned = completed.contains(mission.id)
          Button { onSelect(mission) } label: {
            VStack(spacing: 12) {
              AdventureMissionSeal(name: mission.sealName, size: 76, earned: earned)
                .accessibilityHidden(true)
              Text(mission.chineseName).font(.system(.subheadline, design: .serif))
              Text(locked ? "Pro" : earned ? "Collected · 重溫" : "Still to come")
                .font(.system(.caption2, design: .serif)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 156)
            .padding(10)
            .background(SeekerStyle.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 6))
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(SeekerStyle.gold.opacity(0.28), lineWidth: 1) }
          }
          .buttonStyle(.plain).disabled(!earned && !locked)
          .accessibilityLabel("\(mission.sealName), \(mission.englishName). \(locked ? "Requires Pro" : earned ? "Collected. Read the poem" : "Complete this scene to earn the seal")")
        }
      }
    }
  }
}

private struct AdventureSealMemory: View {
  var mission: AdventureMission
  private var poems: AdventurePoemStore { .shared }
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 25) {
          AdventureMissionSeal(name: mission.sealName, size: 115)
          Text(mission.chineseName).font(SeekerStyle.brush(30))
          Text(mission.englishName).font(.system(.title3, design: .serif))
          AdventureSealPoem(chinese: poems.poem(for: mission).chinese, english: poems.poem(for: mission).english)
        }.padding(28).frame(maxWidth: 620).frame(maxWidth: .infinity)
      }
      .background { SilkBackground().ignoresSafeArea() }.foregroundStyle(SeekerStyle.ink)
      .navigationTitle("一印一詩 · A seal and a poem").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button("Done", systemImage: "checkmark") { dismiss() } }
      }
    }
    .task(id: mission.id) { await poems.prepare(for: mission) }
  }
}
