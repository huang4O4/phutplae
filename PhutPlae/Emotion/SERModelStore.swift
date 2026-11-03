import Foundation

enum SERModelCatalog {
    static let displayName = "emotion2vec+ seed"
    static let huggingfaceID = "emotion2vec/emotion2vec_plus_seed"
    static let fileName = "Emotion2VecPlusSeed.mlpackage"
    static let weightsFileName = "model.pt"
    static let coreMLZipURL = URL(string:
        "https://huggingface.co/emotion2vec/emotion2vec_plus_seed/resolve/main/Emotion2VecPlusSeed.mlpackage.zip"
    )!
    static let weightsURL = URL(string:
        "https://huggingface.co/emotion2vec/emotion2vec_plus_seed/resolve/main/model.pt"
    )!
    static let estimatedCoreMLBytes = 110_000_000
}

enum SERModelStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SER", isDirectory: true)
    }

    static var packageURL: URL {
        directory.appendingPathComponent(SERModelCatalog.fileName)
    }

    static var compiledURL: URL {
        directory.appendingPathComponent("Emotion2VecPlusSeed.mlmodelc")
    }

    static var weightsURL: URL {
        directory.appendingPathComponent(SERModelCatalog.weightsFileName)
    }

    static func isOnDisk() -> Bool {
        FileManager.default.fileExists(atPath: packageURL.path)
            || FileManager.default.fileExists(atPath: compiledURL.path)
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func download(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        try ensureDirectory()
        progress(0.05, "ดาวน์โหลด SER · emotion2vec+ seed")

        if let zip = try? await URLSession.shared.download(from: SERModelCatalog.coreMLZipURL) {
            progress(0.75, "กำลังเก็บ Core ML package")
            let dest = directory.appendingPathComponent("Emotion2VecPlusSeed.mlpackage.zip")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: zip.0, to: dest)
            if !isOnDisk() {
                try? FileManager.default.copyItem(at: dest, to: packageURL)
            }
            if isOnDisk() {
                progress(1.0, "โหลดชุด SER แล้ว")
                return
            }
        }

        progress(0.45, "ดึง checkpoint สำหรับแปลงเป็น Core ML บน Mac")
        let (file, _) = try await URLSession.shared.download(from: SERModelCatalog.weightsURL)
        try? FileManager.default.removeItem(at: weightsURL)
        try FileManager.default.moveItem(at: file, to: weightsURL)
        progress(1.0, "ได้ model.pt แล้ว — รัน scripts/convert_emotion2vec_seed_to_coreml.py บน Mac")
    }
}
