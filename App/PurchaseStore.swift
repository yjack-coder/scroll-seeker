import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class PurchaseStore {
  private(set) var isPro = false
  private(set) var isLoading = false
  private(set) var isConfigured = false
  private(set) var offering: Offering?
  private(set) var planName = "Free · The Soy Sauce Errand"
  private(set) var expirationDate: Date?
  private(set) var restoreMessage: String?
  var errorMessage: String?

  @ObservationIgnored private var customerInfoTask: Task<Void, Never>?

  static var isTestStore: Bool {
    #if DEBUG || targetEnvironment(simulator)
      true
    #else
      false
    #endif
  }

  func configure() {
    guard !isConfigured else { return }

    #if DEBUG || targetEnvironment(simulator)
      // Public RevenueCat Test Store SDK key. Never included in device release builds.
      let apiKey = "test_iuExOSOoAsqoUePAxPEXXrBmsDb"
      Purchases.logLevel = .debug
    #else
      // Supply the App Store public SDK key once the live store is connected.
      let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? ""
      guard apiKey.hasPrefix("appl_") else {
        errorMessage =
          "Purchases are not available in this release yet. You can still play The Soy Sauce Errand and return home."
        return
      }
      Purchases.logLevel = .warn
    #endif

    if !Purchases.isConfigured {
      Purchases.configure(withAPIKey: apiKey)
    }
    isConfigured = true
    customerInfoTask = Task { [weak self] in
      for await customerInfo in Purchases.shared.customerInfoStream {
        guard !Task.isCancelled else { break }
        self?.apply(customerInfo)
      }
    }
  }

  func refresh() async {
    configure()
    guard isConfigured, !isLoading else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      apply(try await Purchases.shared.customerInfo())
    } catch {
      // Leave the last SDK-confirmed entitlement intact during a network outage.
      errorMessage = "Your plan could not be checked. Please reconnect and try again."
    }

    do {
      let offerings = try await Purchases.shared.offerings()
      offering = offerings.offering(identifier: "default") ?? offerings.current
      if offering?.availablePackages.isEmpty != false {
        errorMessage = "The membership scroll is unavailable for the moment. Please try again."
      }
    } catch {
      errorMessage =
        "The membership scroll could not be opened. Please check your connection and try again."
    }
  }

  func restore() async {
    configure()
    guard isConfigured, !isLoading else { return }
    isLoading = true
    errorMessage = nil
    restoreMessage = nil
    defer { isLoading = false }

    do {
      apply(try await Purchases.shared.restorePurchases())
      restoreMessage =
        isPro
        ? "Your Scroll Seeker Pro membership has been restored."
        : "No active Scroll Seeker Pro purchase was found for this account."
    } catch {
      errorMessage = "Purchases could not be restored. Please check your connection and try again."
    }
  }

  func apply(_ customerInfo: CustomerInfo) {
    let entitlement = customerInfo.entitlements.active["pro"]
    isPro = entitlement != nil
    expirationDate = entitlement?.expirationDate
    guard let entitlement else {
      planName = "Free · The Soy Sauce Errand"
      return
    }
    switch entitlement.productIdentifier {
    // Preserve the existing catalog identifiers so previous purchases still unlock Pro.
    case "liubai_pro_monthly": planName = "Scroll Seeker Pro · Monthly"
    case "liubai_pro_yearly": planName = "Scroll Seeker Pro · Yearly"
    case "liubai_pro_lifetime": planName = "Scroll Seeker Pro · Lifetime"
    default: planName = "Scroll Seeker Pro"
    }
  }

  deinit {
    customerInfoTask?.cancel()
  }
}
