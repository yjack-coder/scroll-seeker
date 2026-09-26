import SwiftUI

struct JournalComposer: View {
  var journal: JournalStore
  var isPro: Bool
  var locked: () -> Void
  var painted: (JournalEntry) -> Void
  @AppStorage("liubai.draft") private var words = ""
  @State private var season: LandscapeSeason?
  @State private var speech = SpeechRecorder()
  @FocusState private var focused: Bool

  var body: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 13) {
        HStack {
          Text("What are you carrying today?")
            .font(LiubaiStyle.serif(17))
          Spacer()
          if speech.isAvailable {
            Button(
              speech.recording ? "Stop recording" : "Speak your reflection",
              systemImage: speech.recording ? "stop.fill" : "microphone"
            ) {
              if speech.recording { speech.stop() } else { Task { await speech.start() } }
            }.labelStyle(.iconOnly).frame(width: 44, height: 44)
              .foregroundStyle(LiubaiStyle.red)
          }
        }
        TextField("A thought, a feeling, a small moment…", text: $words, axis: .vertical)
          .font(.system(size: 14, design: .serif))
          .lineSpacing(5).lineLimit(2...5)
          .focused($focused)
          .accessibilityLabel("Today's reflection")
          .onChange(of: words) { _, value in
            if value.count > 1200 { words = String(value.prefix(1200)) }
          }
        HStack {
          Text("A sentence is enough.")
          Spacer()
          Image(systemName: "lock")
          Text("Only on this device")
        }
        .font(.system(size: 9)).foregroundStyle(LiubaiStyle.muted)
      }
      .padding(18)
      .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 5))
      .overlay {
        RoundedRectangle(cornerRadius: 5).strokeBorder(
          LiubaiStyle.rule.opacity(0.5), lineWidth: 0.7)
      }

      HStack {
        if isPro {
          Picker("Seasonal style", selection: $season) {
            Text("Follow my words").tag(Optional<LandscapeSeason>.none)
            ForEach(LandscapeSeason.allCases) { style in
              Text(style.label).tag(Optional(style))
            }
          }.pickerStyle(.menu).font(.caption)
        } else {
          Button("Four seasons", systemImage: "leaf", action: locked)
            .font(.system(size: 11, design: .serif))
          Text("PRO").font(.system(size: 8, weight: .semibold)).foregroundStyle(LiubaiStyle.red)
        }
        Spacer()
        Text(
          isPro
            ? "Every feeling has a place"
            : journal.canPaintToday ? "One quiet moment, each day" : "Today's painting is complete"
        )
        .font(.system(size: 9)).foregroundStyle(LiubaiStyle.muted)
      }

      Button {
        guard isPro || journal.canPaintToday else {
          locked()
          return
        }
        focused = false
        speech.stop()
        Task {
          if let entry = await journal.paint(words: words, season: isPro ? season : nil) {
            words = ""
            painted(entry)
          }
        }
      } label: {
        HStack(spacing: 12) {
          if journal.isPainting { ProgressView().tint(LiubaiStyle.paper) }
          Text(journal.isPainting ? "Listening to the landscape…" : "落筆   Paint my landscape")
          if !journal.isPainting { Image(systemName: "paintbrush.pointed") }
        }
      }
      .buttonStyle(InkButtonStyle())
      .disabled(journal.isPainting || words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .opacity(words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
      if let error = journal.errorMessage ?? speech.errorMessage {
        Text(error).font(.caption).foregroundStyle(LiubaiStyle.red)
      }
    }
    .onChange(of: speech.transcript) { _, transcript in
      if !transcript.isEmpty { words = transcript }
    }
    .onDisappear { speech.stop() }
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done", systemImage: "checkmark") { focused = false }
      }
    }
  }
}
