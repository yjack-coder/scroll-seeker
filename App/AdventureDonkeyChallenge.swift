import SwiftUI
import UIKit

struct AdventureDonkeyChallenge: View {
    var posture: AdventurePostureStore
    var onSuccess: () -> Void
    @State private var lineup: [Int: Int] = [:]
    @State private var selected: Int?
    @State private var image: UIImage?
    private let tokens = [DonkeyToken(id: 1, name: "一"), DonkeyToken(id: 2, name: "二"), DonkeyToken(id: 3, name: "三")]

    var body: some View {
        Group {
            if posture.current == .laptop {
                AdventureLaptopLayout {
                    caravanScene
                } controls: {
                    donkeyControls
                }
            } else {
                VStack(spacing: 24) {
                    caravanScene
                    donkeyControls
                }
            }
        }
        .foregroundStyle(SeekerStyle.ink)
        .sensoryFeedback(.selection, trigger: lineup.count)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: posture.changeCount)
        .task {
            if let url = ScrollArchive.resourceURL(for: "clues/donkeys.jpg") { image = UIImage(contentsOfFile: url.path) }
        }
    }

    private var donkeyControls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                ForEach(tokens) { token in
                    Button { selected = token.id } label: {
                        donkeyCard(token: token, placed: lineup.values.contains(token.id))
                            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(selected == token.id ? SeekerStyle.red : .clear, lineWidth: 2) }
                    }
                    .buttonStyle(.plain)
                    .draggable("donkey-\(token.id)")
                    .disabled(lineup.values.contains(token.id))
                    .accessibilityLabel("Donkey \(token.id), \(lineup.values.contains(token.id) ? "back in line" : "tap to select")")
                }
            }
            .padding(.vertical, 16)
            Text("把驢兒拖到上方空位，或先點驢、再點空位。\nDrag a donkey to a place above, or tap a donkey and then a place.")
                .font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center)
        }
    }

    private var caravanScene: some View {
        VStack(spacing: 20) {
            Text("把三頭驢牽回隊伍").font(SeekerStyle.brush(25))
            Text("Bring the three donkeys back into line.")
                .font(.system(.body, design: .serif)).multilineTextAlignment(.center)
            Text("隊伍 · THE CARAVAN").font(.system(.caption2, design: .serif)).tracking(2)
                .foregroundStyle(SeekerStyle.gold)
            HStack(spacing: 12) {
                ForEach(tokens) { slot in
                    Button {
                        if let selected { place(selected, in: slot.id) }
                    } label: {
                        VStack(spacing: 10) {
                            if let donkey = lineup[slot.id] {
                                Text(tokens[donkey - 1].name).font(SeekerStyle.brush(38))
                                Text("歸隊 · HOME").font(.system(size: 10, design: .serif))
                            } else {
                                Text(slot.name).font(SeekerStyle.brush(38)).opacity(0.3)
                                Text("放在這裡").font(.system(.caption2, design: .serif))
                            }
                        }
                        .foregroundStyle(SeekerStyle.indigo)
                        .frame(maxWidth: .infinity).frame(height: 116)
                        .background(SeekerStyle.gold.opacity(lineup[slot.id] == nil ? 0.05 : 0.17), in: RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold, style: StrokeStyle(lineWidth: 1, dash: lineup[slot.id] == nil ? [5, 4] : [])) }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .dropDestination(for: String.self) { items, _ in
                        guard let item = items.first, item.hasPrefix("donkey-"), let id = Int(item.dropFirst(7)) else { return false }
                        return place(id, in: slot.id)
                    }
                    .accessibilityLabel("Caravan place \(slot.id), \(lineup[slot.id] == nil ? "empty, tap to place selected donkey" : "filled")")
                }
            }
            Text("\(lineup.count) / 3 歸隊 · back in line")
                .font(.system(.subheadline, design: .serif)).foregroundStyle(SeekerStyle.gold)
        }
    }

    private func donkeyCard(token: DonkeyToken, placed: Bool) -> some View {
        VStack(spacing: 8) {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(height: 76).clipped()
            }
            Text("驢 \(token.name)").font(SeekerStyle.brush(22)).padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(SeekerStyle.paper, in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.7), lineWidth: 1) }
        .opacity(placed ? 0.22 : 1)
    }

    @discardableResult private func place(_ donkey: Int, in slot: Int) -> Bool {
        guard (1...3).contains(donkey), lineup[slot] == nil, !lineup.values.contains(donkey) else { return false }
        lineup[slot] = donkey
        selected = nil
        if lineup.count == 3 { onSuccess() }
        return true
    }

    private struct DonkeyToken: Identifiable { var id: Int; var name: String }
}
