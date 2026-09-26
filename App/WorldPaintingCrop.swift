import SwiftUI

/// A viewport into the one authored world, shared by the home and story screens.
/// The source dimensions come from ImageIO rather than an assumed panorama size.
struct WorldPaintingCrop: View {
  var center: CGPoint
  var verticalSpan: CGFloat = 1
  var anchor: UnitPoint = .center
  var heroStage: AdventureStage? = nil
  var heroHeight: CGFloat = 64
  var heroOpacity: Double = 1
  var heroSaturation: Double = 1

  var body: some View {
    GeometryReader { geometry in
      let layout = WorldPaintingViewport(
        sourceSize: WorldPaintingArt.pixelSize,
        viewportSize: geometry.size, center: center, verticalSpan: verticalSpan, anchor: anchor)
      ZStack(alignment: .topLeading) {
        SeekerStyle.paper
        WorldTileRaster(canvasSize: layout.imageSize)
          .offset(x: -layout.origin.x, y: -layout.origin.y)
        if let heroStage {
          AdventureHeroSprite(stage: heroStage, height: heroHeight)
            .opacity(heroOpacity).saturation(heroSaturation)
            .position(x: layout.focus.x,
              y: layout.focus.y - heroHeight * (AdventureHeroSprite.footFraction(for: heroStage) - 0.5))
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
      .clipped()
    }
  }
}

@MainActor
enum WorldPaintingArt {
  static var pixelSize: CGSize { WorldTileStore.shared.sourceSize }

  private static let places: [String: WorldArtPlace] = {
    guard let url = ScrollArchive.resourceURL(for: "world.json"),
      let data = try? Data(contentsOf: url),
      let map = try? JSONDecoder().decode(WorldArtMap.self, from: data) else { return [:] }
    return map.places
  }()

  static func point(for place: String) -> CGPoint {
    guard let point = places[place] else { return CGPoint(x: 0.5, y: 0.5) }
    return CGPoint(x: point.x, y: point.y)
  }
}

private struct WorldArtMap: Decodable {
  var places: [String: WorldArtPlace]
}

private struct WorldArtPlace: Decodable {
  var x: Double
  var y: Double
}

private struct WorldPaintingViewport {
  var imageSize: CGSize
  var origin: CGPoint
  var focus: CGPoint

  init(sourceSize: CGSize, viewportSize: CGSize, center: CGPoint, verticalSpan: CGFloat, anchor: UnitPoint) {
    let width = max(1, sourceSize.width)
    let height = max(1, sourceSize.height)
    let viewportWidth = max(1, viewportSize.width)
    let viewportHeight = max(1, viewportSize.height)
    let span = min(1, max(0.1, verticalSpan))
    let scale = max(viewportWidth / width, viewportHeight / (height * span))
    imageSize = CGSize(width: width * scale, height: height * scale)
    let target = CGPoint(x: min(1, max(0, center.x)) * imageSize.width,
                         y: min(1, max(0, center.y)) * imageSize.height)
    origin = CGPoint(
      x: min(max(0, imageSize.width - viewportWidth), max(0, target.x - viewportWidth * anchor.x)),
      y: min(max(0, imageSize.height - viewportHeight), max(0, target.y - viewportHeight * anchor.y)))
    focus = CGPoint(x: target.x - origin.x, y: target.y - origin.y)
  }
}
