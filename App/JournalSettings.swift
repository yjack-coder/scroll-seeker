import SwiftUI

struct JournalSettings: View {
  var purchases: PurchaseStore
  @Environment(\.dismiss) private var dismiss
  @State private var showMembership = false
  @State private var showCustomerCenter = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          VStack(alignment: .leading, spacing: 14) {
            JournalBrand()
            Text("The space you leave is part of the painting.")
              .font(LiubaiStyle.serif(16)).italic().foregroundStyle(LiubaiStyle.muted)
          }.padding(.vertical, 12)
        }.listRowBackground(Color.clear)

        Section("Your membership") {
          LabeledContent("Plan", value: purchases.planName)
          if let expiration = purchases.expirationDate {
            LabeledContent("Renews or expires") { Text(expiration, style: .date) }
          }
          Button(
            purchases.isPro ? "View membership plans" : "Discover Liubai Pro", systemImage: "scroll"
          ) { showMembership = true }
          Button("Restore purchases", systemImage: "arrow.clockwise") {
            Task { await purchases.restore() }
          }.disabled(purchases.isLoading)
          Button("Customer Center", systemImage: "gearshape") { showCustomerCenter = true }
          if let message = purchases.restoreMessage {
            Text(message).font(.caption).foregroundStyle(LiubaiStyle.muted)
          }
          if let error = purchases.errorMessage {
            Text(error).font(.caption).foregroundStyle(LiubaiStyle.red)
          }
        }
        Section("A private practice") {
          Text(
            "Your words and paintings stay on this device. Emotion interpretation runs on device when Apple Intelligence is available; an offline collection of poems and word associations is always here."
          )
          .font(.footnote).foregroundStyle(LiubaiStyle.muted)
          Text(
            "Ten studio samples are included to introduce the scroll. They never use your daily painting."
          )
          .font(.footnote).foregroundStyle(LiubaiStyle.muted)
          Text("Deleting the app also removes its journal. Export the paintings you want to keep.")
            .font(.footnote).foregroundStyle(LiubaiStyle.muted)
        }
        if PurchaseStore.isTestStore {
          Section("Purchase testing") {
            Text("This build uses RevenueCat Test Store. Test purchases do not charge money.")
              .font(.footnote).foregroundStyle(LiubaiStyle.muted)
          }
        }
        Section {
          Text("留白 · Version 1.0").font(.caption).foregroundStyle(LiubaiStyle.muted)
        }.listRowBackground(Color.clear)
      }
      .scrollContentBackground(.hidden)
      .background(LiubaiStyle.paper)
      .navigationTitle("A quiet corner")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Close", systemImage: "xmark") { dismiss() }
        }
      }
      .sheet(isPresented: $showMembership) { MembershipView(purchaseStore: purchases) }
      .sheet(isPresented: $showCustomerCenter) {
        MembershipCustomerCenterView(purchaseStore: purchases)
      }
    }
    .task { await purchases.refresh() }
  }
}
