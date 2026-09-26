import SwiftUI

struct SeekerHomeView: View {
  var game: SeekerGame
  var isPro: Bool
  var selectChapter: (ScrollChapter) -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 30) {
        VStack(spacing: 10) {
          HStack(alignment: .center, spacing: 18) {
            Text("尋畫").font(SeekerStyle.brush(68))
            SeekerSeal(size: 30).accessibilityHidden(true)
          }
          Text("SCROLL SEEKER").font(.system(.caption, design: .serif)).tracking(5)
          Rectangle().fill(SeekerStyle.gold.opacity(0.6)).frame(width: 50, height: 1).padding(.vertical, 5)
          Text("A thousand lives. One endless scroll.")
            .font(.system(.body, design: .serif)).italic()
        }
        .foregroundStyle(SeekerStyle.paper)
        .padding(.top, 14)
        .padding(.bottom, 6)

        VStack(spacing: 16) {
          ForEach(Array(game.archive.chapters.enumerated()), id: \.element.id) { index, chapter in
            chapterCard(chapter, number: index + 1)
          }
        }
        .frame(maxWidth: 580)

        VStack(spacing: 9) {
          Text("LOOK CLOSELY. TIME MOVES SLOWLY HERE.")
            .font(.system(size: 9, weight: .medium, design: .serif)).tracking(1.8)
          Text("Fold for a clue. Unfold to step inside.")
            .font(.system(.footnote, design: .serif))
          Text("清明上河圖  ·  Northern Song")
            .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.paper.opacity(0.55))
        }
        .foregroundStyle(SeekerStyle.paper.opacity(0.8))
        .padding(.bottom, 18)
      }
      .padding(.horizontal, 26)
      .frame(maxWidth: .infinity)
    }
    .background { SilkBackground(dark: true).ignoresSafeArea() }
  }

  private func chapterCard(_ chapter: ScrollChapter, number: Int) -> some View {
    Button { selectChapter(chapter) } label: {
      VStack(alignment: .leading, spacing: 0) {
        ZStack(alignment: .bottomLeading) {
          if let target = game.archive.targets(for: chapter.id).first {
            ClueArtwork(target: target)
              .frame(height: 92).clipped()
              .overlay(.linearGradient(colors: [.clear, SeekerStyle.ink.opacity(0.35)], startPoint: .top, endPoint: .bottom))
          }
          Text("第\(number == 1 ? "一" : "二")卷  /  CHAPTER \(number)")
            .font(.system(size: 10, weight: .medium, design: .serif)).tracking(2)
            .foregroundStyle(.white).padding(16)
        }
        HStack(spacing: 16) {
          Text(chapter.chineseName).font(SeekerStyle.brush(35)).foregroundStyle(SeekerStyle.ink)
          VStack(alignment: .leading, spacing: 5) {
            Text(chapter.englishName).font(.system(.title3, design: .serif))
            Text(game.progress(for: chapter) == 0 ? (chapter.free ? "Five hidden stories · Begin here" : "Five more stories · Pro") : "\(game.progress(for: chapter)) of 5 stories discovered")
              .font(.system(.caption, design: .serif)).foregroundStyle(SeekerStyle.ink.opacity(0.75))
          }
          Spacer(minLength: 0)
          Image(systemName: !chapter.free && !isPro ? "lock" : "chevron.right")
            .font(.system(.body, weight: .light)).foregroundStyle(SeekerStyle.gold)
        }
        .padding(18)
      }
      .background { SilkBackground() }
      .clipShape(RoundedRectangle(cornerRadius: 7))
      .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(SeekerStyle.gold.opacity(0.7), lineWidth: 1) }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(chapter.title), \(game.progress(for: chapter)) of 5 found\(!chapter.free && !isPro ? ", locked, Pro" : "")")
  }
}
