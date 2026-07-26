import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var romLibrary = ROMLibrary()
    @State private var isImporterPresented = false
    @State private var selectedROM: ImportedROM?
    @State private var shouldOpenSelectedROM = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.purple)

                Text("PMEmu")
                    .font(.largeTitle.bold())

                Text("Game Boy / Game Boy Color no iPhone e Apple Watch.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                NavigationLink("Abrir demo 2048") {
                    EmulatorPlaceholderView(platformName: "iPhone")
                }
                .buttonStyle(.bordered)

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Importar ROM do iPhone", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                if !romLibrary.roms.isEmpty {
                    List(romLibrary.roms) { rom in
                        NavigationLink(value: rom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rom.name)
                                    .font(.headline)
                                Text(rom.fileName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 260)
                }

                NavigationLink(isActive: $shouldOpenSelectedROM) {
                    if let selectedROM {
                        EmulatorPlaceholderView(platformName: selectedROM.name, romURL: selectedROM.url)
                    }
                } label: {
                    EmptyView()
                }
                .hidden()

                Spacer(minLength: 0)
            }
            .padding(.top)
            .navigationTitle("PMEmu")
            .navigationDestination(for: ImportedROM.self) { rom in
                EmulatorPlaceholderView(platformName: rom.name, romURL: rom.url)
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.gameBoyROM, .gameBoyColorROM, .data],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Erro ao importar ROM", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Erro desconhecido")
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let sourceURL = try result.get().first else { return }
            let importedROM = try romLibrary.importROM(from: sourceURL)
            selectedROM = importedROM
            shouldOpenSelectedROM = true
        } catch {
            importError = error.localizedDescription
        }
    }
}
