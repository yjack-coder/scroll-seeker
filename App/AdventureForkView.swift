import SwiftUI

struct AdventureForkView: View {
  var purchases: PurchaseStore
  var posture: AdventurePostureStore
  var onChoose: (AdventureStage) -> Void
  var onClose: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showMembership = false
  @State private var requestedStage: AdventureStage?
  @State private var selectedStage: AdventureStage?
  @State private var transitionTask: Task<Void, Never>?
  @State private var availableWidth: CGFloat = 700

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 22) {
          VStack(spacing: 9) {
            Text("虹橋之上，人生兩途").font(SeekerStyle.brush(33))
            Text("Two futures, between the pages").font(.system(.title3, design: .serif))
          }.multilineTextAlignment(.center).padding(.top, 8)
          if posture.current == .book {
            AdventureFuturePages(isPro: purchases.isPro, selection: selectedStage, choose: choose)
              .frame(height: availableWidth < 500 ? 650 : 510)
            Text("左頁執筆，右頁入夜。\nChoose the brush on the left, or the shadows on the right.")
              .font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center).lineSpacing(5)
          } else {
            VStack(spacing: 23) {
              HStack(spacing: 30) {
                AdventureHeroSprite(stage: .scholar, height: 115)
                AdventureHeroSprite(stage: .thief, height: 115)
              }.opacity(0.45).accessibilityHidden(true)
              Text("Half-open the scroll like a book to see your futures")
                .font(.system(.title3, design: .serif)).multilineTextAlignment(.center)
              Text("半開畫卷，一生兩面。").font(SeekerStyle.brush(26)).foregroundStyle(SeekerStyle.gold)
              Button("Open like a book", systemImage: "book.closed") { posture.set(.book) }
                .buttonStyle(SeekerActionStyle())
            }.padding(24).frame(maxWidth: 500)
              .background(SeekerStyle.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
          }
          Text("Both paths are included with Pro. You can return to this fork and explore the other life.")
            .font(.system(.footnote, design: .serif)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).lineSpacing(4)
          Text("走哪條路，都別忘了回家。\nWhichever way you go, remember home.")
            .font(.system(.subheadline, design: .serif)).italic().multilineTextAlignment(.center).lineSpacing(5)
        }.padding(20).frame(maxWidth: 960).frame(maxWidth: .infinity)
      }
      .background { SilkBackground().ignoresSafeArea() }.foregroundStyle(SeekerStyle.ink)
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
      .navigationTitle("人生岔路 · A choice of lives").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Close", systemImage: "xmark", action: onClose) }
        ToolbarItem(placement: .primaryAction) {
          Picker(selection: Binding(get: { posture.current }, set: { posture.set($0) })) {
            ForEach([AdventurePosture.folded, .book, .open, .tent, .laptop], id: \.self) { value in
              Text(value.englishName).tag(value)
            }
          } label: { Label("Posture", systemImage: "book.closed") }
            .pickerStyle(.menu)
        }
      }
    }
    .sheet(isPresented: $showMembership, onDismiss: finishUnlock) { MembershipView(purchaseStore: purchases) }
    .onChange(of: posture.current) { _, value in
      if value != .book { transitionTask?.cancel(); selectedStage = nil }
    }
    .onDisappear { transitionTask?.cancel() }
  }

  private func choose(_ stage: AdventureStage) {
    guard posture.current == .book, selectedStage == nil else { return }
    guard purchases.isPro else { requestedStage = stage; showMembership = true; return }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) { selectedStage = stage }
    transitionTask?.cancel()
    transitionTask = Task { @MainActor in
      if !reduceMotion {
        do { try await Task.sleep(for: .milliseconds(520)) } catch { return }
      }
      guard !Task.isCancelled, posture.current == .book, purchases.isPro else { return }
      posture.set(.open)
      onChoose(stage)
    }
  }

  private func finishUnlock() {
    let stage = requestedStage
    requestedStage = nil
    if purchases.isPro, let stage { choose(stage) }
  }
}

private struct AdventureFuturePages: View {
  var isPro: Bool
  var selection: AdventureStage?
  var choose: (AdventureStage) -> Void
  var body: some View {
    GeometryReader { geometry in
      let gap: CGFloat = selection == nil ? 16 : 0
      let pageWidth = (geometry.size.width - gap) / 2
      HStack(spacing: gap) {
        ForEach([AdventureStage.scholar, .thief], id: \.self) { stage in
          AdventureFuturePage(stage: stage, isPro: isPro) { choose(stage) }
            .frame(width: selection == nil ? pageWidth : selection == stage ? geometry.size.width : 0)
            .opacity(selection == nil || selection == stage ? 1 : 0).clipped()
            .allowsHitTesting(selection == nil).accessibilityHidden(selection != nil && selection != stage)
        }
      }
    }
  }
}

private struct AdventureFuturePage: View {
  var stage: AdventureStage
  var isPro: Bool
  var choose: () -> Void
  var body: some View {
    Button(action: choose) {
      VStack(spacing: 13) {
        ZStack(alignment: .bottom) {
          WorldPaintingCrop(center: WorldPaintingArt.point(for: stage == .scholar ? "tea_house" : "grain_barge"), verticalSpan: 0.8)
          if stage == .thief { SeekerStyle.indigo.opacity(0.48) }
          AdventureHeroSprite(stage: stage, height: 121).padding(.bottom, 4)
          if stage == .scholar {
            Text("榜").font(SeekerStyle.brush(32)).foregroundStyle(SeekerStyle.paper)
              .padding(5).background(SeekerStyle.gold)
              .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(8)
          }
        }.frame(height: 215).clipped()
        VStack(spacing: 9) {
          Text(stage == .scholar ? "考狀元" : "神偷").font(SeekerStyle.brush(29))
          Text(stage == .scholar ? "The Scholar" : "The Gentleman Thief").font(.system(.headline, design: .serif))
          Text(stage == .scholar ? "The examination hall. A name on the golden list." : "Moonlit rooftops. A cloak, and a kindness left behind.")
            .font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
          Spacer(minLength: 0)
          Label(isPro ? "Choose this life" : "Unlock both lives", systemImage: isPro ? "chevron.right" : "lock")
            .font(.system(.caption, design: .serif).weight(.medium))
            .padding(.vertical, 11).frame(maxWidth: .infinity).foregroundStyle(SeekerStyle.paper)
            .background(SeekerStyle.indigo, in: RoundedRectangle(cornerRadius: 5))
        }.padding(.horizontal, 11).padding(.bottom, 14)
      }
      .multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(SeekerStyle.paper, in: RoundedRectangle(cornerRadius: 7))
      .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(SeekerStyle.gold.opacity(0.5), lineWidth: 1) }
      .contentShape(RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(stage == .scholar ? "Left page, Scholar" : "Right page, Gentleman Thief"). \(isPro ? "Choose this life" : "Requires Pro")")
  }
}
