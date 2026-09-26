import SwiftUI

struct AdventureHomeView: View {
  var game: AdventureGame
  var isPro: Bool
  var onUnfold: () -> Void
  var onPaywall: () -> Void
  var onSettings: () -> Void
  var onChoosePath: (() -> Void)? = nil
  var isVisible = true
  @State private var showJournal = false
  @State private var showSealAlbum = false
  @State private var requestAlbumPaywall = false

  var body: some View {
    ScrollView {
      VStack(spacing: 22) {
        HStack(alignment: .center) {
          VStack(alignment: .leading, spacing: 3) {
            Text("小安的家").font(SeekerStyle.brush(34))
            Text("A QUIET PLACE TO RETURN TO")
              .font(.system(.caption2, design: .serif)).tracking(1.8)
          }
          Spacer()
          Button("Settings", systemImage: "gearshape", action: onSettings)
            .labelStyle(.iconOnly).buttonStyle(.bordered).tint(SeekerStyle.ink)
        }
        AdventureFarmhouse(center: CGPoint(x: game.archive.home.x, y: game.archive.home.y))
        AdventureMotherNote(stage: game.stage, forkUnlocked: game.forkUnlocked, objective: game.objective, reply: game.letters.isEmpty ? nil : game.lastMotherReply)
        Button(action: onUnfold) {
          VStack(spacing: 5) {
            Text("展卷出門").font(SeekerStyle.brush(26))
            Text("Unfold to continue your journey").font(.system(.subheadline, design: .serif))
          }
        }.buttonStyle(SeekerActionStyle())
          .accessibilityHint("Resumes exactly where Xiao An was standing on the road.")

        if game.forkUnlocked {
          if let onChoosePath {
            Button("人生岔路 · Return to the fork", action: onChoosePath)
              .buttonStyle(SeekerActionStyle(secondary: true))
              .accessibilityHint("Choose the Scholar or Gentleman Thief path. Both require Pro.")
          } else {
            AdventurePaths(game: game, isPro: isPro, onUnfold: onUnfold, onPaywall: onPaywall)
          }
        }
        AdventureSatchel(game: game)
        AdventureGearShelf(game: game, isPro: isPro, onPaywall: onPaywall)
        AdventureWardrobe(game: game, isPro: isPro, onPaywall: onPaywall)
        Button { showSealAlbum = true } label: {
          HStack(spacing: 15) {
            AdventureMissionSeal(name: "印譜", size: 44).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
              Text("印譜 · Seal album").font(.system(.headline, design: .serif))
              Text("Every kindness leaves its mark.").font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption)
          }
          .padding(20).frame(maxWidth: .infinity, alignment: .leading)
          .background(SeekerStyle.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
        Button { showJournal = true } label: {
          HStack(spacing: 14) {
            Image(systemName: "book.closed").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
              Text("行記 · Story journal").font(.system(.headline, design: .serif))
              Text("\(game.journalEntries.count) memories along the river")
                .font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption)
          }
          .padding(20).frame(maxWidth: .infinity, alignment: .leading)
          .background(SeekerStyle.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
        Text("不管走多遠，記得回家。\nHowever far you wander, remember the way home.")
          .font(.system(.footnote, design: .serif)).lineSpacing(6)
          .multilineTextAlignment(.center).foregroundStyle(SeekerStyle.ink.opacity(0.65))
          .padding(.vertical, 10)
      }
      .padding(22).frame(maxWidth: 660).frame(maxWidth: .infinity)
    }
    .background { SilkBackground().ignoresSafeArea() }
    .foregroundStyle(SeekerStyle.ink)
    .onChange(of: isVisible) { _, visible in
      if !visible {
        showJournal = false
        showSealAlbum = false
        requestAlbumPaywall = false
      }
    }
    .sheet(isPresented: $showJournal) { AdventureJournalView(entries: game.journalEntries, letters: game.letters) }
    .sheet(isPresented: $showSealAlbum, onDismiss: {
      if requestAlbumPaywall { requestAlbumPaywall = false; onPaywall() }
    }) {
      AdventureSealAlbumView(game: game, isPro: isPro) {
        requestAlbumPaywall = true
        showSealAlbum = false
      }
    }
  }
}

private struct AdventureFarmhouse: View {
  var center: CGPoint

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      WorldPaintingCrop(center: center, verticalSpan: 0.72)
      // Mother and Xiao An are already painted at the doorway. Do not add
      // another character on top of their scene.
        VStack(alignment: .trailing, spacing: 5) {
          Text("家").font(SeekerStyle.brush(35))
          Text("HOME · 村口").font(.system(.caption2, design: .serif)).tracking(1)
        }
        .padding(12).background(SeekerStyle.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 4))
        .padding(14)
    }
    .frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.45), lineWidth: 1) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Mother and Xiao An stand at the doorway of their painted countryside home")
  }
}

private struct AdventureMotherNote: View {
  var stage: AdventureStage
  var forkUnlocked: Bool
  var objective: String
  var reply: String?

  private var words: String {
    switch stage {
    case .child:
      forkUnlocked
        ? "「安兒長大了。路要自己走，家總在這裡。」\n“You’ve grown, An. Choose your own way. Home will be here.”"
        : "「安兒，去市集給娘打一瓶醬油回來。」\n“An, bring Mother a bottle of soy sauce from the market.”"
    case .scholar:
      "「讀好書，也要做好人。」\n“Study well, An. And keep a kind heart.”"
    case .thief:
      "「助人可以，自己要平安回來。」\n“Help those in need. Then come safely home.”"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack(spacing: 13) {
        Text("娘").font(SeekerStyle.brush(32))
          .frame(width: 49, height: 49)
          .foregroundStyle(SeekerStyle.paper)
          .background(SeekerStyle.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 5))
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text("娘的叮囑").font(SeekerStyle.brush(25))
          Text("A WORD FROM MOTHER").font(.system(.caption2, design: .serif)).tracking(1.5)
        }
      }
      if reply != nil {
        Text("娘的回信 · Mother’s reply").font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.red)
      }
      Text(reply ?? words).font(.system(.subheadline, design: .serif)).lineSpacing(6)
      Rectangle().fill(SeekerStyle.gold.opacity(0.3)).frame(height: 1)
      Text("Next · \(objective)").font(.system(.subheadline, design: .serif).weight(.medium))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
    .background(SeekerStyle.paper.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.4), lineWidth: 1) }
  }
}

private struct AdventurePaths: View {
  var game: AdventureGame
  var isPro: Bool
  var onUnfold: () -> Void
  var onPaywall: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("人生岔路 · Two paths").font(.system(.title3, design: .serif))
      Text("The errand is over. A lifetime waits beyond the bridge.")
        .font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
      ForEach([AdventureStage.scholar, .thief], id: \.self) { stage in
        Button {
          guard isPro else { onPaywall(); return }
          if game.selectPath(stage, isPro: isPro) { onUnfold() }
        } label: {
          HStack(spacing: 14) {
            AdventureHeroSprite(stage: stage, height: 66)
            VStack(alignment: .leading, spacing: 4) {
              Text(stage.homeRole).font(.system(.headline, design: .serif))
              Text(stage == .scholar ? "Choose the brush. Seek the imperial examination." : "Choose the shadows. Give to those in need.")
                .font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: isPro ? "chevron.right" : "lock")
          }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(SeekerStyle.gold.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
          .accessibilityLabel("\(stage.homeRole). \(isPro ? "Continue this path" : "Requires Pro")")
      }
    }
  }
}

private struct AdventureSatchel: View {
  var game: AdventureGame

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Text("行囊 · Satchel").font(.system(.title3, design: .serif))
        Spacer()
        HStack(spacing: 7) {
          ZStack {
            Circle().fill(SeekerStyle.gold).frame(width: 18, height: 18)
            Rectangle().fill(SeekerStyle.paper).frame(width: 5, height: 5)
          }.accessibilityHidden(true)
          Text("\(game.coins) copper").font(.system(.subheadline, design: .serif).weight(.medium))
        }.accessibilityLabel("\(game.coins) copper coins")
      }
      if game.inventory.isEmpty && game.ownedGear.isEmpty {
        Text("An empty bottle, and a whole world ahead.")
          .font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
      } else {
        ForEach(game.inventory.sorted(), id: \.self) { item in
          Text(item == "soy_sauce" ? "醬油 · A bottle for Mother" : item == "empty_bottle" ? "空瓶 · Empty bottle" : item.replacingOccurrences(of: "_", with: " ").capitalized)
            .font(.system(.subheadline, design: .serif))
        }
        ForEach(game.archive.gear.filter { game.ownsGear($0.id) }) { gear in
          HStack {
            Text(gear.name).font(.system(.subheadline, design: .serif))
            Spacer()
            Image(systemName: "checkmark").font(.caption).foregroundStyle(SeekerStyle.gold)
          }.accessibilityElement(children: .combine)
        }
      }
      ForEach(game.titles.sorted(), id: \.self) { title in
        Text(title).font(SeekerStyle.brush(24)).foregroundStyle(SeekerStyle.red)
      }
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(SeekerStyle.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct AdventureGearShelf: View {
  var game: AdventureGame
  var isPro: Bool
  var onPaywall: () -> Void
  @State private var purchaseNote: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      Text("備好行裝 · A little preparation").font(.system(.title3, design: .serif))
      Text("Spend the copper you earn by helping people.")
        .font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
      ForEach(game.archive.gear.filter { $0.cost != nil || $0.isPro }) { gear in
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(gear.name).font(.system(.subheadline, design: .serif).weight(.medium))
            Text(gear.effect).font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
          }
          Spacer(minLength: 5)
          if game.ownsGear(gear.id) {
            Label("Owned", systemImage: "checkmark").font(.caption).foregroundStyle(SeekerStyle.gold)
          } else if gear.isPro && !isPro {
            Button("Pro", systemImage: "lock", action: onPaywall)
              .buttonStyle(.bordered).tint(SeekerStyle.red)
          } else if let cost = gear.cost {
            Button("\(cost) copper") {
              if game.buyGear(gear.id, isPro: isPro) { purchaseNote = "\(gear.name) is now in your satchel." }
            }.buttonStyle(.bordered).tint(SeekerStyle.indigo)
              .disabled(game.coins < cost)
              .accessibilityHint(game.coins < cost ? "Earn \(cost - game.coins) more coins." : "Buy with coins earned in the story.")
          } else {
            Text("Story reward").font(.system(.caption2, design: .serif))
              .foregroundStyle(.secondary).multilineTextAlignment(.trailing)
          }
        }.padding(.vertical, 7)
      }
      if let purchaseNote {
        Text(purchaseNote).font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.red)
      }
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(SeekerStyle.paper.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
      .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.3), lineWidth: 1) }
  }
}

private struct AdventureWardrobe: View {
  var game: AdventureGame
  var isPro: Bool
  var onPaywall: () -> Void
  @State private var wardrobeNote: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("衣櫥 · Wardrobe").font(.system(.title3, design: .serif))
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        ForEach([AdventureStage.child, .scholar, .thief], id: \.self) { stage in
          Button {
            if stage != .child && !isPro { onPaywall() }
            else if !game.selectOutfit(stage, isPro: isPro) {
              wardrobeNote = "Finish the childhood errand to discover this part of Xiao An’s life."
            } else { wardrobeNote = nil }
          } label: {
            VStack(spacing: 7) {
              AdventureHeroSprite(stage: stage, height: 78)
              Text(stage.homeShortRole).font(.system(.caption, design: .serif)).multilineTextAlignment(.center)
              if game.selectedOutfit == stage {
                Label("Wearing", systemImage: "checkmark").font(.system(.caption2, design: .serif))
              } else if stage != .child && !isPro {
                Label("Pro", systemImage: "lock").font(.system(.caption2, design: .serif))
              } else {
                Text(game.canSelectOutfit(stage, isPro: isPro) ? "Wear" : "Story locked")
                  .font(.system(.caption2, design: .serif))
              }
            }
            .padding(.vertical, 14).frame(maxWidth: .infinity, minHeight: 157)
            .background(game.selectedOutfit == stage ? SeekerStyle.gold.opacity(0.20) : SeekerStyle.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(game.selectedOutfit == stage ? 0.8 : 0.2), lineWidth: 1) }
          }.buttonStyle(.plain)
            .accessibilityLabel("\(stage.homeRole), \(game.selectedOutfit == stage ? "wearing" : stage != .child && !isPro ? "requires Pro" : "choose outfit")")
        }
      }
      if let wardrobeNote { Text(wardrobeNote).font(.system(.caption, design: .serif)).foregroundStyle(.secondary) }
    }
  }
}

private extension AdventureStage {
  var homeRole: String {
    switch self {
    case .child: "孩童 · The Child"
    case .scholar: "書生 · The Scholar"
    case .thief: "神偷 · Gentleman Thief"
    }
  }

  var homeShortRole: String {
    switch self {
    case .child: "孩童\nChild"
    case .scholar: "書生\nScholar"
    case .thief: "神偷\nThief"
    }
  }
}
