import Foundation
import CoreGraphics

struct OCRRecognizedLine: Identifiable, Sendable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let candidates: [String]
    let sourceImageID: String
    let preprocessingMethod: String

    init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: CGRect = .zero,
        candidates: [String] = [],
        sourceImageID: String = "front",
        preprocessingMethod: String = "original"
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.candidates = candidates
        self.sourceImageID = sourceImageID
        self.preprocessingMethod = preprocessingMethod
    }
}

struct BusinessCardFieldEvidence: Identifiable, Sendable {
    let id: UUID
    let fieldKey: String
    let value: String
    let alternatives: [String]
    let confidence: Double
    let sourceLineIDs: [UUID]
    let reason: String
    let wasCorrected: Bool
    var wasEditedByUser: Bool

    init(
        id: UUID = UUID(),
        fieldKey: String,
        value: String,
        alternatives: [String] = [],
        confidence: Double,
        sourceLineIDs: [UUID] = [],
        reason: String,
        wasCorrected: Bool = false,
        wasEditedByUser: Bool = false
    ) {
        self.id = id
        self.fieldKey = fieldKey
        self.value = value
        self.alternatives = alternatives
        self.confidence = confidence
        self.sourceLineIDs = sourceLineIDs
        self.reason = reason
        self.wasCorrected = wasCorrected
        self.wasEditedByUser = wasEditedByUser
    }
}

struct BusinessCardParseReview: Sendable {
    var draft: BusinessCardDraft
    var evidence: [BusinessCardFieldEvidence]
    var averageOCRConfidence: Double
    var recognizedLineCount: Int

    func evidence(for fieldKey: String) -> BusinessCardFieldEvidence? {
        evidence.first { $0.fieldKey == fieldKey }
    }
}

enum OCRReadingOrder {
    static func sortedLines(_ lines: [OCRRecognizedLine]) -> [OCRRecognizedLine] {
        let nonEmpty = lines.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !nonEmpty.isEmpty else { return [] }

        let averageHeight = nonEmpty.map { Double($0.boundingBox.height) }.reduce(0, +) / Double(nonEmpty.count)
        let rowTolerance = max(averageHeight * 0.65, 0.012)

        var rows: [[OCRRecognizedLine]] = []
        for line in nonEmpty.sorted(by: { $0.boundingBox.midY > $1.boundingBox.midY }) {
            if let index = rows.firstIndex(where: { row in
                guard let anchor = row.first else { return false }
                return abs(Double(anchor.boundingBox.midY - line.boundingBox.midY)) <= rowTolerance
            }) {
                rows[index].append(line)
            } else {
                rows.append([line])
            }
        }

        return rows.flatMap { row in
            row.sorted { lhs, rhs in
                if abs(lhs.boundingBox.minX - rhs.boundingBox.minX) > 0.02 {
                    return lhs.boundingBox.minX < rhs.boundingBox.minX
                }
                return lhs.boundingBox.midY > rhs.boundingBox.midY
            }
        }
    }
}
