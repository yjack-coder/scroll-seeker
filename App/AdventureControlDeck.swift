import SwiftUI

struct AdventureControlDeck: View {
  var game: AdventureGame
  var enabled: Bool
  var talk: () -> Void
  var use: (String?) -> Void
  var jump: () -> Void
  var message: String?
  var posture: AdventurePostureStore
  var onHome: () -> Void
  var onPathEditor: () -> Void
  @State private var selectedItem: String?

  private var slots: [String] { Array((game.inventory.union(game.ownedGear)).sorted().prefix(4)) }

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button("Home", systemImage: "house", action: onHome).labelStyle(.iconOnly).frame(width: 44, height: 30)
        Picker(selection: Binding(get: { posture.current }, set: { posture.set($0) })) {
          ForEach(AdventurePosture.allCases) { value in Text(value.name).tag(value) }
        } label: { Label("Posture", systemImage: "book.closed") }
          .pickerStyle(.menu).font(.caption)
        Spacer()
        Text("\(game.coins) 文").font(.system(.caption, design: .serif))
      }.foregroundStyle(SeekerStyle.paper.opacity(0.8))
      HStack(spacing: 14) {
        HStack(spacing: 5) {
          AdventureWalkControl(direction: -1, enabled: enabled, change: game.setDirection) { game.walk(to: game.heroX - 0.025) }
          AdventureWalkControl(direction: 1, enabled: enabled, change: game.setDirection) { game.walk(to: game.heroX + 0.025) }
        }.frame(maxWidth: .infinity)
        HStack(spacing: 6) {
          action("話", "Talk", action: talk)
          action("用", "Use") { use(selectedItem ?? slots.first) }
          action("躍", "Jump", action: jump)
        }
      }
      GeometryReader { geometry in
        Capsule().fill(SeekerStyle.paper.opacity(0.25)).frame(height: 4).offset(y: 7)
        ForEach(game.archive.segments) { segment in
          Rectangle().fill(SeekerStyle.gold).frame(width: 1, height: 9)
            .position(x: geometry.size.width * (segment.xRange.first ?? 0), y: 9)
        }
        SeekerSeal(size: 16).position(x: 8 + (geometry.size.width - 16) * game.heroX, y: 9)
      }.frame(height: 18)
        .accessibilityLabel("Xiao An is \(Int(game.heroX * 100)) percent across the scroll, city to the left")
        .onLongPressGesture(minimumDuration: 2, perform: onPathEditor)
      HStack(spacing: 8) {
        ForEach(slots, id: \.self) { item in
          Button { selectedItem = item } label: {
            Text(itemName(item)).font(.system(size: 11, design: .serif)).lineLimit(2)
              .frame(maxWidth: .infinity).frame(minHeight: 38)
              .foregroundStyle(SeekerStyle.paper)
              .background(selectedItem == item ? SeekerStyle.gold.opacity(0.65) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
              .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(SeekerStyle.gold.opacity(0.5), lineWidth: 1) }
          }.buttonStyle(.plain).accessibilityLabel("Select \(itemName(item))")
        }
        if slots.isEmpty {
          Text("行囊尚空 · Your satchel is light").font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.paper.opacity(0.7))
        }
      }
      if let message {
        Text(message).font(.system(.caption2, design: .serif)).foregroundStyle(SeekerStyle.paper)
          .multilineTextAlignment(.center)
      }
    }
    .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { SilkBackground(dark: true) }
    .disabled(!enabled)
  }

  private func action(_ chinese: String, _ english: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(spacing: 2) {
        Text(chinese).font(SeekerStyle.brush(20))
        Text(english).font(.system(size: 9, design: .serif))
      }.frame(width: 43, height: 48)
        .foregroundStyle(SeekerStyle.paper)
        .background(SeekerStyle.red, in: RoundedRectangle(cornerRadius: 8))
    }.buttonStyle(.plain).accessibilityLabel(english)
  }

  private func itemName(_ id: String) -> String {
    if id == "soy_sauce" { return "醬油 · Soy sauce" }
    if id == "empty_bottle" { return "空瓶 · Bottle" }
    return game.archive.gear.first { $0.id == id }?.name ?? id
  }
}
