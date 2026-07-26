import SwiftUI

struct EmulatorPlaceholderView: View {
    let platformName: String
    let romURL: URL?
    @StateObject private var viewModel = GBCGameViewModel()

    init(platformName: String, romURL: URL? = nil) {
        self.platformName = platformName
        self.romURL = romURL
    }

    var body: some View {
        GeometryReader { geometry in
            let gameWidth = geometry.size.width
            let gameHeight = gameWidth * 144.0 / 160.0

            VStack(spacing: 0) {
                EmulatorImageView(image: viewModel.image)
                    .frame(width: gameWidth, height: gameHeight)
                    .background(Color.black)

                Spacer(minLength: 18)

                gameBoyControls
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.systemBackground))
        }
        .ignoresSafeArea(edges: [.horizontal])
        .navigationTitle(platformName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Text(viewModel.status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            if let romURL {
                viewModel.startROM(at: romURL)
            } else {
                viewModel.startBundledDemo()
            }
        }
        .onDisappear { viewModel.stop() }
    }

    private var gameBoyControls: some View {
        VStack(spacing: 22) {
            HStack(alignment: .center) {
                GameBoyDPad(viewModel: viewModel)

                Spacer(minLength: 26)

                GameBoyABButtons(viewModel: viewModel)
            }

            HStack(spacing: 20) {
                PressableGameButton(viewModel: viewModel, button: .select) {
                    Text("SELECT")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 86, height: 32)
                        .background(Color.secondary.opacity(0.16))
                        .clipShape(Capsule())
                }

                PressableGameButton(viewModel: viewModel, button: .start) {
                    Text("START")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 86, height: 32)
                        .background(Color.secondary.opacity(0.16))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

private struct PressableGameButton<Content: View>: View {
    let viewModel: GBCGameViewModel
    let button: EmulatorButton
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 80) {
                // no-op; state is handled in `pressing`.
            } onPressingChanged: { isPressing in
                if isPressing {
                    viewModel.press(button)
                } else {
                    viewModel.release(button)
                }
            }
    }
}

private struct GameBoyDPad: View {
    let viewModel: GBCGameViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.24))
                .frame(width: 50, height: 150)

            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.24))
                .frame(width: 150, height: 50)

            VStack(spacing: 0) {
                dpadButton("▲", .up)
                HStack(spacing: 50) {
                    dpadButton("◀", .left)
                    dpadButton("▶", .right)
                }
                dpadButton("▼", .down)
            }
        }
        .frame(width: 150, height: 150)
    }

    private func dpadButton(_ title: String, _ button: EmulatorButton) -> some View {
        PressableGameButton(viewModel: viewModel, button: button) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary.opacity(0.8))
                .frame(width: 50, height: 50)
        }
    }
}

private struct GameBoyABButtons: View {
    let viewModel: GBCGameViewModel

    var body: some View {
        ZStack {
            actionButton("B", .b)
                .offset(x: -38, y: 24)

            actionButton("A", .a)
                .offset(x: 38, y: -24)
        }
        .frame(width: 164, height: 150)
    }

    private func actionButton(_ title: String, _ button: EmulatorButton) -> some View {
        PressableGameButton(viewModel: viewModel, button: button) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(Color.purple.opacity(0.92))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
    }
}
