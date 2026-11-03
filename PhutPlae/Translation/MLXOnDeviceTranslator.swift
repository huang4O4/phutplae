import Foundation

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif
#if canImport(MLX)
import MLX
#endif

final class MLXOnDeviceTranslator: TranslationServicing, @unchecked Sendable {
#if canImport(MLXLLM)
    private var container: ModelContainer?
#endif
    private var ready = false
    private let lock = NSLock()
    let model: TranslatorModelSize

    init(model: TranslatorModelSize) {
        self.model = model
    }

    var isReady: Bool {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return ready
        }
    }

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
#if canImport(MLXLLM)
        progress(0.02, "BOOT · \(model.huggingfaceID)")
        let configuration = ModelConfiguration(
            id: model.huggingfaceID,
            extraEOSTokens: model.extraEOSTokens
        )
        let loaded = try await LLMModelFactory.shared.loadContainer(configuration: configuration) { download in
            let fraction = download.fractionCompleted
            progress(min(0.99, max(0.02, fraction)), "ดาวน์โหลดโมเดลแปล \(Int(fraction * 100))%")
        }
        lock.lock()
        container = loaded
        ready = true
        lock.unlock()
        progress(1.0, "โหลด \(model.thaiLabel) แล้ว")
#else
        throw TranslationServiceError.generationFailed("โปรเจกต์นี้ยังลิงก์ MLX LLM ไม่ได้")
#endif
    }

    func translate(
        sourceText: String,
        sourceLanguage: SpokenLanguage,
        acousticHint: EmotionEstimate
    ) async throws -> TranslationPayload {
        let source = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { throw TranslationServiceError.emptySource }
        guard sourceLanguage.isSourceLanguage else { throw TranslationServiceError.unsupportedSource }

#if canImport(MLXLLM)
        lock.lock()
        let runtime = container
        lock.unlock()
        guard let runtime else { throw TranslationServiceError.notReady }

        let prompt = ChatPromptFormatter.render(
            system: TranslationPrompt.systemPrompt(source: sourceLanguage),
            user: TranslationPrompt.userPrompt(sourceText: source, acousticHint: acousticHint),
            family: model.promptFamily
        )

        let raw = try await runtime.perform { context in
            let input = try await context.processor.prepare(input: UserInput(prompt: prompt))
            let parameters = GenerateParameters(
                maxTokens: 220,
                temperature: 0.25,
                topP: 0.9
            )
            let stream = try MLXLMCommon.generate(
                input: input,
                parameters: parameters,
                context: context
            )
            var output = ""
            for await generation in stream {
                if let chunk = generation.chunk {
                    output += chunk
                }
            }
            return output
        }

        return try TranslationJSONParser.parse(raw)
#else
        throw TranslationServiceError.notReady
#endif
    }

    func releaseMemory() async {
        lock.lock()
        ready = false
#if canImport(MLXLLM)
        container = nil
#endif
        lock.unlock()
#if canImport(MLX)
        GPU.set(cacheLimit: 0)
        GPU.clearCache()
#endif
    }
}

/// Loads Typhoon for EN→TH and Qwen for ZH→TH, one engine in RAM at a time.
final class PairAwareTranslator: TranslationServicing, @unchecked Sendable {
    private let policy: TranslatorPolicy
    private let preferredBootSource: SpokenLanguage
    private var engine: MLXOnDeviceTranslator?
    private let lock = NSLock()

    init(policy: TranslatorPolicy, preferredBootSource: SpokenLanguage = .english) {
        self.policy = policy
        self.preferredBootSource = preferredBootSource
    }

    var isReady: Bool {
        get async {
            lock.lock()
            let current = engine
            lock.unlock()
            return await current?.isReady ?? false
        }
    }

    func prepare(progress: @escaping @Sendable (Double, String) -> Void) async throws {
        try await ensureEngine(for: preferredBootSource, progress: progress)
    }

    func translate(
        sourceText: String,
        sourceLanguage: SpokenLanguage,
        acousticHint: EmotionEstimate
    ) async throws -> TranslationPayload {
        try await ensureEngine(for: sourceLanguage) { _, _ in }
        lock.lock()
        let current = engine
        lock.unlock()
        guard let current else { throw TranslationServiceError.notReady }
        return try await current.translate(
            sourceText: sourceText,
            sourceLanguage: sourceLanguage,
            acousticHint: acousticHint
        )
    }

    func releaseMemory() async {
        lock.lock()
        let current = engine
        engine = nil
        lock.unlock()
        await current?.releaseMemory()
    }

    private func ensureEngine(
        for source: SpokenLanguage,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        let needed = policy.model(for: source)
        lock.lock()
        let current = engine
        lock.unlock()
        if let current, current.model == needed, await current.isReady {
            return
        }
        await current?.releaseMemory()
        let next = MLXOnDeviceTranslator(model: needed)
        try await next.prepare(progress: progress)
        lock.lock()
        engine = next
        lock.unlock()
    }
}
