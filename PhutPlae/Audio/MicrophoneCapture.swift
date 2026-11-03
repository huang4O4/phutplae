import AVFoundation
import Foundation

protocol MicrophoneCapturing: AnyObject {
    var isRunning: Bool { get }
    func start(onBuffer: @escaping @Sendable ([Float]) -> Void) throws
    func stop()
}

enum MicrophoneCaptureError: Error, LocalizedError {
    case permissionDenied
    case engineStartFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "ยังไม่ได้อนุญาตไมโครโฟน"
        case .engineStartFailed(let message): return message
        }
    }
}

/// 16 kHz mono tap via AVAudioEngine. Voice-processing is off so angry speech stays raw.
final class AVAudioEngineCapture: MicrophoneCapturing, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var running = false
    private var handler: (@Sendable ([Float]) -> Void)?

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    func start(onBuffer: @escaping @Sendable ([Float]) -> Void) throws {
        try configureSession()
        lock.lock()
        handler = onBuffer
        lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let tapFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw MicrophoneCaptureError.engineStartFailed("สร้างฟอร์แมตไมค์ไม่สำเร็จ")
        }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            guard let samples = Self.monoSamples(from: buffer) else { return }
            let resampled = Self.resample(samples, from: tapFormat.sampleRate, to: 16_000)
            self?.lock.lock()
            let callback = self?.handler
            self?.lock.unlock()
            callback?(resampled)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw MicrophoneCaptureError.engineStartFailed(error.localizedDescription)
        }
        lock.lock()
        running = true
        lock.unlock()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock()
        running = false
        handler = nil
        lock.unlock()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
        )
        try session.setPreferredSampleRate(48_000)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private static func monoSamples(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    /// Linear resampler. Good enough for Whisper 16 kHz input from 44.1/48 kHz taps.
    static func resample(_ samples: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard sourceRate > 0, !samples.isEmpty else { return samples }
        if abs(sourceRate - targetRate) < 1 {
            return samples
        }
        let ratio = sourceRate / targetRate
        let count = max(1, Int(Double(samples.count) / ratio))
        var output = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let src = Double(i) * ratio
            let index = Int(src)
            let frac = Float(src - Double(index))
            let a = samples[min(index, samples.count - 1)]
            let b = samples[min(index + 1, samples.count - 1)]
            output[i] = a + (b - a) * frac
        }
        return output
    }
}
