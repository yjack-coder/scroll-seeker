import SwiftUI

/// The upper display carries the scene; the lower display is a touch control
/// pad. The physical horizontal division is used when the SDK reports one.
struct AdventureLaptopLayout<Scene: View, Controls: View>: View {
    var scene: Scene
    var controls: Controls

    init(@ViewBuilder scene: () -> Scene, @ViewBuilder controls: () -> Controls) {
        self.scene = scene()
        self.controls = controls()
    }

    var body: some View {
        GeometryReader { geometry in
            let division = split(in: geometry)
            VStack(spacing: 0) {
                ScrollView {
                    scene.padding(.horizontal, 22).padding(.top, 58).padding(.bottom, 18)
                        .frame(maxWidth: 700).frame(maxWidth: .infinity)
                }
                .frame(height: division)
                Rectangle().fill(SeekerStyle.gold.opacity(0.6)).frame(height: 1)
                ScrollView {
                    VStack(spacing: 17) {
                        Text("書案 · THE CONTROL DESK")
                            .font(.system(.caption2, design: .serif)).tracking(2)
                            .foregroundStyle(SeekerStyle.gold)
                        controls
                    }
                    .padding(22).frame(maxWidth: 700).frame(maxWidth: .infinity)
                }
                .frame(height: max(0, geometry.size.height - division - 1))
                .background(SeekerStyle.gold.opacity(0.085))
            }
        }
    }

    private func split(in geometry: GeometryProxy) -> CGFloat {
        let fallback = geometry.size.height / 2
        if #available(iOS 27.1, *),
           let region = geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
            .first(where: { $0.frame.width > $0.frame.height }) {
            return min(geometry.size.height * 0.75, max(geometry.size.height * 0.25, region.frame.midY))
        }
        return fallback
    }
}
