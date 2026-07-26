import CoreGraphics
import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class GBCGameViewModel: ObservableObject {
    @Published var image: CGImage?
    @Published var status: String = "Carregando ROM..."

    private var emulator: MGBAEmulator?
    private var timer: Timer?
    private var audioPlayer: EmulatorAudioPlayer?
    private var activeSaveURL: URL?
    private var activeStateURL: URL?
    private var activeDisplayName: String?
    private var framesSinceSaveFlush = 0

    func startBundledDemo() {
        do {
            let romData = try Self.loadBundledROM()
            start(romData: romData, displayName: "2048.gb", storageKey: "2048")
        } catch {
            self.status = error.localizedDescription
        }
    }

    func startROM(at url: URL) {
        do {
            let romData = try Data(contentsOf: url)
            start(romData: romData, displayName: url.lastPathComponent, storageKey: url.lastPathComponent)
        } catch {
            self.status = error.localizedDescription
        }
    }

    private func start(romData: Data, displayName: String, storageKey: String) {
        guard emulator == nil else { return }

        do {
            let saveURL = Self.saveURL(for: storageKey)
            let stateURL = Self.stateURL(for: storageKey)
            let saveData = try? Data(contentsOf: saveURL)
            let emulator = try MGBAEmulator(romData: romData, saveData: saveData)
            self.emulator = emulator
            self.activeSaveURL = saveURL
            self.activeStateURL = stateURL
            self.activeDisplayName = displayName
            self.status = "Rodando \(displayName) — \(emulator.width)x\(emulator.height)"
            self.audioPlayer = EmulatorAudioPlayer(sampleRate: emulator.audioSampleRate)
            self.audioPlayer?.start()

            // Warm up a few frames so the first visible image is not just the boot screen.
            for _ in 0..<8 {
                _ = try emulator.runFrame()
            }

            runOneFrame()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.runOneFrame()
                }
            }
        } catch {
            self.status = error.localizedDescription
        }
    }

    func stop() {
        persistNativeSave()
        audioPlayer?.stop()
        audioPlayer = nil
        timer?.invalidate()
        timer = nil
        emulator = nil
    }

    func press(_ button: EmulatorButton) {
        emulator?.press(button)
    }

    func release(_ button: EmulatorButton) {
        emulator?.release(button)
    }

    func saveState() {
        guard let emulator, let activeStateURL else {
            status = "Nenhuma ROM rodando para salvar state."
            return
        }

        do {
            try FileManager.default.createDirectory(at: activeStateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try emulator.saveState().write(to: activeStateURL, options: [.atomic])
            persistNativeSave()
            status = "Savestate salvo."
        } catch {
            status = error.localizedDescription
        }
    }

    func loadState() {
        guard let emulator, let activeStateURL else {
            status = "Nenhuma ROM rodando para carregar state."
            return
        }

        do {
            let stateData = try Data(contentsOf: activeStateURL)
            try emulator.loadState(stateData)
            runOneFrame()
            status = "Savestate carregado."
        } catch {
            status = "Nenhum savestate encontrado."
        }
    }

    private func runOneFrame() {
        guard let emulator else { return }

        do {
            let frame = try emulator.runFrame()
            self.image = frame.makeCGImage()
            audioPlayer?.enqueue(samples: emulator.readAudioFrames())
            framesSinceSaveFlush += 1

            if framesSinceSaveFlush >= 120 {
                persistNativeSave()
                framesSinceSaveFlush = 0
            }
        } catch {
            self.status = error.localizedDescription
            self.stop()
        }
    }

    private func persistNativeSave() {
        guard let emulator, let activeSaveURL else { return }

        do {
            let saveData = try emulator.saveData()
            guard !saveData.isEmpty else { return }
            try FileManager.default.createDirectory(at: activeSaveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try saveData.write(to: activeSaveURL, options: [.atomic])
        } catch {
            status = error.localizedDescription
        }
    }

    private static func loadBundledROM() throws -> Data {
        let bundle = Bundle.main
        let candidates = [
            bundle.url(forResource: "2048", withExtension: "gb", subdirectory: "ROMs"),
            bundle.url(forResource: "2048", withExtension: "gb", subdirectory: "Resources/ROMs"),
            bundle.url(forResource: "2048", withExtension: "gb")
        ]

        guard let url = candidates.compactMap({ $0 }).first else {
            throw GBCGameViewModelError.demoROMNotFound
        }

        return try Data(contentsOf: url)
    }

    private static func saveURL(for storageKey: String) -> URL {
        storageDirectory(named: "Saves").appendingPathComponent("\(sanitizedStorageName(storageKey)).sav")
    }

    private static func stateURL(for storageKey: String) -> URL {
        storageDirectory(named: "SaveStates").appendingPathComponent("\(sanitizedStorageName(storageKey)).state")
    }

    private static func storageDirectory(named name: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name, isDirectory: true)
    }

    private static func sanitizedStorageName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        return String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "._-")).isEmpty ? "ROM" : String(scalars)
    }
}

enum GBCGameViewModelError: LocalizedError {
    case demoROMNotFound

    var errorDescription: String? {
        switch self {
        case .demoROMNotFound:
            return "ROM demo 2048.gb não encontrada no bundle. Rode xcodegen generate e confira Resources/ROMs/2048.gb."
        }
    }
}

#if os(iOS)
private final class EmulatorAudioPlayer {
    private let engine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private let format: AVAudioFormat
    private let sampleBuffer = EmulatorAudioSampleBuffer()
    private let sourceSampleRate: Double
    private let outputSampleRate = 44_100.0

    init?(sampleRate: Int) {
        guard sampleRate > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: outputSampleRate, channels: 2, interleaved: false) else {
            return nil
        }

        self.sourceSampleRate = Double(sampleRate)
        self.format = format
        self.sourceNode = AVAudioSourceNode { [sampleBuffer] _, _, frameCount, audioBufferList in
            sampleBuffer.render(frameCount: Int(frameCount), audioBufferList: audioBufferList)
            return noErr
        }
    }

    func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
            try engine.start()
        } catch {
            stop()
        }
    }

    func enqueue(samples: [Int16]) {
        guard engine.isRunning, !samples.isEmpty else { return }
        sampleBuffer.append(samples: samples, sourceSampleRate: sourceSampleRate, outputSampleRate: outputSampleRate)
    }

    func stop() {
        engine.stop()
        sampleBuffer.removeAll()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

private final class EmulatorAudioSampleBuffer {
    private let lock = NSLock()
    private var samples: [Float] = []
    private var readIndex = 0
    private let maximumBufferedSamples = 44_100 * 2

    func append(samples sourceSamples: [Int16], sourceSampleRate: Double, outputSampleRate: Double) {
        let sourceFrames = sourceSamples.count / 2
        guard sourceFrames > 0 else { return }

        let outputFrames = max(1, Int((Double(sourceFrames) * outputSampleRate / sourceSampleRate).rounded(.down)))
        var converted: [Float] = []
        converted.reserveCapacity(outputFrames * 2)

        for outputFrame in 0..<outputFrames {
            let sourceFrame = min(Int(Double(outputFrame) * sourceSampleRate / outputSampleRate), sourceFrames - 1)
            converted.append(Float(sourceSamples[sourceFrame * 2]) / 32768.0)
            converted.append(Float(sourceSamples[sourceFrame * 2 + 1]) / 32768.0)
        }

        lock.lock()
        samples.append(contentsOf: converted)

        if samples.count - readIndex > maximumBufferedSamples {
            readIndex = samples.count - maximumBufferedSamples
        }

        compactIfNeeded()
        lock.unlock()
    }

    func render(frameCount: Int, audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        guard let firstBuffer = buffers.first,
              let firstChannel = firstBuffer.mData?.assumingMemoryBound(to: Float.self) else {
            return
        }
        let secondChannel = buffers.count > 1 ? buffers[1].mData?.assumingMemoryBound(to: Float.self) : nil
        let isInterleaved = secondChannel == nil && firstBuffer.mNumberChannels == 2

        lock.lock()
        for frame in 0..<frameCount {
            if readIndex + 1 < samples.count {
                if let secondChannel {
                    firstChannel[frame] = samples[readIndex]
                    secondChannel[frame] = samples[readIndex + 1]
                } else if isInterleaved {
                    firstChannel[frame * 2] = samples[readIndex]
                    firstChannel[frame * 2 + 1] = samples[readIndex + 1]
                } else {
                    firstChannel[frame] = (samples[readIndex] + samples[readIndex + 1]) * 0.5
                }
                readIndex += 2
            } else {
                if let secondChannel {
                    firstChannel[frame] = 0
                    secondChannel[frame] = 0
                } else if isInterleaved {
                    firstChannel[frame * 2] = 0
                    firstChannel[frame * 2 + 1] = 0
                } else {
                    firstChannel[frame] = 0
                }
            }
        }

        compactIfNeeded()
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        readIndex = 0
        lock.unlock()
    }

    private func compactIfNeeded() {
        guard readIndex > 4096 else { return }
        samples.removeFirst(readIndex)
        readIndex = 0
    }
}
#else
private final class EmulatorAudioPlayer {
    init?(sampleRate: Int) {}
    func start() {}
    func enqueue(samples: [Int16]) {}
    func stop() {}
}
#endif
