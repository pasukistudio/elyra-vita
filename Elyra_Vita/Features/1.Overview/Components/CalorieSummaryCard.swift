import SwiftUI

struct CalorieSummaryCard : View {
    // MARK: - Ansicht

    let accentColor: Color

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Gegessen")
                        .font(.subheadline)
                    Text("0 kcal")
                        .font(.title)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    Text("Übrig")
                        .font(.subheadline)
                    Text("1.800 kcal")
                        .font(.title)
                        .foregroundStyle(accentColor)
                }
            }

        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.primary.opacity(0.07), lineWidth: 1)
        }
    }
}

#Preview("CalorieSummaryCard") {
    CalorieSummaryCard(accentColor: .blue)
}
