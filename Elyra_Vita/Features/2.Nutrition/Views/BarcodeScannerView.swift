import SwiftUI
import VisionKit
import AVFoundation

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

        // Nicht während makeUIViewController den Sheet-State ändern. Das
        // kann SwiftUI dazu bringen, den präsentierten Inhalt sofort durch
        // den darunterliegenden Dialog zu ersetzen.
        DispatchQueue.main.async {
            context.coordinator.startScanning(
                controller: controller,
                onUnavailable: onUnavailable
            )
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    // MARK: - Delegate

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onBarcode: (String) -> Void
        private var didScan = false
        private var didStart = false

        init(onBarcode: @escaping (String) -> Void) {
            self.onBarcode = onBarcode
        }

        func startScanning(
            controller: DataScannerViewController,
            onUnavailable: @escaping () -> Void
        ) {
            guard !didStart else { return }
            guard DataScannerViewController.isSupported else {
                onUnavailable()
                return
            }

            let start: () -> Void = { [weak self, weak controller] in
                guard let self, let controller, !self.didStart else { return }
                guard DataScannerViewController.isAvailable else {
                    onUnavailable()
                    return
                }

                do {
                    try controller.startScanning()
                    self.didStart = true
                } catch {
                    onUnavailable()
                }
            }

            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                start()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        if granted { start() } else { onUnavailable() }
                    }
                }
            case .denied, .restricted:
                onUnavailable()
            @unknown default:
                onUnavailable()
            }
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
