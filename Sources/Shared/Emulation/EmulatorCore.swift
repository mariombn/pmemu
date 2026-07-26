import Foundation

public protocol EmulatorCore {
    func loadROM(_ data: Data) throws
    func reset()
    func runFrame() throws -> EmulatorFrame
    func press(_ button: EmulatorButton)
    func release(_ button: EmulatorButton)
}

public struct EmulatorFrame: Sendable {
    public let width: Int
    public let height: Int
    public let rgba8888: [UInt8]

    public init(width: Int, height: Int, rgba8888: [UInt8]) {
        self.width = width
        self.height = height
        self.rgba8888 = rgba8888
    }
}

public enum EmulatorButton: String, Sendable, CaseIterable {
    case up
    case down
    case left
    case right
    case a
    case b
    case start
    case select
}
