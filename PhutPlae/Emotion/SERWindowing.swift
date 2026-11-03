import Foundation

enum SERWindowing {
    static let sampleRate = 16_000
    static let windowSamples = 32_000
    static let hopSamples = 8_000

    /// Overlapping 2.0 s windows, 0.5 s hop. Short clips become a single zero-padded window.
    static func windows(from samples: [Float]) -> [[Float]] {
        guard !samples.isEmpty else { return [] }
        if samples.count < windowSamples {
            var padded = samples
            padded.append(contentsOf: Array(repeating: 0, count: windowSamples - samples.count))
            return [padded]
        }
        var result: [[Float]] = []
        var start = 0
        while start + windowSamples <= samples.count {
            result.append(Array(samples[start..<(start + windowSamples)]))
            start += hopSamples
        }
        let lastStart = samples.count - windowSamples
        if lastStart > 0, lastStart % hopSamples != 0 {
            result.append(Array(samples[lastStart..<samples.count]))
        }
        return result
    }
}
