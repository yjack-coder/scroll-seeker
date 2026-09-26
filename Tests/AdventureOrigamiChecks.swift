import Foundation

@main
struct AdventureOrigamiChecks {
  @MainActor static func main() {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      checks += 1
      guard condition() else { fatalError(message) }
    }
    for landscape in [false, true] {
      let paper = AdventureOrigamiState()
      paper.configureOrientation(isLandscape: landscape)
      paper.configureOrientation(isLandscape: !landscape)
      check(paper.startingLandscape == landscape, "Starting orientation is stable")
      paper.simulateRotation()
      check(paper.phase == .firstFold, "Rotation cannot skip first fold")
      paper.postureChanged(.tent)
      check(paper.folds == 0, "Tent is not a paper fold")
      paper.postureChanged(.book)
      check(paper.phase == .firstOpen && paper.folds == 1, "First crease requires Book")
      paper.postureChanged(.book)
      check(paper.folds == 1, "Duplicate Book does not fold again")
      paper.postureChanged(.open)
      check(paper.phase == .rotate, "Opening starts the rotation step")
      paper.postureChanged(.book)
      check(paper.phase == .rotate && paper.folds == 1, "Missing rotation cannot be skipped")
      paper.postureChanged(.open)
      paper.orientationChanged(isLandscape: !landscape)
      check(paper.phase == .secondFold, "Quarter turn enables second crease")
      paper.postureChanged(.book)
      check(paper.phase == .secondOpen && paper.folds == 2, "Second Book fold")
      paper.postureChanged(.open)
      check(paper.phase == .rotateBack, "Open before turning back")
      paper.orientationChanged(isLandscape: landscape)
      check(paper.phase == .cornerFold, "Turn back enables corners")
      paper.postureChanged(.book)
      check(paper.phase == .launch && paper.folds == 3, "Three folds make the boat")
      paper.postureChanged(.laptop)
      check(paper.phase == .launch, "Only full opening launches")
      paper.postureChanged(.open)
      check(paper.phase == .complete, "Opening launches the boat")
      for pose in AdventurePosture.allCases { paper.postureChanged(pose) }
      check(paper.phase == .complete && paper.folds == 3, "Completion remains idempotent")
    }
    let earlyTurn = AdventureOrigamiState()
    earlyTurn.configureOrientation(isLandscape: false)
    earlyTurn.orientationChanged(isLandscape: true)
    earlyTurn.postureChanged(.book)
    earlyTurn.postureChanged(.open)
    earlyTurn.simulateRotation()
    check(earlyTurn.phase == .secondFold, "Fallback handles an early physical rotation")
    earlyTurn.postureChanged(.book)
    earlyTurn.postureChanged(.open)
    earlyTurn.simulateRotation()
    check(earlyTurn.phase == .cornerFold, "Second rotation fallback")
    earlyTurn.postureChanged(.book)
    earlyTurn.postureChanged(.open)
    check(earlyTurn.phase == .complete, "All fallback controls can complete the boat")
    let rotatedCrease = AdventureOrigamiState()
    rotatedCrease.configureOrientation(isLandscape: false)
    rotatedCrease.postureChanged(.book)
    rotatedCrease.postureChanged(.open)
    rotatedCrease.simulateRotation()
    rotatedCrease.postureChanged(.laptop)
    check(rotatedCrease.phase == .secondOpen, "A horizontal physical crease is a valid second fold")
    rotatedCrease.postureChanged(.open)
    rotatedCrease.simulateRotation()
    rotatedCrease.postureChanged(.book)
    rotatedCrease.postureChanged(.open)
    check(rotatedCrease.phase == .complete, "Rotated physical-crease sequence completes")
    print("Passed \(checks) origami sequence checks")
  }
}
