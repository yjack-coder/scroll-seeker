import SwiftUI

/// Hinge samples are reduced to discrete transitions. No gameplay reads angle.
struct AdventurePostureObserver: ViewModifier {
  var posture: AdventurePostureStore
  var hardwareDetected: () -> Void
  @State private var isPartlyOpen = false
  @State private var horizontalDivision = false

  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content
        .background {
          GeometryReader { geometry in
            let region = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed).first
            let horizontal = region.map { $0.frame.width > $0.frame.height } ?? false
            Color.clear.onChange(of: horizontal, initial: true) { _, value in
              horizontalDivision = value
              if isPartlyOpen { posture.set(value ? .laptop : .book) }
            }
          }.allowsHitTesting(false)
        }
        .onHingeChange { old, new in
          guard let hinge = new.hinge else { return }
          hardwareDetected()
          // Mounting a view (or a mission sheet) is not a fold action. Keeping
          // the initial sample passive also lets every app launch show Home.
          guard let previous = old.hinge, previous.status != hinge.status else { return }
          isPartlyOpen = hinge.status == .partiallyOpen
          if hinge.status == .closed { posture.set(.folded) }
          else if hinge.status == .fullyOpen { posture.set(.open) }
          else { posture.set(horizontalDivision ? .laptop : .book) }
        }
    } else { content }
  }
}

enum AdventureCrease {
  static func upperHeight(in geometry: GeometryProxy) -> CGFloat {
    if #available(iOS 27.1, *),
       let fold = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed).first,
       fold.frame.width > fold.frame.height {
      return max(150, min(geometry.size.height - 180, fold.frame.midY))
    }
    return geometry.size.height * 0.5
  }
}
