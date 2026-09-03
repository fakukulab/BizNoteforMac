import AVFoundation
import SwiftUI

struct BusinessCardCameraCaptureView: View {
    var onCapture: (NSImage) -> Void
    var onCancel: () -> Void

    @State private var controller = BusinessCardCameraController()
    @State private var devices: [AVCaptureDevice] = []
    @State private var selectedDeviceID: String = ""
    @State private var errorMessage: String? = nil
    @State private var isPreparing = true
    @State private var isCapturing = false

    private var selectedDevice: AVCaptureDevice? {
        devices.first { $0.uniqueID == selectedDeviceID } ?? devices.first
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker(String(localized: "card.camera.device", defaultValue: "카메라"), selection: $selectedDeviceID) {
                    ForEach(devices, id: \.uniqueID) { device in
                        Text(deviceLabel(device)).tag(device.uniqueID)
                    }
                }
                .frame(maxWidth: 320)
                .disabled(devices.isEmpty || isPreparing || isCapturing)

                Spacer()

                Button(String(localized: "action.cancel"), action: close)
            }

            ZStack {
                CameraPreview(session: controller.session)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))

                if isPreparing {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .frame(minWidth: 560, minHeight: 360)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Text(String(localized: "card.camera.hint", defaultValue: "Mac 카메라 또는 iPhone 연속성 카메라로 명함을 프레임 안에 맞춘 뒤 촬영하세요."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    capture()
                } label: {
                    Label(String(localized: "card.camera.capture", defaultValue: "촬영"), systemImage: "camera")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isPreparing || isCapturing || selectedDevice == nil)
            }
        }
        .padding(16)
        .task { prepare() }
        .onDisappear { controller.stopRunning() }
        .onChange(of: selectedDeviceID) { _, _ in
            guard !selectedDeviceID.isEmpty else { return }
            configureSelectedDevice(startAfterConfiguration: true)
        }
    }

    private func prepare() {
        Task {
            isPreparing = true
            errorMessage = nil
            guard await controller.requestAccess() else {
                errorMessage = BusinessCardCameraController.CameraError.accessDenied.localizedDescription
                isPreparing = false
                return
            }

            devices = controller.availableVideoDevices
            guard let first = controller.defaultVideoDevice ?? devices.first else {
                errorMessage = BusinessCardCameraController.CameraError.noCameraAvailable.localizedDescription
                isPreparing = false
                return
            }
            selectedDeviceID = first.uniqueID
            configureSelectedDevice(startAfterConfiguration: true)
        }
    }

    private func configureSelectedDevice(startAfterConfiguration: Bool) {
        isPreparing = true
        controller.configure(device: selectedDevice) { result in
            switch result {
            case .success:
                errorMessage = nil
                if startAfterConfiguration {
                    controller.startRunning()
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            isPreparing = false
        }
    }

    private func capture() {
        isCapturing = true
        controller.capturePhoto { result in
            isCapturing = false
            switch result {
            case .success(let image):
                controller.stopRunning()
                onCapture(image)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func close() {
        controller.stopRunning()
        onCancel()
    }

    private func deviceLabel(_ device: AVCaptureDevice) -> String {
        if device.isContinuityCamera {
            return String(format: String(localized: "card.camera.continuityFormat", defaultValue: "%@ (iPhone)"), device.localizedName)
        }
        return device.localizedName
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
    }
}

private final class PreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = previewLayer
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
