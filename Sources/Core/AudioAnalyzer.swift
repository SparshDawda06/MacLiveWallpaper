import Foundation
import CoreAudio
import Accelerate

/// System-audio tap. Screen recording is never requested: that prompt was looping and
/// `SCShareableContent` kept failing with "user declined TCCs", so the sphere never moved.
public final class AudioAnalyzer: NSObject {
    public static let shared = AudioAnalyzer()

    public let numBins = AudioBins.count
    private let lock = NSLock()
    private var published = [Float](repeating: 0, count: AudioBins.count)
    private var levels = AudioLevelState()

    public var frequencyData: [Float] {
        lock.lock()
        defer { lock.unlock() }
        return published
    }

    private var tapID: AudioObjectID = 0
    private var aggregateID: AudioObjectID = 0
    private var procID: AudioDeviceIOProcID?
    private var ioRunning = false
    private var gaveUp = false
    private var streamFormat = AudioStreamBasicDescription()
    private var hasFormat = false

    private let fftN = 2048
    private let hop = 1024
    private var fftSetup: FFTSetup?
    private var window = [Float](repeating: 0, count: 2048)
    private var acc = [Float](repeating: 0, count: 8192)
    private var accCount = 0
    private var scratch = [Float](repeating: 0, count: 16384)
    private var real = [Float](repeating: 0, count: 2048)
    private var imag = [Float](repeating: 0, count: 2048)
    private var magnitudes = [Float](repeating: 0, count: 1024)
    private var didLogAudio = false
    private var didLogLoud = false

    public var onListening: (() -> Void)?
    private let ioQueue = DispatchQueue(label: "voxel.wallpaper.audio", qos: .userInteractive)

    private override init() {
        super.init()
        let log2n = vDSP_Length(11)
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        vDSP_hann_window(&window, vDSP_Length(fftN), Int32(vDSP_HANN_NORM))
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    public func startCapture() {
        if gaveUp || ioRunning || tapID != 0 {
            if tapID != 0, !ioRunning {
                startIO()
            }
            return
        }
        log("Requesting system audio once")

        let tap = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        tap.name = "Voxel Wallpaper"
        tap.isPrivate = true

        var newTap = AudioObjectID(kAudioObjectUnknown)
        let tapStatus = AudioHardwareCreateProcessTap(tap, &newTap)
        guard tapStatus == noErr, newTap != AudioObjectID(kAudioObjectUnknown) else {
            log("Audio tap failed (\(tapStatus)). Not retrying.")
            gaveUp = true
            return
        }
        tapID = newTap

        // A tap with no hardware device has no clock, and CreateIOProcID then never returns.
        let outputUID = defaultOutputUID() ?? ""
        log("Output device \(outputUID)")
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Voxel Wallpaper Aggregate",
            kAudioAggregateDeviceUIDKey: "voxel-wallpaper-\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: NSNumber(value: 1),
            kAudioAggregateDeviceIsStackedKey: NSNumber(value: 0),
            kAudioAggregateDeviceTapAutoStartKey: NSNumber(value: 1),
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapUIDKey: tap.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: NSNumber(value: 1)
                ]
            ]
        ]

        var newAggregate = AudioObjectID(kAudioObjectUnknown)
        let aggStatus = AudioHardwareCreateAggregateDevice(description as CFDictionary, &newAggregate)
        guard aggStatus == noErr else {
            log("Aggregate device failed (\(aggStatus)). Not retrying.")
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
            gaveUp = true
            return
        }
        aggregateID = newAggregate

        var format = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamFormat,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        let formatStatus = AudioObjectGetPropertyData(aggregateID, &address, 0, nil, &size, &format)
        guard formatStatus == noErr, format.mSampleRate > 0, format.mChannelsPerFrame > 0 else {
            log("Tap has no input format (\(formatStatus)). Not retrying.")
            teardownDevice()
            gaveUp = true
            return
        }
        streamFormat = format
        hasFormat = true
        log(String(format: "Listening at %.0f Hz, %d ch", format.mSampleRate, format.mChannelsPerFrame))

        // Let the main run loop spin before IO setup. A desktop window on top of that
        // call was cancelling the audio prompt and the next launch asked again.
        let deviceID = aggregateID
        DispatchQueue.main.async { [weak self] in
            self?.ioQueue.async {
                self?.installProc(on: deviceID)
            }
        }
    }

    private func installProc(on deviceID: AudioObjectID) {
        var frameSize: UInt32 = 512
        let frameBytes = UInt32(MemoryLayout<UInt32>.size)
        var frameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        log("Setting audio buffer")
        let frameStatus = AudioObjectSetPropertyData(deviceID, &frameAddress, 0, nil, frameBytes, &frameSize)
        log("Buffer size status \(frameStatus)")

        var newProc: AudioDeviceIOProcID?
        let procStatus = AudioDeviceCreateIOProcIDWithBlock(&newProc, deviceID, nil) { [weak self] _, input, _, _, _ in
            self?.consume(input)
        }
        guard procStatus == noErr, let newProc else {
            log("IO proc failed (\(procStatus)). Not retrying.")
            gaveUp = true
            DispatchQueue.main.async { [weak self] in self?.onListening?() }
            return
        }
        procID = newProc
        log("IO proc installed")
        DispatchQueue.main.async { [weak self] in self?.onListening?() }
        startIO()
    }

    public func stopCapture() {
        // Destroy the tap on quit. Leaving it running wedges the next launch.
        guard procID != nil else { return }
        teardownDevice()
        log("Audio tap stopped")
    }

    private func startIO() {
        guard let procID, aggregateID != 0, !ioRunning else { return }
        let status = AudioDeviceStart(aggregateID, procID)
        if status != noErr {
            log("AudioDeviceStart failed (\(status))")
            return
        }
        ioRunning = true
        log("System audio tap running")
    }

    private func defaultOutputUID() -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &device) == noErr else { return nil }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, &uid) == noErr,
              let uid else { return nil }
        return uid.takeRetainedValue() as String
    }

    private func teardownDevice() {
        if let procID, aggregateID != 0 {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != 0 {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = 0
        }
        if tapID != 0 {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = 0
        }
        ioRunning = false
    }

    private func consume(_ input: UnsafePointer<AudioBufferList>?) {
        guard hasFormat, let input else { return }
        let format = streamFormat
        guard format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mChannelsPerFrame > 0 else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let channels = Int(format.mChannelsPerFrame)
        let nonInterleaved = format.mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0
        let frames: Int
        if nonInterleaved {
            guard let first = buffers.first, first.mData != nil else { return }
            frames = min(scratch.count, Int(first.mDataByteSize) / MemoryLayout<Float>.size)
            guard frames > 0 else { return }
            for i in 0..<frames { scratch[i] = 0 }
            var used = 0
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                let samples = data.bindMemory(to: Float.self, capacity: frames)
                for i in 0..<frames { scratch[i] += samples[i] }
                used += 1
            }
            let inv = 1 / Float(max(used, 1))
            for i in 0..<frames { scratch[i] *= inv }
        } else {
            guard let buffer = buffers.first, let data = buffer.mData, format.mBytesPerFrame > 0 else { return }
            frames = min(scratch.count, Int(buffer.mDataByteSize) / Int(format.mBytesPerFrame))
            guard frames > 0 else { return }
            let samples = data.bindMemory(to: Float.self, capacity: frames * channels)
            let inv = 1 / Float(channels)
            for i in 0..<frames {
                var sum: Float = 0
                for c in 0..<channels { sum += samples[i * channels + c] }
                scratch[i] = sum * inv
            }
        }

        var offset = 0
        while offset < frames {
            let space = acc.count - accCount
            let n = min(space, frames - offset)
            for i in 0..<n { acc[accCount + i] = scratch[offset + i] }
            accCount += n
            offset += n
            while accCount >= fftN {
                analyze(acc)
                let remain = accCount - hop
                for i in 0..<remain { acc[i] = acc[i + hop] }
                accCount = remain
            }
        }
    }

    private func analyze(_ samples: [Float]) {
        guard let fftSetup else { return }
        for i in 0..<fftN { real[i] = samples[i] * window[i] }
        for i in 0..<fftN { imag[i] = 0 }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(fftN))

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                realPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftN / 2) { complexPtr in
                    vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(fftN / 2))
                }
                vDSP_fft_zrip(fftSetup, &split, 1, vDSP_Length(11), FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(fftN / 2))
            }
        }
        magnitudes[0] = 0

        AudioBins.push(
            magnitudes: magnitudes,
            rms: rms,
            sampleRate: Float(streamFormat.mSampleRate),
            state: &levels
        )

        lock.lock()
        published = levels.bins
        lock.unlock()

        if !didLogAudio {
            didLogAudio = true
            log(String(format: "First audio buffer rms %.5f", rms))
        }
        if !didLogLoud, rms > 0.02 {
            didLogLoud = true
            log(String(format: "Heard audio rms %.3f", rms))
        }
    }

    private func log(_ message: String) {
        let line = Data((message + "\n").utf8)
        let url = URL(fileURLWithPath: "/tmp/wallpaper.log")
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }
}
