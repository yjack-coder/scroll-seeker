import Foundation

@main
struct AdventureHeroMotionChecks {
  static func main() {
    var checks = 0
    func check(_ condition: @autoclosure () -> Bool, _ message: String) {
      checks += 1
      guard condition() else { fatalError(message) }
    }
    let rate = AdventureHeroMotion.stepsPerSecond
    check(rate == 2.2, "The hero takes 2.2 steps per second")
    let landing = AdventureHeroMotion.sample(time: 0, walking: true, reduceMotion: false)
    let firstHop = AdventureHeroMotion.sample(time: 0.5 / rate, walking: true, reduceMotion: false)
    let secondHop = AdventureHeroMotion.sample(time: 1.5 / rate, walking: true, reduceMotion: false)
    check(landing.lift == 0, "Landings stay on the road")
    check(abs(firstHop.lift - 0.05) < 0.0001, "Visible hop reaches five percent of height")
    check(abs(firstHop.tiltDegrees - 4) < 0.0001, "First foot tilts four degrees")
    check(abs(secondHop.tiltDegrees + 4) < 0.0001, "Next foot tilts the other way")
    check(landing.scaleY < 1 && landing.scaleX > 1, "Landing squashes the body")
    check(firstHop.scaleY > 1 && firstHop.scaleX < 1, "Takeoff stretches the body")
    check(firstHop.shadowScale < landing.shadowScale, "Shadow tightens during the hop")
    check(landing.drawsDust && firstHop.drawsDust, "Every moving step produces dust")

    for index in 0...1000 {
      let time = Double(index) / 60
      let gait = AdventureHeroMotion.sample(time: time, walking: true, reduceMotion: false)
      check((0...0.050001).contains(gait.lift), "Walking never sinks below the road")
      check((-4.00001...4.00001).contains(gait.tiltDegrees), "Tilt remains gentle")
      check((0.98...1.04).contains(gait.scaleX), "Horizontal motion remains bounded")
      check((0.95...1.03).contains(gait.scaleY), "Vertical motion remains bounded")
      check((0..<1).contains(gait.dustPhase), "Each step has one finite dust lifetime")
      let idle = AdventureHeroMotion.sample(time: time, walking: false, reduceMotion: false)
      check(idle.lift == 0 && !idle.drawsDust, "Idle feet stay rooted without dust")
      check((0.99...1.01).contains(idle.scaleX) && (0.97...1.02).contains(idle.scaleY), "Idle breathing is subtle")
      check(AdventureHeroMotion.sample(time: time, walking: true, reduceMotion: true) == AdventureHeroMotion(), "Reduce Motion freezes decorative movement")
    }
    let inhale = AdventureHeroMotion.sample(time: 0.9, walking: false, reduceMotion: false)
    let exhale = AdventureHeroMotion.sample(time: 2.7, walking: false, reduceMotion: false)
    check(abs(inhale.scaleY - 1.015) < 0.00001, "Breathing grows by 1.5 percent")
    check(abs(exhale.scaleY - 0.985) < 0.00001, "Breathing falls by 1.5 percent")
    let blink = AdventureHeroMotion.sample(time: 3.8, walking: false, reduceMotion: false)
    check(blink.tiltDegrees > 0.6, "A brief blink-like nod animates the idle face")
    check(AdventureHeroMotion.sample(time: .infinity, walking: true, reduceMotion: false) == AdventureHeroMotion(), "Invalid timestamps cannot corrupt geometry")
    check(AdventureHeroMotion.sample(time: -.infinity, walking: false, reduceMotion: false) == AdventureHeroMotion(), "Negative infinity is safe")
    print("Passed \(checks) hero-motion checks")
  }
}
