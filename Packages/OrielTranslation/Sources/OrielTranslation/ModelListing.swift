/// Providers whose servers list their models, for the "Fetch models" button in Settings.
protocol ModelListing: Sendable {
    func listModels() async throws -> [String]
}
