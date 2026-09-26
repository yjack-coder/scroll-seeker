import Foundation

/// Coordinate conversion is shared by drawing, hit testing, hints and the
/// minimap. Points always refer to the complete, unmirrored original painting.
enum ScrollViewportMath {
    static func contentSize(viewportHeight: CGFloat, zoom: CGFloat, aspectRatio: CGFloat) -> CGSize {
        let height = max(1, viewportHeight) * min(6, max(1, zoom))
        let validAspect = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1
        return CGSize(width: height * validAspect, height: height)
    }

    static func boundedOffset(_ point: CGPoint, contentSize: CGSize, container: CGSize) -> CGPoint {
        CGPoint(x: min(max(0, point.x), max(0, contentSize.width - container.width)),
                y: min(max(0, point.y), max(0, contentSize.height - container.height)))
    }

    static func normalizedPoint(local: CGPoint, offset: CGPoint, contentSize: CGSize) -> CGPoint {
        CGPoint(x: (offset.x + local.x) / max(1, contentSize.width),
                y: (offset.y + local.y) / max(1, contentSize.height))
    }

    static func localPoint(normalized: CGPoint, offset: CGPoint, contentSize: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * contentSize.width - offset.x,
                y: normalized.y * contentSize.height - offset.y)
    }

    static func visibleRange(offset: CGPoint, contentSize: CGSize, container: CGSize) -> ClosedRange<Double> {
        let width = max(1, contentSize.width)
        let lower = min(1, max(0, offset.x / width))
        let upper = min(1, max(lower, (offset.x + container.width) / width))
        return Double(lower)...Double(upper)
    }
}
