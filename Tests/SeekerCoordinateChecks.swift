import Foundation
import ImageIO

@main
@MainActor
struct SeekerCoordinateChecks {
  static var checks = 0

  static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
  }

  static func near(_ actual: CGFloat, _ expected: CGFloat, _ message: String) {
    check(abs(actual - expected) < 0.000001, message)
  }

  static func main() throws {
    let archivePath = CommandLine.arguments.dropFirst().first ?? "App/Resources/World/world.json"
    let world = try AdventureWorldArchive.load(from: URL(fileURLWithPath: archivePath))
    let storyPath = CommandLine.arguments.dropFirst(2).first ?? "App/Resources/Qingming/story.json"
    let story = try AdventureArchive.load(from: URL(fileURLWithPath: storyPath), worldURL: URL(fileURLWithPath: archivePath))
    let targets = story.allMissions
    check(targets.count == 17, "All 17 remapped mission locations are covered")
    let imageURL = URL(fileURLWithPath: archivePath).deletingLastPathComponent().appendingPathComponent(world.image)
    let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil)!
    let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)! as NSDictionary
    near(world.size[0], (properties[kCGImagePropertyPixelWidth] as! NSNumber).doubleValue,
      "World metadata shares the supplied image's actual width")
    near(world.size[1], (properties[kCGImagePropertyPixelHeight] as! NSNumber).doubleValue,
      "World metadata shares the supplied image's actual height")
    let aspect = world.size[0] / world.size[1]

    let compact = CGSize(width: 700, height: 600)
    let compactContent = ScrollViewportMath.contentSize(viewportHeight: 600, zoom: 1, aspectRatio: aspect)
    near(compactContent.width, 600 * world.size[0] / world.size[1], "Full width scales from exact World image dimensions")
    let rightEdge = ScrollViewportMath.boundedOffset(CGPoint(x: compactContent.width, y: 0), contentSize: compactContent, container: compact)
    near(rightEdge.x, compactContent.width - compact.width, "Initial right edge has the expected physical offset")
    let home = world.places["home"]!
    let localHome = ScrollViewportMath.localPoint(normalized: CGPoint(x: home.x, y: home.y), offset: rightEdge, contentSize: compactContent)
    near(localHome.x, home.x * compactContent.width - rightEdge.x, "Home maps to the unmirrored right-hand scene")
    near(localHome.y, home.y * compactContent.height, "Place y refers to the full world image")
    let rightRange = ScrollViewportMath.visibleRange(offset: rightEdge, contentSize: compactContent, container: compact)
    near(rightRange.upperBound, 1, "Minimap begins at the far right")

    let containers = [CGSize(width: 320, height: 540), CGSize(width: 430, height: 760), CGSize(width: 744, height: 1133), CGSize(width: 1133, height: 744), CGSize(width: 370, height: 700)]
    for container in containers {
      for zoom: CGFloat in [1, 1.5, 2, 3, 4, 5, 6] {
        let content = ScrollViewportMath.contentSize(viewportHeight: container.height, zoom: zoom, aspectRatio: aspect)
        near(content.height, container.height * zoom, "Zoom preserves image aspect ratio")
        for target in targets {
          let normalized = CGPoint(x: target.x, y: target.y)
          let desired = CGPoint(x: normalized.x * content.width - container.width / 2, y: normalized.y * content.height - container.height / 2)
          let offset = ScrollViewportMath.boundedOffset(desired, contentSize: content, container: container)
          let local = ScrollViewportMath.localPoint(normalized: normalized, offset: offset, contentSize: content)
          check(local.x >= 0 && local.x <= container.width, "Hint can reveal \(target.id) horizontally at \(zoom)×")
          check(local.y >= 0 && local.y <= container.height, "Hint can reveal \(target.id) vertically at \(zoom)×")
          let hit = ScrollViewportMath.normalizedPoint(local: local, offset: offset, contentSize: content)
          near(hit.x, normalized.x, "Horizontal hit test reverses drawing coordinates")
          near(hit.y, normalized.y, "Vertical hit test reverses drawing coordinates")
          let range = ScrollViewportMath.visibleRange(offset: offset, contentSize: content, container: container)
          check(range.contains(target.x), "Visible minimap range includes target")
          if target.id == "b3", zoom >= 4 {
            check(offset.y > 0, "The low ox cart remains reachable by vertical pan at \(zoom)×")
            near(local.y, container.height / 2, "Zoomed ox-cart hint is vertically centered")
          }
        }

        let anchor = CGPoint(x: container.width * 0.25, y: container.height * 0.8)
        let paintingAnchor = CGPoint(x: 0.66, y: 0.55)
        let newOffset = ScrollViewportMath.boundedOffset(CGPoint(x: paintingAnchor.x * content.width - anchor.x, y: paintingAnchor.y * content.height - anchor.y), contentSize: content, container: container)
        let anchored = ScrollViewportMath.localPoint(normalized: paintingAnchor, offset: newOffset, contentSize: content)
        near(anchored.x, anchor.x, "Pinch anchor preserves horizontal position")
        if zoom >= 2 { near(anchored.y, anchor.y, "Pinch anchor preserves vertical position when unconstrained") }
      }
    }

    let safe = ScrollViewportMath.contentSize(viewportHeight: 0, zoom: 0, aspectRatio: aspect)
    check(safe.width.isFinite && safe.width > 0 && safe.height == 1, "Transient zero-size layouts stay finite")
    near(ScrollViewportMath.contentSize(viewportHeight: 100, zoom: 8, aspectRatio: aspect).height, 600, "Zoom cannot exceed the magnifier’s 6× limit")
    print("Passed \(checks) production coordinate checks across all 17 quests, 5 viewport sizes and 7 zoom levels.")
  }
}
