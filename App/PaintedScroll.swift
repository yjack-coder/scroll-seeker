import CoreText
import SwiftUI

struct PaintedScroll: View {
  var entry: JournalEntry
  var unroll = 1.0
  var ink = 1.0
  var poem = 1.0
  var showSeal = true
  var isPro = false
  var living = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { geometry in
      let revealedWidth = 58 + max(0, geometry.size.width - 76) * unroll
      ZStack {
        ZStack {
          LiubaiStyle.paper
          TimelineView(
            .animation(
              minimumInterval: 1.0 / 8, paused: !living || reduceMotion || scenePhase != .active)
          ) { timeline in
            InkLandscape(
              parameters: entry.parameters, seed: entry.seed, progress: ink,
              time: reduceMotion || !living ? 0 : timeline.date.timeIntervalSinceReferenceDate)
          }
          VStack {
            Rectangle().fill(LiubaiStyle.rule.opacity(0.15)).frame(height: 12)
            Spacer()
            Rectangle().fill(LiubaiStyle.rule.opacity(0.15)).frame(height: 12)
          }
          if unroll > 0.45 {
            PoemInscription(
              chinese: entry.poemChinese, english: entry.poemEnglish,
              progress: poem, showSeal: showSeal && isPro, calligraphy: isPro
            )
            .frame(width: max(120, min(240, geometry.size.width * 0.4)))
            .padding(.trailing, 30)
            .padding(.top, 35)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          }
        }
        .mask { Rectangle().frame(width: revealedWidth) }
        .overlay {
          if unroll < 0.3 {
            VStack(spacing: 7) {
              Text("山\n水\n寄\n心").font(LiubaiStyle.brush(24)).lineSpacing(9)
              ChopSeal(text: "日記", size: 27).padding(.top, 12)
            }
            .foregroundStyle(LiubaiStyle.ink)
            .opacity(1 - unroll / 0.3)
          }
        }
        ScrollRoller()
          .offset(x: -revealedWidth / 2)
        ScrollRoller()
          .offset(x: revealedWidth / 2)
      }
      .shadow(color: LiubaiStyle.ink.opacity(0.1), radius: 12, x: 0, y: 8)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "\(entry.title). An ink landscape with \(entry.parameters.season.rawValue) mountains, water, mist, and a tiny figure."
    )
  }
}

private struct ScrollRoller: View {
  var body: some View {
    VStack(spacing: 0) {
      Capsule().fill(LiubaiStyle.jade.gradient).frame(width: 18, height: 14)
      Rectangle()
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.67, green: 0.63, blue: 0.49), LiubaiStyle.paper,
              Color(red: 0.78, green: 0.75, blue: 0.64),
            ], startPoint: .leading, endPoint: .trailing)
        )
        .frame(width: 12)
        .overlay(alignment: .leading) { Rectangle().fill(.black.opacity(0.08)).frame(width: 1) }
      Capsule().fill(LiubaiStyle.jade.gradient).frame(width: 18, height: 14)
    }
    .padding(.vertical, 2)
    .accessibilityHidden(true)
  }
}

struct PoemInscription: View {
  var chinese: [String]
  var english: [String]
  var progress = 1.0
  var showSeal = true
  var calligraphy = false

  var body: some View {
    VStack(alignment: .trailing, spacing: 15) {
      HStack(alignment: .top, spacing: 13) {
        ForEach(Array(chinese.enumerated().reversed()), id: \.offset) { line in
          VStack(spacing: 4) {
            ForEach(Array(line.element.enumerated()), id: \.offset) { character in
              let reveal = min(
                1, max(0, progress * 28 - Double(line.offset * 6 + character.offset)))
              if calligraphy {
                BrushCharacter(character: String(character.element), progress: reveal)
                  .frame(width: 21, height: 25)
              } else {
                Text(String(character.element))
                  .font(.system(size: 18, design: .serif))
                  .opacity(reveal)
              }
            }
          }
        }
      }
      if showSeal {
        ChopSeal(size: 27)
          .scaleEffect(showSeal ? 1 : 1.4)
          .transition(.opacity.combined(with: .scale(scale: 1.35)))
      }
      Text(english.joined(separator: "\n"))
        .font(.system(size: 11, weight: .regular, design: .serif))
        .italic().lineSpacing(5)
        .multilineTextAlignment(.trailing)
        .foregroundStyle(LiubaiStyle.muted)
        .opacity(max(0, progress * 4 - 3))
    }
    .foregroundStyle(LiubaiStyle.ink.opacity(0.86))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel((chinese + english).joined(separator: ". "))
  }
}

private struct BrushCharacter: View {
  var character: String
  var progress: Double

  var body: some View {
    Canvas { context, size in
      let base = CTFontCreateWithName("KaitiTC-Regular" as CFString, 24, nil)
      let font = CTFontCreateForString(
        base, character as CFString, CFRange(location: 0, length: character.utf16.count))
      var characters = Array(character.utf16)
      var glyphs = [CGGlyph](repeating: 0, count: characters.count)
      guard !characters.isEmpty,
        CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count),
        let outline = CTFontCreatePathForGlyph(font, glyphs[0], nil)
      else { return }
      let bounds = outline.boundingBox
      let scale = min(size.width / max(1, bounds.width), size.height / max(1, bounds.height))
      var transform = CGAffineTransform(
        translationX: (size.width - bounds.width * scale) / 2, y: size.height)
      transform = transform.scaledBy(x: scale, y: -scale).translatedBy(
        x: -bounds.minX, y: -bounds.minY)
      let path = Path(outline).applying(transform)
      context.stroke(
        path.trimmedPath(from: 0, to: progress), with: .color(LiubaiStyle.ink), lineWidth: 0.7)
      context.opacity = max(0, progress * 2 - 1)
      context.fill(path, with: .color(LiubaiStyle.ink))
    }
  }
}
