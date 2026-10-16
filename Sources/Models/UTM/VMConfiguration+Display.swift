import Foundation

private enum Constants {
  static let mebibytesPerGibibyte = 1024
  static let separator = " · "
}

// MARK: - Display

extension VMConfiguration {
  /// "QEMU · aarch64", or just "Apple" for Virtualization.framework VMs.
  var backendText: String? {
    let parts = [backend, architecture ?? ""].filter { !$0.isEmpty }
    return parts.isEmpty ? nil : parts.joined(separator: Constants.separator)
  }

  /// "4 cores · 8 GB memory"; nil when neither is set.
  var resourcesText: String? {
    var parts: [String] = []
    if let cpuCount, cpuCount > 0 { parts.append(cpuCount == 1 ? "1 core" : "\(cpuCount) cores") }
    if let memoryMiB, memoryMiB > 0 { parts.append("\(memoryText(memoryMiB)) memory") }
    return parts.isEmpty ? nil : parts.joined(separator: Constants.separator)
  }

  /// Whole gigabytes when it divides evenly, otherwise megabytes.
  private func memoryText(_ mebibytes: Int) -> String {
    mebibytes % Constants.mebibytesPerGibibyte == 0
      ? "\(mebibytes / Constants.mebibytesPerGibibyte) GB" : "\(mebibytes) MB"
  }
}
