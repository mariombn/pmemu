import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class GBCGameViewModel: ObservableObject {
    @Published var image: CGImage?
    @Published var status: String = "Carregando ROM..."

    private var emulator: MGBAEmulator?
    private var timer: Timer?

    func startBundledDemo() {
        do {
            let romData = try Self.loadBundledROM()
            start(romData: romData, displayName: "2048.gb")
        } catch {
            self.status = error.localizedDescription
        }
    }

    func startROM(at url: URL) {
        do {
            let romData = try Data(contentsOf: url)
            start(romData: romData, displayName: url.lastPathComponent)
        } catch {
            self.status = error.localizedDescription
        }
    }

    private func start(romData: Data, displayName: String) {
        guard emulator == nil else { return }

        do {
            let emulator = try MGBAEmulator(romData: romData)
            self.emulator = emulator
            self.status = "Rodando \(displayName) — \(emulator.width)x\(emulator.height)"

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

    private func runOneFrame() {
        guard let emulator else { return }

        do {
            let frame = try emulator.runFrame()
            self.image = frame.makeCGImage()
        } catch {
            self.status = error.localizedDescription
            self.stop()
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
