import SwiftUI

struct WatchContentView: View {
    @StateObject private var viewModel = GBCGameViewModel()

    var body: some View {
        VStack(spacing: 5) {
            EmulatorImageView(image: viewModel.image)
                .frame(maxHeight: 112)

            Text(viewModel.status)
                .font(.system(size: 8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Spacer().frame(width: 24, height: 24)
                        EmulatorControlButton(title: "↑", button: .up, viewModel: viewModel)
                            .scaleEffect(0.58)
                        Spacer().frame(width: 24, height: 24)
                    }
                    HStack(spacing: 0) {
                        EmulatorControlButton(title: "←", button: .left, viewModel: viewModel)
                            .scaleEffect(0.58)
                        Spacer().frame(width: 24, height: 24)
                        EmulatorControlButton(title: "→", button: .right, viewModel: viewModel)
                            .scaleEffect(0.58)
                    }
                    HStack(spacing: 0) {
                        Spacer().frame(width: 24, height: 24)
                        EmulatorControlButton(title: "↓", button: .down, viewModel: viewModel)
                            .scaleEffect(0.58)
                        Spacer().frame(width: 24, height: 24)
                    }
                }

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        EmulatorControlButton(title: "B", button: .b, viewModel: viewModel)
                            .scaleEffect(0.62)
                        EmulatorControlButton(title: "A", button: .a, viewModel: viewModel)
                            .scaleEffect(0.62)
                    }
                    HStack(spacing: 2) {
                        EmulatorControlButton(title: "S", button: .start, viewModel: viewModel)
                            .scaleEffect(0.52)
                        EmulatorControlButton(title: "E", button: .select, viewModel: viewModel)
                            .scaleEffect(0.52)
                    }
                }
            }
            .frame(height: 62)
        }
        .padding(.horizontal, 2)
        .onAppear { viewModel.startBundledDemo() }
        .onDisappear { viewModel.stop() }
    }
}
