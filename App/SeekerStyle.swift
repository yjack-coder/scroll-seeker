import SwiftUI
import UIKit

enum SeekerStyle {
  static let indigo = Color(red: 0.12, green: 0.19, blue: 0.24)
  static let ink = Color(red: 0.20, green: 0.23, blue: 0.23)
  static let paper = Color(red: 0.94, green: 0.90, blue: 0.81)
  static let gold = Color(red: 0.61, green: 0.46, blue: 0.25)
  static let red = Color(red: 0.61, green: 0.22, blue: 0.17)

  static func brush(_ size: CGFloat) -> Font { .custom("STKaiti", size: size, relativeTo: .title) }
}

struct SilkBackground: View {
  var dark = false
  var body: some View {
    (dark ? SeekerStyle.indigo : SeekerStyle.paper)
      .overlay {
        Canvas { context, size in
          var weave = Path()
          for x in stride(from: 0.0, through: size.width, by: 4) {
            weave.move(to: CGPoint(x: x, y: 0))
            weave.addLine(to: CGPoint(x: x, y: size.height))
          }
          for y in stride(from: 0.0, through: size.height, by: 5) {
            weave.move(to: CGPoint(x: 0, y: y))
            weave.addLine(to: CGPoint(x: size.width, y: y))
          }
          context.stroke(weave, with: .color((dark ? Color.white : SeekerStyle.gold).opacity(0.065)), lineWidth: 0.45)
        }
        .accessibilityHidden(true)
      }
  }
}

struct SeekerSeal: View {
  var size: CGFloat = 38
  var body: some View {
    Text("尋")
      .font(SeekerStyle.brush(size * 0.70))
      .foregroundStyle(SeekerStyle.paper)
      .frame(width: size, height: size)
      .background(SeekerStyle.red, in: RoundedRectangle(cornerRadius: 3))
      .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(SeekerStyle.paper.opacity(0.55), lineWidth: 1).padding(3) }
      .rotationEffect(.degrees(-4))
      .accessibilityLabel("Found seal")
  }
}

struct SeekerActionStyle: ButtonStyle {
  var secondary = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.body, design: .serif).weight(.medium))
      .padding(.horizontal, 22)
      .padding(.vertical, 16)
      .frame(maxWidth: .infinity)
      .foregroundStyle(secondary ? SeekerStyle.indigo : SeekerStyle.paper)
      .background(secondary ? SeekerStyle.gold.opacity(0.12) : SeekerStyle.indigo, in: RoundedRectangle(cornerRadius: 6))
      .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(SeekerStyle.gold.opacity(0.35), lineWidth: 1) }
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

struct ClueArtwork: View {
  var target: ScrollTarget
  var colorized = false
  var body: some View {
    if let url = ScrollArchive.resourceURL(for: colorized ? "colorized/\(target.id)_color.png" : target.clue),
       let image = UIImage(contentsOfFile: url.path) {
      Image(uiImage: image).resizable().scaledToFill()
    } else if colorized {
      ClueArtwork(target: target).saturation(1.6).overlay { SeekerStyle.gold.opacity(0.16).blendMode(.color) }
    } else {
      SeekerStyle.paper.overlay(Image(systemName: "magnifyingglass"))
    }
  }
}

struct BrassMagnifier: View {
  var target: ScrollTarget
  var diameter: CGFloat = 216
  var body: some View {
    ClueArtwork(target: target)
      .frame(width: diameter, height: diameter)
      .clipShape(Circle())
      .overlay {
        Circle().strokeBorder(.linearGradient(colors: [Color(red: 0.86, green: 0.73, blue: 0.46), SeekerStyle.gold, Color(red: 0.35, green: 0.27, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 9)
      }
      .overlay { Circle().strokeBorder(SeekerStyle.paper.opacity(0.5), lineWidth: 1).padding(11) }
      .background(alignment: .bottomTrailing) {
        RoundedRectangle(cornerRadius: 5)
          .fill(.linearGradient(colors: [SeekerStyle.gold, Color(red: 0.25, green: 0.19, blue: 0.13)], startPoint: .leading, endPoint: .trailing))
          .frame(width: 17, height: diameter * 0.34)
          .rotationEffect(.degrees(-40), anchor: .top)
          .offset(x: -18, y: diameter * 0.17)
      }
      .shadow(color: SeekerStyle.ink.opacity(0.16), radius: 14, x: 3, y: 9)
      .accessibilityLabel("Clue image: \(target.englishName)")
  }
}
