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
              Text("A living museum in your hands.").font(.system(.caption, design: .serif)).foregroundStyle(.secondary)
            }
          }.padding(.vertical, 8)
        }
        Section("Your collection") {
          LabeledContent("Plan", value: purchases.planName)
          if !purchases.isPro {
            Button("Explore Scroll Seeker Pro", systemImage: "lock") { showMembership = true }
          }
          Button("Restore purchases", systemImage: "arrow.clockwise") {
            Task { await purchases.restore() }
          }.disabled(purchases.isLoading)
          Button("Customer Center", systemImage: "book.closed") { showCustomerCenter = true }
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
          Text("Soft paper, plucked strings, and a quiet chime when a chapter comes alive. Respects Silent mode.")
        }
        Section("Inside the scroll") {
          Text("Begin at the right, in the countryside. Pan left toward the city. Pinch to see the smallest details, or use the painting’s accessibility actions.")
          Text("Find each clue to awaken its original ink with warmth and color. The story cards hold colorized interpretations; the historic painting itself stays untouched.")
          NavigationLink("Privacy") { SeekerPrivacyView() }
        }
        Section("The original masterpiece") {
          Text("Zhang Zeduan, Along the River During the Qingming Festival, Northern Song. Public domain.")
            .font(.system(.footnote, design: .serif)).lineSpacing(4)
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
