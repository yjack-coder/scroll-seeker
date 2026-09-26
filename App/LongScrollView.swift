import SwiftUI

struct LongScrollView: View {
  var journal: JournalStore
  var purchases: PurchaseStore
  @Environment(\.dismiss) private var dismiss
  @State private var showMembership = false
  @State private var selected: JournalEntry?

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        let paintingHeight = max(230, min(400, geometry.size.height * 0.48))
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
              Text("長卷").font(LiubaiStyle.brush(36))
              Text("The Long Scroll").font(LiubaiStyle.serif(28))
              Text("Some days are mountains. Some days are water.\nAll of them belong here.")
                .font(LiubaiStyle.serif(14)).lineSpacing(5).foregroundStyle(LiubaiStyle.muted)
            }.padding(.horizontal, 26)
            ScrollView(.horizontal) {
              LazyHStack(spacing: 0) {
                ForEach(journal.entriesForScroll(isPro: purchases.isPro)) { entry in
                  LongScrollPanel(
                    entry: entry, width: max(280, geometry.size.width * 0.75),
                    height: paintingHeight, isPro: purchases.isPro
                  ) {
                    selected = entry
                  }
                }
              }.padding(.horizontal, 24)
            }
            .frame(height: paintingHeight + 68)
            .scrollIndicators(.hidden)
            HStack {
              Image(systemName: "arrow.left.and.right")
              Text("Wander through your days")
              Spacer()
              Text(purchases.isPro ? "365 DAYS" : "LAST 7 DAYS")
                .font(.system(size: 9, weight: .medium)).tracking(1.5)
            }
            .font(.system(size: 11, design: .serif)).foregroundStyle(LiubaiStyle.muted)
            .padding(.horizontal, 26)
            if !purchases.isPro {
              Button {
                showMembership = true
              } label: {
                HStack(spacing: 13) {
                  ChopSeal(text: "長卷", size: 32)
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Give every day a place").font(LiubaiStyle.serif(17))
                    Text("Unroll a full year with Liubai Pro.").font(.caption).foregroundStyle(
                      LiubaiStyle.muted)
                  }
                  Spacer()
                  Image(systemName: "chevron.right").font(.caption)
                }.padding(17).background(
                  LiubaiStyle.rule.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
              }.buttonStyle(.plain).padding(.horizontal, 24)
            }
          }
          .padding(.top, 18)
          .padding(.bottom, 24)
          .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
      }
      .background {
        LiubaiStyle.paper.ignoresSafeArea()
        PaperTexture().ignoresSafeArea()
      }
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
      }
      .sheet(isPresented: $showMembership) { MembershipView(purchaseStore: purchases) }
      .sheet(item: $selected) { OriginalWordsView(entry: $0) }
    }
    .foregroundStyle(LiubaiStyle.ink)
  }
}

private struct LongScrollPanel: View {
  var entry: JournalEntry
  var width: CGFloat
  var height: CGFloat
  var isPro: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 13) {
        ZStack(alignment: .topTrailing) {
          InkLandscape(parameters: entry.parameters, seed: entry.seed)
          Text(entry.poemChinese.prefix(2).joined(separator: "\n"))
            .font(isPro ? LiubaiStyle.brush(18) : LiubaiStyle.serif(16))
            .lineSpacing(9).padding(24)
          VStack {
            Spacer()
            ChopSeal(text: entry.date.formatted(.dateTime.day()), size: 31)
          }.padding(15)
        }
        .frame(width: width, height: height)
        .overlay { Rectangle().strokeBorder(LiubaiStyle.rule.opacity(0.5), lineWidth: 0.6) }
        HStack {
          VStack(alignment: .leading, spacing: 5) {
            Text(entry.title).font(LiubaiStyle.serif(16))
            Text(entry.date, format: .dateTime.month(.abbreviated).day()).font(.caption)
              .foregroundStyle(LiubaiStyle.muted)
          }
          Spacer()
          if entry.isSample {
            Text("STUDIO SAMPLE").font(.system(size: 7, weight: .medium)).tracking(1)
              .foregroundStyle(LiubaiStyle.muted)
          }
        }.padding(.horizontal, 13)
      }
      .frame(width: width)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      "\(entry.title), \(entry.date.formatted(date: .abbreviated, time: .omitted)). Read reflection."
    )
  }
}
