import Foundation

/// The small pages the proxy answers with itself when it cannot forward a request.
enum ProxyResponse {
  /// Nothing is registered for the host.
  static func unknownHost(_ host: String) -> Data {
    page(
      status: "404 Not Found",
      title: "No project at \(host)",
      detail:
        "Start a project in Hangar, or give one this name with \"hostname\" in its .hangar.json."
    )
  }

  /// The host belongs to a project whose port is not answering yet.
  static func notListening(_ host: String, port: Int) -> Data {
    page(
      status: "502 Bad Gateway",
      title: "\(host) is not answering yet",
      detail: "Hangar forwards it to port \(port), which is not accepting connections yet."
    )
  }

  /// The request had no usable Host header.
  static let badRequest = page(
    status: "400 Bad Request",
    title: "No host",
    detail: "Open a project at http://<name>.localhost."
  )

  private static func page(status: String, title: String, detail: String) -> Data {
    let body = """
      <!doctype html><meta charset="utf-8"><title>\(escape(title))</title>
      <body style="font:15px -apple-system,sans-serif;margin:15vh auto;max-width:560px;
      color:#25324A">
      <h1 style="font-size:22px">\(escape(title))</h1><p style="color:#5C6B88">\(escape(detail))</p>
      <p style="color:#8C98AD;font-size:13px">Hangar</p></body>
      """
    let bodyData = Data(body.utf8)
    let head =
      "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n"
      + "Content-Length: \(bodyData.count)\r\nConnection: close\r\n\r\n"
    return Data(head.utf8) + bodyData
  }

  private static func escape(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }
}
