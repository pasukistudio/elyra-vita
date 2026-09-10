import Foundation

extension AddNutritionEntryView {
    /// Sucht erst nach einer kurzen Eingabepause, damit nicht jeder Tastendruck
    /// eine Netzwerkanfrage auslöst. Der lokale Katalog bleibt sofort sichtbar.
    func searchRemoteFoods() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2, selectedFood == nil, foodFilter == .all else {
            remoteFoods = []
            return
        }

        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isLoadingRemoteFoods = true
        defer { isLoadingRemoteFoods = false }

        do {
            remoteFoods = try await OpenFoodFactsService().search(query)
        } catch {
            remoteFoods = []
            errorMessage = "Die Online-Lebensmittelsuche ist momentan nicht erreichbar. "
                + "Lokale Lebensmittel kannst du weiterhin verwenden."
        }
    }

    func loadBarcode(_ barcode: String) async {
        do {
            guard let food = try await OpenFoodFactsService().product(for: barcode) else {
                customFoodSheetPresented = true
                return
            }

            customFoodSheetPresented = false
            selectFood(food)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
