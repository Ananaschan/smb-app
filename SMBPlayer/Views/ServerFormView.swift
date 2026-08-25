import SwiftUI

struct ServerFormView: View {
    @EnvironmentObject private var store: SMBServerStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var host = ""
    @State private var port = "445"
    @State private var username = ""
    @State private var domain = ""
    @State private var password = ""
    @State private var useGuest = false

    init(initialServer: SMBServer? = nil) {
        let server = initialServer
        _displayName = State(initialValue: server?.displayName ?? "")
        _host = State(initialValue: server?.host ?? "")
        _port = State(initialValue: server.map { "\($0.port)" } ?? "445")
        _username = State(initialValue: server?.username ?? "")
        _domain = State(initialValue: server?.domain ?? "")
        _useGuest = State(initialValue: server?.useGuest ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("例如：客厅电脑", text: $displayName)
                }
                Section("连接") {
                    TextField("IP 或主机名", text: $host)
                        .keyboardType(.numbersAndPunctuation)
                    HStack {
                        Text("端口")
                        Spacer()
                        TextField("445", text: $port)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("访客登录", isOn: $useGuest)
                }
                if !useGuest {
                    Section("账号") {
                        TextField("用户名", text: $username)
                            .textContentType(.username)
                        TextField("域（可选）", text: $domain)
                        SecureField("密码", text: $password)
                            .textContentType(.password)
                    }
                }
            }
            .navigationTitle("添加服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(host.isEmpty)
                }
            }
        }
    }

    @MainActor
    private func save() {
        let server = SMBServer(
            displayName: displayName.isEmpty ? host : displayName,
            host: host,
            port: Int(port) ?? 445,
            username: username,
            domain: domain,
            useGuest: useGuest
        )
        store.add(server)
        KeychainStore.setPassword(useGuest ? nil : password, for: server)
        dismiss()
    }
}
