import Foundation

struct SMBServer: Identifiable, Codable, Hashable {
    var id = UUID()
    var displayName: String
    var host: String
    var port: Int = 445
    var username: String = ""
    var domain: String = ""
    var useGuest: Bool = false

    var baseURL: URL {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = host
        if port != 445 {
            components.port = port
        }
        return components.url ?? URL(string: "smb://\(host)")!
    }

    var resolvedUsername: String {
        if useGuest {
            return "guest"
        }
        return username.isEmpty ? "guest" : username
    }
}
