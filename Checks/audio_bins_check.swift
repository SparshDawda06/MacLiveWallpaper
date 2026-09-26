import Foundation

@main
struct AudioBinsCheck {
    static func main() {
        func expect(_ ok: Bool, _ message: String) {
            if !ok {
                fputs("FAIL \(message)\n", stderr)
                exit(1)
            }
        }

        var silence = AudioLevelState()
        let zeros = [Float](repeating: 0, count: 1024)
        AudioBins.push(magnitudes: zeros, rms: 0, sampleRate: 48000, state: &silence)
        expect(silence.bins.allSatisfy { $0 < 0.02 }, "silence should stay near zero, got \(silence.bins)")

        var tone = AudioLevelState()
        var mags = [Float](repeating: 0, count: 1024)
        mags[2] = 4
        for _ in 0..<4 {
            AudioBins.push(magnitudes: mags, rms: 0.2, sampleRate: 48000, state: &tone)
        }
        expect(tone.bins[0] > 0.45, "bass bin should rise, got \(tone.bins[0])")
        expect(tone.bins[0] > tone.bins[31] + 0.25, "bass should beat the top band, low \(tone.bins[0]) high \(tone.bins[31])")

        var decay = AudioLevelState()
        decay.bins = [Float](repeating: 1, count: AudioBins.count)
        AudioBins.push(magnitudes: zeros, rms: 0, sampleRate: 48000, state: &decay)
        expect(decay.bins.allSatisfy { $0 < 0.85 }, "levels should release, got \(decay.bins[0])")

        print("audio bins ok")
    }
}
