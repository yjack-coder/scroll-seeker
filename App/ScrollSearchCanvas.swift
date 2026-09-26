import SwiftUI
import UIKit

/// The supplied world raster remains in its native left-to-right pixel order.
/// Viewport-sized overlays preserve the painting's geometry at every zoom.
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
    var heroPosition: CGPoint? = nil
    var heroStage: AdventureStage = .child
    var heroWalking = false
    var heroFacingLeft = true
    var maximumZoom: CGFloat = 4
    var missionPosition: CGPoint? = nil
    var lanternRadius: Double = 1
    var heroJumpTrigger = 0
    var lanternLit = false
    var heroOpacity: Double = 1
    var showsWalkHint = false
    var fogEnabled = false
    var revealProgress: Double = 1
    var excludedTouchRects: [CGRect] = []
    var pathPoints: [AdventurePathPoint] = []
    var isEditingPath: Bool = false
    var onPathPointMove: ((UUID, CGPoint) -> Void)? = nil
    var onPathPointDelete: ((UUID) -> Void)? = nil
    var onPathPointAdd: ((CGPoint) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position = ScrollPosition(edge: .trailing)
    @State private var zoom: CGFloat = 1
    @State private var pinch: ScrollPinchAnchor?
    @State private var viewport = ScrollViewportGeometry()
    @State private var didPosition = false
    @State private var foundDates: [String: Date] = [:]
    @State private var completionDate: Date?
    @State private var hintDate = Date.distantPast
    @State private var feedbackDate = Date.distantPast
    @State private var camera = ScrollHeroCamera()
    @State private var hasOpenedCamera = false
    @State private var pathDrag: ScrollPathDrag?
    @State private var selectedPathPoint: UUID?
    @State private var lastPathInteraction = Date.distantPast

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = ScrollViewportMath.contentSize(viewportHeight: geometry.size.height, zoom: zoom, aspectRatio: archive.aspectRatio)

            let interactiveCanvas = ZStack(alignment: .topLeading) {
                if heroPosition == nil || isEditingPath {
                  ScrollView([.horizontal, .vertical]) {
                    WorldTileRaster(canvasSize: canvasSize)
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
                    if didPosition, oldValue.container != newValue.container, oldValue.content.width > 1, pinch == nil {
                        let center = heroPosition ?? oldValue.normalizedCenter
                        move(to: center, contentSize: canvasSize, container: geometry.size)
                    }
                    onViewportChange(newValue.visibleRange)
                }
                } else {
                    WorldTileRaster(canvasSize: canvasSize)
                        .offset(x: -viewport.offset.x, y: -viewport.offset.y)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                        .clipped()
                }

                ScrollLivingOverlay(
                    contentSize: canvasSize,
                    offset: viewport.offset,
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

                if let heroPosition, !isEditingPath {
                    WorldFogLayer(heroX: heroPosition.x, contentSize: canvasSize,
                                  offset: viewport.offset, isActive: isActive, enabled: fogEnabled)
                        .allowsHitTesting(false)
                }

                if isEditingPath {
                    ScrollPathDrawing(points: pathPoints, contentSize: canvasSize, offset: viewport.offset)
                        .allowsHitTesting(false).accessibilityHidden(true)
                    ForEach(pathPoints) { point in
                        pathHandle(point, contentSize: canvasSize, container: geometry.size)
                    }
                }

                if let missionPosition {
                    let npc = ScrollViewportMath.localPoint(normalized: missionPosition, offset: viewport.offset, contentSize: canvasSize)
                    Circle().stroke(SeekerStyle.gold.opacity(0.7), lineWidth: 1.5)
                        .frame(width: 36 * lanternRadius, height: 36 * lanternRadius)
                        .background { Circle().fill(SeekerStyle.gold.opacity(0.13)).blur(radius: 10) }
                        .overlay(alignment: .top) {
                            Text("!").font(.system(size: 18, weight: .bold, design: .serif)).foregroundStyle(SeekerStyle.paper)
                                .padding(5).background(SeekerStyle.indigo, in: Circle()).offset(y: -23)
                        }
                        .position(npc).allowsHitTesting(false).accessibilityHidden(true)
                }
                if let heroPosition {
                    let hero = ScrollViewportMath.localPoint(normalized: heroPosition, offset: viewport.offset, contentSize: canvasSize)
                    let spriteHeight = max(110, geometry.size.height * 0.22)
                    let footFraction = AdventureHeroSprite.footFraction(for: heroStage)
                    AdventureHeroSprite(stage: heroStage, walking: heroWalking && isActive, facingLeft: heroFacingLeft, height: spriteHeight, jumpTrigger: heroJumpTrigger, showsName: true)
                        .shadow(color: lanternLit ? SeekerStyle.gold.opacity(0.9) : .clear, radius: lanternLit ? 16 : 0)
                        .position(x: hero.x, y: hero.y - spriteHeight * (footFraction - 0.5))
                        .opacity(heroOpacity)
                        .allowsHitTesting(false).accessibilityHidden(true)
                    if showsWalkHint && !heroWalking {
                        ScrollWalkHint()
                            .position(x: min(geometry.size.width - 138, max(138, hero.x)),
                                      y: max(100, hero.y - spriteHeight - 35))
                            .allowsHitTesting(false)
                    }
                }
            }
            .coordinateSpace(name: ScrollCanvasSpace.viewport)
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(pinchGesture(contentSize: canvasSize, container: geometry.size))
            .simultaneousGesture(
                SpatialTapGesture().onEnded { event in
                    guard pinch == nil, pathDrag == nil,
                          Date.now.timeIntervalSince(lastPathInteraction) > 0.35,
                          !excludedTouchRects.contains(where: { $0.contains(event.location) }) else { return }
                    if isEditingPath, pathPoints.contains(where: {
                        let point = ScrollViewportMath.localPoint(normalized: CGPoint(x: $0.x, y: $0.y), offset: viewport.offset, contentSize: canvasSize)
                        return hypot(point.x - event.location.x, point.y - event.location.y) < 24
                    }) { return }
                    tap(at: event.location, contentSize: canvasSize)
                }
            )
            let accessibleCanvas = interactiveCanvas
            .accessibilityElement(children: isEditingPath ? .contain : .ignore)
            .accessibilityLabel(isEditingPath ? "Walking path editor" : "A Life Along the River, painted world")
            .accessibilityValue("\(Int(zoom * 100)) percent zoom, \(Int(viewport.visibleRange.upperBound * 100)) percent across the painting")
            .accessibilityHint(isEditingPath ? "Pan and pinch to inspect the road. Drag yellow points to trace it. Tap empty painting to add a point; hold a point to delete." : heroPosition == nil ? "Pan left toward the city. Pinch to examine the painting." : "Tap the road to walk there. Hold the direction controls to walk. Pinch to examine the world.")
            .accessibilityAction(named: Text("Zoom in")) {
                changeZoom(to: min(maximumZoom, zoom + 0.5), container: geometry.size)
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
            .accessibilityAction(named: Text(isEditingPath ? "Add path point at the center of the view" : "Walk to the center of the view")) {
                tap(at: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2), contentSize: canvasSize)
            }
            accessibleCanvas
            .task(id: geometry.size) {
                guard heroPosition == nil || isEditingPath else { return }
                guard !didPosition, geometry.size.width > 1, geometry.size.height > 1 else { return }
                // The initial geometry callback can precede UIScrollView's
                // attachment. Wait for that layout before issuing a point move;
                // until then, the native trailing-edge position is authoritative.
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled, !didPosition else { return }
                moveToBeginning(contentSize: canvasSize, container: geometry.size)
                didPosition = true
            }
            .onChange(of: geometry.size, initial: true) { _, size in
                guard !isEditingPath, let heroPosition else { return }
                camera.resize(content: canvasSize, container: size, target: heroPosition)
                if revealProgress > 0 && !hasOpenedCamera {
                    camera.beginOpening(atHome: heroPosition.x > 0.90, reduceMotion: reduceMotion)
                    hasOpenedCamera = true
                }
                publishCamera()
            }
            .onChange(of: revealProgress) { old, value in
                guard !isEditingPath, let heroPosition, old <= 0, value > 0 else { return }
                camera.resize(content: canvasSize, container: geometry.size, target: heroPosition)
                camera.beginOpening(atHome: !hasOpenedCamera && heroPosition.x > 0.90, reduceMotion: reduceMotion)
                hasOpenedCamera = true
                publishCamera()
            }
            .task(id: isActive && revealProgress > 0 && !isEditingPath) {
                guard isActive, revealProgress > 0, heroPosition != nil, !isEditingPath else { return }
                var previous = Date.now
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                    let now = Date.now
                    camera.tick(delta: now.timeIntervalSince(previous), reduceMotion: reduceMotion)
                    previous = now
                    publishCamera()
                }
            }
            .onChange(of: chapterID) { _, _ in
                zoom = 1
                pinch = nil
                hintDate = .distantPast
                feedbackDate = .distantPast
                completionDate = chapterComplete ? .distantPast : nil
                let freshSize = ScrollViewportMath.contentSize(viewportHeight: geometry.size.height, zoom: 1, aspectRatio: archive.aspectRatio)
                moveToBeginning(contentSize: freshSize, container: geometry.size)
            }
            .onChange(of: heroPosition) { _, newPosition in
                guard !isEditingPath, let newPosition else { return }
                camera.target = newPosition
            }
            .onChange(of: heroStage) { _, _ in
                guard !isEditingPath, let heroPosition else { return }
                move(to: heroPosition, contentSize: canvasSize, container: geometry.size)
            }
            .onChange(of: isActive) { _, active in
                guard active, !isEditingPath, let heroPosition else { return }
                camera.target = heroPosition
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
        // Locale must not mirror the world or its normalized coordinates.
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

    private func pinchGesture(contentSize: CGSize, container: CGSize) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.005)
            .onChanged { event in
                if isEditingPath {
                    lastPathInteraction = .now
                    if pathDrag != nil { pathDrag = nil }
                }
                if pinch == nil {
                    let local = event.startLocation
                    pinch = ScrollPinchAnchor(
                        startZoom: zoom,
                        normalizedPoint: ScrollViewportMath.normalizedPoint(local: local, offset: viewport.offset, contentSize: contentSize),
                        localPoint: local
                    )
                }
                guard let pinch else { return }
                let updatedZoom = min(maximumZoom, max(1, pinch.startZoom * event.magnification))
                zoom = updatedZoom
                let updatedSize = ScrollViewportMath.contentSize(viewportHeight: container.height, zoom: updatedZoom, aspectRatio: archive.aspectRatio)
                if !isEditingPath, let heroPosition {
                    camera.resize(content: updatedSize, container: container, target: heroPosition)
                    publishCamera()
                    return
                }
                position.scrollTo(point: boundedOffset(
                    CGPoint(x: pinch.normalizedPoint.x * updatedSize.width - pinch.localPoint.x,
                            y: pinch.normalizedPoint.y * updatedSize.height - pinch.localPoint.y),
                    contentSize: updatedSize, container: container
                ))
            }
            .onEnded { _ in
                pinch = nil
                if isEditingPath { lastPathInteraction = .now }
            }
    }

    private func changeZoom(to value: CGFloat, container: CGSize) {
        let center = heroPosition ?? viewport.normalizedCenter
        zoom = value
        let size = ScrollViewportMath.contentSize(viewportHeight: container.height, zoom: value, aspectRatio: archive.aspectRatio)
        move(to: center, contentSize: size, container: container)
    }

    private func moveToBeginning(contentSize: CGSize, container: CGSize) {
        if let heroPosition {
            move(to: heroPosition, contentSize: contentSize, container: container)
            return
        }
        position.scrollTo(point: boundedOffset(CGPoint(x: startX * contentSize.width - container.width, y: 0), contentSize: contentSize, container: container))
    }

    private func move(to normalizedPoint: CGPoint, contentSize: CGSize, container: CGSize) {
        if heroPosition != nil && !isEditingPath {
            camera.resize(content: contentSize, container: container, target: normalizedPoint)
            publishCamera()
            return
        }
        position.scrollTo(point: boundedOffset(
            CGPoint(x: normalizedPoint.x * contentSize.width - container.width / 2,
                    y: normalizedPoint.y * contentSize.height - container.height / 2),
            contentSize: contentSize, container: container
        ))
    }

    private func pan(by amount: CGSize, contentSize: CGSize, container: CGSize) {
        guard heroPosition == nil || isEditingPath else { return }
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

    private func publishCamera() {
        let next = ScrollViewportGeometry(offset: camera.offset, content: camera.content, container: camera.container)
        guard viewport != next else { return }
        viewport = next
        onViewportChange(next.visibleRange)
    }

    private func tap(at point: CGPoint, contentSize: CGSize) {
        let normalized = ScrollViewportMath.normalizedPoint(local: point, offset: viewport.offset, contentSize: contentSize)
        guard (0...1).contains(normalized.x), (0...1).contains(normalized.y) else { return }
        if isEditingPath {
            onPathPointAdd?(normalized)
        } else {
            onTap(Double(normalized.x), Double(normalized.y))
        }
    }

    private func pathHandle(_ point: AdventurePathPoint, contentSize: CGSize, container: CGSize) -> some View {
        let local = ScrollViewportMath.localPoint(normalized: CGPoint(x: point.x, y: point.y), offset: viewport.offset, contentSize: contentSize)
        let visible = CGRect(origin: .zero, size: container).insetBy(dx: -22, dy: -22).contains(local)
        return Button {
            selectedPathPoint = point.id
            lastPathInteraction = .now
        } label: {
            Circle().fill(Color.yellow)
                .frame(width: 16, height: 16)
                .overlay { Circle().strokeBorder(selectedPathPoint == point.id ? Color.red : SeekerStyle.ink, lineWidth: selectedPathPoint == point.id ? 3 : 1.5) }
                .shadow(color: .black.opacity(0.25), radius: 2)
                .frame(width: 44, height: 44).contentShape(Circle())
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(ScrollCanvasSpace.viewport))
                .onChanged { value in
                    guard pinch == nil else { return }
                    lastPathInteraction = .now
                    selectedPathPoint = point.id
                    if pathDrag?.id != point.id {
                        pathDrag = ScrollPathDrag(id: point.id, start: CGPoint(x: point.x, y: point.y))
                    }
                    guard let drag = pathDrag, hypot(value.translation.width, value.translation.height) > 0.5 else { return }
                    let origin = ScrollViewportMath.localPoint(normalized: drag.start, offset: viewport.offset, contentSize: contentSize)
                    let updated = ScrollViewportMath.normalizedPoint(
                        local: CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height),
                        offset: viewport.offset, contentSize: contentSize
                    )
                    onPathPointMove?(point.id, clampedPathPoint(updated))
                }
                .onEnded { _ in
                    lastPathInteraction = .now
                    pathDrag = nil
                }
                .simultaneously(with:
                    LongPressGesture(minimumDuration: 0.7, maximumDistance: 8)
                        .onEnded { _ in deletePathPoint(point.id) }
                )
        )
        .position(local)
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
        .accessibilityLabel("Path control point")
        .accessibilityValue("x \(point.x, specifier: "%.3f"), y \(point.y, specifier: "%.3f")")
        .accessibilityHint("Drag to move, or hold to delete. Direction actions are also available.")
        .accessibilityAction(named: Text("Move left")) { nudgePathPoint(point, dx: -0.001, dy: 0) }
        .accessibilityAction(named: Text("Move right")) { nudgePathPoint(point, dx: 0.001, dy: 0) }
        .accessibilityAction(named: Text("Move up")) { nudgePathPoint(point, dx: 0, dy: -0.01) }
        .accessibilityAction(named: Text("Move down")) { nudgePathPoint(point, dx: 0, dy: 0.01) }
        .accessibilityAction(named: Text("Delete path point")) { deletePathPoint(point.id) }
    }

    private func clampedPathPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(1, max(0, point.x)), y: min(1, max(0, point.y)))
    }

    private func nudgePathPoint(_ point: AdventurePathPoint, dx: Double, dy: Double) {
        selectedPathPoint = point.id
        lastPathInteraction = .now
        onPathPointMove?(point.id, clampedPathPoint(CGPoint(x: point.x + dx, y: point.y + dy)))
    }

    private func deletePathPoint(_ id: UUID) {
        lastPathInteraction = .now
        pathDrag = nil
        selectedPathPoint = nil
        guard pathPoints.count > 2 else { return }
        onPathPointDelete?(id)
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

private enum ScrollCanvasSpace: Hashable { case viewport }

private struct ScrollPathDrag {
    var id: UUID
    var start: CGPoint
}

private struct ScrollPathDrawing: View {
    var points: [AdventurePathPoint]
    var contentSize: CGSize
    var offset: CGPoint

    var body: some View {
        Canvas { context, size in
            guard points.count >= 2, contentSize.width > 0,
                  let minX = points.last?.x, let maxX = points.first?.x else { return }
            let left = max(minX, Double(offset.x / contentSize.width))
            let right = min(maxX, Double((offset.x + size.width) / contentSize.width))
            guard left <= right else { return }
            let steps = max(1, Int(ceil(size.width / 4)))
            var path = Path()
            for step in 0...steps {
                let x = left + (right - left) * Double(step) / Double(steps)
                guard let normalized = AdventureWalkPath.interpolate(points: points, atX: x) else { continue }
                let pixel = ScrollViewportMath.localPoint(normalized: normalized, offset: offset, contentSize: contentSize)
                if step == 0 { path.move(to: pixel) } else { path.addLine(to: pixel) }
            }
            context.stroke(path, with: .color(Color.white.opacity(0.8)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }
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

private struct ScrollWalkHint: View {
    var body: some View {
        VStack(spacing: 3) {
            Text("按住左邊走路").font(SeekerStyle.brush(18))
            Text("Hold left to walk").font(.system(.caption, design: .serif))
        }
        .foregroundStyle(SeekerStyle.indigo)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 260)
    }
}

/// All animated artwork is drawn into the small viewport, never into a layer
/// the width of the whole scroll. The saturation layer redraws only the original
/// raster pixels, preserving every contour and world coordinate.
private struct ScrollLivingOverlay: View {
    var contentSize: CGSize
    var offset: CGPoint
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
        WorldTileStore.shared.draw(in: &context, contentSize: contentSize, offset: offset, viewportSize: size)
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
        let localTime = time.truncatingRemainder(dividingBy: 1000)

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
            let inscription = target.seal ?? "印"
            context.draw(Text(inscription).font(.system(size: inscription.count > 1 ? 10 : 16, weight: .medium, design: .serif)).foregroundStyle(Color(red: 0.98, green: 0.93, blue: 0.77)), at: CGPoint(x: stampRect.midX, y: stampRect.midY))
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
