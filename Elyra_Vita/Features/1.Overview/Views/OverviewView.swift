//
//  OverviewView.swift
//  elyra_vita
//
//  Created by Pascal Smigielski on 14.08.26.
//


import SwiftUI
struct OverviewView: View {
    // MARK: - Ansicht
    let accentColor: Color

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Kalorien")
                CalorieSummaryCard(
                    accentColor: accentColor
                )
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(.horizontal)

        }
        .appBackground()
    }
}


#Preview("OverviewView") {
    OverviewView(accentColor: .blue)
}
