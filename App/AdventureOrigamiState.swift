import Foundation
import Observation

/// The paper boat is made by three distinct folds, separated by opening and
/// rotation. Repeated hinge samples cannot skip a step or earn another reward.
@MainActor
@Observable
final class AdventureOrigamiState {
  private(set) var phase: AdventureOrigamiPhase = .firstFold
  private(set) var folds = 0
  private(set) var startingLandscape = false
  private(set) var isLandscape = false
  private var configured = false
  private var lastPosture: AdventurePosture = .open

  func configureOrientation(isLandscape: Bool) {
    guard !configured else { return }
    configured = true
    startingLandscape = isLandscape
    self.isLandscape = isLandscape
  }

  func orientationChanged(isLandscape: Bool) {
    guard self.isLandscape != isLandscape else { return }
    self.isLandscape = isLandscape
    if phase == .rotate, isLandscape != startingLandscape { phase = .secondFold }
    else if phase == .rotateBack, isLandscape == startingLandscape { phase = .cornerFold }
  }

  func simulateRotation() {
    guard phase == .rotate || phase == .rotateBack else { return }
    // The explicit fallback also works if the player turned early, before the
    // rotate prompt became active. It records one intentional step, never two.
    if phase == .rotate {
      isLandscape = !startingLandscape
      phase = .secondFold
    } else {
      isLandscape = startingLandscape
      phase = .cornerFold
    }
  }

  func postureChanged(_ posture: AdventurePosture) {
    guard posture != lastPosture else { return }
    lastPosture = posture
    switch (phase, posture) {
    case (.firstFold, .book), (.firstFold, .laptop): folds = 1; phase = .firstOpen
    case (.firstOpen, .open): phase = .rotate
    case (.secondFold, .book), (.secondFold, .laptop): folds = 2; phase = .secondOpen
    case (.secondOpen, .open): phase = .rotateBack
    case (.cornerFold, .book), (.cornerFold, .laptop): folds = 3; phase = .launch
    case (.launch, .open): phase = .complete
    default: break
    }
  }
}

enum AdventureOrigamiPhase: String, Equatable {
  case firstFold, firstOpen, rotate, secondFold, secondOpen, rotateBack, cornerFold, launch, complete

  var foldNumber: Int {
    switch self {
    case .firstFold, .firstOpen: 1
    case .rotate, .secondFold, .secondOpen: 2
    case .rotateBack, .cornerFold: 3
    case .launch, .complete: 4
    }
  }

  var instructionsChinese: LocalizedStringResource {
    switch self {
    case .firstFold: "第一摺 · 對摺成半"
    case .firstOpen: "展開，留下一道摺痕"
    case .rotate: "轉動手機九十度"
    case .secondFold: "第二摺 · 沿新摺線對摺"
    case .secondOpen: "再展開，讓紙記住方向"
    case .rotateBack: "轉回原來的方向"
    case .cornerFold: "第三摺 · 收起船角"
    case .launch: "全部展開，送紙船入水"
    case .complete: "小小紙船，載著新的歡喜"
    }
  }

  var instructionsEnglish: LocalizedStringResource {
    switch self {
    case .firstFold: "Half-fold into Book posture. The hinge is your crease."
    case .firstOpen: "Open fully to reveal the first crease."
    case .rotate: "Rotate portrait to landscape, or landscape to portrait."
    case .secondFold: "Half-fold again along the new crease."
    case .secondOpen: "Open fully before turning the paper back."
    case .rotateBack: "Rotate back to the starting orientation."
    case .cornerFold: "Half-fold once more to bring the corners together."
    case .launch: "Open fully. A little boat is ready for the stream."
    case .complete: "The child cheers as the paper boat finds its way."
    }
  }
}
