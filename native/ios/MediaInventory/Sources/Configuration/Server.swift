import Foundation

enum Server {
    #if DEBUG
    static let url = URL(string: "http://localhost:3000")!
    #else
    static let url = URL(string: "https://your-production-url.com")!
    #endif

    static let pathConfigurationURL = url.appendingPathComponent("/configurations/ios_v1.json")
}
