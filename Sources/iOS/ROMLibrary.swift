import Foundation
import UniformTypeIdentifiers

struct ImportedROM: Identifiable, Hashable {
    let url: URL

    var id: String { url.path }
    var name: String { url.deletingPathExtension().lastPathComponent }
    var fileName: String { url.lastPathComponent }
}

@MainActor
final class ROMLibrary: ObservableObject {
    @Published private(set) var roms: [ImportedROM] = []

    let romsDirectory: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.romsDirectory = documents.appendingPathComponent("ROMs", isDirectory: true)
        try? FileManager.default.createDirectory(at: romsDirectory, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: romsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        self.roms = urls
            .filter { ["gb", "gbc"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map(ImportedROM.init(url:))
    }

    @discardableResult
    func importROM(from sourceURL: URL) throws -> ImportedROM {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        guard ["gb", "gbc"].contains(fileExtension) else {
            throw ROMLibraryError.unsupportedFileType
        }

        try FileManager.default.createDirectory(at: romsDirectory, withIntermediateDirectories: true)

        let destinationURL = uniqueDestinationURL(for: sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        reload()
        return ImportedROM(url: destinationURL)
    }

    private func uniqueDestinationURL(for fileName: String) -> URL {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: fileName).pathExtension
        var candidate = romsDirectory.appendingPathComponent(fileName)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = romsDirectory.appendingPathComponent("\(baseName) \(index).\(ext)")
            index += 1
        }

        return candidate
    }
}

enum ROMLibraryError: LocalizedError {
    case unsupportedFileType

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Formato não suportado. Escolha uma ROM .gb ou .gbc."
        }
    }
}

extension UTType {
    static let gameBoyROM = UTType(filenameExtension: "gb") ?? .data
    static let gameBoyColorROM = UTType(filenameExtension: "gbc") ?? .data
}
