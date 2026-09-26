import SwiftUI

struct ScrollUnrollPresentation: ViewModifier, Animatable {
  var progress: Double
  var viewportSize: CGSize
  var reduceMotion: Bool

  nonisolated var animatableData: Double {
    get { progress }
    set { progress = min(1, max(0, newValue)) }
  }

  func body(content: Content) -> some View {
    let revealedWidth = viewportSize.width * min(1, max(0, progress))
    content
      .mask { Rectangle().frame(width: revealedWidth) }
      .overlay {
        // Read the interpolated presentation value so the rollers stay visible
        // while the model's progress has already reached its destination.
        if progress > 0 && progress < 0.999 && !reduceMotion {
          ZStack {
            WoodenRoller().offset(x: -revealedWidth / 2)
            WoodenRoller().offset(x: revealedWidth / 2)
          }
          .frame(width: viewportSize.width, height: viewportSize.height + 10)
          .transition(.identity)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
        }
      }
  }
}

struct WoodenRoller: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 5)
      .fill(.linearGradient(colors: [Color(red: 0.18, green: 0.11, blue: 0.07), SeekerStyle.gold, Color(red: 0.30, green: 0.19, blue: 0.11), Color(red: 0.13, green: 0.09, blue: 0.06)], startPoint: .leading, endPoint: .trailing))
      .frame(width: 12)
      .overlay(alignment: .top) { Capsule().fill(SeekerStyle.ink).frame(width: 17, height: 10) }
      .overlay(alignment: .bottom) { Capsule().fill(SeekerStyle.ink).frame(width: 17, height: 10) }
      .shadow(color: .black.opacity(0.35), radius: 8)
      .accessibilityHidden(true)
  }
}

struct SeekerMinimap: View {
  var viewport: ClosedRange<Double>
  var found: [ScrollTarget]
  var body: some View {
    VStack(spacing: 6) {
      GeometryReader { geometry in
        Capsule().fill(SeekerStyle.gold.opacity(0.25))
        ForEach(found) { target in
          Circle().fill(SeekerStyle.red).frame(width: 4, height: 4)
            .position(x: geometry.size.width * target.x, y: 3)
        }
        Capsule().fill(SeekerStyle.indigo)
          .frame(width: max(8, geometry.size.width * (viewport.upperBound - viewport.lowerBound)))
          .offset(x: min(geometry.size.width - 8, geometry.size.width * viewport.lowerBound))
      }.frame(height: 6)
      HStack {
        Text("城 · CITY")
        Spacer()
        Text("←  FOLLOW THE SCROLL")
        Spacer()
        Text("野 · COUNTRYSIDE")
      }.font(.system(size: 8, weight: .medium, design: .serif)).tracking(0.6)
    }
    .padding(12).foregroundStyle(SeekerStyle.ink)
    .background(SeekerStyle.paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Scroll position, \(Int(viewport.lowerBound * 100)) to \(Int(viewport.upperBound * 100)) percent from the left")
  }
}

struct SeekerHingeObserver: ViewModifier {
  var enabled: Bool
  var change: (Double, Bool) -> Void
  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content.onHingeChange { _, new in
        guard enabled, let hinge = new.hinge else { return }
        if hinge.status == .partiallyOpen {
          change(min(1, max(0, hinge.angle.degrees / 180)), false)
        } else { change(hinge.status == .fullyOpen ? 1 : 0, true) }
      }
    } else { content }
  }
}
