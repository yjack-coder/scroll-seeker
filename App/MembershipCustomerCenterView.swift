import RevenueCatUI
import SwiftUI

struct MembershipCustomerCenterView: View {
  var purchaseStore: PurchaseStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Group {
        if purchaseStore.isConfigured {
          CustomerCenterView()
            .onCustomerCenterRestoreCompleted { customerInfo in
              purchaseStore.apply(customerInfo)
            }
        } else {
          ContentUnavailableView {
            Text("Membership unavailable")
          } description: {
            Text(purchaseStore.errorMessage ?? "Please try again when connected.")
          } actions: {
            Button("Try Again", systemImage: "arrow.clockwise") {
              Task { await purchaseStore.refresh() }
            }
          }
        }
      }
      .toolbar {
        if !purchaseStore.isConfigured {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close", systemImage: "xmark") { dismiss() }
          }
        }
      }
      .tint(Color(red: 0.592, green: 0.235, blue: 0.188))
      .task { await purchaseStore.refresh() }
    }
  }
}
