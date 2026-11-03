import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject, PipelinePresenting {
    @Published var phase: PipelinePhase = .booting
    @Published var liveSource: String = ""
    @Published var liveTranslation: String = ""
    @Published var liveSourceLanguage: SpokenLanguage?
    @Published var liveEmotion: Emotion = .neutral
    @Published var liveIntensity: Double = 0
    @Published var liveEmotionConfidence: Double = 0
    @Published var liveLatencyMs: Int = 0
    @Published var lastLatency: LatencySplit?
    @Published var turns: [TranscriptTurn] = []
    @Published var errorMessage: String?
    @Published var statusLine: String = "BOOTING SYSTEMS"
    @Published var telemetry = LiveTelemetry()
    @Published var hasEnhancedThaiVoice = false
    @Published var isModelsReady = false
    @Published var justBecameReady = false
    @Published var showPacks = false

    let settings: UserSettings
    let downloads: ModelDownloadManager
    let pathMonitor = PathMonitor()

    private var pipeline: SpeechTranslationPipeline?
    private var transcriber: SpeechTranscribing
    private var translator: TranslationServicing
    private var ser: SpeechEmotionRecognizing
    private let synthesizer: SpeechSynthesizing
    private let capture: MicrophoneCapturing
    private var preparedSignature: String?
    private var bootTask: Task<Void, Never>?
    private var modelsHeldInMemory = false

    init(
        settings: UserSettings? = nil,
        downloads: ModelDownloadManager? = nil,
        transcriber: SpeechTranscribing = WhisperKitTranscriber(),
        translator: TranslationServicing? = nil,
        ser: SpeechEmotionRecognizing = CoreMLSpeechEmotionRecognizer(),
        synthesizer: SpeechSynthesizing = AVSpeechVoiceSynthesizer(),
        capture: MicrophoneCapturing = AVAudioEngineCapture()
    ) {
        // Default arguments are nonisolated; construct MainActor types in this isolated body.
        let settings = settings ?? UserSettings()
        self.settings = settings
        self.downloads = downloads ?? ModelDownloadManager()
        self.transcriber = transcriber
        self.translator = translator ?? PairAwareTranslator(
            policy: settings.translatorPolicy,
            preferredBootSource: settings.downloadedEnglishPack ? .english : .mandarin
        )
        self.ser = ser
        self.synthesizer = synthesizer
        self.capture = capture
        self.hasEnhancedThaiVoice = SpeechVoicePicker.installedEnhancedThaiVoice() != nil
        self.showPacks = !settings.canRunOffline
    }

    var isListening: Bool { pipeline?.isListening == true }

    var isBooting: Bool {
        phase == .booting || phase == .downloading || downloads.isWorking
    }

    var readiness: OfflineReadiness {
        if !settings.canRunOffline { return .packsMissing }
        if isBooting || !isModelsReady { return .booting }
        return pathMonitor.isSatisfied ? .readyOnline : .readyOffline
    }

    func refreshVoiceInventory() {
        hasEnhancedThaiVoice = SpeechVoicePicker.installedEnhancedThaiVoice() != nil
    }

    func bootOnLaunch() {
        guard bootTask == nil else { return }
        bootTask = Task { [weak self] in
            await self?.bootstrapIfNeeded()
            self?.bootTask = nil
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        switch scenePhase {
        case .background:
            Task { await sleepSession() }
        case .active:
            refreshVoiceInventory()
            if settings.canRunOffline {
                bootOnLaunch()
            }
        default:
            break
        }
    }

    func bootstrapIfNeeded() async {
        guard settings.canRunOffline || settings.downloadedWhisperPack else {
            phase = .idle
            statusLine = "ดาวน์โหลดชุดภาษาอย่างน้อยหนึ่งชุดก่อนเดินทาง"
            return
        }

        let signature = modelSignature
        if modelsHeldInMemory,
           preparedSignature == signature,
           await transcriber.isReady,
           await translator.isReady {
            isModelsReady = true
            markReady()
            return
        }

        phase = .booting
        isModelsReady = false
        justBecameReady = false
        statusLine = "BOOTING · โหลดโมเดลจากดิสก์"
        transcriber = WhisperKitTranscriber()
        translator = PairAwareTranslator(
            policy: settings.translatorPolicy,
            preferredBootSource: settings.downloadedEnglishPack ? .english : .mandarin
        )
        ser = CoreMLSpeechEmotionRecognizer()
        do {
            try await downloads.ensureModels(
                whisper: transcriber,
                translator: translator,
                whisperVariant: settings.whisperSize.whisperKitVariant
            )
            if settings.downloadedSERPack || SERModelStore.isOnDisk() {
                try? await ser.prepare { [weak self] fraction, message in
                    Task { @MainActor in
                        guard let self else { return }
                        var next = self.downloads.state
                        next.message = message
                        next.fraction = max(next.fraction, 0.85 + fraction * 0.1)
                        self.downloads.state = next
                    }
                }
            }
            preparedSignature = signature
            modelsHeldInMemory = true
            settings.downloadedWhisperPack = true
            markReady()
        } catch is CancellationError {
            statusLine = "ยกเลิกการบูต"
        } catch {
            phase = .failed
            isModelsReady = false
            modelsHeldInMemory = false
            errorMessage = error.localizedDescription
            statusLine = "BOOT FAILED"
        }
    }

    func downloadPack(_ pack: LanguagePack) async {
        phase = .downloading
        do {
            if let whisper = pack.whisper {
                let engine = WhisperKitTranscriber()
                try await engine.prepare(variant: whisper.whisperKitVariant) { [weak self] fraction, message in
                    Task { @MainActor in
                        self?.downloads.state = ModelDownloadState(
                            fraction: fraction,
                            message: message,
                            isComplete: false,
                            errorMessage: nil
                        )
                    }
                }
                await engine.releaseMemory()
                settings.downloadedWhisperPack = true
            }
            if pack.includesSER {
                try await SERModelStore.download { [weak self] fraction, message in
                    Task { @MainActor in
                        self?.downloads.state = ModelDownloadState(
                            fraction: fraction,
                            message: message,
                            isComplete: false,
                            errorMessage: nil
                        )
                    }
                }
                settings.downloadedSERPack = SERModelStore.isOnDisk() || FileManager.default.fileExists(atPath: SERModelStore.weightsURL.path)
            }
            if let model = pack.translator {
                let engine = MLXOnDeviceTranslator(model: model)
                try await engine.prepare { [weak self] fraction, message in
                    Task { @MainActor in
                        self?.downloads.state = ModelDownloadState(
                            fraction: fraction,
                            message: message,
                            isComplete: false,
                            errorMessage: nil
                        )
                    }
                }
                await engine.releaseMemory()
                if model == .typhoon3b { settings.downloadedEnglishPack = true }
                if model == .qwen3b { settings.downloadedChinesePack = true }
            }
            settings.hasCompletedOnboardingDownload = settings.packsReadyForTravel
            errorMessage = nil
            statusLine = "ชุด \(pack.thaiTitle) อยู่ในเครื่องแล้ว"
            phase = .idle
            if settings.canRunOffline {
                showPacks = false
                bootOnLaunch()
            }
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
            statusLine = "โหลดชุดภาษาไม่สำเร็จ"
        }
    }

    func downloadAllPacks() async {
        for pack in LanguagePackCatalog.packs(whisper: settings.whisperSize) {
            await downloadPack(pack)
            if phase == .failed { return }
        }
    }

    func sleepSession() async {
        bootTask?.cancel()
        bootTask = nil
        pipeline?.stop()
        pipeline = nil
        synthesizer.stop()
        await transcriber.releaseMemory()
        await translator.releaseMemory()
        await ser.releaseMemory()
        modelsHeldInMemory = false
        preparedSignature = nil
        isModelsReady = false
        justBecameReady = false
        telemetry = LiveTelemetry()
        if phase != .failed {
            phase = .idle
            statusLine = "STANDBY · คืนหน่วยความจำโมเดลแล้ว"
        }
    }

    func toggleListening() async {
        if isListening {
            pipeline?.stop()
            statusLine = "หยุดฟังแล้ว"
            return
        }
        guard settings.canRunOffline else {
            showPacks = true
            statusLine = "ดาวน์โหลดชุดภาษาก่อน"
            return
        }
        guard isModelsReady else {
            statusLine = "รอ BOOT ให้จบก่อน"
            bootOnLaunch()
            return
        }
        await bootstrapIfNeeded()
        guard isModelsReady else { return }

        if !(await AVAudioEngineCapture.requestPermission()) {
            errorMessage = "อนุญาตไมโครโฟนในการตั้งค่า iPhone ก่อน"
            phase = .failed
            return
        }

        let pipe = SpeechTranslationPipeline(
            settings: settings,
            capture: capture,
            transcriber: transcriber,
            translator: translator,
            synthesizer: synthesizer,
            ser: ser,
            presenter: self
        )
        pipeline = pipe
        do {
            try pipe.start()
            liveSource = ""
            liveTranslation = ""
            errorMessage = nil
            statusLine = "กำลังฟังอังกฤษหรือจีนกลาง…"
        } catch {
            errorMessage = error.localizedDescription
            phase = .failed
            statusLine = "เปิดไมค์ไม่สำเร็จ"
        }
    }

    func pipelineDidChangePhase(_ phase: PipelinePhase) {
        self.phase = phase
        switch phase {
        case .listening: statusLine = "กำลังฟัง EN / ZH"
        case .transcribing: statusLine = "กำลังถอดข้อความ"
        case .translating: statusLine = "กำลังแปลเป็นไทย"
        case .speaking: statusLine = "กำลังพูดภาษาไทย"
        case .idle: statusLine = isModelsReady ? "READY · ฟังอย่างเดียว" : "STANDBY"
        case .booting, .downloading: statusLine = "BOOTING SYSTEMS"
        case .failed: break
        }
    }

    func pipelineDidEmitPartialSource(_ text: String, language: SpokenLanguage?) {
        liveSource = text
        liveSourceLanguage = language
    }

    func pipelineDidComplete(_ turn: TranscriptTurn) {
        liveSource = turn.sourceText
        liveTranslation = turn.translatedText
        liveSourceLanguage = turn.sourceLanguage
        liveEmotion = turn.emotion
        liveIntensity = turn.intensity
        liveEmotionConfidence = turn.confidence
        lastLatency = turn.latency
        liveLatencyMs = turn.latency.totalMs
        turns.insert(turn, at: 0)
        if turns.count > 40 { turns = Array(turns.prefix(40)) }
    }

    func pipelineDidFail(_ message: String) {
        errorMessage = message
        statusLine = message
    }

    func pipelineDidUpdateLiveLatency(_ milliseconds: Int) {
        liveLatencyMs = milliseconds
    }

    func pipelineDidUpdateTelemetry(pitchHz: Double, loudnessDB: Double, waveform: [Double], energy: Double) {
        var next = telemetry
        next.pitchHz = pitchHz
        next.loudnessDB = loudnessDB
        next.waveform = waveform
        next.energy = energy
        AudioMetering.append(pitchHz, to: &next.pitchHistory)
        AudioMetering.append(loudnessDB, to: &next.loudnessHistory)
        telemetry = next
    }

    private func markReady() {
        phase = .idle
        isModelsReady = true
        errorMessage = nil
        statusLine = "READY · EN/ZH → TH"
        justBecameReady = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            self?.justBecameReady = false
        }
    }

    private var modelSignature: String {
        "\(settings.whisperSize.rawValue)|\(settings.translatorPolicy.rawValue)"
    }
}
