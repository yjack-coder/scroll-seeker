import SwiftUI

struct SeekerPrivacyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        Text("Your discoveries stay with you.")
          .font(.system(.title, design: .serif))
        SeekerPrivacyParagraph(
          title: "Your progress",
          detail:
            "Scroll Seeker saves your found objects, chapter times, hints used, and preferences on this device. These may be included in device backups you choose to keep. You do not need an account to explore the painting."
        )
        SeekerPrivacyParagraph(
          title: "The painting",
          detail:
            "The painting, clue images, and stories are included in the app and can be explored offline. Scroll Seeker does not request microphone, camera, or photo-library access."
        )
        SeekerPrivacyParagraph(
          title: "Membership",
          detail:
            "RevenueCat receives an anonymous app identifier, purchase information, and basic device and app-usage information to check your plan, restore purchases, and manage your membership. Your found-object progress stays on this device and is not sent to RevenueCat. An internet connection is needed for purchases and restores."
        )
        Link(
          "RevenueCat's privacy policy",
          destination: URL(string: "https://www.revenuecat.com/privacy/")!
        )
        .font(.system(.body, design: .serif))
        SeekerPrivacyParagraph(
          title: "A public-domain masterpiece",
          detail:
            "Zhang Zeduan, Along the River During the Qingming Festival, Northern Song. Public domain."
        )
      }
      .padding(28)
      .frame(maxWidth: 640, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .foregroundStyle(Color(red: 0.098, green: 0.184, blue: 0.216))
    .background(Color(red: 0.933, green: 0.890, blue: 0.800))
    .navigationTitle("Privacy in Scroll Seeker")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct SeekerPrivacyParagraph: View {
  var title: LocalizedStringResource
  var detail: LocalizedStringResource

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(.headline, design: .serif))
      Text(detail)
        .font(.system(.body, design: .serif))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
