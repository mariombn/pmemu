import CoreGraphics
import Foundation

public final class MGBAEmulator {
    private var handle: OpaquePointer?

    public let width: Int
    public let height: Int

    public init(romData: Data) throws {
        var createdHandle: OpaquePointer?

        romData.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }
            createdHandle = PMMGBAEmulatorCreate(baseAddress, romData.count)
        }

        guard let createdHandle else {
            throw MGBAEmulatorError.failedToCreateCore
        }

        self.handle = createdHandle
        self.width = Int(PMMGBAEmulatorWidth(createdHandle))
        self.height = Int(PMMGBAEmulatorHeight(createdHandle))

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

    public var errorDescription: String? {
        switch self {
        case .failedToCreateCore: return "Não foi possível criar o core mGBA."
        case .invalidVideoSize: return "O core mGBA retornou um tamanho de vídeo inválido."
        case .coreUnavailable: return "Core mGBA indisponível."
        case .failedToRunFrame: return "Não foi possível executar o próximo frame."
        case .failedToCopyFrame: return "Não foi possível copiar o framebuffer."
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
