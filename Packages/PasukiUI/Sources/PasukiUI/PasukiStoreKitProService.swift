import Foundation
import StoreKit
import SwiftUI

// MARK: - PasukiProProductConfiguration

/// Verbindet StoreKit-Produkte mit den gemeinsamen PasukiUI-Pro-Funktionen.
///
/// Die Produkt-IDs bleiben bewusst in der jeweiligen App konfigurierbar. So
/// können Elyra Vita und Elyra Budget denselben Service verwenden, ohne sich
/// Produktkataloge oder App Store Connect-Konfigurationen zu teilen.
public struct PasukiProProductConfiguration: Sendable {

    // MARK: - Daten

    public let productIdentifiers: Set<String>
    public let featureByProductIdentifier: [String: PasukiProFeature]

    // MARK: - Initialisierung

    public init(
        featureByProductIdentifier: [String: PasukiProFeature]
    ) {
        self.featureByProductIdentifier = featureByProductIdentifier
        self.productIdentifiers = Set(featureByProductIdentifier.keys)
    }
}

// MARK: - PasukiStoreKitState

/// Grober, UI-tauglicher Zustand des StoreKit-Katalogs.
public enum PasukiStoreKitState: Equatable, Sendable {
    case idle
    case loading
    case ready
    case failed(message: String)
}

// MARK: - PasukiStoreKitError

/// Bekannte Fehler, die die aufrufende App verständlich darstellen kann.
public enum PasukiStoreKitError: LocalizedError, Equatable {
    case productNotFound
    case unverifiedTransaction

    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            "Das Pro-Produkt ist aktuell nicht verfügbar."
        case .unverifiedTransaction:
            "Der Kauf konnte nicht verifiziert werden."
        }
    }
}

// MARK: - PasukiStoreKitProService

/// Gemeinsamer StoreKit-2-Service für Pro-Produkte und Entitlements.
///
/// StoreKit bleibt die Quelle der Wahrheit: Käufe, Wiederherstellung und
/// laufende Transaktionsupdates werden ausschließlich über Apples APIs
/// verarbeitet. Der Service übersetzt die verifizierten Produkt-IDs lediglich
/// in die appübergreifenden `PasukiProFeature`-Werte.
@MainActor
public final class PasukiStoreKitProService: ObservableObject, PasukiProAccess {

    // MARK: - Beobachtbarer Zustand

    @Published public private(set) var state: PasukiStoreKitState = .idle
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var entitledFeatures: Set<PasukiProFeature> = []

    // MARK: - Abhängigkeiten

    private let configuration: PasukiProProductConfiguration
    private var transactionUpdatesTask: Task<Void, Never>?

    // MARK: - Initialisierung

    public init(configuration: PasukiProProductConfiguration) {
        self.configuration = configuration
        transactionUpdatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.process(update)
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    // MARK: - Katalog und Entitlements

    /// Lädt den StoreKit-Katalog und den aktuellen Entitlement-Stand.
    public func refresh() async {
        state = .loading

        do {
            products = try await Product.products(
                for: configuration.productIdentifiers
            )
            await refreshEntitlements()
            state = .ready
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Prüft ein Feature gegen die aktuell verifizierten Transaktionen.
    public func hasAccess(to feature: PasukiProFeature) -> Bool {
        entitledFeatures.contains(feature)
    }

    // MARK: - Kauf und Wiederherstellung

    /// Startet den Kauf eines geladenen StoreKit-Produkts.
    @discardableResult
    public func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verifiedTransaction(from: verification)
            await transaction.finish()
            await refreshEntitlements()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }

        return result
    }

    /// Fordert Apples Wiederherstellung der Käufe für die Apple-ID an.
    public func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Interne StoreKit-Verarbeitung

    private func refreshEntitlements() async {
        var features = Set<PasukiProFeature>()

        for await verification in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(from: verification),
                  transaction.revocationDate == nil,
                  let feature = configuration.featureByProductIdentifier[
                    transaction.productID
                  ]
            else {
                continue
            }

            features.insert(feature)
        }

        entitledFeatures = features
    }

    private func process(
        _ verification: VerificationResult<StoreKit.Transaction>
    ) async {
        guard let transaction = try? verifiedTransaction(from: verification) else {
            return
        }

        await transaction.finish()
        await refreshEntitlements()
    }

    private func verifiedTransaction(
        from verification: VerificationResult<StoreKit.Transaction>
    ) throws -> StoreKit.Transaction {
        switch verification {
        case .verified(let transaction):
            transaction
        case .unverified:
            throw PasukiStoreKitError.unverifiedTransaction
        }
    }
}
