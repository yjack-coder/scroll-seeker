import SwiftUI

struct AdventureLetterView: View {
  var onFinished: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var folded = false
  @State private var sealed = false
  @State private var didFinish = false

  var body: some View {
    VStack(spacing: 26) {
      Text("家書").font(SeekerStyle.brush(45))
      Text("A letter for Mother").font(.system(.title2, design: .serif))
      ZStack {
        RoundedRectangle(cornerRadius: 4).fill(SeekerStyle.paper)
          .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(SeekerStyle.gold.opacity(0.65), lineWidth: 1) }
        VStack(alignment: .leading, spacing: 10) {
          Text("娘親，見字如面。").font(SeekerStyle.brush(21))
          ForEach(0..<3) { index in
            Rectangle().fill(SeekerStyle.ink.opacity(0.16)).frame(width: CGFloat(170 - index * 18), height: 2)
          }
        }.padding(23).opacity(folded ? 0 : 1)
        Rectangle().fill(SeekerStyle.paper)
          .overlay(alignment: .bottom) { Rectangle().fill(SeekerStyle.gold.opacity(0.4)).frame(height: 1) }
          .frame(height: 78).frame(maxHeight: .infinity, alignment: .top)
          .rotation3DEffect(.degrees(folded ? -175 : -18), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.25)
        Text("安").font(SeekerStyle.brush(34)).foregroundStyle(SeekerStyle.paper)
          .frame(width: 47, height: 47).background(SeekerStyle.red, in: RoundedRectangle(cornerRadius: 3))
          .rotationEffect(.degrees(-6)).scaleEffect(sealed ? 1 : 1.35).opacity(sealed ? 1 : 0)
      }
      .frame(width: 265, height: 157).shadow(color: SeekerStyle.ink.opacity(0.12), radius: 13, y: 6)
      .accessibilityHidden(true)
      Text("山水再遠，總有回音。\nAcross mountains and water, a word finds its way home.")
        .font(.system(.subheadline, design: .serif)).multilineTextAlignment(.center).lineSpacing(5).foregroundStyle(.secondary)
      Button("Skip letter animation", action: finish)
        .font(.system(.subheadline, design: .serif)).buttonStyle(.bordered)
    }
    .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
    .background { SilkBackground().ignoresSafeArea() }.foregroundStyle(SeekerStyle.ink)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: sealed)
    .task {
      if reduceMotion { finish(); return }
      withAnimation(.easeInOut(duration: 0.42)) { folded = true }
      do { try await Task.sleep(for: .milliseconds(440)) } catch { return }
      guard !didFinish else { return }
      withAnimation(.easeOut(duration: 0.22)) { sealed = true }
      do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
      finish()
    }
  }

  private func finish() {
    guard !didFinish else { return }
    didFinish = true
    onFinished()
  }
}
