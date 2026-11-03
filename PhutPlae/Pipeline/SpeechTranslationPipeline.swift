import Foundation

@MainActor
protocol PipelinePresenting: AnyObject {
    func pipelineDidChangePhase(_ phase: PipelinePhase)
    func pipelineDidEmitPartialSource(_ text: String, language: SpokenLanguage?)
    func pipelineDidComplete(_ turn: TranscriptTurn)
    func pipelineDidFail(_ message: String)
    func pipelineDidUpdateLiveLatency(_ milliseconds: Int)
    func pipelineDidUpdateTelemetry(pitchHz: Double, loudnessDB: Double, waveform: [Double], energy: Double)
}

@MainActor
final class SpeechTranslationPipeline {
    private let capture: MicrophoneCapturing
    private let transcriber: SpeechTranscribing
    private let translator: TranslationServicing
    private let synthesizer: SpeechSynthesizing
    private let ser: SpeechEmotionRecognizing
    private weak var presenter: PipelinePresenting?

    private var vad = VoiceActivityDetector()
    private var listening = false
    private var speaking = false
    private var workTask: Task<Void, Never>?
    private var pending = [VoiceActivityDetector.Segment]()
    private var lastTelemetryAt: ContinuousClock.Instant?

    var settings: UserSettings

    init(
        settings: UserSettings,
        capture: MicrophoneCapturing,
        transcriber: SpeechTranscribing,
        translator: TranslationServicing,
        synthesizer: SpeechSynthesizing,
        ser: SpeechEmotionRecognizing,
        presenter: PipelinePresenting
    ) {
        self.settings = settings
        self.capture = capture
        self.transcriber = transcriber
        self.translator = translator
        self.synthesizer = synthesizer
        self.ser = ser
        self.presenter = presenter
    }

    var isListening: Bool { listening }

    func start() throws {
        guard !listening else { return }
        vad.reset()
        pending.removeAll()
        listening = true
        presenter?.pipelineDidChangePhase(.listening)
        try capture.start { [weak self] samples in
            Task { @MainActor in
                self?.ingest(samples)
            }
        }
    }

    func stop() {
        listening = false
        capture.stop()
        synthesizer.stop()
        workTask?.cancel()
        if let leftover = vad.flush() {
            enqueue(leftover)
        }
        presenter?.pipelineDidChangePhase(.idle)
    }

    private func ingest(_ samples: [Float]) {
        guard listening else { return }
        publishTelemetry(samples)
        guard !speaking else { return }
        for segment in vad.push(samples) {
            enqueue(segment)
        }
    }

    private func publishTelemetry(_ samples: [Float]) {
        let now = ContinuousClock.now
        if let last = lastTelemetryAt, last.duration(to: now) < .milliseconds(50) {
            return
        }
        lastTelemetryAt = now
        let rms = VoiceActivityDetector.rms(of: samples)
        presenter?.pipelineDidUpdateTelemetry(
            pitchHz: AcousticEmotionAnalyzer.estimatePitchHz(samples, sampleRate: 16_000) ?? 0,
            loudnessDB: AudioMetering.loudnessDBFS(samples),
            waveform: AudioMetering.waveform(samples),
            energy: min(1, rms * 10)
        )
    }

    private func enqueue(_ segment: VoiceActivityDetector.Segment) {
        pending.append(segment)
        pump()
    }

    private func pump() {
        guard workTask == nil, let segment = pending.first else { return }
        pending.removeFirst()
        workTask = Task { [weak self] in
            await self?.process(segment)
            self?.workTask = nil
            self?.pump()
        }
    }

    private func process(_ segment: VoiceActivityDetector.Segment) async {
        var split = LatencySplit(vadMs: Int(segment.durationSeconds * 1000), sttMs: 0, serMs: 0, translateMs: 0, ttsMs: 0)
        do {
            presenter?.pipelineDidChangePhase(.transcribing)
            let sttStart = ContinuousClock.now
            async let transcriptTask = transcriber.transcribe(
                samples: segment.samples,
                detectLanguage: true
            )
            let serStart = ContinuousClock.now
            async let serTask = classifyEmotion(segment.samples)
            let transcript = try await transcriptTask
            let serResult = await serTask
            split.sttMs = elapsedMs(since: sttStart)
            split.serMs = elapsedMs(since: serStart)
            presenter?.pipelineDidUpdateLiveLatency(split.sttMs)

            let cleaned = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count >= 2 else {
                presenter?.pipelineDidChangePhase(listening ? .listening : .idle)
                return
            }

            let language = transcript.language ?? SpokenLanguage.guess(from: cleaned)
            presenter?.pipelineDidEmitPartialSource(cleaned, language: language)

            guard let language, language.isSourceLanguage else {
                presenter?.pipelineDidFail("ข้าม — ได้ยินไม่ใช่อังกฤษหรือจีนกลาง")
                presenter?.pipelineDidChangePhase(listening ? .listening : .idle)
                return
            }

            let acoustic = AcousticEmotionAnalyzer.estimate(
                from: AcousticEmotionAnalyzer.snapshot(samples: segment.samples)
            )

            presenter?.pipelineDidChangePhase(.translating)
            let txStart = ContinuousClock.now
            let payload = try await translator.translate(
                sourceText: cleaned,
                sourceLanguage: language,
                acousticHint: acoustic
            )
            split.translateMs = elapsedMs(since: txStart)

            let textual = EmotionEstimate(
                emotion: payload.emotion,
                intensity: payload.intensity,
                scores: [payload.emotion: max(0.4, payload.intensity)]
            )
            let fused = EmotionFusion.fuse(
                ser: serResult.distribution,
                acoustic: acoustic,
                textual: textual,
                serAvailable: serResult.available
            )

            let utterance = SpokenUtterance(
                text: payload.spokenText,
                language: "th-TH",
                emotion: fused.emotion,
                intensity: fused.intensity,
                speedScale: settings.clampedVoiceSpeed
            )

            speaking = true
            presenter?.pipelineDidChangePhase(.speaking)
            let ttsStart = ContinuousClock.now
            try await synthesizer.speak(utterance)
            split.ttsMs = elapsedMs(since: ttsStart)
            speaking = false

            presenter?.pipelineDidComplete(
                TranscriptTurn(
                    sourceText: cleaned,
                    translatedText: payload.spokenText,
                    sourceLanguage: language,
                    emotion: fused.emotion,
                    intensity: fused.intensity,
                    confidence: fused.confidence,
                    latency: split
                )
            )
            presenter?.pipelineDidChangePhase(listening ? .listening : .idle)
        } catch is CancellationError {
            speaking = false
        } catch {
            speaking = false
            presenter?.pipelineDidFail(error.localizedDescription)
            presenter?.pipelineDidChangePhase(listening ? .listening : .failed)
        }
    }

    private func classifyEmotion(_ samples: [Float]) async -> (distribution: EmotionDistribution, available: Bool) {
        do {
            return (try await ser.classify(samples: samples), true)
        } catch {
            return (.uniform(confidence: 0), false)
        }
    }

    private func elapsedMs(since start: ContinuousClock.Instant) -> Int {
        Int(start.duration(to: .now) / Duration.milliseconds(1))
    }
}
