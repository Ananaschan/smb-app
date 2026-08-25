import Foundation

struct SMBDiscoveredServer: Identifiable {
    var id: String { "\(host):\(port)" }
    let name: String
    let host: String
    let port: Int
}

final class SMBDiscovery: NSObject, ObservableObject {
    @Published var results: [SMBDiscoveredServer] = []

    private var browser: NetServiceBrowser?

    func start() {
        stop()
        results.removeAll()
        let browser = NetServiceBrowser()
        self.browser = browser
        browser.delegate = self
        browser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")
    }

    func stop() {
        browser?.stop()
        browser = nil
    }
}

extension SMBDiscovery: NetServiceBrowserDelegate {
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        service.delegate = self
        service.resolve(withTimeout: 5)
        _ = moreComing
    }
}

extension SMBDiscovery: NetServiceDelegate {
    func netServiceDidResolveAddress(_ sender: NetService) {
        let name = sender.name
        let host = sender.hostName
        let port = sender.port
        DispatchQueue.main.async { [weak self] in
            guard let self, let host else {
                return
            }
            let item = SMBDiscoveredServer(name: name, host: host, port: port)
            if !self.results.contains(where: { $0.id == item.id }) {
                self.results.append(item)
            }
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        _ = errorDict
        _ = sender
    }
}
