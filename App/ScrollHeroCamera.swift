import Foundation
import CoreGraphics

/// A single continuous world-space camera. Resizing never reuses a stale
/// viewport center, and following never changes the hero's world coordinate.
struct ScrollHeroCamera {
    var offset = CGPoint.zero
    var target = CGPoint(x: 0.9333, y: 0.5)
    var content = CGSize.zero
    var container = CGSize.zero
    var openingStart: CGPoint?
    var openingElapsed: TimeInterval = 0
    private var openingAtHome = false

    mutating func resize(content: CGSize, container: CGSize, target: CGPoint) {
        let isOpening = openingStart != nil
        self.content = content
        self.container = container
        self.target = target
        if isOpening {
            // Duo can publish its final open bounds after the reveal begins.
            // Recompute both ends in the NEW geometry at the SAME phase; never
            // cancel the glide, reuse an old pixel offset, or restart its clock.
            let start = openingOffset
            openingStart = start
            offset = interpolatedOpeningOffset(from: start)
        } else {
            offset = centeredOffset
        }
    }

    mutating func beginOpening(atHome: Bool, reduceMotion: Bool) {
        openingAtHome = atHome
        offset = reduceMotion ? centeredOffset : openingOffset
        openingStart = reduceMotion ? nil : offset
        openingElapsed = 0
    }

    mutating func tick(delta: TimeInterval, reduceMotion: Bool) {
        let dt = min(0.05, max(0, delta))
        if let start = openingStart, !reduceMotion {
            openingElapsed += dt
            let t = min(1, openingElapsed / 1.2)
            offset = interpolatedOpeningOffset(from: start)
            if t == 1 { openingStart = nil }
            return
        }
        // A narrow dead zone lets footsteps breathe, with exponential catch-up
        // outside it. Hard visibility bounds protect the large hero at any zoom.
        let hero = CGPoint(x: target.x * content.width, y: target.y * content.height)
        let local = CGPoint(x: hero.x - offset.x, y: hero.y - offset.y)
        let halfZone = container.width * 0.045
        var desired = offset
        if local.x < container.width / 2 - halfZone {
            desired.x = hero.x - container.width / 2 + halfZone
        } else if local.x > container.width / 2 + halfZone {
            desired.x = hero.x - container.width / 2 - halfZone
        }
        desired.y = centeredOffset.y
        desired = bounded(desired)
        let blend = reduceMotion ? 1 : 1 - exp(-dt * 7)
        offset = bounded(CGPoint(x: offset.x + (desired.x - offset.x) * blend,
                                 y: offset.y + (desired.y - offset.y) * blend))
        let margin = min(container.width * 0.22, 130)
        offset.x = min(hero.x - margin, max(hero.x - container.width + margin, offset.x))
        offset = bounded(offset)
    }

    var centeredOffset: CGPoint {
        // Feet sit below center so the taller sprite's head stays in the frame.
        bounded(CGPoint(x: target.x * content.width - container.width / 2,
                        y: target.y * content.height - container.height * 0.66))
    }

    private var openingOffset: CGPoint {
        let end = centeredOffset
        return bounded(CGPoint(
            x: openingAtHome ? content.width - container.width : end.x + container.width * 0.12,
            y: end.y))
    }

    private func interpolatedOpeningOffset(from start: CGPoint) -> CGPoint {
        let t = min(1, max(0, openingElapsed / 1.2))
        let eased = t * t * (3 - 2 * t)
        let end = centeredOffset
        return bounded(CGPoint(x: start.x + (end.x - start.x) * eased,
                               y: start.y + (end.y - start.y) * eased))
    }

    private func bounded(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(0, content.width - container.width), max(0, point.x)),
                y: min(max(0, content.height - container.height), max(0, point.y)))
    }
}
