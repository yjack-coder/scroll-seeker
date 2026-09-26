import SwiftUI

@main
struct AppDefinition: App {
  @State private var purchases = PurchaseStore()

  var body: some Scene {
    WindowGroup {
      ContentView(purchases: purchases)
        .tint(LiubaiStyle.red)
        .preferredColorScheme(.light)
        .task {
          purchases.configure()
          await purchases.refresh()
        }
    }
  }
}
