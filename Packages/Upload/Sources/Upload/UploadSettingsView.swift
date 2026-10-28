import OrielCore
import SwiftUI

/// Settings → Upload (PLAN §7.8): one S3-compatible destination.
public struct UploadSettingsView: View {
    @Bindable private var settings: SettingsStore
    private let keychain: KeychainStore
    private let coordinator: UploadCoordinator
    @State private var secretKey = ""
    @State private var testResult: String?
    @State private var isTesting = false

    public init(settings: SettingsStore, keychain: KeychainStore, coordinator: UploadCoordinator) {
        self.settings = settings
        self.keychain = keychain
        self.coordinator = coordinator
    }

    public var body: some View {
        Form {
            Section {
                TextField("Endpoint", text: field(\.endpoint), prompt: Text("https://s3.eu-central-1.amazonaws.com"))
                TextField("Region", text: field(\.region), prompt: Text("us-east-1, or auto for R2"))
                TextField("Bucket", text: field(\.bucket))
                TextField("Folder in bucket", text: field(\.pathPrefix), prompt: Text("optional"))
                Toggle("Path-style URLs (MinIO, most self-hosted servers)", isOn: field(\.usesPathStyle))
            } header: {
                Text("S3-compatible storage")
            } footer: {
                Text("AWS S3, MinIO, Cloudflare R2 and Backblaze B2 all work. Objects get an unguessable name.")
            }
            Section("Credentials") {
                TextField("Access key", text: field(\.accessKey))
                SecureField("Secret key", text: $secretKey)
                    .onSubmit(saveSecret)
                    .onChange(of: secretKey) { saveSecret() }
                Text("The secret key is stored in your login keychain, never in settings files.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Links") {
                TextField("Public base URL", text: field(\.publicBaseURL), prompt: Text("https://files.internal/oriel (optional)"))
                Toggle("Copy the link after uploading", isOn: $settings[UploadSettings.copiesLink])
                Toggle("Remove image metadata before uploading", isOn: field(\.stripsMetadata))
            }
            Section {
                HStack {
                    Button(isTesting ? "Testing…" : "Test connection") {
                        isTesting = true
                        Task {
                            testResult = await coordinator.testConnection()
                            isTesting = false
                        }
                    }
                    .disabled(isTesting || !settings[UploadSettings.configuration].isComplete)
                    if let testResult {
                        Text(testResult).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            secretKey = keychain.string(service: UploadSettings.keychainService, account: UploadSettings.keychainAccount) ?? ""
        }
    }

    private func field<Value>(_ keyPath: WritableKeyPath<UploadConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { settings[UploadSettings.configuration][keyPath: keyPath] },
            set: { settings[UploadSettings.configuration][keyPath: keyPath] = $0 }
        )
    }

    private func saveSecret() {
        try? keychain.setString(secretKey, service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)
    }
}
