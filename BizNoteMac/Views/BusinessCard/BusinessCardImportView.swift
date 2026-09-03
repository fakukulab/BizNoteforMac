import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct BusinessCardImportView: View {
    @State private var isDragOver = false
    @State private var showsCameraCapture = false
    var onImage: (NSImage) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isDragOver ? Color.accentColor : Color.secondary.opacity(0.4),
                                  style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDragOver ? Color.accentColor.opacity(0.10) : Color.clear)
                    )
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "cardImport.dropOrClick"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text(String(localized: "cardImport.supportedTypes"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
            .frame(height: 140)
            .contentShape(Rectangle())
            .onTapGesture(perform: openPanel)
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver, perform: handleDrop)

            HStack(spacing: 8) {
                Button {
                    openPanel()
                } label: {
                    Label(String(localized: "cardImport.selectFile"), systemImage: "folder")
                }

                Button {
                    showsCameraCapture = true
                } label: {
                    Label(String(localized: "cardImport.captureCamera", defaultValue: "카메라로 촬영"), systemImage: "camera")
                }
            }
        }
        .sheet(isPresented: $showsCameraCapture) {
            BusinessCardCameraCaptureView { image in
                showsCameraCapture = false
                onImage(image)
            } onCancel: {
                showsCameraCapture = false
            }
        }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "cardImport.panelTitle")
        panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let img = NSImage(contentsOf: url) else { return }
        onImage(img)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let u = item as? URL {
                    url = u
                }
                if let url, let img = NSImage(contentsOf: url) {
                    DispatchQueue.main.async { onImage(img) }
                }
            }
            return true
        }
        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { obj, _ in
                if let img = obj as? NSImage {
                    DispatchQueue.main.async { onImage(img) }
                }
            }
            return true
        }
        return false
    }
}
