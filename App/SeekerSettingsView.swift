import SwiftUI

struct SeekerSettingsView: View {
  var purchases: PurchaseStore
  @Environment(\.dismiss) private var dismiss
  @AppStorage("seeker.soundEnabled") private var soundEnabled = false
  @State private var showMembership = false
  @State private var showCustomerCenter = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          HStack(spacing: 15) {
            SeekerSeal(size: 44)
            VStack(alignment: .leading, spacing: 4) {
              Text("尋畫 Scroll Seeker").font(.system(.headline, design: .serif))
              Text("A life along the river.").font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
            }
          }.padding(.vertical, 8)
        }
        Section("Your unfolding story") {
          LabeledContent("Plan", value: purchases.planName)
          Button(purchases.isPro ? "View membership plans" : "Explore Scroll Seeker Pro", systemImage: "lock") { showMembership = true }
          Button("Restore purchases", systemImage: "arrow.clockwise") {
            Task { await purchases.restore() }
          }.disabled(purchases.isLoading)
          Button("Customer Center", systemImage: "book.closed") { showCustomerCenter = true }
          Text("Act I and the home hub are free. Pro includes both Act II paths, their story-earned gear, and extra outfits.")
            .font(.footnote).foregroundStyle(.secondary)
          if let message = purchases.restoreMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
          if let error = purchases.errorMessage { Text(error).font(.footnote).foregroundStyle(SeekerStyle.red) }
          if PurchaseStore.isTestStore {
            Text("Demo purchases use RevenueCat Test Store. No real payment is taken.")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        Section {
          Toggle("Paper & guqin sounds", systemImage: soundEnabled ? "speaker.wave.2" : "speaker.slash", isOn: $soundEnabled)
        } header: { Text("Atmosphere") } footer: {
          Text("Soft paper, plucked strings, and a quiet chime for each new memory. Respects Silent mode.")
        }
        Section("Inside the scroll") {
          Text("Walk with Xiao An through the countryside and toward the capital. Follow Mother’s errand, meet the people inside the painting, and find your own path.")
          Text("Fold to return home to Mother, prepare your gear, and open the seal album. Unfold to resume exactly where Xiao An was standing. Walk through the mist to reach the next scene.")
          Text("Copper coins are earned by completing missions. Spend them on ordinary gear at home; coins are never sold for real money.")
          NavigationLink("Privacy") { SeekerPrivacyView() }
        }
        Section("The original masterpiece") {
          Text("Zhang Zeduan, Along the River During the Qingming Festival, Northern Song. Public domain.")
            .font(.system(.footnote, design: .serif)).lineSpacing(4)
          Text("The game world is a separate illustrated setting supplied by the team, inspired by the historic handscroll.")
            .font(.footnote).foregroundStyle(.secondary)
        }
      }
      .scrollContentBackground(.hidden)
      .background { SilkBackground().ignoresSafeArea() }
      .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    .sheet(isPresented: $showMembership) { MembershipView(purchaseStore: purchases) }
    .sheet(isPresented: $showCustomerCenter) { MembershipCustomerCenterView(purchaseStore: purchases) }
  }
}
