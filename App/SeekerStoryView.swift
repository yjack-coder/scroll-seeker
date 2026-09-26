import SwiftUI

struct SeekerStoryView: View {
  var target: ScrollTarget
  var isNew: Bool
  var chapterComplete: Bool
  var next: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var bloom = false

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        HStack(spacing: 10) {
          SeekerSeal(size: 32)
          Text(isNew ? "A STORY DISCOVERED" : "FROM YOUR COLLECTION")
            .font(.system(.caption2, design: .serif)).tracking(2.2)
            .foregroundStyle(SeekerStyle.gold)
          Spacer()
          Button("Close", systemImage: "xmark", action: next)
            .labelStyle(.iconOnly).frame(width: 44, height: 44)
        }
        VStack(spacing: 9) {
          ZStack {
            ClueArtwork(target: target)
            ClueArtwork(target: target, colorized: true)
              .mask {
                Circle().scaleEffect(bloom ? 1.5 : 0.001)
                  .blur(radius: bloom ? 0 : 18)
              }
          }
          .aspectRatio(1, contentMode: .fit)
          .frame(maxWidth: 380)
          .clipped()
          .overlay { Rectangle().strokeBorder(SeekerStyle.gold.opacity(0.65), lineWidth: 1).padding(7) }
          .accessibilityLabel("An artistically colorized interpretation of \(target.englishName)")
          Text("The scene come to life")
            .font(.system(.caption, design: .serif)).italic().foregroundStyle(SeekerStyle.gold)
        }
        VStack(spacing: 8) {
          Text(target.chineseName).font(SeekerStyle.brush(36))
          Text(target.englishName).font(.system(.title2, design: .serif))
        }
        .foregroundStyle(SeekerStyle.indigo)
        Rectangle().fill(SeekerStyle.gold.opacity(0.5)).frame(width: 48, height: 1)
        Text(target.story)
          .font(.system(.body, design: .serif)).lineSpacing(7)
          .foregroundStyle(SeekerStyle.ink)
          .frame(maxWidth: 520, alignment: .leading)
        Button(isNew ? (chapterComplete ? "Complete the chapter" : "The next hidden story") : "Return to the scroll", action: next)
          .buttonStyle(SeekerActionStyle()).frame(maxWidth: 520)
      }
      .padding(26).padding(.top, 12).frame(maxWidth: .infinity)
    }
    .background { SilkBackground().ignoresSafeArea() }
    .task {
      withAnimation(reduceMotion ? nil : .easeOut(duration: 1.8)) { bloom = true }
    }
  }
}
