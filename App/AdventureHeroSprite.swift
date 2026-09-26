import SwiftUI
import UIKit
import ImageIO

struct AdventureHeroSprite: View {
  var stage: AdventureStage
  var walking = false
  var facingLeft = true
  var height: CGFloat = 64
  var jumpTrigger = 0
  var showsName = false
  @State private var jumpOffset: CGFloat = 0
  @State private var phaseStart = Date.now
  @State private var hasStartedWalking = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active)) { timeline in
      let motion = AdventureHeroMotion.sample(
        time: timeline.date.timeIntervalSince(phaseStart), walking: walking, reduceMotion: reduceMotion)
      let foot = Self.footFraction(for: stage)
      ZStack(alignment: .topLeading) {
        AdventureHeroGround(height: height, footFraction: foot, motion: motion, facingLeft: facingLeft)
        AdventureHeroImage(stage: stage, height: height)
          .scaleEffect(x: facingLeft ? 1 : -1, y: 1)
          .scaleEffect(x: motion.scaleX, y: motion.scaleY, anchor: UnitPoint(x: 0.5, y: foot))
          .rotationEffect(.degrees(motion.tiltDegrees), anchor: UnitPoint(x: 0.5, y: foot))
          .offset(y: jumpOffset - height * motion.lift)
          .shadow(color: SeekerStyle.paper.opacity(0.94), radius: 1.5)
          .shadow(color: SeekerStyle.gold.opacity(0.7), radius: max(4, height * 0.045))
      }
      .frame(width: height * (2.0 / 3.0), height: height)
    }
    .overlay(alignment: .top) {
      Text("小安")
        .font(SeekerStyle.brush(17))
        .foregroundStyle(SeekerStyle.ink)
        .padding(.horizontal, 10).padding(.vertical, 3)
        .background(SeekerStyle.paper.opacity(0.9), in: Capsule())
        .overlay(Capsule().stroke(SeekerStyle.gold.opacity(0.5), lineWidth: 0.7))
        .offset(y: -20)
        .opacity(showsName && !hasStartedWalking ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 1.3), value: hasStartedWalking)
        .accessibilityHidden(true)
    }
    .accessibilityLabel("小安 Xiao An, \(stage.rawValue)")
    .onChange(of: walking, initial: true) { _, moving in
      phaseStart = .now
      if moving { hasStartedWalking = true }
    }
    .onChange(of: reduceMotion) { _, reduce in if reduce { jumpOffset = 0 } }
    .onDisappear { jumpOffset = 0 }
    .task(id: jumpTrigger) {
      guard jumpTrigger > 0, !reduceMotion else { return }
      withAnimation(.easeOut(duration: 0.2)) { jumpOffset = -height * 0.32 }
      try? await Task.sleep(for: .milliseconds(210))
      guard !Task.isCancelled else { return }
      withAnimation(.easeIn(duration: 0.24)) { jumpOffset = 0 }
    }
  }

  /// Lowest opaque foot row in each supplied 1024 × 1536 sprite. Scaling the
  /// walk cycle around this point keeps landings fixed on the traced road.
  static func footFraction(for stage: AdventureStage) -> CGFloat {
    switch stage {
    case .child: 1471.0 / 1536.0
    case .scholar: 1504.0 / 1536.0
    case .thief: 1492.0 / 1536.0
    }
  }
}

private struct AdventureHeroImage: View {
  var stage: AdventureStage
  var height: CGFloat

  var body: some View {
    Group {
      if let image = AdventureSpriteCache.image(for: stage.rawValue) {
        Image(uiImage: image).resizable().interpolation(.high).scaledToFit()
      } else {
        Text("安").font(SeekerStyle.brush(height * 0.65)).foregroundStyle(SeekerStyle.indigo)
      }
    }
    .frame(width: height * (2.0 / 3.0), height: height)
  }
}

private struct AdventureHeroGround: View {
  var height: CGFloat
  var footFraction: CGFloat
  var motion: AdventureHeroMotion
  var facingLeft: Bool

  var body: some View {
    Canvas { context, size in
      let foot = CGPoint(x: size.width / 2, y: height * footFraction)
      let shadowWidth = height * 0.28 * motion.shadowScale
      let shadow = CGRect(x: foot.x - shadowWidth / 2, y: foot.y - height * 0.009,
                          width: shadowWidth, height: height * 0.044)
      context.addFilter(.blur(radius: max(1, height * 0.011)))
      context.fill(Path(ellipseIn: shadow), with: .color(SeekerStyle.ink.opacity(0.3)))
      guard motion.drawsDust else { return }
      let direction: CGFloat = facingLeft ? 1 : -1
      let age = motion.dustPhase
      let opacity = 0.34 * pow(1 - age, 1.4)
      for particle in 0..<3 {
        let spread = CGFloat(particle + 1) / 3
        let radius = height * (0.009 + 0.02 * age) * (0.65 + 0.35 * spread)
        let center = CGPoint(
          x: foot.x + direction * height * (0.055 + age * 0.19 * spread),
          y: foot.y - height * (0.01 + age * 0.065 * (1.3 - spread)))
        let puff = CGRect(x: center.x - radius, y: center.y - radius * 0.7,
                          width: radius * 2, height: radius * 1.4)
        context.fill(Path(ellipseIn: puff), with: .color(SeekerStyle.paper.opacity(opacity)))
      }
    }
    .frame(width: height * (2.0 / 3.0), height: height)
    .accessibilityHidden(true)
  }
}

@MainActor
private enum AdventureSpriteCache {
  static var images: [String: UIImage] = [:]
  static func image(for stage: String) -> UIImage? {
    if let cached = images[stage] { return cached }
    guard let url = ScrollArchive.resourceURL(for: "Characters/xiao_an_\(stage).png"),
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 600,
            kCGImageSourceShouldCacheImmediately: true
          ] as CFDictionary) else { return nil }
    let image = UIImage(cgImage: cgImage)
    images[stage] = image
    return image
  }
}
