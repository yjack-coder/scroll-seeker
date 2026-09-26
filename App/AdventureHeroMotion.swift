import Foundation

/// A deterministic gait shared by every presentation of Xiao An. Fractions
/// are relative to sprite height; the caller keeps the foot anchor on its road.
struct AdventureHeroMotion: Equatable {
  var lift = 0.0
  var tiltDegrees = 0.0
  var scaleX = 1.0
  var scaleY = 1.0
  var shadowScale = 1.0
  var dustPhase = 0.0
  var drawsDust = false

  static let stepsPerSecond = 2.2

  static func sample(time: TimeInterval, walking: Bool, reduceMotion: Bool) -> Self {
    guard !reduceMotion, time.isFinite else { return Self() }
    let time = max(0, time)
    if walking {
      let steps = time * stepsPerSecond
      let phase = steps.truncatingRemainder(dividingBy: 1)
      let hop = pow(sin(phase * .pi), 2)
      let contactDistance = min(phase, 1 - phase)
      let landing = exp(-pow(contactDistance / 0.09, 2))
      return Self(
        lift: 0.05 * hop,
        tiltDegrees: 4 * sin(steps * .pi),
        scaleX: 1 + 0.035 * landing - 0.012 * hop,
        scaleY: 1 - 0.045 * landing + 0.025 * hop,
        shadowScale: 1 - 0.22 * hop,
        dustPhase: phase,
        drawsDust: true)
    }

    let breath = sin(time * 2 * .pi / 3.6)
    // A brief two-part nod reads like a blink without repainting the face.
    let blinkPhase = time.truncatingRemainder(dividingBy: 4.8)
    let nod = exp(-pow((blinkPhase - 3.8) / 0.10, 2))
    return Self(
      tiltDegrees: 0.7 * nod,
      scaleX: 1 + breath * 0.0075,
      scaleY: 1 + breath * 0.015 - nod * 0.014)
  }
}
