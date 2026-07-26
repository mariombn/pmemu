import SwiftUI

struct EmulatorPlaceholderView: View {
    let platformName: String
    let romURL: URL?
    @StateObject private var viewModel = GBCGameViewModel()
    @State private var isEditingLayout = false
    @AppStorage("gameScreenScale") private var gameScreenScale = 1.0
    @AppStorage("gameScreenXOffset") private var gameScreenXOffset = 0.0
    @AppStorage("gameScreenYOffset") private var gameScreenYOffset = 0.0
    @AppStorage("gameControlsScale") private var gameControlsScale = 1.0
    @AppStorage("gameDPadXOffset") private var gameDPadXOffset = 0.0
    @AppStorage("gameDPadYOffset") private var gameDPadYOffset = 0.0
    @AppStorage("gameActionButtonsXOffset") private var gameActionButtonsXOffset = 0.0
    @AppStorage("gameActionButtonsYOffset") private var gameActionButtonsYOffset = 0.0
    @AppStorage("gameMenuButtonsXOffset") private var gameMenuButtonsXOffset = 0.0
    @AppStorage("gameMenuButtonsYOffset") private var gameMenuButtonsYOffset = 0.0

    init(platformName: String, romURL: URL? = nil) {
        self.platformName = platformName
        self.romURL = romURL
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width, UIScreen.main.bounds.width)
            let gameWidth = availableWidth * max(gameScreenScale, 1.0)
            let gameHeight = gameWidth * 144.0 / 160.0

            ZStack {
                Color(.systemBackground)

                EditableLayoutElement(
                    isEditing: isEditingLayout,
                    xOffset: $gameScreenXOffset,
                    yOffset: $gameScreenYOffset,
                    scale: $gameScreenScale,
                    range: 1.0...1.8,
                    resizeSensitivity: availableWidth
                ) {
                    EmulatorImageView(image: viewModel.image)
                        .frame(width: gameWidth, height: gameHeight)
                        .background(Color.black)
                }
                .position(
                    x: geometry.size.width / 2 + gameScreenXOffset,
                    y: gameHeight / 2 + gameScreenYOffset
                )

                EditableLayoutElement(
                    isEditing: isEditingLayout,
                    xOffset: $gameDPadXOffset,
                    yOffset: $gameDPadYOffset,
                    scale: $gameControlsScale,
                    range: 0.75...1.35,
                    resizeSensitivity: 260
                ) {
                    GameBoyDPad(viewModel: viewModel)
                        .scaleEffect(gameControlsScale)
                }
                .position(
                    x: 98 + gameDPadXOffset,
                    y: geometry.size.height - 132 + gameDPadYOffset
                )

                EditableLayoutElement(
                    isEditing: isEditingLayout,
                    xOffset: $gameActionButtonsXOffset,
                    yOffset: $gameActionButtonsYOffset,
                    scale: $gameControlsScale,
                    range: 0.75...1.35,
                    resizeSensitivity: 260
                ) {
                    GameBoyABButtons(viewModel: viewModel)
                        .scaleEffect(gameControlsScale)
                }
                .position(
                    x: geometry.size.width - 104 + gameActionButtonsXOffset,
                    y: geometry.size.height - 132 + gameActionButtonsYOffset
                )

                EditableLayoutElement(
                    isEditing: isEditingLayout,
                    xOffset: $gameMenuButtonsXOffset,
                    yOffset: $gameMenuButtonsYOffset,
                    scale: $gameControlsScale,
                    range: 0.75...1.35,
                    resizeSensitivity: 260
                ) {
                    menuButtons
                        .scaleEffect(gameControlsScale)
                }
                .position(
                    x: geometry.size.width / 2 + gameMenuButtonsXOffset,
                    y: geometry.size.height - 46 + gameMenuButtonsYOffset
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(edges: [.horizontal])
        .navigationTitle(platformName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditingLayout {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Redefinir") {
                        resetLayout()
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingLayout.toggle()
                } label: {
                    Image(systemName: isEditingLayout ? "checkmark" : "gearshape")
                }
                .accessibilityLabel(isEditingLayout ? "Concluir edição de layout" : "Editar layout")
            }

            ToolbarItem(placement: .bottomBar) {
                Text(isEditingLayout ? "Arraste os elementos. Use a alça para redimensionar." : viewModel.status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            gameScreenScale = max(gameScreenScale, 1.0)

            if let romURL {
                viewModel.startROM(at: romURL)
            } else {
                viewModel.startBundledDemo()
            }
        }
        .onDisappear { viewModel.stop() }
    }

    private var menuButtons: some View {
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

    private func resetLayout() {
        gameScreenScale = 1.0
        gameScreenXOffset = 0.0
        gameScreenYOffset = 0.0
        gameControlsScale = 1.0
        gameDPadXOffset = 0.0
        gameDPadYOffset = 0.0
        gameActionButtonsXOffset = 0.0
        gameActionButtonsYOffset = 0.0
        gameMenuButtonsXOffset = 0.0
        gameMenuButtonsYOffset = 0.0
    }
}

private struct EditableLayoutElement<Content: View>: View {
    let isEditing: Bool
    @Binding var xOffset: Double
    @Binding var yOffset: Double
    @Binding var scale: Double
    let range: ClosedRange<Double>
    let resizeSensitivity: Double
    @ViewBuilder let content: () -> Content

    @State private var dragStartOffset: CGSize?
    @State private var resizeStartScale: Double?

    var body: some View {
        if isEditing {
            content()
                .overlay(alignment: .topLeading) {
                    Image(systemName: "move.3d")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.blue.opacity(0.9), in: Circle())
                        .padding(6)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.blue.opacity(0.9), in: Circle())
                        .padding(6)
                        .highPriorityGesture(resizeGesture)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.blue.opacity(0.85), lineWidth: 2)
                }
                .contentShape(Rectangle())
                .gesture(moveGesture)
        } else {
            content()
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartOffset == nil {
                    dragStartOffset = CGSize(width: xOffset, height: yOffset)
                }

                xOffset = (dragStartOffset?.width ?? 0) + value.translation.width
                yOffset = (dragStartOffset?.height ?? 0) + value.translation.height
            }
            .onEnded { _ in
                dragStartOffset = nil
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeStartScale == nil {
                    resizeStartScale = scale
                }

                let delta = (value.translation.width + value.translation.height) / resizeSensitivity
                scale = clamp((resizeStartScale ?? scale) + delta)
            }
            .onEnded { _ in
                resizeStartScale = nil
            }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
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
