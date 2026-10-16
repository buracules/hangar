import SwiftUI

private enum Constants {
  /// The `.st` box from the design.
  static let frame: CGFloat = 12
  static let symbolSize: CGFloat = 8
  static let triangleSize: CGFloat = 9
  static let fullTurn: Double = 360
}

/// The shape half of the status language. ◌ turns while busy, unless Reduce Motion is on.
struct StatusSymbol: View {
  let kind: MachineStatus.Kind

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isTurning = false

  var body: some View {
    Image(systemName: kind.symbolName)
      .font(.system(size: size, weight: kind == .error ? .bold : .regular))
      .foregroundStyle(kind.color)
      .rotationEffect(.degrees(isTurning ? Constants.fullTurn : 0))
      .frame(width: Constants.frame, height: Constants.frame)
      .accessibilityHidden(true)
      .onAppear(perform: updateTurning)
      .onChange(of: kind) { updateTurning() }
      .onChange(of: reduceMotion) { updateTurning() }
  }

  private var size: CGFloat { kind == .unhealthy ? Constants.triangleSize : Constants.symbolSize }

  private func updateTurning() {
    let shouldTurn = kind == .busy && !reduceMotion
    guard shouldTurn != isTurning else { return }
    if shouldTurn {
      withAnimation(.linear(duration: Motion.spin).repeatForever(autoreverses: false)) {
        isTurning = true
      }
    } else {
      isTurning = false
    }
  }
}
