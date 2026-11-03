import Foundation

/// On-device acoustic affect from loudness, pitch, rate and energy dynamics.
enum AcousticEmotionAnalyzer {
    static func snapshot(samples: [Float], sampleRate: Double = 16_000) -> AcousticSnapshot {
        guard !samples.isEmpty else {
            return AcousticSnapshot(
                rms: 0,
                peakRMS: 0,
                pitchHz: nil,
                energyVariance: 0,
                speakingRate: 0,
                durationSeconds: 0
            )
        }

        let duration = Double(samples.count) / sampleRate
        let frameSize = max(1, Int(sampleRate * 0.02))
        var frameEnergies: [Double] = []
        var pitches: [Double] = []
        var bursts = 0
        var previouslyVoiced = false
        var peak: Double = 0
        var offset = 0

        while offset < samples.count {
            let end = min(samples.count, offset + frameSize)
            let frame = Array(samples[offset..<end])
            offset = end
            let energy = VoiceActivityDetector.rms(of: frame)
            frameEnergies.append(energy)
            peak = max(peak, energy)
            let voiced = energy >= 0.012
            if voiced, let f0 = estimatePitchHz(frame, sampleRate: sampleRate) {
                pitches.append(f0)
            }
            if voiced && !previouslyVoiced {
                bursts += 1
            }
            previouslyVoiced = voiced
        }

        let mean = frameEnergies.reduce(0, +) / Double(max(1, frameEnergies.count))
        let variance: Double = {
            guard frameEnergies.count > 1 else { return 0 }
            let ss = frameEnergies.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            return sqrt(ss / Double(frameEnergies.count - 1)) / max(0.0001, mean)
        }()

        let medianPitch: Double? = {
            guard !pitches.isEmpty else { return nil }
            let sorted = pitches.sorted()
            return sorted[sorted.count / 2]
        }()

        let rate = duration > 0 ? Double(bursts) / duration : 0

        return AcousticSnapshot(
            rms: mean,
            peakRMS: peak,
            pitchHz: medianPitch,
            energyVariance: variance,
            speakingRate: rate,
            durationSeconds: duration
        )
    }

    static func estimate(from snapshot: AcousticSnapshot) -> EmotionEstimate {
        var scores: [Emotion: Double] = Dictionary(uniqueKeysWithValues: Emotion.allCases.map { ($0, 0.05) })

        let loud = normalize(snapshot.peakRMS, low: 0.02, high: 0.18)
        let meanLoud = normalize(snapshot.rms, low: 0.008, high: 0.08)
        let rate = normalize(snapshot.speakingRate, low: 1.5, high: 6.5)
        let variance = normalize(snapshot.energyVariance, low: 0.2, high: 1.4)
        let pitch: Double = {
            guard let hz = snapshot.pitchHz else { return 0.45 }
            return normalize(hz, low: 90, high: 280)
        }()

        scores[.angry] = 0.15 + 0.45 * loud + 0.25 * variance + 0.15 * rate + 0.10 * pitch
        scores[.happy] = 0.10 + 0.30 * pitch + 0.25 * rate + 0.20 * meanLoud + 0.10 * (1 - variance)
        scores[.sad] = 0.12 + 0.40 * (1 - meanLoud) + 0.30 * (1 - rate) + 0.20 * (1 - pitch)
        scores[.fearful] = 0.10 + 0.35 * pitch + 0.25 * rate + 0.20 * (1 - meanLoud) + 0.15 * variance
        scores[.surprised] = 0.08 + 0.35 * pitch + 0.25 * variance + 0.20 * loud + 0.10 * rate
        scores[.neutral] = 0.35 + 0.25 * (1 - abs(meanLoud - 0.4)) + 0.20 * (1 - variance) + 0.15 * (1 - abs(rate - 0.4))

        let winner = scores.max { $0.value < $1.value }?.key ?? .neutral
        let top = scores[winner] ?? 0
        let second = scores
            .filter { $0.key != winner }
            .map(\.value)
            .max() ?? 0
        let intensity = TranslationPayload.clampIntensity((top - second) * 1.4 + 0.25 * loud)

        return EmotionEstimate(emotion: winner, intensity: intensity, scores: scores)
    }

    static func estimatePitchHz(_ samples: [Float], sampleRate: Double) -> Double? {
        let minHz = 70.0
        let maxHz = 350.0
        let minLag = Int(sampleRate / maxHz)
        let maxLag = Int(sampleRate / minHz)
        guard samples.count > maxLag + 2 else { return nil }

        var bestLag = 0
        var bestCorr = 0.0
        let n = samples.count
        for lag in minLag...min(maxLag, n / 2) {
            var corr = 0.0
            var normA = 0.0
            var normB = 0.0
            let count = n - lag
            for i in 0..<count {
                let a = Double(samples[i])
                let b = Double(samples[i + lag])
                corr += a * b
                normA += a * a
                normB += b * b
            }
            let denom = sqrt(normA * normB)
            guard denom > 0 else { continue }
            let value = corr / denom
            if value > bestCorr {
                bestCorr = value
                bestLag = lag
            }
        }

        guard bestCorr > 0.35, bestLag > 0 else { return nil }
        return sampleRate / Double(bestLag)
    }

    static func normalize(_ value: Double, low: Double, high: Double) -> Double {
        TranslationPayload.clampIntensity((value - low) / max(0.0001, high - low))
    }
}
