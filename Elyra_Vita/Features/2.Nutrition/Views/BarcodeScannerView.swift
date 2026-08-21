import SwiftUI
import VisionKit

// MARK: - BarcodeScannerView

/// Native Apple-Scanner für EAN/UPC-Barcodes.
struct BarcodeScannerView: UIViewControllerRepresentable {

    // MARK: - Eingaben

    let onBarcode: (String) -> Void
    let onUnavailable: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onBarcode: onBarcode)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        guard DataScannerViewController.isSupported,
              DataScannerViewController.isAvailable else {
            onUnavailable()
            return controller
        }

        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    // MARK: - Delegate

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onBarcode: (String) -> Void
        private var didScan = false

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didScan,
                  case let .barcode(barcode) = addedItems.first,
                  let value = barcode.payloadStringValue else { return }

            didScan = true
            onBarcode(value)
        }
    }
}
