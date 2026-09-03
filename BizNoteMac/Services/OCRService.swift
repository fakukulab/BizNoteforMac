import Foundation
import Vision
import AppKit
import CoreImage

enum OCRError: Error, LocalizedError {
    case invalidImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "이미지를 처리할 수 없습니다."
        case .recognitionFailed(let m): return "인식 실패: \(m)"
        }
    }
}

struct OCRResult: Sendable {
    let recognizedLines: [OCRRecognizedLine]
    let dominantLanguage: String   // "ko" | "en" | "zh"
    let preprocessingMethod: String

    var lines: [String] { recognizedLines.map(\.text) }
    var fullText: String { lines.joined(separator: "\n") }
    var averageConfidence: Float {
        guard !recognizedLines.isEmpty else { return 0 }
        let total = recognizedLines.map(\.confidence).reduce(0, +)
        return total / Float(recognizedLines.count)
    }

    init(recognizedLines: [OCRRecognizedLine], dominantLanguage: String, preprocessingMethod: String = "original") {
        self.recognizedLines = OCRReadingOrder.sortedLines(recognizedLines)
        self.dominantLanguage = dominantLanguage
        self.preprocessingMethod = preprocessingMethod
    }

    init(lines: [String], dominantLanguage: String) {
        self.recognizedLines = lines.map { OCRRecognizedLine(text: $0, confidence: 0, candidates: [$0]) }
        self.dominantLanguage = dominantLanguage
        self.preprocessingMethod = "legacy"
    }
}

actor OCRService {
    static let shared = OCRService()

    func recognizeText(from image: NSImage) async throws -> OCRResult {
        guard let cgImage = image.cgImageForOCR else { throw OCRError.invalidImage }

        let variants = Self.makeImageVariants(from: cgImage)
        var bestResult: OCRResult?
        var lastError: Error?

        for variant in variants {
            for profile in Self.languageProfiles {
                do {
                    let result = try Self.recognizeText(
                        in: variant.image,
                        sourceImageID: variant.name,
                        preprocessingMethod: variant.name,
                        preferredLanguages: profile
                    )
                    if Self.score(result) > Self.score(bestResult) {
                        bestResult = result
                    }
                } catch {
                    lastError = error
                }
            }
        }

        if let bestResult {
            return bestResult
        }
        if let lastError {
            throw lastError
        }
        throw OCRError.recognitionFailed("텍스트를 찾지 못했습니다.")
    }

    private nonisolated static func recognizeText(
        in cgImage: CGImage,
        sourceImageID: String,
        preprocessingMethod: String,
        preferredLanguages: [String]
    ) throws -> OCRResult {
        var recognizedLines: [OCRRecognizedLine] = []
        var recognitionError: Error?

        let request = VNRecognizeTextRequest { req, err in
            if let err {
                recognitionError = OCRError.recognitionFailed(err.localizedDescription)
                return
            }
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            recognizedLines = observations.compactMap { observation -> OCRRecognizedLine? in
                let candidates = observation.topCandidates(5)
                guard let top = candidates.first else { return nil }
                return OCRRecognizedLine(
                    text: top.string,
                    confidence: top.confidence,
                    boundingBox: observation.boundingBox,
                    candidates: candidates.map(\.string),
                    sourceImageID: sourceImageID,
                    preprocessingMethod: preprocessingMethod
                )
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        request.recognitionLanguages = Self.supportedLanguages(preferredLanguages, for: request)
        if !request.recognitionLanguages.contains(where: { $0.hasPrefix("zh") }) {
            request.customWords = Self.customWords
        }

        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }

        if let recognitionError {
            throw recognitionError
        }

        let lang = Self.detectDominantLanguage(recognizedLines.map(\.text).joined(separator: " "))
        return OCRResult(recognizedLines: recognizedLines, dominantLanguage: lang, preprocessingMethod: preprocessingMethod)
    }

    private nonisolated static let languageProfiles = [
        ["ko-KR", "en-US"],
        ["en-US", "ko-KR"],
        ["zh-Hans", "en-US"],
        ["zh-Hant", "en-US"]
    ]

    private nonisolated static let customWords = [
        "Tel", "TEL", "Phone", "Mobile", "Fax", "Email", "E-mail", "Website",
        "대표", "이사", "부장", "차장", "과장", "대리", "팀장", "실장", "본부장",
        "주식회사", "유한회사", "사업자등록번호", "팩스", "전화", "휴대폰"
    ]

    private struct ImageVariant {
        let name: String
        let image: CGImage
    }

    private nonisolated static func makeImageVariants(from cgImage: CGImage) -> [ImageVariant] {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let input = CIImage(cgImage: cgImage)
        var variants = [ImageVariant(name: "original", image: cgImage)]

        appendVariant(
            named: "document-enhanced",
            image: input
                .applyingFilter("CIDocumentEnhancer")
                .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.45]),
            to: &variants,
            context: context
        )

        let grayscaleHighContrast = input
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.55,
                kCIInputBrightnessKey: 0.02
            ])
            .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.65])

        appendVariant(named: "high-contrast", image: grayscaleHighContrast, to: &variants, context: context)
        appendVariant(
            named: "inverted-high-contrast",
            image: grayscaleHighContrast.applyingFilter("CIColorInvert"),
            to: &variants,
            context: context
        )

        if max(cgImage.width, cgImage.height) < 2400 {
            appendVariant(
                named: "upscaled-document-enhanced",
                image: input
                    .transformed(by: CGAffineTransform(scaleX: 2, y: 2))
                    .applyingFilter("CIDocumentEnhancer")
                    .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.35]),
                to: &variants,
                context: context
            )
        }

        return variants
    }

    private nonisolated static func appendVariant(
        named name: String,
        image: CIImage,
        to variants: inout [ImageVariant],
        context: CIContext
    ) {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0,
              let rendered = context.createCGImage(image, from: extent) else { return }
        variants.append(ImageVariant(name: name, image: rendered))
    }

    private nonisolated static func score(_ result: OCRResult?) -> Double {
        guard let result else { return -.infinity }
        let text = result.fullText
        let emailCount = Self.matchCount(#"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, in: text)
        let phoneCount = Self.matchCount(#"(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{4}"#, in: text)
        let urlCount = Self.matchCount(#"(?:https://|www\.)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+"#, in: text)
        let lineScore = min(Double(result.recognizedLines.count), 16) * 0.08
        let confidenceScore = Double(result.averageConfidence) * 2.0
        return confidenceScore + lineScore + Double(emailCount) * 0.55 + Double(phoneCount) * 0.35 + Double(urlCount) * 0.25
    }

    private nonisolated static func matchCount(_ pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private nonisolated static func supportedLanguages(_ preferred: [String], for request: VNRecognizeTextRequest) -> [String] {
        guard let supported = try? request.supportedRecognitionLanguages() else {
            return preferred
        }
        return preferred.filter { supported.contains($0) }
    }

    private nonisolated static func detectDominantLanguage(_ text: String) -> String {
        var ko = 0, zh = 0, en = 0
        for ch in text.unicodeScalars {
            switch ch.value {
            case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F:  ko += 1
            case 0x4E00...0x9FFF, 0x3400...0x4DBF:                   zh += 1
            case 0x0041...0x005A, 0x0061...0x007A:                   en += 1
            default: break
            }
        }
        if ko >= zh && ko >= en { return "ko" }
        if zh >= en { return "zh" }
        return "en"
    }
}
