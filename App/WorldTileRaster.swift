import SwiftUI

/// Six small retained textures in one non-lazy strip. Never rasterize this entire
/// HStack into a drawing/compositing group: it may exceed the GPU texture limit.
struct WorldTileRaster: View {
  var canvasSize: CGSize
  @Environment(\.displayScale) private var displayScale
  private var store: WorldTileStore { .shared }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(store.tiles) { tile in
        let layout = WorldTileLayout(pixelX: tile.pixelX, pixelWidth: tile.pixelWidth,
                                     sourceWidth: store.sourceSize.width,
                                     canvasWidth: canvasSize.width, displayScale: displayScale)
        WorldTileCell(image: tile.image, width: layout.width,
                      height: canvasSize.height, overdraw: layout.overdraw)
      }
    }
    .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
    .environment(\.layoutDirection, .leftToRight)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task { await store.awaitReady() }
  }
}

private struct WorldTileCell: View {
  var image: CGImage
  var width: CGFloat
  var height: CGFloat
  var overdraw: CGFloat

  var body: some View {
    Image(decorative: image, scale: 1, orientation: .up)
      .resizable()
      .interpolation(.high)
      .frame(width: width + overdraw, height: height)
      .frame(width: width, height: height, alignment: .leading)
  }
}

extension WorldTileStore {
  /// Viewport-sized effects (for example a completed quest's warm bloom) reuse
  /// the same decoded tiles. No full-world image or giant offscreen surface.
  func draw(in context: inout GraphicsContext, contentSize: CGSize,
            offset: CGPoint, viewportSize: CGSize, displayScale: CGFloat = 2) {
    let visible = CGRect(origin: .zero, size: viewportSize)
    for tile in tiles {
      let layout = WorldTileLayout(pixelX: tile.pixelX, pixelWidth: tile.pixelWidth,
                                   sourceWidth: sourceSize.width,
                                   canvasWidth: contentSize.width, displayScale: displayScale)
      let frame = CGRect(x: layout.origin - offset.x, y: -offset.y,
                         width: layout.width + layout.overdraw, height: contentSize.height)
      guard frame.intersects(visible) else { continue }
      context.draw(Image(decorative: tile.image, scale: 1, orientation: .up), in: frame)
    }
  }
}
