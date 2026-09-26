import RevenueCat
import RevenueCatUI
import SwiftUI

struct MembershipView: View {
  var purchaseStore: PurchaseStore
  @Environment(\.dismiss) private var dismiss
  @State private var isShowingPrivacy = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color(red: 0.953, green: 0.941, blue: 0.902).ignoresSafeArea()
        if let offering = purchaseStore.offering, !offering.availablePackages.isEmpty {
          PaywallView(offering: offering, displayCloseButton: false)
            .onPurchaseCompleted { customerInfo in
              purchaseStore.apply(customerInfo)
              if purchaseStore.isPro { dismiss() }
            }
            .onRestoreCompleted { customerInfo in
              purchaseStore.apply(customerInfo)
              if purchaseStore.isPro { dismiss() }
            }
            .onRequestedDismissal { dismiss() }
        } else if purchaseStore.isLoading {
          ProgressView("Opening the membership scroll…")
            .font(.system(.body, design: .serif))
        } else {
          MembershipUnavailableView(
            message: purchaseStore.errorMessage,
            retry: { Task { await purchaseStore.refresh() } }
          )
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
      }
      .toolbarBackground(.hidden, for: .navigationBar)
      .navigationDestination(isPresented: $isShowingPrivacy) {
        LiubaiPrivacyView()
      }
      .onOpenURL { url in
        if url.scheme == "liubai", url.host == "privacy" {
          isShowingPrivacy = true
        }
      }
      .tint(Color(red: 0.647, green: 0.282, blue: 0.220))
      .task { await purchaseStore.refresh() }
    }
    .preferredColorScheme(.light)
  }
}

private struct MembershipUnavailableView: View {
  var message: String?
  var retry: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        Text("留白")
          .font(.system(.largeTitle, design: .serif))
          .foregroundStyle(Color(red: 0.647, green: 0.282, blue: 0.220))
        Text("A little space, for now.")
          .font(.system(.title2, design: .serif))
        Text(message ?? "The membership scroll is not available yet. Please try again in a moment.")
          .font(.system(.body, design: .serif))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Button("Try Again", systemImage: "arrow.clockwise", action: retry)
          .buttonStyle(.bordered)
      }
      .padding(32)
      .frame(maxWidth: .infinity)
    }
  }
}
