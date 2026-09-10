import Foundation

extension HealthTrendView {
    // MARK: - Datenaufbereitung

    var rangeStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .day, value: -(selectedRange.days - 1), to: today) ?? today
    }

    var rangeEnd: Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate
    }

    @MainActor
    func loadPoints() async {
        isLoading = true
        defer { isLoading = false }

        if metric.usesHealthKit {
            await loadHealthKitPoints()
        } else {
            points = localPoints()
        }
    }

    @MainActor
    private func loadHealthKitPoints() async {
        guard !HealthKitService.isDisabledForCurrentProcess else {
            points = []
            return
        }

        do {
            let service = HealthKitService.shared
            try await service.requestAuthorization()
            let calendar = Calendar.current
            var dates: [Date] = []
            var date = rangeStart

            while date < rangeEnd {
                dates.append(date)
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? rangeEnd
            }

            let metricsByDate = try await service.dailyMetrics(from: rangeStart, to: rangeEnd)
            points = dates.compactMap { date in
                guard let metrics = metricsByDate[calendar.startOfDay(for: date)],
                      let value = value(for: metric, in: metrics) else { return nil }
                return HealthTrendPoint(date: date, value: value)
            }
            errorMessage = nil
        } catch {
            points = []
            errorMessage = error.localizedDescription
        }
    }

    private func localPoints() -> [HealthTrendPoint] {
        let calendar = Calendar.current

        switch metric {
        case .calories:
            let grouped = Dictionary(grouping: nutritionEntries.filter {
                $0.date >= rangeStart && $0.date < rangeEnd
            }) { calendar.startOfDay(for: $0.date) }
            return grouped.keys.sorted().map { date in
                HealthTrendPoint(
                    date: date,
                    value: grouped[date, default: []].reduce(0) { $0 + $1.calories }
                )
            }
        case .water:
            let grouped = Dictionary(grouping: waterEntries.filter {
                $0.date >= rangeStart && $0.date < rangeEnd
            }) { calendar.startOfDay(for: $0.date) }
            return grouped.keys.sorted().map { date in
                HealthTrendPoint(
                    date: date,
                    value: Double(grouped[date, default: []].reduce(0) { $0 + $1.amount })
                )
            }
        case .weight:
            return weightEntries
                .filter { $0.date >= rangeStart && $0.date < rangeEnd }
                .map { HealthTrendPoint(date: $0.date, value: $0.weightKilograms) }
        default:
            return []
        }
    }

    private func value(for metric: HealthTrendMetric, in metrics: HealthMetrics) -> Double? {
        switch metric {
        case .calories: nil
        case .steps: metrics.steps
        case .walkingRunningDistance: metrics.walkingRunningDistanceKilometers
        case .activeEnergy: metrics.activeEnergyKilocalories
        case .basalEnergy: metrics.basalEnergyKilocalories
        case .totalEnergy: metrics.totalEnergyKilocalories
        case .protein: metrics.proteinGrams
        case .carbohydrates: metrics.carbohydratesGrams
        case .fat: metrics.fatGrams
        case .weight, .water: nil
        }
    }
}
