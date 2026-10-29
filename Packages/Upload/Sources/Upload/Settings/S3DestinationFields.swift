import SwiftUI

/// An S3-compatible bucket's settings.
struct S3DestinationFields: View {
    let model: UploadSettingsModel
    let id: UUID
    @Binding var configuration: UploadConfiguration

    var body: some View {
        TextField("Endpoint", text: $configuration.endpoint, prompt: Text("Required"))
            .textContentType(.URL)
        TextField("Region", text: $configuration.region, prompt: Text("us-east-1, or auto for R2"))
        TextField("Bucket", text: $configuration.bucket, prompt: Text("Required"))
        TextField("Folder in bucket", text: $configuration.pathPrefix, prompt: Text("Optional"))
        Toggle("Path-style URLs (MinIO, most self-hosted servers)", isOn: $configuration.usesPathStyle)
        TextField("Access key", text: $configuration.accessKey, prompt: Text("Required"))
        UploadSecretField(title: "Secret key", model: model, id: id)
        TextField("Public base URL", text: $configuration.publicBaseURL, prompt: Text("Optional"))
            .textContentType(.URL)
        Text(Self.note).uploadCaption()
    }

    private static let note = """
    AWS S3, MinIO, Cloudflare R2 and Backblaze B2 all work; the endpoint is the service's address, such as \
    https://s3.eu-central-1.amazonaws.com. Without a public base URL (such as https://files.example.com/oriel), the link \
    is the object's address at the endpoint, which works when the bucket is public.
    """
}
