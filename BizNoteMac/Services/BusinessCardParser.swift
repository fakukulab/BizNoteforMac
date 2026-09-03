import Foundation

enum BusinessCardParser {

    private static let emailRegex = try! NSRegularExpression(
        pattern: #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)
    private static let urlRegex = try! NSRegularExpression(
        pattern: #"(?:https://|www\.)[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+(?::\d+)?(?:/[^\s]*)?"#)
    private static let phoneRegex = try! NSRegularExpression(
        pattern: #"(?:\+\d{1,3}[-.\s]?(?:\(?\d{1,4}\)?[-.\s]?){1,4}\d{3,4}|(?:\+?\d{1,3}[-.\s]?)?(?:\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{4})"#)

    private static let jobTitleKeywords = [
        "대표", "이사", "부장", "차장", "과장", "대리", "주임", "사원", "팀장", "실장",
        "부사장", "사장", "회장", "본부장", "책임", "선임", "수석", "매니저", "연구원",
        "CEO", "COO", "CFO", "CTO", "President", "Director", "Manager", "Engineer",
        "Founder", "Head", "Lead", "Senior", "Principal", "Chief", "Officer", "Chairman", "Chair",
        "总经理", "经理", "总监", "主管"
    ]
    private static let companyKeywords = [
        "㈜", "(주)", "|주|", "주식회사", "유한회사", "협회", "Inc.", "Inc", "Corp", "Corporation", "Ltd", "LLC",
        "Co.,", "Co.", "Company", "Group", "有限公司", "股份公司", "集团"
    ]
    private static let addressKeywords = [
        "시 ", "도 ", "구 ", "동 ", "로 ", "길 ", "번지", "층", "호",
        "Street", "St.", "Ave", "Road", "Rd.", "Blvd", "Suite", "Floor",
        "市", "区", "路", "号"
    ]
    private static let departmentKeywords = [
        "팀", "부", "본부", "실", "센터", "연구소", "사업부", "영업부", "마케팅", "개발팀",
        "Department", "Dept", "Division", "Team", "Center", "Laboratory", "Lab"
    ]

    static func parse(_ ocr: OCRResult) -> BusinessCardDraft {
        parseForReview(ocr).draft
    }

    static func parseForReview(_ ocr: OCRResult) -> BusinessCardParseReview {
        var draft = BusinessCardDraft()
        draft.scannedLanguage = ocr.dominantLanguage

        let lines = OCRReadingOrder.sortedLines(ocr.recognizedLines).map { line in
            ParsedLine(source: line, normalized: normalizeSpacing(line.text))
        }
        var remaining = lines
        var evidence: [BusinessCardFieldEvidence] = []

        if let match = firstFieldMatch(emailRegex, in: remaining) {
            let value = normalizeEmail(match.value)
            draft.email = value
            evidence.append(fieldEvidence("email", value: value, match: match, reason: "이메일 패턴과 일치"))
            removeLine(id: match.line.source.id, from: &remaining)
        }

        if let match = firstURLMatch(in: remaining, excludingEmail: draft.email) {
            let value = match.value.hasPrefix("http") ? match.value : "https://\(match.value)"
            draft.website = value
            evidence.append(fieldEvidence("website", value: value, match: match, reason: "웹사이트 도메인 패턴과 일치"))
            removeLine(id: match.line.source.id, from: &remaining)
        }

        let phoneMatches = sortedPhoneMatches(phoneFieldMatches(in: remaining))
        for match in phoneMatches {
            switch match.label {
            case .fax:
                break
            case .work where draft.officePhone.isEmpty:
                draft.officePhone = match.value
                evidence.append(fieldEvidence("officePhone", value: match.value, match: match.match, reason: "업무/대표 전화 레이블 주변의 전화번호"))
            case .mobile where draft.phone.isEmpty:
                draft.phone = match.value
                evidence.append(fieldEvidence("phone", value: match.value, match: match.match, reason: "휴대폰 레이블 주변의 전화번호"))
            case .unknown where draft.phone.isEmpty:
                draft.phone = match.value
                evidence.append(fieldEvidence("phone", value: match.value, match: match.match, confidence: 0.55, reason: "전화번호 형식과 일치하지만 레이블 없음"))
            case .unknown where draft.officePhone.isEmpty:
                draft.officePhone = match.value
                evidence.append(fieldEvidence("officePhone", value: match.value, match: match.match, confidence: 0.50, reason: "추가 전화번호 후보"))
            default:
                break
            }
            removeLine(id: match.match.line.source.id, from: &remaining)
        }

        var jobTitleMatch: FieldMatch?
        if let pair = bestRoleDepartmentPairCandidate(in: remaining) {
            draft.jobTitle = pair.jobTitle.value
            draft.department = pair.department.value
            jobTitleMatch = pair.jobTitle
            evidence.append(fieldEvidence("jobTitle", value: pair.jobTitle.value, match: pair.jobTitle, confidence: confidence(from: pair.jobTitle.score), reason: "/ 또는 | 기준 짧은 항목을 직급으로 분리"))
            evidence.append(fieldEvidence("department", value: pair.department.value, match: pair.department, confidence: confidence(from: pair.department.score), reason: "/ 또는 | 기준 긴 항목을 부서로 분리"))
            removeLine(id: pair.sourceLineID, from: &remaining)
        } else if let match = bestJobTitleCandidate(in: remaining) {
            draft.jobTitle = match.value
            jobTitleMatch = match
            evidence.append(fieldEvidence("jobTitle", value: match.value, match: match, confidence: confidence(from: match.score), reason: "직책 키워드/짧은 역할명 점수"))
            removeLine(id: match.line.source.id, from: &remaining)
        }

        if draft.name.isEmpty, let match = bestNameCandidate(in: remaining, email: draft.email, jobTitleLine: jobTitleMatch?.line) {
            draft.name = match.value
            evidence.append(fieldEvidence("name", value: match.value, match: match, confidence: confidence(from: match.score), reason: "직급 위/왼쪽 옆 텍스트 우선/이름 형식 점수"))
            removeLine(id: match.line.source.id, from: &remaining)
        }

        if draft.department.isEmpty, let match = bestDepartmentCandidate(in: remaining) {
            draft.department = match.value
            evidence.append(fieldEvidence("department", value: match.value, match: match, confidence: confidence(from: match.score), reason: "부서/조직 단위 키워드 점수"))
            removeLine(id: match.line.source.id, from: &remaining)
        }

        if let match = bestCompanyCandidate(in: remaining) {
            draft.company = match.value
            evidence.append(fieldEvidence("company", value: match.value, match: match, confidence: confidence(from: match.score), reason: "회사명 키워드/길이/위치 점수"))
            removeLine(id: match.line.source.id, from: &remaining)
        }

        draft.memo = remaining.map(\.normalized).filter { $0 != draft.company }.joined(separator: "\n")

        return BusinessCardParseReview(
            draft: draft,
            evidence: evidence,
            averageOCRConfidence: Double(ocr.averageConfidence),
            recognizedLineCount: ocr.recognizedLines.count
        )
    }

    private struct ParsedLine {
        let source: OCRRecognizedLine
        let normalized: String

        var candidateTexts: [String] {
            var seen = Set<String>()
            return ([source.text] + source.candidates).compactMap { candidate in
                let normalizedCandidate = normalizeSpacing(candidate)
                guard !normalizedCandidate.isEmpty, seen.insert(normalizedCandidate).inserted else {
                    return nil
                }
                return normalizedCandidate
            }
        }
    }

    private struct FieldMatch {
        let line: ParsedLine
        let value: String
        var wasCorrected: Bool = false
        var score: Double = 0
    }

    private enum PhoneLabel {
        case mobile, work, fax, unknown
    }

    private struct PhoneMatch {
        let match: FieldMatch
        let value: String
        let label: PhoneLabel
    }

    private struct RoleDepartmentPair {
        let sourceLineID: UUID
        let jobTitle: FieldMatch
        let department: FieldMatch
    }

    private static func firstFieldMatch(_ regex: NSRegularExpression, in lines: [ParsedLine]) -> FieldMatch? {
        for line in lines {
            for candidate in line.candidateTexts {
                let corrected = correctContactContext(candidate)
                if let value = firstMatch(regex, in: corrected.value) {
                    return FieldMatch(line: line, value: value, wasCorrected: corrected.wasCorrected)
                }
            }
        }
        return nil
    }

    private static func firstURLMatch(in lines: [ParsedLine], excludingEmail email: String) -> FieldMatch? {
        let emailDomain = email.split(separator: "@").last.map(String.init)?.lowercased()
        for line in lines {
            for candidate in line.candidateTexts {
                let corrected = correctContactContext(candidate)
                for value in matches(urlRegex, in: corrected.value) {
                    let lower = value.lowercased()
                    guard lower.hasPrefix("www.") || lower.hasPrefix("https://") else { continue }
                    if lower.contains("@") { continue }
                    if let emailDomain, lower == emailDomain || lower == "www.\(emailDomain)" { continue }
                    return FieldMatch(line: line, value: value, wasCorrected: corrected.wasCorrected)
                }
            }
        }
        return nil
    }

    private static func phoneFieldMatches(in lines: [ParsedLine]) -> [PhoneMatch] {
        var results: [PhoneMatch] = []
        for line in lines {
            for candidate in line.candidateTexts {
                let corrected = correctPhoneContext(candidate)
                for value in matches(phoneRegex, in: corrected.value) where digits(value).count >= 8 {
                    guard !results.contains(where: { $0.value == value && $0.match.line.source.id == line.source.id }) else {
                        continue
                    }
                    results.append(PhoneMatch(
                        match: FieldMatch(line: line, value: value, wasCorrected: corrected.wasCorrected),
                        value: value,
                        label: phoneLabel(for: candidate, phoneNumber: value)
                    ))
                }
            }
        }
        return results
    }

    private static func bestRoleDepartmentPairCandidate(in lines: [ParsedLine]) -> RoleDepartmentPair? {
        lines.compactMap { line -> RoleDepartmentPair? in
            guard !isLikelyTopLeftLogoText(line), !isContactLike(line.normalized), !looksLikeAddress(line.normalized) else {
                return nil
            }
            for candidate in line.candidateTexts {
                let parts = candidate
                    .split(whereSeparator: { $0 == "/" || $0 == "|" })
                    .map { normalizeSpacing(String($0)) }
                    .filter { !$0.isEmpty }
                guard parts.count == 2 else { continue }

                let lhsWordCount = wordCount(parts[0])
                let rhsWordCount = wordCount(parts[1])
                let lhsIsJobTitle = if lhsWordCount != rhsWordCount {
                    lhsWordCount < rhsWordCount
                } else {
                    parts[0].count < parts[1].count
                }

                let jobTitle = lhsIsJobTitle ? parts[0] : parts[1]
                let department = lhsIsJobTitle ? parts[1] : parts[0]
                guard jobTitle.count <= 24, department.count <= 48 else { continue }

                let baseScore = 0.78 + min(Double(abs(lhsWordCount - rhsWordCount)) * 0.06, 0.18)
                return RoleDepartmentPair(
                    sourceLineID: line.source.id,
                    jobTitle: FieldMatch(line: line, value: jobTitle, score: baseScore),
                    department: FieldMatch(line: line, value: department, score: baseScore - 0.04)
                )
            }
            return nil
        }
        .max { lhs, rhs in lhs.jobTitle.score < rhs.jobTitle.score }
    }

    private static func bestAddressCandidate(in lines: [ParsedLine]) -> FieldMatch? {
        bestCandidate(in: lines, minimumScore: 0.60) { line, value in
            guard value.count >= 8, !isContactLike(value) else { return 0 }
            var score = 0.0
            if addressKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score += 0.62 }
            if value.range(of: #"\d{2,5}"#, options: .regularExpression) != nil { score += 0.15 }
            if value.range(of: #"(로|길|번길|Street|St\.|Road|Rd\.|Ave|号)"#, options: [.regularExpression, .caseInsensitive]) != nil { score += 0.18 }
            if line.source.boundingBox.midY < 0.45 { score += 0.08 }
            if value.count >= 18 { score += 0.10 }
            return score
        }
    }

    private static func bestJobTitleCandidate(in lines: [ParsedLine]) -> FieldMatch? {
        bestCandidate(in: lines, minimumScore: 0.48) { line, value in
            guard value.count <= 36, !isContactLike(value), !looksLikeAddress(value), !isLikelyTopLeftLogoText(line) else { return 0 }
            var score = 0.0
            if jobTitleKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score += 0.68 }
            if value.range(of: #"(CEO|COO|CFO|CTO|CIO|CPO|VP|PM|Chairman|Chair|Designer|Developer|Sales)"#, options: [.regularExpression, .caseInsensitive]) != nil { score += 0.30 }
            if value.count <= 14 { score += 0.10 }
            if line.source.boundingBox.midY > 0.35 && line.source.boundingBox.midY < 0.85 { score += 0.06 }
            if companyKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score -= 0.45 }
            if value.range(of: #"^[가-힣]{2,5}$"#, options: .regularExpression) != nil { score -= 0.35 }
            return score
        }
    }

    private static func bestDepartmentCandidate(in lines: [ParsedLine]) -> FieldMatch? {
        bestCandidate(in: lines, minimumScore: 0.50) { line, value in
            guard value.count <= 40, !isContactLike(value), !looksLikeAddress(value), !isLikelyTopLeftLogoText(line) else { return 0 }
            var score = 0.0
            if departmentKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score += 0.55 }
            if value.range(of: #"(팀|부|본부|실|센터|연구소)$"#, options: .regularExpression) != nil { score += 0.22 }
            if jobTitleKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score -= 0.25 }
            if companyKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score -= 0.25 }
            if line.source.boundingBox.midY > 0.25 && line.source.boundingBox.midY < 0.80 { score += 0.05 }
            return score
        }
    }

    private static func bestCompanyCandidate(in lines: [ParsedLine]) -> FieldMatch? {
        bestCandidate(in: lines, minimumScore: 0.42) { line, value in
            guard value.count >= 2, !isContactLike(value), !looksLikeAddress(value) else { return 0 }
            var score = 0.0
            if companyKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score += 0.68 }
            if value.range(of: #"(주식회사|\(주\)|\|주\||㈜|협회|Inc\.?|Corp\.?|Corporation|Ltd\.?|LLC|Company|Group|Co\.?,?)"#, options: [.regularExpression, .caseInsensitive]) != nil { score += 0.18 }
            if value.count >= 8 { score += 0.16 }
            if line.source.boundingBox.midY > 0.55 { score += 0.12 }
            if line.source.boundingBox.height > 0.045 { score += 0.08 }
            if jobTitleKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score -= 0.45 }
            if departmentKeywords.contains(where: { value.localizedCaseInsensitiveContains($0) }) { score -= 0.25 }
            if value.range(of: #"^[가-힣]{2,5}$"#, options: .regularExpression) != nil { score -= 0.35 }
            return score
        }
    }

    private static func bestNameCandidate(in lines: [ParsedLine], email: String, jobTitleLine: ParsedLine?) -> FieldMatch? {
        if let jobTitleLine,
           let nearJobTitle = bestNameNearJobTitleCandidate(in: lines, jobTitleLine: jobTitleLine) {
            return nearJobTitle
        }

        let userName = email.split(separator: "@").first.map { String($0).lowercased() }
        let candidates = lines.filter { line in
            let text = line.normalized
            return text.count >= 2 && text.count <= 24 &&
                !isLikelyTopLeftLogoText(line) &&
                !text.contains(where: { $0.isNumber }) &&
                !text.contains("@") &&
                !text.contains(".") &&
                !companyKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) &&
                !departmentKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) &&
                !jobTitleKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) })
        }
        return candidates.compactMap { line -> FieldMatch? in
            let score = nameScore(line, emailUserName: userName)
            guard score >= 0.45 else { return nil }
            return FieldMatch(line: line, value: normalizedNameValue(line.normalized), score: score)
        }
        .max { lhs, rhs in lhs.score < rhs.score }
    }

    private static func bestNameNearJobTitleCandidate(in lines: [ParsedLine], jobTitleLine: ParsedLine) -> FieldMatch? {
        lines.compactMap { line -> FieldMatch? in
            let text = line.normalized
            guard text.count >= 2 && text.count <= 24,
                  !isLikelyTopLeftLogoText(line),
                  !isContactLike(text),
                  !looksLikeAddress(text),
                  !text.contains(where: { $0.isNumber }),
                  !companyKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) }),
                  !departmentKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) }),
                  !jobTitleKeywords.contains(where: { text.localizedCaseInsensitiveContains($0) }) else {
                return nil
            }

            let horizontalDistance = abs(line.source.boundingBox.midX - jobTitleLine.source.boundingBox.midX)
            let verticalDistance = abs(line.source.boundingBox.midY - jobTitleLine.source.boundingBox.midY)
            let verticalGap = line.source.boundingBox.minY - jobTitleLine.source.boundingBox.maxY
            let isAboveJobTitle = line.source.boundingBox.midY > jobTitleLine.source.boundingBox.midY &&
                verticalGap >= -0.02 &&
                verticalGap <= 0.16 &&
                (horizontalDistance <= 0.28 || horizontallyOverlaps(line, jobTitleLine, padding: 0.08))
            let horizontalGap = jobTitleLine.source.boundingBox.minX - line.source.boundingBox.maxX
            let isLeftOfJobTitle = line.source.boundingBox.midX < jobTitleLine.source.boundingBox.midX &&
                horizontalGap >= -0.02 &&
                horizontalGap <= 0.18 &&
                verticalDistance <= max(line.source.boundingBox.height, jobTitleLine.source.boundingBox.height) * 0.85
            guard isAboveJobTitle || isLeftOfJobTitle else { return nil }

            var score = 1.15
            if isAboveJobTitle {
                score += max(0, 0.16 - Double(verticalGap)) * 1.5
            }
            if isLeftOfJobTitle {
                score += max(0, 0.18 - Double(horizontalGap)) * 1.2 + 0.20
            }
            if isSpacedKoreanName(text) { score += 0.45 }
            if text.range(of: #"^[가-힣]{2,5}$"#, options: .regularExpression) != nil { score += 0.25 }
            if text.range(of: #"^[A-Za-z .]{3,24}$"#, options: .regularExpression) != nil { score += 0.12 }
            if horizontalDistance <= 0.10 { score += 0.12 }
            return FieldMatch(line: line, value: normalizedNameValue(text), score: score)
        }
        .max { lhs, rhs in lhs.score < rhs.score }
    }

    private static func nameScore(_ line: ParsedLine, emailUserName: String?) -> Double {
        var score = 0.0
        let text = line.normalized
        if isSpacedKoreanName(text) { score += 0.70 }
        if text.count <= 12 { score += 0.35 }
        if line.source.boundingBox.midY > 0.55 { score += 0.15 }
        if text.range(of: #"^[가-힣]{2,5}$"#, options: .regularExpression) != nil { score += 0.25 }
        if text.range(of: #"^[A-Za-z .]{3,24}$"#, options: .regularExpression) != nil { score += 0.15 }
        if let emailUserName, !emailUserName.isEmpty,
           text.lowercased().split(separator: " ").contains(where: { emailUserName.contains($0) }) {
            score += 0.15
        }
        return score
    }

    private static func isSpacedKoreanName(_ text: String) -> Bool {
        let parts = text.split(separator: " ").map(String.init)
        guard parts.count >= 2, parts.count <= 5 else { return false }
        return parts.allSatisfy { part in
            part.count == 1 && part.range(of: #"^[가-힣]$"#, options: .regularExpression) != nil
        }
    }

    private static func normalizedNameValue(_ text: String) -> String {
        isSpacedKoreanName(text) ? text.replacingOccurrences(of: " ", with: "") : text
    }

    private static func wordCount(_ text: String) -> Int {
        let words = text.split { $0.isWhitespace || $0 == "-" || $0 == "_" }
        return max(words.count, text.count <= 4 ? 1 : words.count)
    }

    private static func bestCandidate(
        in lines: [ParsedLine],
        minimumScore: Double,
        score: (ParsedLine, String) -> Double
    ) -> FieldMatch? {
        lines.compactMap { line -> FieldMatch? in
            line.candidateTexts.compactMap { value -> FieldMatch? in
                let candidateScore = score(line, value)
                guard candidateScore >= minimumScore else { return nil }
                return FieldMatch(line: line, value: value, score: candidateScore)
            }
            .max { lhs, rhs in lhs.score < rhs.score }
        }
        .max { lhs, rhs in lhs.score < rhs.score }
    }

    private static func confidence(from score: Double) -> Double {
        min(max(0.45 + score * 0.40, 0.48), 0.92)
    }

    private static func isContactLike(_ text: String) -> Bool {
        firstMatch(emailRegex, in: text) != nil ||
            firstMatch(phoneRegex, in: correctPhoneContext(text).value) != nil ||
            text.localizedCaseInsensitiveContains("www.") ||
            text.localizedCaseInsensitiveContains("http")
    }

    private static func looksLikeAddress(_ text: String) -> Bool {
        text.count >= 8 && addressKeywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func horizontallyOverlaps(_ lhs: ParsedLine, _ rhs: ParsedLine, padding: CGFloat) -> Bool {
        lhs.source.boundingBox.maxX >= rhs.source.boundingBox.minX - padding &&
            lhs.source.boundingBox.minX <= rhs.source.boundingBox.maxX + padding
    }

    private static func isLikelyTopLeftLogoText(_ line: ParsedLine) -> Bool {
        let box = line.source.boundingBox
        let text = line.normalized
        return box.minX < 0.22 &&
            box.midY > 0.72 &&
            (box.height > 0.045 || text.count <= 12) &&
            !isContactLike(text)
    }

    private static func phoneLabel(for text: String, phoneNumber: String = "") -> PhoneLabel {
        let lower = text.lowercased()
        if isMobilePhoneNumber(phoneNumber.isEmpty ? text : phoneNumber) { return .mobile }
        if lower.contains("fax") || text.contains("팩스") || text.contains("传真") || hasShortLabel("f", in: lower) { return .fax }
        if lower.contains("mobile") || lower.contains("mob") || lower.contains("cell") || lower.contains("h/p") || lower.contains("hp") || text.contains("휴대폰") || hasShortLabel("m", in: lower) { return .mobile }
        if lower.contains("tel") || lower.contains("telephone") || lower.contains("office") || lower.contains("direct") || text.contains("대표") || text.contains("전화") || text.contains("직통") || text.contains("电话") || hasShortLabel("t", in: lower) { return .work }
        return .unknown
    }

    private static func sortedPhoneMatches(_ matches: [PhoneMatch]) -> [PhoneMatch] {
        matches.sorted { lhs, rhs in
            let lhsPriority = phonePriority(lhs.label)
            let rhsPriority = phonePriority(rhs.label)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.match.line.source.boundingBox.midY > rhs.match.line.source.boundingBox.midY
        }
    }

    private static func phonePriority(_ label: PhoneLabel) -> Int {
        switch label {
        case .mobile: return 0
        case .work: return 1
        case .fax: return 2
        case .unknown: return 3
        }
    }

    private static func hasShortLabel(_ label: String, in text: String) -> Bool {
        text.range(of: #"(^|\s)\#(label)[\s.:-]+"#, options: .regularExpression) != nil
    }

    private static func isMobilePhoneNumber(_ text: String) -> Bool {
        let compact = text
            .filter { $0.isNumber || $0 == "+" }
        return compact.hasPrefix("010") || compact.hasPrefix("+8210")
    }

    private static func normalizeSpacing(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeEmail(_ email: String) -> String {
        let trimmed = email.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:()[]{}<>"))
        let parts = trimmed.split(separator: "@", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return trimmed }
        return "\(parts[0])@\(parts[1].lowercased())"
    }

    private static func correctContactContext(_ text: String) -> (value: String, wasCorrected: Bool) {
        var corrected = normalizeSpacing(text)
        let replacements = [
            ("＠", "@"),
            ("﹫", "@"),
            (" at ", "@"),
            (" dot ", "."),
            ("．", "."),
            ("。", "."),
            ("，", "."),
            ("＿", "_")
        ]
        for (old, new) in replacements {
            corrected = corrected.replacingOccurrences(of: old, with: new, options: .caseInsensitive)
        }
        corrected = corrected.replacingOccurrences(of: #"(?<=\S)\s*@\s*(?=\S)"#, with: "@", options: .regularExpression)
        corrected = corrected.replacingOccurrences(of: #"(?<=\S)\s*\.\s*(?=\S)"#, with: ".", options: .regularExpression)
        return (corrected, corrected != text)
    }

    private static func correctPhoneContext(_ text: String) -> (value: String, wasCorrected: Bool) {
        guard phoneLabel(for: text) != .unknown || text.range(of: #"\d[-\d .()]{6,}\d"#, options: .regularExpression) != nil else {
            return (text, false)
        }
        var corrected = text
        let replacements = [("O", "0"), ("o", "0"), ("I", "1"), ("l", "1"), ("S", "5"), ("B", "8")]
        for (old, new) in replacements {
            corrected = corrected.replacingOccurrences(of: old, with: new)
        }
        return (corrected, corrected != text)
    }

    private static func fieldEvidence(_ key: String, value: String, match: FieldMatch, confidence: Double? = nil, reason: String) -> BusinessCardFieldEvidence {
        BusinessCardFieldEvidence(
            fieldKey: key,
            value: value,
            alternatives: match.line.source.candidates.filter { $0 != value },
            confidence: confidence ?? Double(match.line.source.confidence),
            sourceLineIDs: [match.line.source.id],
            reason: reason,
            wasCorrected: match.wasCorrected
        )
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> String? {
        matches(regex, in: text).first
    }

    private static func matches(_ regex: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return String(text[r]).trimmingCharacters(in: CharacterSet(charactersIn: " .,;:()[]{}<>"))
        }
    }

    private static func digits(_ s: String) -> String {
        s.filter { $0.isNumber }
    }

    private static func removeLine(id: UUID, from lines: inout [ParsedLine]) {
        lines.removeAll { $0.source.id == id }
    }
}
