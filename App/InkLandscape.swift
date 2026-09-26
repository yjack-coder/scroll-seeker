import SwiftUI

/// A deterministic shan-shui composition. Everything is drawn in ink, including its texture.
/// `progress` is the wet-ink reveal; `time` is an optional, slow moving ambient clock.
struct InkLandscape: View, Animatable {
  var parameters: LandscapeParameters
  var seed: Int
  var progress: Double = 1
  var time: Double = 0

  var animatableData: Double {
    get { progress }
    set { progress = min(1, max(0, newValue)) }
  }

  var body: some View {
    ZStack {
      PaperTexture(seed: seed)
      Canvas { context, size in
        guard size.width > 0, size.height > 0 else { return }
        context.scaleBy(x: size.width / 1000, y: size.height / 680)
        let painter = ShanShuiPainter(
          parameters: parameters, seed: seed, progress: progress, time: time)
        painter.paint(in: context)
      }
    }
    .clipped()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Ink-wash landscape, with mountains, mist, quiet water, and a small \(figureDescription)")
  }

  private var figureDescription: String {
    switch parameters.pose {
    case .standing: "figure looking out from a cliff"
    case .sitting: "figure sitting beside the water"
    case .crossing: "figure crossing a bridge"
    case .rowing: "boat on the water"
    }
  }
}

/// Warm xuan paper with fine, irregular fibers. Its grain never changes between animation frames.
struct PaperTexture: View {
  var seed: Int = 41

  var body: some View {
    Canvas { context, size in
      let rect = CGRect(origin: .zero, size: size)
      context.fill(Path(rect), with: .color(Color(red: 0.958, green: 0.944, blue: 0.901)))
      context.fill(
        Path(rect),
        with: .linearGradient(
          Gradient(colors: [
            .white.opacity(0.25), Color(red: 0.78, green: 0.73, blue: 0.61).opacity(0.045),
          ]),
          startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
      var random = InkRandom(seed: seed &+ 151)
      let count = min(1700, max(300, Int(size.width * size.height / 160)))
      for _ in 0..<count {
        let x = random.next() * size.width
        let y = random.next() * size.height
        var fiber = Path()
        fiber.move(to: CGPoint(x: x, y: y))
        fiber.addLine(to: CGPoint(x: x + random.range(-1.4, 1.4), y: y + random.range(0.3, 3.8)))
        context.stroke(
          fiber,
          with: .color(
            Color(red: 0.35, green: 0.29, blue: 0.18).opacity(random.range(0.025, 0.07))),
          lineWidth: 0.35)
      }
    }
    .accessibilityHidden(true)
  }
}

private struct ShanShuiPainter {
  var parameters: LandscapeParameters
  var seed: Int
  var progress: Double
  var time: Double

  private var ink: Color { Color(red: 0.15, green: 0.19, blue: 0.18) }
  private var paper: Color { Color(red: 0.958, green: 0.944, blue: 0.901) }
  private var burden: Double { min(1, max(0, parameters.burden)) }
  private var flow: Double { min(1, max(0, parameters.flow)) }
  private var uncertainty: Double { min(1, max(0, parameters.uncertainty)) }

  func paint(in context: GraphicsContext) {
    drawLight(in: context)
    reveal(in: context, start: 0.015, duration: 0.30, softness: 16) { layer in
      drawMist(in: layer, foreground: false)
    }
    reveal(in: context, start: 0.10, duration: 0.34, softness: 11) { layer in
      drawMountain(in: layer, depth: 0)
    }
    reveal(in: context, start: 0.23, duration: 0.36, softness: 9) { layer in
      drawMountain(in: layer, depth: 1)
    }
    reveal(in: context, start: 0.36, duration: 0.33, softness: 7) { layer in
      drawMountain(in: layer, depth: 2)
    }
    reveal(in: context, start: 0.48, duration: 0.31, softness: 5) { layer in
      drawWater(in: layer)
      drawMist(in: layer, foreground: true)
    }
    reveal(in: context, start: 0.59, duration: 0.27, softness: 4) { layer in
      drawShore(in: layer)
      drawTrees(in: layer)
    }
    reveal(in: context, start: 0.75, duration: 0.24, softness: 3) { layer in
      drawFigure(in: layer)
      drawBirds(in: layer)
    }
  }

  private func reveal(
    in context: GraphicsContext, start: Double, duration: Double, softness: Double,
    drawing: (GraphicsContext) -> Void
  ) {
    let value = min(1, max(0, (progress - start) / duration))
    guard value > 0 else { return }
    let eased = value * value * (3 - 2 * value)
    var layer = context
    layer.opacity = eased
    if value < 0.995 {
      layer.addFilter(.blur(radius: (1 - eased) * softness))
      // The upper edge of a broad wet brush sweeps down the paper as pigment arrives.
      layer.clip(to: Path(CGRect(x: -30, y: -40, width: 1060, height: 780 * min(1, value * 1.65))))
    }
    drawing(layer)
  }

  private func drawLight(in context: GraphicsContext) {
    guard progress > 0 else { return }
    var layer = context
    layer.opacity = min(1, progress * 4)
    let color: Color
    switch parameters.light {
    case .dawn: color = Color(red: 0.73, green: 0.53, blue: 0.37)
    case .dusk: color = Color(red: 0.61, green: 0.39, blue: 0.27)
    case .moon: color = Color(red: 0.36, green: 0.43, blue: 0.52)
    case .day: color = Color(red: 0.64, green: 0.63, blue: 0.51)
    }
    layer.fill(
      Path(CGRect(x: 0, y: 0, width: 1000, height: 680)),
      with: .linearGradient(
        Gradient(colors: [color.opacity(parameters.light == .moon ? 0.075 : 0.045), .clear]),
        startPoint: .zero, endPoint: CGPoint(x: 0, y: 490)))
    if parameters.light != .day {
      let center = CGPoint(x: 590 + Double(seed % 8) * 5, y: 145)
      var glow = layer
      glow.addFilter(.blur(radius: 13))
      glow.fill(
        Path(ellipseIn: CGRect(x: center.x - 27, y: center.y - 27, width: 54, height: 54)),
        with: .color(color.opacity(0.07)))
      let disc = Path(ellipseIn: CGRect(x: center.x - 17, y: center.y - 17, width: 34, height: 34))
      layer.fill(
        disc, with: .color(parameters.light == .moon ? .white.opacity(0.58) : color.opacity(0.20)))
    }
  }

  private func drawMountain(in context: GraphicsContext, depth: Int) {
    let ridge = ridgePoints(depth: depth)
    let path = mountainPath(points: ridge, bottom: 635)
    let topAlpha = [0.17, 0.32, 0.64][depth] * (0.82 + burden * 0.30)
    let tint =
      parameters.light == .moon
      ? Color(red: 0.20, green: 0.27, blue: 0.31)
      : ink
    let top = ridge.map(\.y).min() ?? 100
    var bleed = context
    bleed.addFilter(.blur(radius: depth == 0 ? 3.4 : 1.15))
    bleed.fill(path, with: .color(tint.opacity(topAlpha * 0.10)))
    context.fill(
      path,
      with: .linearGradient(
        Gradient(stops: [
          .init(color: tint.opacity(topAlpha), location: 0),
          .init(color: tint.opacity(topAlpha * 0.64), location: 0.34),
          .init(color: tint.opacity(topAlpha * 0.19), location: 0.74),
          .init(color: tint.opacity(0), location: 1),
        ]), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 45, y: 567 + Double(depth) * 13)
      ))

    var clipped = context
    clipped.clip(to: path)
    var random = InkRandom(seed: seed &+ depth * 103 &+ 23)

    // Blur one composited wash rather than creating an offscreen surface for every mark.
    var washes = clipped
    washes.addFilter(.blur(radius: 15))
    washes.drawLayer { wash in
      for _ in 0..<(depth == 0 ? 22 : 36) {
        let x = random.range(-40, 1050)
        let ridgeY = height(at: x, ridge: ridge)
        let y = ridgeY + random.range(10, 150)
        let rect = CGRect(x: x, y: y, width: random.range(30, 105), height: random.range(35, 180))
        wash.fill(
          Path(ellipseIn: rect),
          with: .color(tint.opacity(random.range(0.008, 0.045) * Double(depth + 1))))
      }
    }

    guard depth > 0 else { return }
    // A discontinuous contour keeps the ridge drawn by a brush, never a vector outline.
    for index in stride(from: 1, to: ridge.count - 4, by: 5) {
      guard ridge[index].y < 495 else { continue }
      var contour = Path()
      contour.move(to: ridge[index])
      for offset in 1...3 { contour.addLine(to: ridge[index + offset]) }
      clipped.stroke(
        contour, with: .color(tint.opacity(depth == 2 ? 0.35 : 0.14)),
        style: StrokeStyle(lineWidth: random.range(0.7, 1.5), lineCap: .round))
    }

    // Broken, down-sloping cun strokes: the fine dry-brush structure of shan-shui rocks.
    for _ in 0..<(depth == 1 ? 175 : 340) {
      let x = random.range(-20, depth == 2 ? 680 : 1040)
      let ridgeY = height(at: x, ridge: ridge)
      let y = ridgeY + random.range(0, depth == 2 ? 175 : 105)
      guard y < 580 else { continue }
      let length = random.range(7, depth == 2 ? 84 : 49)
      var stroke = Path()
      stroke.move(to: CGPoint(x: x, y: y))
      var dx = x
      var dy = y
      for segment in 0..<5 {
        dx += random.range(-5, 2) + (x < 255 ? -1.2 : 1.3)
        dy += length / 5
        stroke.addLine(to: CGPoint(x: dx + sin(Double(segment) * 2.8 + x) * 1.6, y: dy))
      }
      let fading = max(0.05, (590 - y) / 400)
      clipped.stroke(
        stroke, with: .color(tint.opacity(random.range(0.045, 0.19) * fading)),
        lineWidth: random.range(0.4, 1.7))
    }
    var granules = [Path](repeating: Path(), count: 5)
    for _ in 0..<(depth == 2 ? 800 : 230) {
      let x = random.range(-10, 1030)
      let ridgeY = height(at: x, ridge: ridge)
      let y = ridgeY + random.range(3, 170)
      guard y < 530 else { continue }
      let width = random.range(0.35, 2.0)
      let rect = CGRect(x: x, y: y, width: width, height: width * random.range(0.4, 1.8))
      let bucket = min(4, Int(random.next() * 5))
      granules[bucket].addEllipse(in: rect)
    }
    for bucket in granules.indices {
      clipped.fill(granules[bucket], with: .color(tint.opacity(0.035 + Double(bucket) * 0.028)))
    }
    if parameters.season == .winter {
      var snow = Path()
      for (index, point) in ridge.enumerated() {
        let adjusted = CGPoint(x: point.x, y: point.y + 2.5)
        if index == 0 { snow.move(to: adjusted) } else { snow.addLine(to: adjusted) }
      }
      clipped.stroke(snow, with: .color(paper.opacity(0.70)), lineWidth: depth == 2 ? 4.5 : 2.6)
    }
  }

  private func ridgePoints(depth: Int) -> [CGPoint] {
    let phase = Double(seed % 97) * 0.23
    let elevation = 0.75 + burden * 0.42
    return (0...170).map { index in
      let x = -35 + Double(index) * 6.4
      let base: Double
      let height: Double
      switch depth {
      case 0:
        base = 464
        height =
          bell(x, center: 170, width: 99, height: 137)
          + bell(x, center: 342, width: 87, height: 205)
          + bell(x, center: 531, width: 100, height: 104)
          + bell(x, center: 886, width: 125, height: 94)
      case 1:
        base = 515
        height =
          bell(x, center: 68, width: 77, height: 170)
          + bell(x, center: 262, width: 81, height: 271)
          + bell(x, center: 419, width: 65, height: 173)
          + bell(x, center: 983, width: 101, height: 91)
      default:
        base = 589
        height =
          bell(x, center: -42, width: 98, height: 175)
          + bell(x, center: 143, width: 91, height: 234)
          + bell(x, center: 326, width: 66, height: 129)
          + bell(x, center: 1101, width: 93, height: 125)
      }
      let roughness = min(1, height / 80)
      let noise =
        (sin(x * 0.044 + phase + Double(depth)) * 8
          + sin(x * 0.081 + phase * 2.1) * 4.7
          + sin(x * 0.171 + phase * 0.7) * 2.1
          + sin(x * 0.387 + phase * 3) * 1.1) * roughness
      return CGPoint(x: x, y: base - height * elevation + noise)
    }
  }

  private func bell(_ x: Double, center: Double, width: Double, height: Double) -> Double {
    let distance = abs((x - center) / width)
    return exp(-pow(distance, 1.75)) * height
  }

  private func height(at x: Double, ridge: [CGPoint]) -> Double {
    let position = min(Double(ridge.count - 1), max(0, (x + 35) / 6.4))
    let lower = Int(position)
    let upper = min(ridge.count - 1, lower + 1)
    return ridge[lower].y + (ridge[upper].y - ridge[lower].y) * (position - Double(lower))
  }

  private func mountainPath(points: [CGPoint], bottom: Double) -> Path {
    var path = Path()
    guard let first = points.first, let last = points.last else { return path }
    path.move(to: first)
    for index in 1..<points.count {
      let previous = points[index - 1]
      let point = points[index]
      let midpoint = CGPoint(x: (previous.x + point.x) * 0.5, y: (previous.y + point.y) * 0.5)
      path.addQuadCurve(to: midpoint, control: previous)
    }
    path.addLine(to: last)
    path.addLine(to: CGPoint(x: last.x, y: bottom))
    path.addLine(to: CGPoint(x: first.x, y: bottom))
    path.closeSubpath()
    return path
  }

  private func drawMist(in context: GraphicsContext, foreground: Bool) {
    var layer = context
    layer.addFilter(.blur(radius: foreground ? 16 : 24))
    let drift = sin(time * 0.10) * (8 + uncertainty * 10)
    for index in 0..<(foreground ? 3 : 4) {
      let y = foreground ? 431 + Double(index) * 53 : 280 + Double(index) * 44
      let x = -100 + Double(index) * 103 + drift
      let width = foreground ? 1020.0 : 870.0
      let height = foreground ? 38 + uncertainty * 31 : 28 + uncertainty * 32
      let shape = Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height))
      layer.fill(
        shape, with: .color(paper.opacity((foreground ? 0.48 : 0.43) + uncertainty * 0.16)))
    }
  }

  private func drawWater(in context: GraphicsContext) {
    let waterColor = Color(red: 0.36, green: 0.45, blue: 0.46)
    let waterRect = CGRect(x: 0, y: 480, width: 1000, height: 195)
    context.fill(
      Path(waterRect),
      with: .linearGradient(
        Gradient(colors: [
          waterColor.opacity(0), waterColor.opacity(0.025 + flow * 0.023), waterColor.opacity(0),
        ]),
        startPoint: CGPoint(x: 0, y: 480), endPoint: CGPoint(x: 0, y: 675)))
    var random = InkRandom(seed: seed &+ 721)
    for index in 0..<56 {
      let y = random.range(497, 664)
      let center = random.range(370, 1030)
      let length = random.range(7, 107) * ((y - 455) / 200)
      let drift = sin(time * (0.12 + flow * 0.06) + Double(index) * 2.3) * (1 + flow * 3.5)
      var ripple = Path()
      ripple.move(to: CGPoint(x: center - length * 0.5 + drift, y: y))
      ripple.addQuadCurve(
        to: CGPoint(x: center + length * 0.5 + drift, y: y - 0.4),
        control: CGPoint(x: center, y: y - random.range(0.4, 1.9)))
      context.stroke(
        ripple, with: .color(ink.opacity(random.range(0.055, 0.18))),
        lineWidth: random.range(0.45, 0.85))
    }
    if flow > 0.62 {
      var waterfall = Path()
      waterfall.move(to: CGPoint(x: 337, y: 383))
      waterfall.addCurve(
        to: CGPoint(x: 362, y: 487), control1: CGPoint(x: 330, y: 420),
        control2: CGPoint(x: 372, y: 449))
      context.stroke(
        waterfall, with: .color(paper.opacity(0.73)),
        style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
      var edge = context
      edge.translateBy(x: 3, y: 0)
      edge.stroke(waterfall, with: .color(ink.opacity(0.11)), lineWidth: 0.7)
    }
    if parameters.season == .summer {
      var rain = context
      rain.opacity = 0.06
      for index in 0..<55 {
        let x = random.range(0, 580)
        let y = random.range(210, 515) + sin(time * 0.2 + Double(index)) * 5
        var stroke = Path()
        stroke.move(to: CGPoint(x: x, y: y))
        stroke.addLine(to: CGPoint(x: x - 2, y: y + random.range(9, 19)))
        rain.stroke(stroke, with: .color(ink), lineWidth: 0.55)
      }
    }
  }

  private func drawShore(in context: GraphicsContext) {
    var shore = Path()
    shore.move(to: CGPoint(x: -20, y: 592))
    shore.addCurve(
      to: CGPoint(x: 190, y: 551), control1: CGPoint(x: 51, y: 564),
      control2: CGPoint(x: 128, y: 572))
    shore.addCurve(
      to: CGPoint(x: 313, y: 561), control1: CGPoint(x: 234, y: 543),
      control2: CGPoint(x: 284, y: 546))
    shore.addCurve(
      to: CGPoint(x: 146, y: 604), control1: CGPoint(x: 286, y: 574),
      control2: CGPoint(x: 213, y: 581))
    shore.addCurve(
      to: CGPoint(x: -20, y: 649), control1: CGPoint(x: 63, y: 615),
      control2: CGPoint(x: 28, y: 633))
    shore.closeSubpath()
    context.fill(
      shore,
      with: .linearGradient(
        Gradient(colors: [ink.opacity(0.55), ink.opacity(0.04)]), startPoint: CGPoint(x: 0, y: 545),
        endPoint: CGPoint(x: 0, y: 639)))
    context.stroke(shore, with: .color(ink.opacity(0.20)), lineWidth: 0.8)
    var random = InkRandom(seed: seed &+ 654)
    for _ in 0..<30 {
      let x = random.range(8, 250)
      let y = 580 + sin(x * 0.035) * 8 + random.range(0, 13)
      var stroke = Path()
      stroke.move(to: CGPoint(x: x, y: y))
      stroke.addLine(to: CGPoint(x: x + random.range(4, 28), y: y - random.range(1, 4)))
      context.stroke(
        stroke, with: .color(ink.opacity(random.range(0.12, 0.29))),
        lineWidth: random.range(0.4, 1.2))
    }
  }

  private func drawTrees(in context: GraphicsContext) {
    pine(in: context, x: 108, y: 573, height: 103, seedOffset: 5, opacity: 0.91)
    pine(in: context, x: 153, y: 562, height: 76, seedOffset: 19, opacity: 0.80)
    pine(in: context, x: 70, y: 584, height: 60, seedOffset: 33, opacity: 0.63)
    pine(in: context, x: 252, y: 454, height: 33, seedOffset: 83, opacity: 0.36)
    pine(in: context, x: 273, y: 461, height: 24, seedOffset: 87, opacity: 0.30)
    if parameters.season == .spring || parameters.season == .autumn {
      var random = InkRandom(seed: seed &+ 912)
      let accent =
        parameters.season == .spring
        ? Color(red: 0.66, green: 0.37, blue: 0.37)
        : Color(red: 0.66, green: 0.36, blue: 0.19)
      for _ in 0..<66 {
        let x = random.range(70, 185)
        let y = random.range(478, 548)
        let radius = random.range(1.1, 2.8)
        context.fill(
          Path(ellipseIn: CGRect(x: x, y: y, width: radius * 1.4, height: radius)),
          with: .color(accent.opacity(random.range(0.10, 0.52))))
      }
    }
  }

  private func pine(
    in context: GraphicsContext, x: Double, y: Double, height: Double, seedOffset: Int,
    opacity: Double
  ) {
    var random = InkRandom(seed: seed &+ seedOffset)
    let lean = height * random.range(0.09, 0.18)
    var trunk = Path()
    trunk.move(to: CGPoint(x: x, y: y))
    trunk.addCurve(
      to: CGPoint(x: x + lean, y: y - height),
      control1: CGPoint(x: x - height * 0.07, y: y - height * 0.37),
      control2: CGPoint(x: x + height * 0.17, y: y - height * 0.70))
    context.stroke(
      trunk, with: .color(ink.opacity(opacity)),
      style: StrokeStyle(lineWidth: max(0.8, height * 0.029), lineCap: .round))
    for tier in 0..<5 {
      let fraction = 0.34 + Double(tier) * 0.13
      let start = CGPoint(x: x + lean * fraction, y: y - height * fraction)
      let side = tier % 2 == 0 ? -1.0 : 1.0
      let spread = height * (0.35 - Double(tier) * 0.041)
      let end = CGPoint(x: start.x + spread * side, y: start.y - height * 0.09)
      var branch = Path()
      branch.move(to: start)
      branch.addQuadCurve(
        to: end, control: CGPoint(x: start.x + spread * side * 0.8, y: start.y + height * 0.005))
      context.stroke(
        branch, with: .color(ink.opacity(opacity)), lineWidth: max(0.6, height * 0.016))
      for cluster in 0..<3 {
        let position = 0.35 + Double(cluster) * 0.27
        let centerX = start.x + (end.x - start.x) * position
        let centerY = start.y + (end.y - start.y) * position
        for _ in 0..<14 {
          let angle = random.range(-2.9, -0.2)
          let length = random.range(height * 0.035, height * 0.11)
          let origin = CGPoint(
            x: centerX + random.range(-height * 0.04, height * 0.04),
            y: centerY + random.range(-height * 0.022, height * 0.022))
          var needle = Path()
          needle.move(to: origin)
          needle.addLine(
            to: CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length))
          context.stroke(
            needle, with: .color(ink.opacity(opacity * random.range(0.5, 0.9))),
            style: StrokeStyle(lineWidth: max(0.45, height * 0.009), lineCap: .round))
        }
      }
    }
  }

  private func drawFigure(in context: GraphicsContext) {
    switch parameters.pose {
    case .rowing: drawBoat(in: context)
    case .standing: drawPerson(in: context, x: 274, y: 550, scale: 1.02, seated: false)
    case .sitting: drawPerson(in: context, x: 267, y: 557, scale: 0.95, seated: true)
    case .crossing:
      var bridge = Path()
      bridge.move(to: CGPoint(x: 279, y: 553))
      bridge.addQuadCurve(to: CGPoint(x: 422, y: 545), control: CGPoint(x: 347, y: 513))
      context.stroke(bridge, with: .color(ink.opacity(0.58)), lineWidth: 2)
      var lower = context
      lower.translateBy(x: 0, y: 5)
      lower.stroke(bridge, with: .color(ink.opacity(0.26)), lineWidth: 1)
      for index in 0..<9 {
        let position = Double(index) / 8
        let x = 279 + position * 143
        let y =
          pow(1 - position, 2) * 553 + 2 * (1 - position) * position * 513 + pow(position, 2) * 545
        var post = Path()
        post.move(to: CGPoint(x: x, y: y + 4))
        post.addLine(to: CGPoint(x: x, y: y - 5))
        context.stroke(post, with: .color(ink.opacity(0.50)), lineWidth: 0.9)
      }
      drawPerson(in: context, x: 350, y: 531, scale: 0.88, seated: false)
    }
  }

  private func drawBoat(in context: GraphicsContext) {
    let x = 621 + sin(time * 0.065) * 7
    let y = 572 + sin(time * 0.12) * 0.9
    var boat = Path()
    boat.move(to: CGPoint(x: x - 30, y: y - 2))
    boat.addQuadCurve(to: CGPoint(x: x + 30, y: y - 4), control: CGPoint(x: x + 3, y: y + 13))
    boat.addQuadCurve(to: CGPoint(x: x - 30, y: y - 2), control: CGPoint(x: x - 2, y: y + 4))
    context.fill(boat, with: .color(ink.opacity(0.80)))
    drawPerson(in: context, x: x + 5, y: y, scale: 0.90, seated: true)
    var oar = Path()
    oar.move(to: CGPoint(x: x + 6, y: y - 8))
    oar.addLine(to: CGPoint(x: x + 36, y: y + 10))
    context.stroke(
      oar, with: .color(ink.opacity(0.72)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    var reflection = Path()
    reflection.move(to: CGPoint(x: x - 22, y: y + 14))
    reflection.addQuadCurve(to: CGPoint(x: x + 22, y: y + 13), control: CGPoint(x: x, y: y + 11))
    context.stroke(reflection, with: .color(ink.opacity(0.17)), lineWidth: 0.65)
  }

  private func drawPerson(
    in context: GraphicsContext, x: Double, y: Double, scale: Double, seated: Bool
  ) {
    var layer = context
    layer.translateBy(x: x, y: y)
    layer.scaleBy(x: scale, y: scale)
    let headY = seated ? -14.0 : -22.0
    layer.fill(
      Path(ellipseIn: CGRect(x: -2.4, y: headY - 4, width: 4.8, height: 4.8)),
      with: .color(ink.opacity(0.88)))
    var robe = Path()
    robe.move(to: CGPoint(x: -1, y: headY + 1))
    robe.addQuadCurve(to: CGPoint(x: -5, y: -3), control: CGPoint(x: -5, y: headY + 6))
    robe.addLine(to: CGPoint(x: seated ? 7 : 3, y: -2))
    robe.addQuadCurve(to: CGPoint(x: 2, y: headY + 1), control: CGPoint(x: seated ? 0 : 4, y: -9))
    robe.closeSubpath()
    layer.fill(robe, with: .color(ink.opacity(0.83)))
    var hat = Path()
    hat.move(to: CGPoint(x: -5.5, y: headY - 1))
    hat.addLine(to: CGPoint(x: 0, y: headY - 6))
    hat.addLine(to: CGPoint(x: 5.2, y: headY - 1))
    hat.closeSubpath()
    layer.fill(hat, with: .color(ink.opacity(0.80)))
    if !seated {
      var legs = Path()
      legs.move(to: CGPoint(x: -1.5, y: -3))
      legs.addLine(to: CGPoint(x: -2, y: 2))
      legs.move(to: CGPoint(x: 1.4, y: -3))
      legs.addLine(to: CGPoint(x: 3, y: 2))
      layer.stroke(legs, with: .color(ink.opacity(0.86)), lineWidth: 1)
      var staff = Path()
      staff.move(to: CGPoint(x: 7, y: -15))
      staff.addLine(to: CGPoint(x: 9, y: 3))
      layer.stroke(staff, with: .color(ink.opacity(0.68)), lineWidth: 0.8)
    }
  }

  private func drawBirds(in context: GraphicsContext) {
    let drift = sin(time * 0.034) * 24
    for index in 0..<3 {
      let x = 522 + Double(index) * 18 + drift
      let y = 290 - Double(index) * 7 + sin(time * 0.18 + Double(index)) * 1.5
      let span = 3.2 - Double(index) * 0.4
      var bird = Path()
      bird.move(to: CGPoint(x: x - span, y: y - 1.5))
      bird.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 1, y: y - 2))
      bird.addQuadCurve(to: CGPoint(x: x + span, y: y - 1.5), control: CGPoint(x: x + 1, y: y - 2))
      context.stroke(
        bird, with: .color(ink.opacity(0.37)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }
  }
}

private struct InkRandom {
  private var state: UInt64

  init(seed: Int) {
    state = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
  }

  mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / 9_007_199_254_740_992.0
  }

  mutating func range(_ lower: Double, _ upper: Double) -> Double {
    lower + (upper - lower) * next()
  }
}
