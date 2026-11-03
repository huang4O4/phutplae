import Darwin
import Foundation

enum AudioMetering {
    static let historyLimit = 40
    static let waveformBars = 48

    static func loudnessDBFS(_ samples: [Float]) -> Double {
        let rms = VoiceActivityDetector.rms(of: samples)
        guard rms > 0.000_01 else { return -80 }
        return max(-80, 20 * log10(rms))
    }

    static func waveform(_ samples: [Float], bars: Int = waveformBars) -> [Double] {
        guard !samples.isEmpty, bars > 0 else {
            return Array(repeating: 0, count: max(0, bars))
        }
        let window = max(1, samples.count / bars)
        return (0..<bars).map { index in
            let start = index * window
            let end = min(samples.count, start + window)
            guard start < end else { return 0 }
            let slice = Array(samples[start..<end])
            return min(1, VoiceActivityDetector.rms(of: slice) * 8)
        }
    }

    static func append(_ value: Double, to history: inout [Double], limit: Int = historyLimit) {
        history.append(value)
        if history.count > limit {
            history.removeFirst(history.count - limit)
        }
    }
}

struct LiveTelemetry: Equatable, Sendable {
    var pitchHz: Double = 0
    var loudnessDB: Double = -80
    var waveform: [Double] = Array(repeating: 0.04, count: AudioMetering.waveformBars)
    var pitchHistory: [Double] = Array(repeating: 0, count: AudioMetering.historyLimit)
    var loudnessHistory: [Double] = Array(repeating: -80, count: AudioMetering.historyLimit)
    var energy: Double = 0
}
