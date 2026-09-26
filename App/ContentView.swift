import SwiftUI

struct ContentView: View {
  var purchases: PurchaseStore
  @State private var journal = JournalStore()
  @State private var animator = ScrollAnimator()
  @State private var selected: JournalEntry?
  @State private var presentation: JournalPresentation?
  @State private var showWords = false
  @State private var scrollPosition = ScrollPosition(edge: .top)
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var entry: JournalEntry? { selected ?? journal.today ?? journal.entries.first }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: 28) {
            JournalBrand()
            if let entry {
              if animator.isOpen {
                PaintingHeading(entry: entry)
              } else {
                InvitationHeading()
              }
              Button {
                if animator.isOpen {
                  showWords = true
                } else {
                  animator.setOpen(true, reduceMotion: reduceMotion)
                }
              } label: {
                PaintedScroll(
                  entry: entry, unroll: animator.unroll, ink: animator.ink,
                  poem: animator.poem, showSeal: animator.seal, isPro: purchases.isPro
                )
                .frame(
                  height: animator.isOpen ? max(350, min(540, geometry.size.height * 0.62)) : 228
                )
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .accessibilityLabel(
                animator.isOpen ? "Read the words behind this painting" : "Open sample scroll")
              if animator.isOpen {
                PaintingActions(
                  entry: entry, isPro: purchases.isPro,
                  showWords: { showWords = true },
                  export: { presentation = purchases.isPro ? .export : .membership })
              } else {
                JournalComposer(
                  journal: journal, isPro: purchases.isPro, locked: { presentation = .membership }
                ) { newEntry in
                  selected = newEntry
                  animator.setOpen(true, reduceMotion: reduceMotion)
                }
              }
            }
            RecentScrolls(
              entries: Array(journal.entries.prefix(3)),
              openEntry: { recent in
                selected = recent
                animator.setOpen(true, reduceMotion: reduceMotion)
              }, openLongScroll: { presentation = .longScroll })
            Text("山水有情，留白有聲。")
              .font(LiubaiStyle.brush(14))
              .tracking(3).foregroundStyle(LiubaiStyle.muted.opacity(0.8))
              .padding(.vertical, 8)
          }
          .padding(.horizontal, geometry.size.width > 650 ? 48 : 24)
          .padding(.top, 14).padding(.bottom, 24)
          .frame(maxWidth: 1100)
          .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .scrollPosition($scrollPosition)
        .onChange(of: animator.isOpen) { _, _ in
          withAnimation(.easeInOut(duration: 0.55)) { scrollPosition.scrollTo(edge: .top) }
        }
        .onChange(of: selected?.id) { _, _ in
          withAnimation(.easeInOut(duration: 0.55)) { scrollPosition.scrollTo(edge: .top) }
        }
        .background {
          LiubaiStyle.paper.ignoresSafeArea()
          PaperTexture().ignoresSafeArea().allowsHitTesting(false)
        }
      }
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button(animator.isOpen ? "Folded" : "Open", systemImage: "arrow.left.and.right") {
            animator.setOpen(!animator.isOpen, reduceMotion: reduceMotion)
          }
          .accessibilityValue(animator.isOpen ? "Open" : "Folded")
          Button("Settings", systemImage: "gearshape") { presentation = .settings }
        }
      }
      .toolbarBackground(LiubaiStyle.paper.opacity(0.9), for: .navigationBar)
      .modifier(HingeObserver(animator: animator))
      .sensoryFeedback(.impact(weight: .heavy, intensity: 0.6), trigger: animator.stampCount)
      .sheet(item: $presentation) { destination in
        switch destination {
        case .longScroll: LongScrollView(journal: journal, purchases: purchases)
        case .settings: JournalSettings(purchases: purchases)
        case .membership: MembershipView(purchaseStore: purchases)
        case .export:
          if let entry { ExportScrollView(entry: entry) }
        }
      }
      .sheet(isPresented: $showWords) {
        if let entry { OriginalWordsView(entry: entry) }
      }
    }
    .foregroundStyle(LiubaiStyle.ink)
  }
}

private enum JournalPresentation: String, Identifiable {
  case longScroll, settings, membership, export
  var id: String { rawValue }
}

private struct InvitationHeading: View {
  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 10) {
        Rectangle().frame(width: 20, height: 0.5)
        Text(Date.now, format: .dateTime.month(.wide).day()).textCase(.uppercase).tracking(2)
        Rectangle().frame(width: 20, height: 0.5)
      }
      .font(.system(size: 9, weight: .medium)).foregroundStyle(LiubaiStyle.muted)
      Text("A little space\nto set it down.")
        .font(.system(size: 36, weight: .regular, design: .serif))
        .lineSpacing(2).multilineTextAlignment(.center)
      Text("今天，你心裡放著什麼？")
        .font(LiubaiStyle.brush(18)).foregroundStyle(LiubaiStyle.muted)
    }
    .padding(.top, 10)
    .accessibilityElement(children: .combine)
  }
}

private struct PaintingHeading: View {
  var entry: JournalEntry

  var body: some View {
    VStack(spacing: 10) {
      Text(entry.isSample ? "FROM THE STUDIO · SAMPLE LANDSCAPE" : "YOUR INNER LANDSCAPE")
        .font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(LiubaiStyle.muted)
      Text(entry.title).font(LiubaiStyle.serif(32)).multilineTextAlignment(.center)
      Text(entry.date, format: .dateTime.month(.wide).day().year())
        .font(.system(size: 11, design: .serif)).foregroundStyle(LiubaiStyle.muted)
    }
    .padding(.top, 8)
  }
}

private struct PaintingActions: View {
  var entry: JournalEntry
  var isPro: Bool
  var showWords: () -> Void
  var export: () -> Void

  var body: some View {
    VStack(spacing: 17) {
      Text("The mountain holds. The water lets go.")
        .font(LiubaiStyle.serif(15)).italic().foregroundStyle(LiubaiStyle.muted)
      HStack(spacing: 20) {
        Button("Your words", systemImage: "book.closed", action: showWords)
        Rectangle().fill(LiubaiStyle.rule).frame(width: 0.5, height: 18)
        Button("Export unroll", systemImage: "square.and.arrow.up", action: export)
        if !isPro {
          Text("PRO").font(.system(size: 8, weight: .semibold)).foregroundStyle(LiubaiStyle.red)
        }
      }
      .font(.system(size: 12, design: .serif)).buttonStyle(.plain)
    }
  }
}

private struct RecentScrolls: View {
  var entries: [JournalEntry]
  var openEntry: (JournalEntry) -> Void
  var openLongScroll: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 17) {
      Rectangle().fill(LiubaiStyle.rule.opacity(0.6)).frame(height: 0.5)
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Days become a landscape").font(LiubaiStyle.serif(19))
          Text("A few pages from the journey.").font(.system(size: 11)).foregroundStyle(
            LiubaiStyle.muted)
        }
        Spacer(minLength: 4)
        Button("The Long Scroll", systemImage: "chevron.right", action: openLongScroll)
          .labelStyle(.iconOnly).frame(width: 44, height: 44)
          .foregroundStyle(LiubaiStyle.red)
      }
      HStack(spacing: 12) {
        ForEach(entries) { entry in
          Button {
            openEntry(entry)
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              InkLandscape(parameters: entry.parameters, seed: entry.seed)
                .frame(height: 83).clipped()
                .overlay {
                  Rectangle().strokeBorder(LiubaiStyle.rule.opacity(0.45), lineWidth: 0.5)
                }
              Text(entry.date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 10, design: .serif)).foregroundStyle(LiubaiStyle.muted)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            "\(entry.title), \(entry.date.formatted(date: .abbreviated, time: .omitted))")
        }
      }
      Button(action: openLongScroll) {
        HStack {
          Text("長卷  ·  The Long Scroll")
          Spacer()
          Image(systemName: "arrow.left.and.right")
        }.font(.system(size: 12, design: .serif))
          .padding(.vertical, 8).contentShape(Rectangle())
      }
      .buttonStyle(.plain).foregroundStyle(LiubaiStyle.red)
    }
  }
}

struct OriginalWordsView: View {
  var entry: JournalEntry
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          ChopSeal(text: "心語", size: 44)
          Text(entry.isSample ? "Words from the studio" : "What you were carrying")
            .font(LiubaiStyle.serif(29))
          Text(entry.words).font(.system(.title2, design: .serif)).lineSpacing(9)
          Divider()
          Text(entry.poemChinese.joined(separator: "\n"))
            .font(.system(.title3, design: .serif)).lineSpacing(10)
          Text(entry.poemEnglish.joined(separator: "\n"))
            .font(.system(.body, design: .serif)).italic().lineSpacing(8).foregroundStyle(
              LiubaiStyle.muted)
          Text(entry.date, format: .dateTime.month(.wide).day().year()).font(.caption)
            .foregroundStyle(LiubaiStyle.muted)
        }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(LiubaiStyle.paper)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }
}
