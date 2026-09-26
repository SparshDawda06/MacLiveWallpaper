import Foundation

/// Smoothed 0...1 levels for the voxel sphere. Pure so the check can run it without Core Audio.
struct AudioLevelState {
    var bins: [Float]
    var bandGain: Float
    var rmsGain: Float

    init() {
        bins = [Float](repeating: 0, count: AudioBins.count)
        bandGain = 0.05
        rmsGain = 0.01
    }
}

enum AudioBins {
    static let count = 32

    /// `magnitudes` is an FFT power spectrum (length fftSize/2). `rms` is the time-domain level.
    static func push(magnitudes: [Float], rms: Float, sampleRate: Float, state: inout AudioLevelState) {
        let n = magnitudes.count
        let fftSize = max(n * 2, 2)
        var bands = [Float](repeating: 0, count: count)

        if n > 1, sampleRate > 0 {
            let minHz: Float = 40
            let maxHz = min(sampleRate * 0.45, 16000)
            let logMin = log2(minHz)
            let logMax = log2(max(maxHz, minHz + 1))
            for i in 0..<count {
                let f0 = exp2(logMin + (logMax - logMin) * Float(i) / Float(count))
                let f1 = exp2(logMin + (logMax - logMin) * Float(i + 1) / Float(count))
                let hzToBin = Float(fftSize) / sampleRate
                let i0 = min(n - 1, max(1, Int(f0 * hzToBin)))
                let i1 = min(n, max(i0 + 1, Int(ceil(f1 * hzToBin))))
                var peak: Float = 0
                for j in i0..<i1 {
                    peak = max(peak, magnitudes[j])
                }
                bands[i] = sqrt(peak)
            }
        }

        let peakBand = bands.max() ?? 0
        if peakBand > state.bandGain {
            state.bandGain = peakBand
        } else {
            state.bandGain = max(0.05, state.bandGain * 0.997)
        }

        if rms > state.rmsGain {
            state.rmsGain = rms
        } else {
            state.rmsGain = max(0.01, state.rmsGain * 0.995)
        }
        let energy = min(1, rms / state.rmsGain)

        for i in 0..<count {
            let norm = min(1, bands[i] / state.bandGain)
            let shaped = pow(norm, 0.55)
            let prev = state.bins[i]
            let follow: Float = shaped > prev ? 0.62 : 0.2
            let band = prev + (shaped - prev) * follow
            state.bins[i] = min(1, band + energy * 0.12)
        }
    }
}
