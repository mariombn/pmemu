import CoreGraphics
import Foundation

public final class MGBAEmulator {
    private var handle: OpaquePointer?

    public let width: Int
    public let height: Int
    public let audioSampleRate: Int

    public init(romData: Data, saveData: Data? = nil) throws {
        var createdHandle: OpaquePointer?

        romData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            createdHandle = PMMGBAEmulatorCreate(baseAddress, romData.count)
        }

        guard let createdHandle else {
            throw MGBAEmulatorError.failedToCreateCore
        }

        if let saveData, !saveData.isEmpty {
            let loadedSave = saveData.withUnsafeBytes { rawBuffer in
                PMMGBAEmulatorLoadSaveData(createdHandle, rawBuffer.bindMemory(to: UInt8.self).baseAddress, saveData.count)
            }

            guard loadedSave else {
                PMMGBAEmulatorDestroy(createdHandle)
                throw MGBAEmulatorError.failedToLoadSaveData
            }
        }

        self.handle = createdHandle
        self.width = Int(PMMGBAEmulatorWidth(createdHandle))
        self.height = Int(PMMGBAEmulatorHeight(createdHandle))
        self.audioSampleRate = Int(PMMGBAEmulatorAudioSampleRate(createdHandle))

        guard self.width > 0, self.height > 0 else {
            throw MGBAEmulatorError.invalidVideoSize
        }
    }

    deinit {
        if let handle {
            PMMGBAEmulatorDestroy(handle)
        }
    }

    public func runFrame() throws -> EmulatorFrame {
        guard let handle else {
            throw MGBAEmulatorError.coreUnavailable
        }

        guard PMMGBAEmulatorRunFrame(handle) else {
            throw MGBAEmulatorError.failedToRunFrame
        }

        let rgbaCount = width * height * 4
        var rgba = [UInt8](repeating: 0, count: rgbaCount)
        let copied = rgba.withUnsafeMutableBytes { rawBuffer in
            PMMGBAEmulatorCopyFrameRGBA(handle, rawBuffer.bindMemory(to: UInt8.self).baseAddress, rgbaCount)
        }

        guard copied else {
            throw MGBAEmulatorError.failedToCopyFrame
        }

        return EmulatorFrame(width: width, height: height, rgba8888: rgba)
    }

    public func saveData() throws -> Data {
        guard let handle else {
            throw MGBAEmulatorError.coreUnavailable
        }

        let size = PMMGBAEmulatorSaveDataSize(handle)
        guard size > 0 else {
            return Data()
        }

        var data = Data(count: size)
        let copied = data.withUnsafeMutableBytes { rawBuffer in
            PMMGBAEmulatorCopySaveData(handle, rawBuffer.bindMemory(to: UInt8.self).baseAddress, size)
        }

        guard copied else {
            throw MGBAEmulatorError.failedToCopySaveData
        }

        return data
    }

    public func saveState() throws -> Data {
        guard let handle else {
            throw MGBAEmulatorError.coreUnavailable
        }

        let size = PMMGBAEmulatorStateSize(handle)
        guard size > 0 else {
            throw MGBAEmulatorError.invalidStateSize
        }

        var data = Data(count: size)
        let saved = data.withUnsafeMutableBytes { rawBuffer in
            PMMGBAEmulatorSaveState(handle, rawBuffer.bindMemory(to: UInt8.self).baseAddress, size)
        }

        guard saved else {
            throw MGBAEmulatorError.failedToSaveState
        }

        return data
    }

    public func loadState(_ data: Data) throws {
        guard let handle else {
            throw MGBAEmulatorError.coreUnavailable
        }

        let loaded = data.withUnsafeBytes { rawBuffer in
            PMMGBAEmulatorLoadState(handle, rawBuffer.bindMemory(to: UInt8.self).baseAddress, data.count)
        }

        guard loaded else {
            throw MGBAEmulatorError.failedToLoadState
        }
    }

    public func readAudioFrames() -> [Int16] {
        guard let handle else { return [] }

        let availableFrames = PMMGBAEmulatorAudioAvailable(handle)
        guard availableFrames > 0 else { return [] }

        var samples = [Int16](repeating: 0, count: availableFrames * 2)
        let framesRead = samples.withUnsafeMutableBufferPointer { buffer in
            PMMGBAEmulatorReadAudioS16(handle, buffer.baseAddress, availableFrames)
        }

        guard framesRead > 0 else { return [] }
        if framesRead < availableFrames {
            samples.removeLast((availableFrames - framesRead) * 2)
        }

        return samples
    }

    public func press(_ button: EmulatorButton) {
        set(button, pressed: true)
    }

    public func release(_ button: EmulatorButton) {
        set(button, pressed: false)
    }

    private func set(_ button: EmulatorButton, pressed: Bool) {
        guard let handle else { return }
        PMMGBAEmulatorSetButton(handle, button.mgbaButton, pressed)
    }
}

public enum MGBAEmulatorError: Error, LocalizedError {
    case failedToCreateCore
    case invalidVideoSize
    case coreUnavailable
    case failedToRunFrame
    case failedToCopyFrame
    case failedToLoadSaveData
    case failedToCopySaveData
    case invalidStateSize
    case failedToSaveState
    case failedToLoadState

    public var errorDescription: String? {
        switch self {
        case .failedToCreateCore: return "Não foi possível criar o core mGBA."
        case .invalidVideoSize: return "O core mGBA retornou um tamanho de vídeo inválido."
        case .coreUnavailable: return "Core mGBA indisponível."
        case .failedToRunFrame: return "Não foi possível executar o próximo frame."
        case .failedToCopyFrame: return "Não foi possível copiar o framebuffer."
        case .failedToLoadSaveData: return "Não foi possível carregar o save nativo."
        case .failedToCopySaveData: return "Não foi possível copiar o save nativo."
        case .invalidStateSize: return "O tamanho do savestate é inválido."
        case .failedToSaveState: return "Não foi possível salvar o savestate."
        case .failedToLoadState: return "Não foi possível carregar o savestate."
        }
    }
}

private extension EmulatorButton {
    var mgbaButton: PMMGBAButton {
        switch self {
        case .up: return PMMGBAButtonUp
        case .down: return PMMGBAButtonDown
        case .left: return PMMGBAButtonLeft
        case .right: return PMMGBAButtonRight
        case .a: return PMMGBAButtonA
        case .b: return PMMGBAButtonB
        case .start: return PMMGBAButtonStart
        case .select: return PMMGBAButtonSelect
        }
    }
}

public extension EmulatorFrame {
    func makeCGImage() -> CGImage? {
        let data = Data(rgba8888) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
