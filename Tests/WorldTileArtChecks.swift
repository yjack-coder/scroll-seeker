import Foundation
import CoreGraphics
import ImageIO

/// Reads the supplied artwork only. This never creates or rewrites image assets.
@main
struct WorldTileArtChecks {
  static func main() throws {
    let path = CommandLine.arguments.dropFirst().first ?? "App/Resources/World/tiles/tiles.json"
    let url = URL(fileURLWithPath: path)
    let manifest = try JSONDecoder().decode(WorldTileManifest.self, from: Data(contentsOf: url))
    precondition(manifest.isValid)
    let directory = url.deletingLastPathComponent()
    let sourceURL = directory.deletingLastPathComponent().appendingPathComponent(manifest.source)
    let source = try pixels(at: sourceURL)
    precondition(source.width == manifest.size[0] && source.height == manifest.size[1])
    let sourceBytes = source.data!.assumingMemoryBound(to: UInt8.self)
    var checks = 1
    var totalDifference = 0
    var sampleCount = 0
    let began = Date.now
    for tile in manifest.tiles {
      let decoded = try pixels(at: directory.appendingPathComponent(tile.file))
      precondition(decoded.width == tile.width && decoded.height == manifest.size[1])
      checks += 1
      let tileBytes = decoded.data!.assumingMemoryBound(to: UInt8.self)
      // Dense samples on both sides of every seam, plus the center, establish
      // that each file belongs at its exact authored offset. Independent JPEG
      // recompression is lossy, so compare bounded mean error, not equal bytes.
      var difference = 0
      var samples = 0
      for y in stride(from: 0, to: decoded.height, by: 4) {
        for x in [0, 1, 2, 3, decoded.width / 2,
                  decoded.width - 4, decoded.width - 3, decoded.width - 2, decoded.width - 1] {
          for channel in 0..<3 {
            let a = Int(sourceBytes[y * source.bytesPerRow + (tile.x + x) * 4 + channel])
            let b = Int(tileBytes[y * decoded.bytesPerRow + x * 4 + channel])
            difference += abs(a - b)
            samples += 1
          }
        }
      }
      let mean = Double(difference) / Double(samples)
      precondition(mean < 12, "Tile \(tile.file) does not align with world.jpg at x=\(tile.x)")
      checks += 1
      totalDifference += difference
      sampleCount += samples
      print("\(tile.file): \(decoded.width)×\(decoded.height), x=\(tile.x), mean RGB difference \(String(format: "%.3f", mean))/255")
    }
    print("WorldTileArtChecks: \(checks) checks passed; \(sampleCount) RGB seam samples; mean \(String(format: "%.3f", Double(totalDifference) / Double(sampleCount)))/255; six eager decodes \(String(format: "%.3f", Date.now.timeIntervalSince(began)))s")
  }

  private static func pixels(at url: URL) throws -> CGContext {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0,
            [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
          let context = CGContext(data: nil, width: image.width, height: image.height,
                                  bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
      throw CocoaError(.fileReadCorruptFile)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return context
  }
}
