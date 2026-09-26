import SwiftUI
import UIKit

/// A crease is an action, not a timer: only distinct fold, open and rotation
/// events advance the paper. Every physical action also has a native button.
struct AdventureOrigamiChallenge: View {
    var posture: AdventurePostureStore
    var onSuccess: () -> Void
    @State private var state = AdventureOrigamiState()
    @State private var boatProgress: CGFloat = 0
    @State private var launchProgress: CGFloat = 0
    @State private var delivered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 14) {
                OrigamiInstructionHeader(phase: state.phase, folds: state.folds)
                OrigamiPaperStage(folds: state.folds, folding: folding, isLandscape: state.isLandscape,
                                  counterRotation: state.isLandscape == state.startingLandscape ? 0 : -90,
                                  boatProgress: boatProgress, launchProgress: launchProgress,
                                  isComplete: state.phase == .complete)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                OrigamiControls(isComplete: state.phase == .complete, rotating: rotating, folding: folding,
                                needsOpen: needsOpen, actionTitle: actionTitle, onAction: performFallback)
            }
            .padding(.horizontal, 22)
            // The mission's native Later control occupies the top-right edge.
            .padding(.top, 62).padding(.bottom, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                let orientation = UIDevice.current.orientation
                state.configureOrientation(isLandscape: orientation.isLandscape || (!orientation.isPortrait && geometry.size.width > geometry.size.height))
            }
        }
        .foregroundStyle(SeekerStyle.indigo)
        .background { SilkBackground().ignoresSafeArea() }
        .onDisappear { UIDevice.current.endGeneratingDeviceOrientationNotifications() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            // Opening a fold changes the window's aspect ratio. It is not a
            // rotation, so geometry is used only for the initial fallback.
            guard orientation.isPortrait || orientation.isLandscape else { return }
            withAnimation(paperAnimation) { state.orientationChanged(isLandscape: orientation.isLandscape) }
        }
        .onChange(of: posture.current) { _, pose in
            withAnimation(paperAnimation) { state.postureChanged(pose) }
        }
        .onChange(of: state.folds) { _, count in
            ScrollSound.shared.paperFold()
            if count == 3 {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.1)) { boatProgress = 1 }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.55), trigger: state.folds)
        .task(id: state.phase) {
            guard state.phase == .complete, !delivered else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 2.4)) { launchProgress = 1 }
            do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
            while scenePhase != .active {
                do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            }
            guard !Task.isCancelled, !delivered else { return }
            delivered = true
            onSuccess()
        }
    }

    private var paperAnimation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.75) }
    private var folding: Bool { [.firstOpen, .secondOpen, .launch].contains(state.phase) }
    private var rotating: Bool { state.phase == .rotate || state.phase == .rotateBack }

    private var needsOpen: Bool {
        let partial = posture.current == .book || posture.current == .laptop
        return folding || ((state.phase == .firstFold || state.phase == .secondFold || state.phase == .cornerFold) && partial)
    }

    private var actionTitle: String {
        if rotating { return state.phase == .rotate ? "轉動九十度 · Rotate 90°" : "轉回來 · Rotate back" }
        if needsOpen { return folding ? "展開 · Unfold" : "先展開 · Open first" }
        return "半摺 · Fold"
    }

    private func performFallback() {
        if rotating {
            withAnimation(paperAnimation) { state.simulateRotation() }
        } else {
            posture.set(needsOpen ? .open : .book)
        }
    }
}

private struct OrigamiInstructionHeader: View {
    var phase: AdventureOrigamiPhase
    var folds: Int

    var body: some View {
        VStack(spacing: 7) {
            Text("一紙小舟 · A LITTLE PAPER BOAT")
                .font(.system(.caption, design: .serif)).tracking(1.8).foregroundStyle(SeekerStyle.gold)
            Text(phase.instructionsChinese)
                .font(SeekerStyle.brush(27)).multilineTextAlignment(.center)
            Text(phase.instructionsEnglish)
                .font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { number in
                    Text(number <= folds ? "摺" : "\(number)")
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .frame(width: 26, height: 26)
                        .foregroundStyle(number <= folds ? SeekerStyle.paper : SeekerStyle.gold)
                        .background(number <= folds ? SeekerStyle.red : SeekerStyle.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(folds) of three paper folds made")
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }
}

private struct OrigamiPaperStage: View {
    var folds: Int
    var folding: Bool
    var isLandscape: Bool
    var counterRotation: Double
    var boatProgress: CGFloat
    var launchProgress: CGFloat
    var isComplete: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let crease = physicalCrease(in: geometry)
            let side = max(70, min(geometry.size.width - 34, geometry.size.height - 30))
            let paperCenter = crease.horizontal
                ? CGPoint(x: geometry.size.width / 2, y: crease.center.y)
                : CGPoint(x: crease.center.x, y: geometry.size.height / 2)
            ZStack {
                OrigamiStream()
                    .opacity(isComplete ? 1 : 0)
                OrigamiPaperSheet(
                    folds: folds,
                    folded: folding && !reduceMotion,
                    horizontal: crease.horizontal,
                    counterRotation: counterRotation
                )
                .frame(width: side, height: side)
                .opacity(1 - boatProgress)
                .position(paperCenter)

                OrigamiBoatShape(progress: boatProgress)
                    .fill(LinearGradient(colors: [SeekerStyle.paper, Color(red: 0.83, green: 0.77, blue: 0.59)], startPoint: .top, endPoint: .bottom))
                    .overlay { OrigamiBoatShape(progress: boatProgress).stroke(SeekerStyle.gold.opacity(0.8), lineWidth: 1) }
                    .overlay {
                        OrigamiBoatSeams().stroke(SeekerStyle.gold.opacity(0.65), lineWidth: 1)
                            .opacity(boatProgress)
                    }
                    .frame(width: side, height: side)
                    .scaleEffect(1 - launchProgress * 0.32)
                    .opacity(boatProgress)
                    .shadow(color: SeekerStyle.ink.opacity(0.12), radius: 12, y: 8)
                    .position(x: paperCenter.x - (reduceMotion ? 0 : launchProgress * side * 0.3),
                              y: paperCenter.y + (reduceMotion ? 0 : launchProgress * side * 0.05))

                if folds < 3 {
                    Canvas { context, size in
                        var path = Path()
                        if crease.horizontal {
                            path.move(to: CGPoint(x: max(0, paperCenter.x - side / 2 - 12), y: crease.center.y))
                            path.addLine(to: CGPoint(x: min(size.width, paperCenter.x + side / 2 + 12), y: crease.center.y))
                        } else {
                            path.move(to: CGPoint(x: crease.center.x, y: max(0, paperCenter.y - side / 2 - 12)))
                            path.addLine(to: CGPoint(x: crease.center.x, y: min(size.height, paperCenter.y + side / 2 + 12)))
                        }
                        context.stroke(path, with: .color(SeekerStyle.red.opacity(0.65)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
                    }
                    .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(folds == 3 ? "A small folded paper boat" : "A square of paper. The dashed red line follows the phone's physical crease.")
        }
    }

    private func physicalCrease(in geometry: GeometryProxy) -> OrigamiCrease {
        if #available(iOS 27.1, *), let region = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed).first {
            return OrigamiCrease(center: CGPoint(x: region.frame.midX, y: region.frame.midY), horizontal: region.frame.width > region.frame.height)
        }
        return OrigamiCrease(center: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2), horizontal: isLandscape)
    }
}

private struct OrigamiControls: View {
    var isComplete: Bool
    var rotating: Bool
    var folding: Bool
    var needsOpen: Bool
    var actionTitle: String
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if !isComplete {
                OrigamiPhoneDiagram(rotating: rotating, folded: folding)
                    .frame(width: 94, height: 46).accessibilityHidden(true)
                Button(action: onAction) {
                    Label(actionTitle, systemImage: rotating ? "rectangle.portrait.rotate" : needsOpen ? "arrow.up.left.and.arrow.down.right" : "book.closed")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SeekerActionStyle())
                Text("也可用下方按鈕 · Physical gestures and buttons do the same thing.")
                    .font(.system(.caption2, design: .serif)).multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text("順水去吧 · Let the stream carry it")
                    .font(.system(.headline, design: .serif)).padding(.vertical, 18)
            }
        }
        .frame(maxWidth: 400)
    }

}

private struct OrigamiCrease {
    var center: CGPoint
    var horizontal: Bool
}

private struct OrigamiPaperSheet: View {
    var folds: Int
    var folded: Bool
    var horizontal: Bool
    var counterRotation: Double

    var body: some View {
        ZStack {
            OrigamiPaperFace(folds: folds).rotationEffect(.degrees(counterRotation))
                .mask(OrigamiHalf(horizontal: horizontal, farSide: false))
            OrigamiPaperFace(folds: folds).rotationEffect(.degrees(counterRotation))
                .overlay(SeekerStyle.ink.opacity(folded ? 0.08 : 0))
                .mask(OrigamiHalf(horizontal: horizontal, farSide: true))
                .rotation3DEffect(.degrees(folded ? (horizontal ? 153 : -153) : 0),
                                  axis: (x: horizontal ? 1 : 0, y: horizontal ? 0 : 1, z: 0),
                                  anchor: .center, perspective: 0.5)
        }
        .shadow(color: SeekerStyle.ink.opacity(0.12), radius: 12, y: 8)
    }
}

private struct OrigamiPaperFace: View {
    var folds: Int
    var body: some View {
        GeometryReader { geometry in
            Rectangle().fill(LinearGradient(colors: [Color(red: 1, green: 0.985, blue: 0.91), SeekerStyle.paper], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { Rectangle().stroke(SeekerStyle.gold.opacity(0.45), lineWidth: 1) }
            Canvas { context, size in
                for strand in 0..<52 {
                    let y = CGFloat(strand) / 52 * size.height
                    var fiber = Path()
                    fiber.move(to: CGPoint(x: CGFloat(strand % 7) * 3, y: y))
                    fiber.addLine(to: CGPoint(x: size.width - CGFloat(strand % 5) * 4, y: y + CGFloat(strand % 3 - 1) * 2))
                    context.stroke(fiber, with: .color(SeekerStyle.gold.opacity(0.035)), lineWidth: 0.5)
                }
                var creases = Path()
                if folds >= 1 {
                    creases.move(to: CGPoint(x: size.width / 2, y: 0))
                    creases.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                }
                if folds >= 2 {
                    creases.move(to: CGPoint(x: 0, y: size.height / 2))
                    creases.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                }
                context.stroke(creases, with: .color(SeekerStyle.gold.opacity(0.42)), lineWidth: 1)
            }
            Text("安").font(SeekerStyle.brush(20)).foregroundStyle(SeekerStyle.red.opacity(0.8))
                .padding(4).overlay { Rectangle().stroke(SeekerStyle.red.opacity(0.6), lineWidth: 1) }
                .position(x: geometry.size.width * 0.77, y: geometry.size.height * 0.8)
        }
    }
}

private struct OrigamiHalf: Shape {
    var horizontal: Bool
    var farSide: Bool
    func path(in rect: CGRect) -> Path {
        Path(horizontal
             ? CGRect(x: rect.minX, y: farSide ? rect.midY : rect.minY, width: rect.width, height: rect.height / 2)
             : CGRect(x: farSide ? rect.midX : rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
    }
}

private struct OrigamiBoatShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func path(in rect: CGRect) -> Path {
        let square: [CGPoint] = [.init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 0.5), .init(x: 1, y: 1), .init(x: 0.5, y: 1), .init(x: 0, y: 1), .init(x: 0, y: 0.5)]
        let boat: [CGPoint] = [.init(x: 0.06, y: 0.58), .init(x: 0.28, y: 0.58), .init(x: 0.5, y: 0.2), .init(x: 0.73, y: 0.58), .init(x: 0.94, y: 0.58), .init(x: 0.78, y: 0.83), .init(x: 0.22, y: 0.83), .init(x: 0.06, y: 0.58)]
        var path = Path()
        for index in square.indices {
            let point = CGPoint(x: rect.minX + (square[index].x + (boat[index].x - square[index].x) * progress) * rect.width,
                                y: rect.minY + (square[index].y + (boat[index].y - square[index].y) * progress) * rect.height)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

private struct OrigamiBoatSeams: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.06, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.width * 0.94, y: rect.height * 0.58))
        path.move(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.83))
        path.move(to: CGPoint(x: rect.width * 0.22, y: rect.height * 0.83))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.58))
        path.addLine(to: CGPoint(x: rect.width * 0.78, y: rect.height * 0.83))
        return path
    }
}

private struct OrigamiStream: View {
    var body: some View {
        Canvas { context, size in
            for line in 0..<9 {
                let y = size.height * 0.60 + CGFloat(line) * size.height * 0.027
                var ripple = Path()
                ripple.move(to: CGPoint(x: 0, y: y))
                ripple.addCurve(to: CGPoint(x: size.width, y: y + 2), control1: CGPoint(x: size.width * 0.3, y: y - 12), control2: CGPoint(x: size.width * 0.7, y: y + 12))
                context.stroke(ripple, with: .color(SeekerStyle.indigo.opacity(0.12 + Double(line % 3) * 0.025)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct OrigamiPhoneDiagram: View {
    var rotating: Bool
    var folded: Bool
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 5).stroke(SeekerStyle.gold, lineWidth: 1.5)
                .frame(width: 25, height: 38)
                .overlay { Rectangle().fill(SeekerStyle.gold.opacity(0.6)).frame(width: 1, height: 31) }
                .rotation3DEffect(.degrees(folded ? 42 : 0), axis: (x: 0, y: 1, z: 0))
            Image(systemName: rotating ? "rectangle.portrait.rotate" : "arrow.left.and.right")
                .font(.system(size: 23, weight: .light)).foregroundStyle(SeekerStyle.gold)
        }
    }
}
