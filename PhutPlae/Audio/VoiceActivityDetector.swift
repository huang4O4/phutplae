import Darwin
import Foundation

/// Energy VAD with hangover. Operates on 16 kHz mono Float32 samples.
struct VoiceActivityDetector: Sendable {
    var sampleRate: Double = 16_000
    var frameMs: Double = 20
    var startFrames: Int = 3
    var hangoverFrames: Int = 15
    var minUtteranceMs: Double = 400
    var maxUtteranceMs: Double = 12_000
    var rmsStart: Double = 0.018
    var rmsHold: Double = 0.010

    struct Segment: Equatable, Sendable {
        var samples: [Float]
        var durationSeconds: Double
    }

    private enum State: Sendable {
        case silence
        case speech
    }

    private var state: State = .silence
    private var voicedRun = 0
    private var silentRun = 0
    private var buffer: [Float] = []

    mutating func reset() {
        state = .silence
        voicedRun = 0
        silentRun = 0
        buffer.removeAll(keepingCapacity: true)
    }

    mutating func push(_ samples: [Float]) -> [Segment] {
        guard !samples.isEmpty else { return [] }
        let frameSize = max(1, Int(sampleRate * frameMs / 1000))
        var emitted: [Segment] = []
        var offset = 0
        while offset < samples.count {
            let end = min(samples.count, offset + frameSize)
            let frame = Array(samples[offset..<end])
            offset = end
            if let segment = consume(frame: frame, frameSize: frameSize) {
                emitted.append(segment)
            }
        }
        return emitted
    }

    mutating func flush() -> Segment? {
        defer { reset() }
        return finishCurrentIfValid()
    }

    private mutating func consume(frame: [Float], frameSize: Int) -> Segment? {
        let rms = Self.rms(of: frame)
        switch state {
        case .silence:
            if rms >= rmsStart {
                voicedRun += 1
                buffer.append(contentsOf: frame)
                if voicedRun >= startFrames {
                    state = .speech
                    silentRun = 0
                }
            } else {
                voicedRun = 0
                buffer.removeAll(keepingCapacity: true)
            }
        case .speech:
            buffer.append(contentsOf: frame)
            if rms >= rmsHold {
                silentRun = 0
            } else {
                silentRun += 1
            }
            let durationMs = Double(buffer.count) / sampleRate * 1000
            if silentRun >= hangoverFrames || durationMs >= maxUtteranceMs {
                let segment = finishCurrentIfValid()
                reset()
                return segment
            }
        }
        return nil
    }

    private func finishCurrentIfValid() -> Segment? {
        let durationMs = Double(buffer.count) / sampleRate * 1000
        guard durationMs >= minUtteranceMs, !buffer.isEmpty else { return nil }
        return Segment(samples: buffer, durationSeconds: durationMs / 1000)
    }

    static func rms(of samples: [Float]) -> Double {
        guard !samples.isEmpty else { return 0 }
        var sum: Double = 0
        for sample in samples {
            let v = Double(sample)
            sum += v * v
        }
        return sqrt(sum / Double(samples.count))
    }
}
