import Foundation

@main
struct WorldTileChecks {
  static func main() throws {
    let path = CommandLine.arguments.dropFirst().first ?? "App/Resources/World/tiles/tiles.json"
    let manifest = try JSONDecoder().decode(WorldTileManifest.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
    var count = 0
    func check(_ result: Bool, _ name: String) {
      precondition(result, name)
      count += 1
    }
    check(manifest.isValid, "Supplied tile manifest must be a continuous left-to-right painting")
    check(manifest.tiles.count == 6, "All six source textures are supplied")
    check(manifest.tiles.reduce(0) { $0 + $1.width } == manifest.size[0],
          "Uses exact manifest width, including a shorter final tile")

    for density: CGFloat in [1, 2, 3] {
      for height: CGFloat in [320, 430, 669, 951, 1366] {
        for zoom: CGFloat in [1, 1.25, 1.75, 2, 3, 4] {
          let canvasWidth = CGFloat(manifest.size[0]) / CGFloat(manifest.size[1]) * height * zoom
          var previousEnd: CGFloat = 0
          for tile in manifest.tiles {
            let geometry = WorldTileLayout(pixelX: tile.x, pixelWidth: tile.width,
                                           sourceWidth: CGFloat(manifest.size[0]),
                                           canvasWidth: canvasWidth, displayScale: density)
            check(abs(geometry.origin - previousEnd) < 0.00001, "Every neighboring boundary must be identical")
            check(abs(geometry.origin * density - (geometry.origin * density).rounded()) < 0.00001,
                  "Tile origins lie on device pixels")
            check(geometry.width > 0, "No empty tile")
            let isLast = tile.x + tile.width == manifest.size[0]
            check(geometry.overdraw == (isLast ? 0 : 1 / density), "One physical pixel overlap except world edge")
            previousEnd = geometry.origin + geometry.width
          }
          check(abs(previousEnd - canvasWidth) <= 0.5 / density + 0.00001,
                "Rounding may never accumulate across tiles")
        }
      }
    }

    var invalid = manifest
    invalid.tiles[1].x += 1
    check(!invalid.isValid, "Reject source gaps")
    invalid = manifest
    invalid.tiles[1].x -= 1
    check(!invalid.isValid, "Reject accidental source overlap")
    invalid = manifest
    invalid.tiles[0].file = "../world.jpg"
    check(!invalid.isValid, "Reject unsafe filenames")
    invalid = manifest
    invalid.tiles[1].file = invalid.tiles[0].file
    check(!invalid.isValid, "Reject duplicate tile identities")
    invalid = manifest
    invalid.order = "right_to_left"
    check(!invalid.isValid, "Reading direction must not reverse image assembly")
    invalid = manifest
    invalid.tiles.removeLast()
    check(!invalid.isValid, "Never accept a partially loaded world")
    print("WorldTileChecks: \(count) checks passed")
  }
}
