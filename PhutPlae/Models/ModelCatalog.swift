import Foundation

enum WhisperModelSize: String, CaseIterable, Identifiable, Sendable {
    case tiny
    case base
    case small

    var id: String { rawValue }

    var thaiLabel: String {
        switch self {
        case .tiny: return "เล็ก · เร็ว (tiny หลายภาษา)"
        case .base: return "กลาง · สมดุล (base หลายภาษา)"
        case .small: return "ใหญ่ · แม่นกว่า (small หลายภาษา)"
        }
    }

    var footnote: String {
        switch self {
        case .tiny: return "ประมาณ 75 MB · ไทย/จีนหลุดคำง่าย"
        case .base: return "ประมาณ 150 MB · ค่าเริ่มต้น ฟังอังกฤษและจีนกลางในโมเดลเดียว"
        case .small: return "ประมาณ 500 MB · แนะนำถ้าสำเนียงจีนกลางหลากหลาย"
        }
    }

    /// Always multilingual — English-only variants cannot hear Mandarin.
    var whisperKitVariant: String { rawValue }
}

enum PromptFamily: String, Sendable {
    case llama3
    case qwen
}

enum TranslatorModelSize: String, CaseIterable, Identifiable, Sendable {
    case typhoon3b
    case typhoon1b
    case qwen15b
    case qwen3_1_7b
    case qwen3b

    var id: String { rawValue }

    var thaiLabel: String {
        switch self {
        case .typhoon3b: return "Typhoon 2 3B · 4-bit"
        case .typhoon1b: return "Typhoon 2 1B · 4-bit"
        case .qwen15b: return "Qwen 2.5 1.5B · 4-bit"
        case .qwen3_1_7b: return "Qwen 3 1.7B · 4-bit"
        case .qwen3b: return "Qwen 2.5 3B · 4-bit"
        }
    }

    var huggingfaceID: String {
        switch self {
        case .typhoon3b: return "typhoon-ai/llama3.2-typhoon2-3b-instruct-mlx-4bit"
        case .typhoon1b: return "typhoon-ai/llama3.2-typhoon2-1b-instruct-mlx-4bit"
        case .qwen15b: return "mlx-community/Qwen2.5-1.5B-Instruct-4bit"
        case .qwen3_1_7b: return "mlx-community/Qwen3-1.7B-4bit"
        case .qwen3b: return "mlx-community/Qwen2.5-3B-Instruct-4bit"
        }
    }

    var promptFamily: PromptFamily {
        switch self {
        case .typhoon3b, .typhoon1b: return .llama3
        case .qwen15b, .qwen3_1_7b, .qwen3b: return .qwen
        }
    }

    var extraEOSTokens: [String] {
        switch promptFamily {
        case .llama3: return ["<|eot_id|>", "<|end_of_text|>"]
        case .qwen: return ["<|im_end|>"]
        }
    }

    var footnote: String {
        switch self {
        case .typhoon3b:
            return "SCB 10X · จูนไทย · ประมาณ 1.7 GB · ค่าเริ่มต้นของอังกฤษ→ไทย"
        case .typhoon1b:
            return "เบา · ประมาณ 0.8 GB"
        case .qwen15b:
            return "เบา · จีนใช้เดินทางได้ · ประมาณ 1.0 GB"
        case .qwen3_1_7b:
            return "Qwen 3 · ประมาณ 1.2 GB"
        case .qwen3b:
            return "จีนกลางดีที่สุดในชุดนี้ · ประมาณ 2.0 GB · ค่าเริ่มต้นของจีน→ไทย"
        }
    }
}

struct LanguagePack: Identifiable, Equatable, Sendable {
    var id: String
    var thaiTitle: String
    var detail: String
    var whisper: WhisperModelSize?
    var translator: TranslatorModelSize?
    var includesSER: Bool = false
}

enum LanguagePackCatalog {
    static func packs(whisper: WhisperModelSize) -> [LanguagePack] {
        [
            LanguagePack(
                id: "whisper",
                thaiTitle: "ชุดฟังเสียง EN + ZH",
                detail: "WhisperKit \(whisper.rawValue) หลายภาษา · ฟังอังกฤษและจีนกลางออฟไลน์",
                whisper: whisper
            ),
            LanguagePack(
                id: "en-th",
                thaiTitle: "ชุดแปลอังกฤษ → ไทย",
                detail: "Typhoon 2 3B Instruct 4-bit · จูนไทยโดย SCB 10X",
                translator: .typhoon3b
            ),
            LanguagePack(
                id: "zh-th",
                thaiTitle: "ชุดแปลจีนกลาง → ไทย",
                detail: "Qwen 2.5 3B Instruct 4-bit · จีนกลางแข็งกว่า Typhoon",
                translator: .qwen3b
            ),
            LanguagePack(
                id: "ser",
                thaiTitle: "ชุดอ่านอารมณ์จากเสียง (SER)",
                detail: "emotion2vec+ seed · Core ML · ไม่ผูกภาษา · ประมาณ 80–140 MB",
                includesSER: true
            )
        ]
    }
}
