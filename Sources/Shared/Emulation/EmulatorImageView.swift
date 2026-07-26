import CoreGraphics
import SwiftUI

struct EmulatorImageView: View {
    let image: CGImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black

                if let image {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Text("Sem frame")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

struct EmulatorControlButton: View {
    let title: String
    let button: EmulatorButton
    let viewModel: GBCGameViewModel

    var body: some View {
        Text(title)
            .font(.headline.monospaced())
            .frame(minWidth: 42, minHeight: 42)
            .background(Color.secondary.opacity(0.18))
            .clipShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in viewModel.press(button) }
                    .onEnded { _ in viewModel.release(button) }
            )
    }
}

struct EmulatorDPad: View {
    let viewModel: GBCGameViewModel

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                Color.clear.frame(width: 42, height: 42)
                EmulatorControlButton(title: "↑", button: .up, viewModel: viewModel)
                Color.clear.frame(width: 42, height: 42)
            }
            GridRow {
                EmulatorControlButton(title: "←", button: .left, viewModel: viewModel)
                Circle().fill(.secondary.opacity(0.25)).frame(width: 42, height: 42)
                EmulatorControlButton(title: "→", button: .right, viewModel: viewModel)
            }
            GridRow {
                Color.clear.frame(width: 42, height: 42)
                EmulatorControlButton(title: "↓", button: .down, viewModel: viewModel)
                Color.clear.frame(width: 42, height: 42)
            }
        }
    }
}
