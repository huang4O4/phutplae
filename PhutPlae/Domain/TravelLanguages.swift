import Foundation

enum SpokenLanguage: String, Codable, CaseIterable, Sendable {
    case thai
    case english
    case mandarin

    var code: String {
        switch self {
        case .thai: return "th"
        case .english: return "en"
        case .mandarin: return "zh"
        }
    }

    var shortHUD: String {
        switch self {
        case .thai: return "TH"
        case .english: return "EN"
        case .mandarin: return "ZH"
        }
    }

    var thaiName: String {
        switch self {
        case .thai: return "ไทย"
        case .english: return "อังกฤษ"
        case .mandarin: return "จีนกลาง"
        }
    }

    var jsonKey: String {
        switch self {
        case .thai: return "thai"
        case .english: return "english"
        case .mandarin: return "chinese"
        }
    }

    /// Foreign speech the app is allowed to listen to.
    var isSourceLanguage: Bool {
        self == .english || self == .mandarin
    }

    static func fromWhisper(_ raw: String?) -> SpokenLanguage? {
        guard let raw else { return nil }
        let key = raw.lowercased()
        if key.hasPrefix("th") { return .thai }
        if key.hasPrefix("en") { return .english }
        if key.hasPrefix("zh") || key.contains("chinese") || key.hasPrefix("cmn") {
            return .mandarin
        }
        return nil
    }

    static func guess(from text: String) -> SpokenLanguage? {
        var thai = 0
        var han = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            if (0x0E00...0x0E7F).contains(scalar.value) {
                thai += 1
            } else if (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value) {
                han += 1
            } else if CharacterSet.letters.contains(scalar) {
                latin += 1
            }
        }
        let scores: [(SpokenLanguage, Int)] = [(.thai, thai), (.mandarin, han), (.english, latin)]
        let winner = scores.max(by: { $0.1 < $1.1 })
        guard let winner, winner.1 >= 2 else { return nil }
        return winner.0
    }
}

enum TranslatorPolicy: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case typhoon
    case qwen

    var id: String { rawValue }

    var thaiLabel: String {
        switch self {
        case .automatic: return "อัตโนมัติตามภาษาที่ได้ยิน"
        case .typhoon: return "บังคับ Typhoon (เน้น EN→TH)"
        case .qwen: return "บังคับ Qwen (เน้น ZH→TH)"
        }
    }

    var footnote: String {
        switch self {
        case .automatic:
            return "อังกฤษ→ไทยใช้ Typhoon 2 3B (จูนไทย) · จีนกลาง→ไทยใช้ Qwen 2.5 3B (จีนแข็งกว่า) · สลับจากดิสก์เมื่อภาษาเปลี่ยน ไม่ต้องใช้เน็ต"
        case .typhoon:
            return "ใช้ Typhoon ทั้งคู่ภาษา · ไทยเป็นธรรมชาติ แต่จีนกลางด้อยกว่า Qwen"
        case .qwen:
            return "ใช้ Qwen ทั้งคู่ภาษา · จีนกลางดี ไทยใช้ได้ แต่ไม่เท่า Typhoon"
        }
    }

    func model(for source: SpokenLanguage) -> TranslatorModelSize {
        switch self {
        case .automatic:
            return source == .mandarin ? .qwen3b : .typhoon3b
        case .typhoon:
            return .typhoon3b
        case .qwen:
            return .qwen3b
        }
    }
}
