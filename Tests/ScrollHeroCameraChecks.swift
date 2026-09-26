import Foundation
import CoreGraphics

@main struct ScrollHeroCameraChecks {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            checks += 1
        }
        var camera = ScrollHeroCamera()
        let data = try! Data(contentsOf: URL(fileURLWithPath: "App/Resources/World/world.json"))
        let world = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let size = world["size"] as! [Double]
        let places = world["places"] as! [String: [String: Any]]
        let homePlace = places["home"]!
        let container = CGSize(width: 951, height: 669)
        let content = CGSize(width: 669 * size[0] / size[1], height: 669)
        let home = CGPoint(x: homePlace["x"] as! Double, y: homePlace["y"] as! Double)
        camera.resize(content: content, container: container, target: home)
        for cycle in 0..<5 {
            camera.beginOpening(atHome: cycle == 0, reduceMotion: false)
            var previousX = camera.offset.x
            for frame in 0..<80 {
                if frame == 30 {
                    let elapsed = camera.openingElapsed
                    camera.resize(content: CGSize(width: 400 * size[0] / size[1], height: 400),
                                  container: CGSize(width: 640, height: 400), target: home)
                    check(camera.openingStart != nil, "Late Duo layout keeps opening alive")
                    check(camera.openingElapsed == elapsed, "Late Duo layout preserves reveal phase")
                    let start = camera.openingStart!
                    let t = elapsed / 1.2
                    let expectedX = start.x + (camera.centeredOffset.x - start.x) * t * t * (3 - 2 * t)
                    check(abs(camera.offset.x - expectedX) < 0.0001, "Resized camera uses new endpoints at existing phase")
                    previousX = camera.offset.x
                }
                camera.tick(delta: 1.0 / 60, reduceMotion: false)
                check(camera.offset.x <= previousX + 0.001, "Unroll glides continuously left")
                check(camera.offset.x.isFinite && camera.offset.x >= 0, "No blank negative offset")
                previousX = camera.offset.x
            }
            check(abs(camera.offset.x - camera.centeredOffset.x) < 0.01, "Every unroll ends at Xiao An")
            camera.resize(content: content, container: container, target: home)
        }
        for step in 0..<1800 {
            camera.target.x = home.x - Double(step) * 0.00045
            camera.tick(delta: 1.0 / 60, reduceMotion: false)
            let localX = camera.target.x * content.width - camera.offset.x
            check(localX > 120 && localX < container.width - 120, "Hero stays in view during entire journey")
            check(camera.offset.x >= 0 && camera.offset.x <= content.width - container.width, "No canvas gaps")
        }
        let resizeTarget = camera.target
        camera.resize(content: CGSize(width: 400 * size[0] / size[1], height: 400),
                      container: CGSize(width: 640, height: 400), target: resizeTarget)
        check(camera.target == resizeTarget, "Resize preserves hero world position")
        check(camera.offset == camera.centeredOffset, "Resize anchors to hero, never stale viewport")
        camera.beginOpening(atHome: false, reduceMotion: true)
        check(camera.openingStart == nil && camera.offset == camera.centeredOffset, "Reduce Motion skips glide")
        print("\(checks) hero camera checks passed")
    }
}
