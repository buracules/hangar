import Foundation

/// One binary, two faces: with a CLI command it runs that and exits, otherwise it is the
/// menu bar app.
@main
enum Entry {
  @MainActor
  static func main() {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard CLI.handles(arguments) else {
      HangarApp.main()
      return
    }
    Task { @MainActor in
      exit(await CLI.run(arguments))
    }
    dispatchMain()
  }
}
