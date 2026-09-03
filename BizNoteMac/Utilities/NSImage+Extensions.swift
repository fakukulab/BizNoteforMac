import AppKit

extension NSImage {
    var cgImageForOCR: CGImage? {
        var rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    func centeredSquareImage() -> NSImage? {
        guard let cgImage = cgImageForOCR else { return nil }
        let side = min(cgImage.width, cgImage.height)
        let cropRect = CGRect(
            x: (cgImage.width - side) / 2,
            y: (cgImage.height - side) / 2,
            width: side,
            height: side
        )
        guard let croppedImage = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: croppedImage, size: NSSize(width: side, height: side))
    }
}
