import Foundation

@MainActor
final class SMBServerStore: ObservableObject {
    @Published var servers: [SMBServer] = []

    private var fileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("servers.json")
    }

    init() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SMBServer].self, from: data) {
            servers = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(servers) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func add(_ server: SMBServer) {
        servers.append(server)
        save()
    }

    func delete(at offsets: IndexSet) {
        servers.remove(atOffsets: offsets)
        save()
    }
}
