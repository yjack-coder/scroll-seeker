import SwiftUI
import UIKit
import ImageIO

/// The actual handscroll stays in its original left-to-right pixel order. We
/// begin at the right edge, so a player's journey follows the historical scroll.
struct ScrollSearchCanvas: View {
    var archive: ScrollArchive
    var activeTarget: ScrollTarget?
    var foundTargets: [ScrollTarget]
    var museumMode: Bool
    var hintTarget: ScrollTarget?
    var hintTrigger: Int
    var onTap: (Double, Double) -> Void
    var onViewportChange: (ClosedRange<Double>) -> Void
    var feedback: SearchTapFeedback? = nil
    var chapterID: String = "river"
    var startX: Double = 1
    var chapterComplete: Bool = false
    var chapterRange: ClosedRange<Double> = 0.4...1
    var isActive: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(point: .zero)
    @State private var zoom: CGFloat = 1
    @State private var pinch: ScrollPinchAnchor?
    @State private var viewport = ScrollViewportGeometry()
    @State private var didPosition = false
    @State private var foundDates: [String: Date] = [:]
    @State private var completionDate: Date?
    @State private var hintDate = Date.distantPast
    @State private var feedbackDate = Date.distantPast
    @State private var visibleTileImages: [String: UIImage] = [:]

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = ScrollViewportMath.contentSize(viewportHeight: geometry.size.height, zoom: zoom)

            let interactiveCanvas = ZStack(alignment: .topLeading) {
                ScrollView([.horizontal, .vertical]) {
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(Array(archive.tiles.enumerated()), id: \.element) { index, tile in
                            let pixelWidth: Double = index == archive.tiles.count - 1 ? 3195 : 3202
                            ScrollRasterTile(
                                url: ScrollArchive.resourceURL(for: tile),
                                isNearViewport: tileIsNearViewport(index: index, contentSize: canvasSize),
                                onImageChange: { image in visibleTileImages[tile] = image }
                            )
                            .frame(width: canvasSize.height * pixelWidth / ScrollArchive.fullHeight, height: canvasSize.height)
                        }
                    }
                    .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .defaultScrollAnchor(.topTrailing, for: .initialOffset)
                .scrollPosition($position)
                .onScrollGeometryChange(for: ScrollViewportGeometry.self) { value in
                    ScrollViewportGeometry(
                        offset: CGPoint(
                            x: value.contentOffset.x + value.contentInsets.leading,
                            y: value.contentOffset.y + value.contentInsets.top
                        ),
                        content: value.contentSize,
                        container: value.containerSize
                    )
                } action: { oldValue, newValue in
                    viewport = newValue
                    guard newValue.content.width > 1, newValue.container.width > 1 else { return }
                    if !didPosition {
                        didPosition = true
                        moveToBeginning(contentSize: canvasSize, container: geometry.size)
                    } else if oldValue.container != newValue.container, oldValue.content.width > 1, pinch == nil {
                        // Opening the Duo changes the visible area, not the place in the painting.
                        let center = oldValue.normalizedCenter
                        move(to: center, contentSize: canvasSize, container: geometry.size)
                    }
                    onViewportChange(newValue.visibleRange)
                }

                ScrollLivingOverlay(
                    contentSize: canvasSize,
                    offset: viewport.offset,
                    tiles: archive.tiles,
                    tileImages: visibleTileImages,
                    landmarks: archive.targets,
                    foundTargets: foundTargets,
                    foundDates: foundDates,
                    completedRegions: completedColorRegions,
                    hintTarget: hintTarget,
                    hintDate: hintDate,
                    feedback: feedback,
                    feedbackDate: feedbackDate,
                    isActive: isActive
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(pinchGesture(contentSize: canvasSize, container: geometry.size))
            .simultaneousGesture(
                SpatialTapGesture().onEnded { event in
                    guard pinch == nil else { return }
                    tap(at: event.location, contentSize: canvasSize)
                }
            )
            let accessibleCanvas = interactiveCanvas
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Qingming handscroll")
            .accessibilityValue("\(Int(zoom * 100)) percent zoom, \(Int(viewport.visibleRange.upperBound * 100)) percent across the painting")
            .accessibilityHint("Pan left toward the city. Pinch to examine the painting. Tap an object to inspect it.")
            .accessibilityAction(named: Text("Zoom in")) {
                changeZoom(to: min(4, zoom + 0.5), container: geometry.size)
            }
            .accessibilityAction(named: Text("Zoom out")) {
                changeZoom(to: max(1, zoom - 0.5), container: geometry.size)
            }
            .accessibilityAction(named: Text("Pan toward the city")) {
                pan(by: CGSize(width: -geometry.size.width * 0.75, height: 0), contentSize: canvasSize, container: geometry.size)
            }
            .accessibilityAction(named: Text("Pan toward the countryside")) {
                pan(by: CGSize(width: geometry.size.width * 0.75, height: 0), contentSize: canvasSize, container: geometry.size)
            }
            .accessibilityAction(named: Text("Pan upward")) {
                pan(by: CGSize(width: 0, height: -geometry.size.height * 0.6), contentSize: canvasSize, container: geometry.size)
            }
            .accessibilityAction(named: Text("Pan downward")) {
                pan(by: CGSize(width: 0, height: geometry.size.height * 0.6), contentSize: canvasSize, container: geometry.size)
            }
            .accessibilityAction(named: Text("Inspect the center of the painting")) {
                tap(at: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2), contentSize: canvasSize)
            }
            accessibleCanvas
            .onChange(of: chapterID) { _, _ in
                zoom = 1
                pinch = nil
                hintDate = .distantPast
                feedbackDate = .distantPast
                completionDate = chapterComplete ? .distantPast : nil
                let freshSize = ScrollViewportMath.contentSize(viewportHeight: geometry.size.height, zoom: 1)
                moveToBeginning(contentSize: freshSize, container: geometry.size)
            }
            .onChange(of: hintTrigger) { _, _ in
                guard let target = hintTarget else { return }
                hintDate = .now
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.25)) {
                    move(to: CGPoint(x: target.x, y: target.y), contentSize: canvasSize, container: geometry.size)
                }
            }
            .onChange(of: activeTarget?.id) { _, _ in
                // A paid hint describes this clue, never the next one.
                hintDate = .distantPast
            }
            .onChange(of: feedback?.id) { _, _ in feedbackDate = .now }
            .onChange(of: foundTargets.map(\.id), initial: true) { oldValue, newValue in
                let retainedIDs = Set(newValue)
                foundDates = foundDates.filter { retainedIDs.contains($0.key) }
                for id in newValue where foundDates[id] == nil {
                    foundDates[id] = oldValue == newValue ? .distantPast : .now
                }
            }
            .onChange(of: chapterComplete, initial: true) { oldValue, newValue in
                completionDate = newValue ? (oldValue == newValue ? .distantPast : .now) : nil
            }
        }
        // Locale must not reverse the supplied tile order or normalized coordinates.
        .environment(\.layoutDirection, .leftToRight)
        .background(Color(red: 0.78, green: 0.71, blue: 0.55))
        .task(id: hintTrigger) {
            // TimelineView is intentionally paused with Reduce Motion. An
            // independent deadline still removes its static hint marker.
            guard hintTarget != nil else { return }
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            hintDate = .distantPast
        }
        .task(id: feedback?.id) {
            guard feedback != nil else { return }
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            feedbackDate = .distantPast
        }
    }

    private var completedColorRegions: [ScrollCompletedColorRegion] {
        let earned = Set(foundTargets.map(\.id))
        return archive.chapters.compactMap { chapter in
            let targets = archive.targets.filter { $0.chapter == chapter.id }
            let complete = !targets.isEmpty && targets.allSatisfy { earned.contains($0.id) }
            guard complete || (chapter.id == chapterID && chapterComplete),
                  let lower = chapter.xRange.min(), let upper = chapter.xRange.max() else { return nil }
            let range = chapter.id == chapterID ? chapterRange : lower...upper
            let lastFound = targets.compactMap { foundDates[$0.id] }.max() ?? .distantPast
            let began = chapter.id == chapterID ? (completionDate ?? lastFound) : lastFound
            return ScrollCompletedColorRegion(range: range, began: began)
        }
    }

    private func tileIsNearViewport(index: Int, contentSize: CGSize) -> Bool {
        let tileWidth = contentSize.height * 3202 / ScrollArchive.fullHeight
        let left = CGFloat(index) * tileWidth
        let preload = max(viewport.container.width, 200)
        return left + tileWidth >= viewport.offset.x - preload && left <= viewport.offset.x + viewport.container.width + preload
    }

    private func pinchGesture(contentSize: CGSize, container: CGSize) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.005)
            .onChanged { event in
                if pinch == nil {
                    let local = event.startLocation
                    pinch = ScrollPinchAnchor(
                        startZoom: zoom,
                        normalizedPoint: ScrollViewportMath.normalizedPoint(local: local, offset: viewport.offset, contentSize: contentSize),
                        localPoint: local
                    )
                }
                guard let pinch else { return }
                let updatedZoom = min(4, max(1, pinch.startZoom * event.magnification))
                zoom = updatedZoom
                let updatedSize = ScrollViewportMath.contentSize(viewportHeight: container.height, zoom: updatedZoom)
                position.scrollTo(point: boundedOffset(
                    CGPoint(x: pinch.normalizedPoint.x * updatedSize.width - pinch.localPoint.x,
                            y: pinch.normalizedPoint.y * updatedSize.height - pinch.localPoint.y),
                    contentSize: updatedSize, container: container
                ))
            }
            .onEnded { _ in pinch = nil }
    }

    private func changeZoom(to value: CGFloat, container: CGSize) {
        let center = viewport.normalizedCenter
        zoom = value
        let size = ScrollViewportMath.contentSize(viewportHeight: container.height, zoom: value)
        move(to: center, contentSize: size, container: container)
    }

    private func moveToBeginning(contentSize: CGSize, container: CGSize) {
        position.scrollTo(point: boundedOffset(CGPoint(x: startX * contentSize.width - container.width, y: 0), contentSize: contentSize, container: container))
    }

    private func move(to normalizedPoint: CGPoint, contentSize: CGSize, container: CGSize) {
        position.scrollTo(point: boundedOffset(
            CGPoint(x: normalizedPoint.x * contentSize.width - container.width / 2,
                    y: normalizedPoint.y * contentSize.height - container.height / 2),
            contentSize: contentSize, container: container
        ))
    }

    private func pan(by amount: CGSize, contentSize: CGSize, container: CGSize) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
            position.scrollTo(point: boundedOffset(
                CGPoint(x: viewport.offset.x + amount.width, y: viewport.offset.y + amount.height),
                contentSize: contentSize, container: container
            ))
        }
    }

    private func boundedOffset(_ point: CGPoint, contentSize: CGSize, container: CGSize) -> CGPoint {
        ScrollViewportMath.boundedOffset(point, contentSize: contentSize, container: container)
    }

    private func tap(at point: CGPoint, contentSize: CGSize) {
        let normalized = ScrollViewportMath.normalizedPoint(local: point, offset: viewport.offset, contentSize: contentSize)
        guard (0...1).contains(normalized.x), (0...1).contains(normalized.y) else { return }
        onTap(Double(normalized.x), Double(normalized.y))
    }
}

struct SearchTapFeedback: Equatable {
    var id = UUID()
    var x: Double
    var y: Double
    var isFound: Bool
}

private struct ScrollPinchAnchor {
    var startZoom: CGFloat
    var normalizedPoint: CGPoint
    var localPoint: CGPoint
}

private struct ScrollCompletedColorRegion {
    var range: ClosedRange<Double>
    var began: Date
}

private struct ScrollViewportGeometry: Equatable {
    var offset = CGPoint.zero
    var content = CGSize.zero
    var container = CGSize.zero

    var visibleRange: ClosedRange<Double> {
        ScrollViewportMath.visibleRange(offset: offset, contentSize: content, container: container)
    }

    var normalizedCenter: CGPoint {
        ScrollViewportMath.normalizedPoint(local: CGPoint(x: container.width / 2, y: container.height / 2), offset: offset, contentSize: content)
    }
}

/// Each visible tile owns its decoded pixels; leaving the prefetch window drops
/// them. We never make a 25,609-pixel UIImage, offscreen layer, or image cache.
private struct ScrollRasterTile: View {
    var url: URL?
    var isNearViewport: Bool
    var onImageChange: (UIImage?) -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(red: 0.78, green: 0.71, blue: 0.55)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
            }
        }
        .task(id: isNearViewport) {
            guard isNearViewport, let url else {
                image = nil
                onImageChange(nil)
                return
            }
            let loaded = await Task.detached(priority: .userInitiated) {
                Self.loadTile(url)
            }.value
            guard !Task.isCancelled else { return }
            image = loaded
            onImageChange(loaded)
        }
        .onDisappear {
            image = nil
            onImageChange(nil)
        }
        .accessibilityHidden(true)
    }

    nonisolated private static func loadTile(_ url: URL) -> UIImage? {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 3202,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
}

/// All animated artwork is drawn into the small viewport, never into a layer
/// the width of the whole scroll. The saturation layer redraws only the original
/// tile pixels, preserving every contour and historical target coordinate.
private struct ScrollLivingOverlay: View {
    var contentSize: CGSize
    var offset: CGPoint
    var tiles: [String]
    var tileImages: [String: UIImage]
    var landmarks: [ScrollTarget]
    var foundTargets: [ScrollTarget]
    var foundDates: [String: Date]
    var completedRegions: [ScrollCompletedColorRegion]
    var hintTarget: ScrollTarget?
    var hintDate: Date
    var feedback: SearchTapFeedback?
    var feedbackDate: Date
    var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let gold = Color(red: 0.77, green: 0.55, blue: 0.22)
    private let vermilion = Color(red: 0.63, green: 0.18, blue: 0.12)
    private let warmLight = Color(red: 1, green: 0.77, blue: 0.4)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion || scenePhase != .active || !isActive)) { timeline in
            let time = (reduceMotion ? Date.now : timeline.date).timeIntervalSinceReferenceDate
            ZStack {
                Canvas { context, size in
                    drawOriginalColor(context: &context, size: size, time: time)
                }
                Canvas { context, size in
                    drawWarmth(context: &context, size: size, time: time)
                }
                .blendMode(.softLight)
                Canvas { context, size in
                    if !reduceMotion {
                        drawLivingDetails(context: &context, size: size, time: time)
                    }
                    drawFoundRings(context: &context, size: size, time: time)
                    drawHint(context: &context, time: time)
                    drawFeedback(context: &context, time: time)
                }
            }
        }
    }

    private func point(_ x: Double, _ y: Double) -> CGPoint {
        ScrollViewportMath.localPoint(normalized: CGPoint(x: x, y: y), offset: offset, contentSize: contentSize)
    }

    private func drawOriginalColor(context: inout GraphicsContext, size: CGSize, time: Double) {
        guard !foundTargets.isEmpty || !completedRegions.isEmpty else { return }
        context.clipToLayer { mask in
            for target in foundTargets {
                let progress = discoveryProgress(target: target, time: time)
                let bloom = 1 - pow(1 - progress, 3)
                let center = point(target.x, target.y)
                let radius = CGSize(width: contentSize.width * 0.022 * bloom, height: contentSize.height * 0.24 * bloom)
                pigmentPool(context: &mask, center: center, radius: radius, color: .white, opacity: progress)
            }
            for region in completedRegions {
                let rect = completedRevealRect(region: region, size: size, time: time)
                guard rect.width > 0 else { continue }
                mask.fill(Path(rect), with: .color(.white))
            }
        }
        context.addFilter(.saturation(1.7))
        context.addFilter(.contrast(1.025))
        let visibleRect = CGRect(origin: .zero, size: size)
        for (index, tile) in tiles.enumerated() {
            let pixelWidth: Double = index == tiles.count - 1 ? 3195 : 3202
            let rect = CGRect(
                x: Double(index) * 3202 / ScrollArchive.fullWidth * contentSize.width - offset.x,
                y: -offset.y,
                width: pixelWidth / ScrollArchive.fullWidth * contentSize.width,
                height: contentSize.height
            )
            guard rect.intersects(visibleRect), let image = tileImages[tile] else { continue }
            context.draw(Image(uiImage: image), in: rect)
        }
    }

    private func discoveryProgress(target: ScrollTarget, time: Double) -> Double {
        let age = time - (foundDates[target.id] ?? .distantPast).timeIntervalSinceReferenceDate
        return reduceMotion ? 1 : min(1, max(0, age / 2.6))
    }

    private func completedRevealRect(region: ScrollCompletedColorRegion, size: CGSize, time: Double) -> CGRect {
        let age = time - region.began.timeIntervalSinceReferenceDate
        let progress = reduceMotion ? 1 : min(1, max(0, age / 5))
        let sweepX = region.range.upperBound - (region.range.upperBound - region.range.lowerBound) * progress
        let left = max(0, sweepX * contentSize.width - offset.x)
        let right = min(size.width, region.range.upperBound * contentSize.width - offset.x)
        return CGRect(x: left, y: 0, width: max(0, right - left), height: size.height)
    }

    private func drawWarmth(context: inout GraphicsContext, size: CGSize, time: Double) {
        for target in foundTargets {
            let progress = discoveryProgress(target: target, time: time)
            let bloom = 1 - pow(1 - progress, 3)
            let center = point(target.x, target.y)
            let rx = contentSize.width * 0.022 * bloom
            let ry = contentSize.height * 0.24 * bloom
            guard rx > 0, CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2).intersects(CGRect(origin: .zero, size: size)) else { continue }
            pigmentPool(context: &context, center: center, radius: CGSize(width: rx, height: ry), color: warmLight, opacity: 0.34 * progress)
        }

        for region in completedRegions {
            var chapterContext = context
            drawCompletedChapter(context: &chapterContext, size: size, time: time, region: region)
        }
    }

    private func drawCompletedChapter(context: inout GraphicsContext, size: CGSize, time: Double, region: ScrollCompletedColorRegion) {
        let rect = completedRevealRect(region: region, size: size, time: time)
        guard rect.width > 0 else { return }
        context.fill(Path(rect), with: .color(warmLight.opacity(0.23)))
    }

    private func pigmentPool(context: inout GraphicsContext, center: CGPoint, radius: CGSize, color: Color, opacity: Double) {
        guard radius.width > 0, radius.height > 0 else { return }
        var wash = context
        wash.translateBy(x: center.x, y: center.y)
        wash.scaleBy(x: radius.width, y: radius.height)
        wash.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)), with: .radialGradient(
            Gradient(stops: [.init(color: color.opacity(opacity), location: 0), .init(color: color.opacity(opacity * 0.85), location: 0.43), .init(color: color.opacity(0), location: 1)]),
            center: .zero, startRadius: 0, endRadius: 1
        ))
    }

    private func drawLivingDetails(context: inout GraphicsContext, size: CGSize, time: Double) {
        let visibleRect = CGRect(origin: .zero, size: size).insetBy(dx: -40, dy: -40)
        let localTime = time.truncatingRemainder(dividingBy: 1000)
        let scale = contentSize.height / 700

        // Quiet ambient life is present throughout the original painting, even
        // before discovery. Only the stronger warm color is earned by finding.
        for index in 0..<68 {
            let x = 0.415 + Double(index) / 68 * 0.385
            let y = 0.25 + Double((index * 37) % 31) / 100
            let p = point(x, y)
            guard visibleRect.contains(p) else { continue }
            let phase = localTime * 0.8 + Double(index) * 1.7
            let alpha = 0.05 + (sin(phase) + 1) * 0.075
            let drift = CGFloat(sin(phase * 0.5)) * 3 * scale
            var ripple = Path()
            ripple.move(to: CGPoint(x: p.x - 9 * scale + drift, y: p.y))
            ripple.addQuadCurve(to: CGPoint(x: p.x + 9 * scale + drift, y: p.y), control: CGPoint(x: p.x, y: p.y - 1.5 * scale))
            context.stroke(ripple, with: .color(Color(red: 0.95, green: 0.9, blue: 0.67).opacity(alpha)), style: StrokeStyle(lineWidth: max(0.5, scale), lineCap: .round))
        }

        // Lantern warmth belongs to the two real tavern locations.
        for location in [CGPoint(x: 0.116, y: 0.47), CGPoint(x: 0.444, y: 0.42)] {
            let p = point(location.x, location.y)
            guard visibleRect.contains(p) else { continue }
            let glow = 0.17 + sin(localTime * 1.2 + location.x * 20) * 0.04
            pigmentPool(context: &context, center: p, radius: CGSize(width: 24 * scale, height: 35 * scale), color: .orange, opacity: glow)
        }

        // One unhurried flock appears briefly, then the air is still again.
        let flight = localTime.truncatingRemainder(dividingBy: 28)
        if flight < 9 {
            for index in 0..<3 {
                let x = size.width * CGFloat(1.1 - flight / 7.5) + CGFloat(index) * 19
                let y = size.height * 0.19 + CGFloat(index) * 8 + CGFloat(sin(localTime + Double(index))) * 3
                let wing = 2 + CGFloat(sin(localTime * 3.5 + Double(index))) * 1.7
                var bird = Path()
                bird.move(to: CGPoint(x: x - 5, y: y - wing))
                bird.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 1.8, y: y - 3))
                bird.addQuadCurve(to: CGPoint(x: x + 5, y: y - wing), control: CGPoint(x: x + 1.8, y: y - 3))
                context.stroke(bird, with: .color(Color(red: 0.16, green: 0.2, blue: 0.2).opacity(0.45)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
        }

        // Slow, translucent veils and a few trembling leaves add breath without
        // moving a photographed target away from its hit-test coordinate.
        for target in landmarks {
            let p = point(target.x, target.y)
            guard visibleRect.insetBy(dx: -100, dy: -100).contains(p) else { continue }
            let drift = CGFloat(sin(localTime * 0.14 + target.x * 20)) * 24
            pigmentPool(context: &context, center: CGPoint(x: p.x + drift, y: p.y - 52 * scale), radius: CGSize(width: 100 * scale, height: 20 * scale), color: Color(red: 0.94, green: 0.9, blue: 0.77), opacity: 0.055)
            if target.x > 0.85 {
                for leaf in 0..<5 {
                    let sway = CGFloat(sin(localTime * 0.65 + Double(leaf))) * 1.8 * scale
                    let leafPoint = CGPoint(x: p.x - 40 * scale + CGFloat(leaf) * 12 * scale + sway, y: p.y - 46 * scale + CGFloat(leaf % 2) * 8 * scale)
                    context.fill(Path(ellipseIn: CGRect(x: leafPoint.x, y: leafPoint.y, width: 4 * scale, height: 1.5 * scale)), with: .color(gold.opacity(0.2)))
                }
            }
        }
    }

    private func drawFoundRings(context: inout GraphicsContext, size: CGSize, time: Double) {
        for target in foundTargets {
            let p = point(target.x, target.y)
            guard CGRect(origin: .zero, size: size).insetBy(dx: -90, dy: -90).contains(p) else { continue }
            let age = time - (foundDates[target.id] ?? .distantPast).timeIntervalSinceReferenceDate
            let progress = reduceMotion ? 1 : min(1, max(0, age / 1.2))
            let radius = min(58, max(25, contentSize.height * 0.045)) * (0.65 + 0.35 * progress)
            let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(gold.opacity(0.75)), style: StrokeStyle(lineWidth: 1.7))
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(gold.opacity(0.27)), style: StrokeStyle(lineWidth: 0.7))
            let stampRect = CGRect(x: p.x + radius * 0.55, y: p.y + radius * 0.4, width: 21, height: 24)
            context.fill(Path(roundedRect: stampRect, cornerRadius: 2), with: .color(vermilion.opacity(0.92)))
            context.draw(Text("尋").font(.system(size: 16, weight: .medium, design: .serif)).foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.77)), at: CGPoint(x: stampRect.midX, y: stampRect.midY))
        }
    }

    private func drawHint(context: inout GraphicsContext, time: Double) {
        guard let target = hintTarget else { return }
        let age = time - hintDate.timeIntervalSinceReferenceDate
        guard age >= 0, age < 8 else { return }
        let p = point(target.x, target.y)
        let pulse = reduceMotion ? 0.5 : (sin(age * 3) + 1) / 2
        let radius = CGFloat(37 + pulse * 6)
        let rect = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: rect), with: .color(gold.opacity(0.7 + pulse * 0.25)), style: StrokeStyle(lineWidth: 4))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 5, dy: 5)), with: .color(Color.white.opacity(0.38)), lineWidth: 1)
        var handle = Path()
        handle.move(to: CGPoint(x: p.x + radius * 0.71, y: p.y + radius * 0.71))
        handle.addLine(to: CGPoint(x: p.x + radius * 1.22, y: p.y + radius * 1.22))
        context.stroke(handle, with: .color(Color(red: 0.28, green: 0.19, blue: 0.11)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
    }

    private func drawFeedback(context: inout GraphicsContext, time: Double) {
        guard let feedback else { return }
        let age = time - feedbackDate.timeIntervalSinceReferenceDate
        guard age >= 0, age < 1.5 else { return }
        let progress = min(1, age / 1.5)
        let p = point(feedback.x, feedback.y)
        let radius = reduceMotion ? 24 : 10 + progress * (feedback.isFound ? 90 : 36)
        let color = feedback.isFound ? gold : Color(red: 0.98, green: 0.94, blue: 0.8)
        context.stroke(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)), with: .color(color.opacity((1 - progress) * 0.8)), lineWidth: feedback.isFound ? 3 : 1.5)
    }
}
