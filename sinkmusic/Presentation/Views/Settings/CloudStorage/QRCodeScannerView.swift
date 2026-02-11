//
//  QRCodeScannerView.swift
//  sinkmusic
//
//  Vista de cámara para escanear códigos QR (ej. URL de carpeta Mega).
//  Usa @Observable (Observation), MainActor y async/await. Sin Combine ni NotificationCenter.
//

import SwiftUI
import AVFoundation

struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: (String) -> Void

    @State private var scanner = QRScanner()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if scanner.isAuthorized {
                CameraPreview(session: scanner.session)
                    .ignoresSafeArea()

                VStack {
                    Text("Apunta al código QR de la carpeta de Mega")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 40)

                    Spacer()

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appPurple, lineWidth: 3)
                        .frame(width: 260, height: 260)
                        .padding(.bottom, 80)

                    Spacer()
                }

                if let errorMessage = scanner.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.textGray)
                    Text(scanner.authorizationMessage)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .task {
            await scanner.start()
        }
        .onDisappear {
            scanner.stop()
        }
        .onChange(of: scanner.scannedString) { _, newValue in
            if let url = newValue, !url.isEmpty {
                onScan(url)
                dismiss()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Camera Preview (UIKit wrapper)

private struct CameraPreview: UIViewControllerRepresentable {
    let session: AVCaptureSession

    func makeUIViewController(context: Context) -> CameraPreviewController {
        let vc = CameraPreviewController()
        vc.session = session
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraPreviewController, context: Context) {}
}

private final class CameraPreviewController: UIViewController {
    var session: AVCaptureSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let session else { return }
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.frame = view.bounds
    }
}

// MARK: - QR Scanner (@Observable, MainActor, async/await)

@MainActor
@Observable
private final class QRScanner: NSObject {
    let session = AVCaptureSession()

    var scannedString: String?
    var errorMessage: String?
    var isAuthorized = false
    var authorizationMessage = "Comprobando permiso de cámara..."

    private var hasScanned = false

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            isAuthorized = granted
            if granted {
                setupSession()
            } else {
                authorizationMessage = "Se necesita permiso de cámara para escanear el QR. Actívalo en Ajustes."
                errorMessage = "Sin permiso de cámara"
            }
        case .denied, .restricted:
            isAuthorized = false
            authorizationMessage = "Permiso de cámara denegado. Actívalo en Ajustes para escanear el QR."
        @unknown default:
            isAuthorized = false
            authorizationMessage = "No se puede acceder a la cámara."
        }
    }

    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            errorMessage = "No se pudo acceder a la cámara"
            return
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddInput(input), session.canAddOutput(output) {
            session.addInput(input)
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
            session.startRunning()
        } else {
            errorMessage = "No se pudo configurar la cámara"
        }
    }

    /// Llamado desde el delegate (que se ejecuta en cola .main) vía MainActor.assumeIsolated
    func updateScannedString(_ string: String) {
        guard !hasScanned else { return }
        hasScanned = true
        scannedString = string
    }
}

extension QRScanner: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = obj.stringValue, !string.isEmpty else { return }

        MainActor.assumeIsolated {
            self.updateScannedString(string)
        }
    }
}
