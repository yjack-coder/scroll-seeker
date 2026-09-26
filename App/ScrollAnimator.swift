import Observation
import SwiftUI

@MainActor @Observable
final class ScrollAnimator {
  var isOpen = false
  var unroll = 0.0
  var ink = 0.0
  var poem = 0.0
  var seal = false
  var stampCount = 0
  private var task: Task<Void, Never>?

  func setOpen(_ open: Bool, reduceMotion: Bool, tracksHinge: Bool = false) {
    task?.cancel()
    isOpen = open
    if reduceMotion {
      unroll = open ? 1 : 0
      ink = unroll
      poem = unroll
      seal = open
      return
    }
    task = Task { @MainActor in
      if open {
        seal = false
        ink = 0
        poem = 0
        if !tracksHinge {
          withAnimation(.easeInOut(duration: 1.05)) { unroll = 1 }
        }
        guard await pause(0.5) else { return }
        // Canvas evaluates each wash against this continuous, staggered timeline.
        let start = Date()
        while Date().timeIntervalSince(start) < 3 {
          guard !Task.isCancelled else { return }
          ink = min(1, Date().timeIntervalSince(start) / 3)
          guard await pause(1.0 / 30) else { return }
        }
        ink = 1
        let poemStart = Date()
        while Date().timeIntervalSince(poemStart) < 1.5 {
          guard !Task.isCancelled else { return }
          poem = min(1, Date().timeIntervalSince(poemStart) / 1.5)
          guard await pause(1.0 / 30) else { return }
        }
        poem = 1
        withAnimation(.easeOut(duration: 0.3)) { seal = true }
        stampCount += 1
      } else {
        withAnimation(.easeOut(duration: 0.3)) {
          seal = false
          poem = 0
        }
        let start = Date()
        let initialInk = ink
        while Date().timeIntervalSince(start) < 0.65 {
          guard !Task.isCancelled else { return }
          ink = initialInk * (1 - Date().timeIntervalSince(start) / 0.65)
          guard await pause(1.0 / 30) else { return }
        }
        ink = 0
        withAnimation(.easeInOut(duration: 0.85)) { unroll = 0 }
      }
    }
  }

  func followHinge(fraction: Double, reduceMotion: Bool) {
    if !isOpen { setOpen(true, reduceMotion: reduceMotion, tracksHinge: true) }
    unroll = min(1, max(0, fraction))
  }

  private func pause(_ seconds: Double) async -> Bool {
    do {
      try await Task.sleep(for: .seconds(seconds))
      return !Task.isCancelled
    } catch { return false }
  }
}

struct HingeObserver: ViewModifier {
  var animator: ScrollAnimator
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content.onHingeChange { old, new in
        guard let hinge = new.hinge else { return }
        if hinge.status == .partiallyOpen {
          animator.followHinge(fraction: hinge.angle.degrees / 180, reduceMotion: reduceMotion)
        } else if hinge.status == .fullyOpen {
          if old.hinge?.status == .partiallyOpen {
            withAnimation(.easeOut(duration: 0.4)) { animator.unroll = 1 }
          } else {
            animator.setOpen(true, reduceMotion: reduceMotion)
          }
        } else if hinge.status == .closed {
          animator.setOpen(false, reduceMotion: reduceMotion)
        }
      }
    } else {
      content
    }
  }
}
