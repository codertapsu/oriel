import Foundation

/// DeepL glossaries made on demand (PLAN §17): one per provider, glossary project and language pair, created the first
/// time a translation needs it and again when the project's terms for that pair change, after which the old one is
/// deleted. Ids are remembered between launches through `persist`. Two translations that need the same glossary at
/// the same time wait for one creation, and the supported pairs are asked for once a day per provider.
actor DeepLGlossaryBook {
    typealias Records = [String: DeepLGlossaryRecord]

    private var records: Records
    private var supportedPairs: [String: (pairs: Set<String>, fetched: Date)] = [:]
    private var creating: [String: Task<String?, any Error>] = [:]
    private let persist: @Sendable (Records) async -> Void
    private let now: @Sendable () -> Date

    /// How long the list of supported pairs is trusted.
    static let pairsLifetime: TimeInterval = 86400

    init(
        records: Records = [:],
        persist: @escaping @Sendable (Records) async -> Void = { _ in },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.records = records
        self.persist = persist
        self.now = now
    }

    /// The glossary to send with a translation, or nil when DeepL has no glossaries for the pair (the caller then
    /// protects the terms itself). Throws when DeepL refused to create it.
    func glossaryID(for spec: DeepLGlossarySpec, client: some DeepLGlossaryClient) async throws -> String? {
        if let record = records[spec.key], record.contentHash == spec.contentHash {
            return record.glossaryID
        }
        if let pending = creating[spec.key] {
            return try await pending.value
        }
        let task = Task { try await self.create(spec, client: client) }
        creating[spec.key] = task
        defer { creating[spec.key] = nil }
        return try await task.value
    }

    /// Drops a glossary DeepL no longer knows (it was deleted in the account, or the key belongs to another account),
    /// so the next translation creates it again.
    func forget(_ key: String) async {
        guard records.removeValue(forKey: key) != nil else { return }
        await persist(records)
    }

    /// Removes the records of a deleted project and returns them, so their glossaries can be deleted on the server.
    func removeRecords(forProject projectID: UUID) async -> [(key: String, record: DeepLGlossaryRecord)] {
        let removed = records.filter { $0.value.projectID == projectID }.map { (key: $0.key, record: $0.value) }
        guard !removed.isEmpty else { return [] }
        for item in removed {
            records[item.key] = nil
        }
        await persist(records)
        return removed
    }

    func record(for key: String) -> DeepLGlossaryRecord? {
        records[key]
    }

    private func create(_ spec: DeepLGlossarySpec, client: some DeepLGlossaryClient) async throws -> String? {
        guard await supports(spec, client: client) else { return nil }
        let id = try await client.createGlossary(spec)
        let previous = records[spec.key]
        records[spec.key] = DeepLGlossaryRecord(glossaryID: id, contentHash: spec.contentHash, projectID: spec.projectID, created: now())
        await persist(records)
        if let previous, previous.glossaryID != id {
            try? await client.deleteGlossary(previous.glossaryID)
        }
        return id
    }

    /// Whether DeepL lists the pair. When the list cannot be fetched, the creation is tried anyway: DeepL refuses a
    /// pair it does not support.
    private func supports(_ spec: DeepLGlossarySpec, client: some DeepLGlossaryClient) async -> Bool {
        let provider = spec.providerID.rawValue
        if let cached = supportedPairs[provider], now().timeIntervalSince(cached.fetched) < Self.pairsLifetime {
            return cached.pairs.contains(spec.pairKey)
        }
        guard let pairs = try? await client.glossaryLanguagePairs() else { return true }
        supportedPairs[provider] = (pairs, now())
        return pairs.contains(spec.pairKey)
    }
}
