import SwiftUI

struct LiubaiPrivacyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        Text("Your words deserve a quiet place.")
          .font(.system(.title, design: .serif))
        LiubaiPrivacyParagraph(
          title: "Your journal",
          detail:
            "Your words, poems, and paintings are saved on this device. They may be included in the device backups you choose to keep. Liubai does not send your journal words to RevenueCat."
        )
        LiubaiPrivacyParagraph(
          title: "A private interpretation",
          detail:
            "When available, Apple's on-device models help turn your words into a landscape. Otherwise, Liubai uses an offline interpretation and a collection of poems."
        )
        LiubaiPrivacyParagraph(
          title: "Membership",
          detail:
            "RevenueCat receives an anonymous app identifier, purchase information, and basic device and app-usage information to check your plan, restore purchases, and manage your membership. Your journal is separate from your purchase history."
        )
        Link(
          "RevenueCat's privacy policy",
          destination: URL(string: "https://www.revenuecat.com/privacy/")!
        )
        .font(.system(.body, design: .serif))
        LiubaiPrivacyParagraph(
          title: "Your voice, your choice",
          detail:
            "Dictation is optional and uses Apple's speech services with your permission. You can always write instead. Microphone and speech access can be changed in iPhone Settings."
        )
        LiubaiPrivacyParagraph(
          title: "Sharing",
          detail:
            "When you export a painting, you choose where to save or share the video. The app does not publish your journal automatically."
        )
      }
      .padding(28)
      .frame(maxWidth: 640, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color(red: 0.953, green: 0.941, blue: 0.902))
    .navigationTitle("Privacy in Liubai")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct LiubaiPrivacyParagraph: View {
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
