import SwiftUI

struct AdventureJournalView: View {
  var entries: [AdventureJournalEntry]
  var letters: [AdventureLetter] = []
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          VStack(alignment: .leading, spacing: 8) {
            Text("一筆一生").font(SeekerStyle.brush(39))
            Text("A small life, remembered.").font(.system(.title3, design: .serif)).italic()
          }.padding(.vertical, 8)
          if entries.isEmpty && letters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
              Text("The first page is still unwritten.")
                .font(.system(.headline, design: .serif))
              Text("Unfold the scroll. Every kindness and every adventure will find a place here.")
                .font(.system(.body, design: .serif)).foregroundStyle(.secondary)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
              .background(SeekerStyle.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
          }
          ForEach(entries.reversed()) { entry in
            AdventureMemoryCard(entry: entry)
          }
          if !letters.isEmpty {
            Text("家書 · Letters home").font(SeekerStyle.brush(28)).padding(.top, 8)
            ForEach(letters.reversed()) { letter in
              AdventureJournalLetter(letter: letter)
            }
          }
        }
        .padding(24).frame(maxWidth: 660, alignment: .leading).frame(maxWidth: .infinity)
      }
      .background { SilkBackground().ignoresSafeArea() }
      .foregroundStyle(SeekerStyle.ink)
      .navigationTitle("行記 · Story journal").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}

private struct AdventureJournalLetter: View {
  var letter: AdventureLetter
  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      Text(letter.date, style: .date).font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
      Text(letter.body).font(.system(.body, design: .serif)).lineSpacing(5)
      Rectangle().fill(SeekerStyle.gold.opacity(0.35)).frame(height: 1)
      Text("娘的回信 · Mother’s reply").font(.system(.subheadline, design: .serif).weight(.medium)).foregroundStyle(SeekerStyle.red)
      Text(letter.reply).font(.system(.body, design: .serif)).lineSpacing(5)
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      .background(SeekerStyle.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

private struct AdventureMemoryCard: View {
  var entry: AdventureJournalEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      HStack(alignment: .top, spacing: 14) {
        Text("記").font(SeekerStyle.brush(25)).foregroundStyle(SeekerStyle.red)
          .padding(5).overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(SeekerStyle.red.opacity(0.7), lineWidth: 1) }
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.title).font(.system(.headline, design: .serif))
          Text(entry.date, style: .date).font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
        }
      }
      Text(entry.body).font(.system(.body, design: .serif)).lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
    .background(SeekerStyle.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(SeekerStyle.gold.opacity(0.35), lineWidth: 1) }
  }
}
