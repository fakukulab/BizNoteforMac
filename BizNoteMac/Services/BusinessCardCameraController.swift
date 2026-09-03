import AppKit
import AVFoundation
import Foundation

final class BusinessCardCameraController: NSObject, AVCapturePhotoCaptureDelegate {
    enum CameraError: LocalizedError {
        case accessDenied
        case noCameraAvailable
        case cannotAddInput
        case cannotAddOutput
        case captureFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "카메라 접근 권한이 필요합니다. 시스템 설정에서 권한을 허용해 주세요."
            case .noCameraAvailable:
                return "사용 가능한 카메라를 찾을 수 없습니다. Mac 카메라 또는 iPhone 연속성 카메라 연결을 확인해 주세요."
            case .cannotAddInput:
                return "선택한 카메라를 사용할 수 없습니다."
            case .cannotAddOutput:
                return "카메라 촬영 출력을 구성할 수 없습니다."
            case .captureFailed:
                return "사진을 촬영하지 못했습니다. 다시 시도해 주세요."
            }
        }
    }

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.fakuku.biznote.camera.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var activeInput: AVCaptureDeviceInput?
    private var completion: ((Result<NSImage, Error>) -> Void)?

    var availableVideoDevices: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    var defaultVideoDevice: AVCaptureDevice? {
        AVCaptureDevice.systemPreferredCamera ?? availableVideoDevices.first
    }

    func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func configure(device: AVCaptureDevice? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        let selectedDevice = device ?? defaultVideoDevice
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let selectedDevice else {
                DispatchQueue.main.async { completion(.failure(CameraError.noCameraAvailable)) }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: selectedDevice)
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                if let activeInput = self.activeInput {
                    self.session.removeInput(activeInput)
                }
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.activeInput = input
                    AVCaptureDevice.userPreferredCamera = selectedDevice
                } else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { completion(.failure(CameraError.cannotAddInput)) }
                    return
                }

                if !self.session.outputs.contains(self.photoOutput) {
                    if self.session.canAddOutput(self.photoOutput) {
                        self.session.addOutput(self.photoOutput)
                        self.photoOutput.maxPhotoQualityPrioritization = .quality
                    } else {
                        self.session.commitConfiguration()
                        DispatchQueue.main.async { completion(.failure(CameraError.cannotAddOutput)) }
                        return
                    }
                }
                if let maxPhotoDimensions = Self.maxPhotoDimensions(for: selectedDevice) {
                    self.photoOutput.maxPhotoDimensions = maxPhotoDimensions
                }

                self.session.commitConfiguration()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func startRunning() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopRunning() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (Result<NSImage, Error>) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization == .quality ? .quality : .balanced
        settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let completion = completion
        self.completion = nil

        if let error {
            DispatchQueue.main.async { completion?(.failure(error)) }
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = NSImage(data: data) else {
            DispatchQueue.main.async { completion?(.failure(CameraError.captureFailed)) }
            return
        }
        DispatchQueue.main.async { completion?(.success(image)) }
    }

    private static func maxPhotoDimensions(for device: AVCaptureDevice) -> CMVideoDimensions? {
        device.activeFormat.supportedMaxPhotoDimensions.max { lhs, rhs in
            Int(lhs.width) * Int(lhs.height) < Int(rhs.width) * Int(rhs.height)
        }
    }
}
