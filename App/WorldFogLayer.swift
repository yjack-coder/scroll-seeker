import SwiftUI

/// Only this viewport is composited. No panorama-sized blur or duplicate map
/// textures are created, even while the hero reveals a new chapter of scenery.
struct WorldFogLayer: View {
  var heroX: Double
  var contentSize: CGSize
  var offset: CGPoint
  var isActive: Bool
  var enabled: Bool
  @State private var progress = WorldFogProgress()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30,
      paused: !enabled || !isActive || scenePhase != .active || (reduceMotion && !progress.hasActiveReveal))) { timeline in
      WorldFogCanvas(contentSize: contentSize, offset: offset, progress: progress,
        date: timeline.date, reduceMotion: reduceMotion)
    }
    .opacity(enabled ? 1 : 0)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task {
      guard let world = try? AdventureWorldArchive.load() else { return }
      progress.configure(world: world)
      if enabled && isActive { progress.observe(heroX: heroX) }
    }
    .onChange(of: heroX) { _, x in
      if enabled && isActive { progress.observe(heroX: x) }
    }
    .onChange(of: enabled) { _, enabled in
      if enabled && isActive { progress.observe(heroX: heroX) }
    }
    .onChange(of: isActive) { _, active in
      if active && enabled { progress.observe(heroX: heroX) }
    }
    .task(id: progress.revealCount) {
      guard progress.hasActiveReveal else { return }
      do { try await Task.sleep(for: .milliseconds(3100)) } catch { return }
      progress.settle()
    }
  }
}

private struct WorldFogCanvas: View {
  var contentSize: CGSize
  var offset: CGPoint
  var progress: WorldFogProgress
  var date: Date
  var reduceMotion: Bool

  var body: some View {
    Canvas { context, size in
      guard size.width > 0, size.height > 0, contentSize.width > 0 else { return }
      let clock = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
      let bankWidth = size.width * 1.2
      for (index, band) in progress.bands.enumerated() {
        let lift = progress.liftProgress(for: band, at: date, reduceMotion: reduceMotion)
        guard lift < 1 else { continue }
        let x = band.center * contentSize.width - offset.x
        guard x + bankWidth > 0, x - bankWidth < size.width else { continue }
        var bank = context
        bank.opacity = 1 - lift
        let liftY = -size.height * 0.64 * lift
        let spread = 1 + lift * 0.48
        // Cool shadow underneath cream silk wisps gives depth without a hard
        // rectangular veil. The five banks retain independently painted edges.
        drawWisp(in: &bank,
          center: CGPoint(x: x, y: size.height * 0.58 + liftY),
          width: bankWidth * spread, height: size.height * 0.6,
          color: Color(red: 0.72, green: 0.74, blue: 0.70), opacity: 0.2)
        for cloud in 0..<5 {
          let phase = Double(index * 5 + cloud) * 1.71
          let drift = sin(clock * (0.11 + Double(cloud) * 0.02) + phase)
          let side: CGFloat = cloud % 2 == 0 ? -1 : 1
          let center = CGPoint(
            x: x + side * bankWidth * (0.06 + lift * 0.2),
            y: size.height * (0.08 + Double(cloud) * 0.21) + drift * size.height * 0.025 + liftY)
          drawWisp(in: &bank, center: center,
            width: bankWidth * (cloud == 2 ? 0.88 : 0.82) * spread,
            height: size.height * (cloud % 2 == 0 ? 0.42 : 0.36),
            color: Color(red: 0.96, green: 0.94, blue: 0.87), opacity: 0.86)
          // Low feathered tails keep these horizontal handscroll wisps, not
          // giant oval clouds or opaque vertical replacement panels.
          drawWisp(in: &bank,
            center: CGPoint(x: center.x - side * bankWidth * 0.21,
                            y: center.y + size.height * 0.055),
            width: bankWidth * 0.48 * spread, height: size.height * 0.18,
            color: Color(red: 0.96, green: 0.94, blue: 0.87), opacity: 0.35)
        }
      }

      if let band = progress.titleBand, let started = progress.titleDate {
        let age = date.timeIntervalSince(started)
        guard (0..<3).contains(age) else { return }
        let fade = reduceMotion ? 1 : min(1, age / 0.35) * min(1, (3 - age) / 0.7)
        var titleContext = context
        titleContext.opacity = fade
        let name = Text(band.chineseName).font(SeekerStyle.brush(31)).foregroundStyle(SeekerStyle.ink)
        titleContext.addFilter(.shadow(color: SeekerStyle.paper.opacity(0.94), radius: 6))
        titleContext.draw(name, at: CGPoint(x: size.width / 2, y: size.height * 0.2))
      }
    }
  }

  private func drawWisp(in context: inout GraphicsContext, center: CGPoint,
                       width: CGFloat, height: CGFloat, color: Color, opacity: Double) {
    var layer = context
    layer.translateBy(x: center.x, y: center.y)
    layer.scaleBy(x: width / 2, y: height / 2)
    let ellipse = Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2))
    layer.fill(ellipse, with: .radialGradient(
      Gradient(stops: [.init(color: color.opacity(opacity), location: 0),
                       .init(color: color.opacity(opacity * 0.83), location: 0.42),
                       .init(color: color.opacity(opacity * 0.38), location: 0.73),
                       .init(color: color.opacity(0), location: 1)]),
      center: .zero, startRadius: 0, endRadius: 1))
  }
}
