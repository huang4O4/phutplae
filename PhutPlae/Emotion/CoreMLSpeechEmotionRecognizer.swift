import CoreML
import Foundation

/// Runs emotion2vec+ seed (Core ML) on raw 16 kHz mono, then smooths window posteriors.
final class CoreMLSpeechEmotionRecognizer: SpeechEmotionRecognizing, @unchecked Sendable {
    private let lock = NSLock()
    private var model: MLModel?
    private var ready = false

    var isReady: Bool {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return ready
        }
    }

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        progress(0.1, "BOOT · SER emotion2vec+ seed")
        let modelURL: URL
        if FileManager.default.fileExists(atPath: SERModelStore.compiledURL.path) {
            modelURL = SERModelStore.compiledURL
        } else if FileManager.default.fileExists(atPath: SERModelStore.packageURL.path) {
            let compiled = try await MLModel.compileModel(at: SERModelStore.packageURL)
            try? FileManager.default.removeItem(at: SERModelStore.compiledURL)
            try FileManager.default.copyItem(at: compiled, to: SERModelStore.compiledURL)
            modelURL = SERModelStore.compiledURL
        } else {
            throw SpeechEmotionError.modelMissing
        }

        let loaded = try await MLModel.load(contentsOf: modelURL, configuration: MLModelConfiguration())
        lock.lock()
        model = loaded
        ready = true
        lock.unlock()
        progress(1.0, "โหลด SER แล้ว")
    }

    func classify(samples: [Float]) async throws -> EmotionDistribution {
        guard !samples.isEmpty else { throw SpeechEmotionError.emptyAudio }
        lock.lock()
        let runtime = model
        lock.unlock()
        guard let runtime else { throw SpeechEmotionError.notReady }

        let windows = SERWindowing.windows(from: samples)
        var smoother = UtteranceEmotionSmoother(alpha: 0.40)
        for window in windows {
            let frame = try infer(window, model: runtime)
            smoother.add(frame)
        }
        return smoother.finalized()
    }

    func releaseMemory() async {
        lock.lock()
        model = nil
        ready = false
        lock.unlock()
    }

    private func infer(_ samples: [Float], model: MLModel) throws -> EmotionDistribution {
        let array = try MLMultiArray(shape: [1, NSNumber(value: samples.count)], dataType: .float32)
        for (index, sample) in samples.enumerated() {
            array[index] = NSNumber(value: sample)
        }
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "audio": MLFeatureValue(multiArray: array)
        ])
        let out = try model.prediction(from: input)
        if let multi = out.featureValue(for: "logits")?.multiArrayValue
            ?? out.featureValue(for: "var_9")?.multiArrayValue {
            return EmotionDistribution.fromEmotion2VecPlus(logits: floats(from: multi))
        }
        if let first = out.featureNames.compactMap({ out.featureValue(for: $0)?.multiArrayValue }).first {
            return EmotionDistribution.fromEmotion2VecPlus(logits: floats(from: first))
        }
        throw SpeechEmotionError.inferenceFailed("โมเดล SER ไม่มีเอาต์พุต logits")
    }

    private func floats(from array: MLMultiArray) -> [Double] {
        let count = array.count
        var values: [Double] = []
        values.reserveCapacity(count)
        for i in 0..<count {
            values.append(array[i].doubleValue)
        }
        return values
    }
}
