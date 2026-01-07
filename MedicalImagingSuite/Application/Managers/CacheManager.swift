//
//  CacheManager.swift
//  MedicalImagingSuite
//
//  LRU cache manager for DICOM files and volumes
//

import Foundation

// MARK: - Cache Policy

struct CachePolicy {
    var maxSizeBytes: Int64 = 5 * 1024 * 1024 * 1024  // 5 GB default
    var maxAgeDays: Int = 7  // 7 days default
    var evictionStrategy: EvictionStrategy = .lru

    enum EvictionStrategy {
        case lru  // Least Recently Used
        case lfu  // Least Frequently Used
        case fifo  // First In First Out
    }
}

// MARK: - Cache Entry

struct CacheEntry: Codable {
    let key: String
    let filePath: String
    let size: Int64
    var accessCount: Int
    var lastAccessed: Date
    let created: Date

    mutating func recordAccess() {
        accessCount += 1
        lastAccessed = Date()
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let totalSize: Int64
    let entryCount: Int
    let oldestEntry: Date?
    let newestEntry: Date?
    let hitRate: Double
    let missRate: Double

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }

    var summary: String {
        """
        Cache Size: \(formattedSize)
        Entries: \(entryCount)
        Hit Rate: \(String(format: "%.1f%%", hitRate * 100))
        Miss Rate: \(String(format: "%.1f%%", missRate * 100))
        """
    }
}

// MARK: - Cache Manager

/// Manages local file caching with LRU eviction
actor CacheManager {

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let policy: CachePolicy
    private let encryptionService: EncryptionService

    private var entries: [String: CacheEntry] = [:]
    private var totalSize: Int64 = 0
    private var hits: Int = 0
    private var misses: Int = 0

    // MARK: - Initialization

    init(policy: CachePolicy = CachePolicy(), encryptionService: EncryptionService) throws {
        self.policy = policy
        self.encryptionService = encryptionService

        // Get cache directory
        let cacheDir = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        self.cacheDirectory = cacheDir.appendingPathComponent("DICOMCache")

        // Create cache directory if needed
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load existing cache entries
        loadCacheIndex()

        print("✅ CacheManager initialized at \(cacheDirectory.path)")
    }

    // MARK: - Cache Operations

    /// Store data in cache
    func store(data: Data, forKey key: String) async throws {
        // Check if we need to evict entries first
        let projectedSize = totalSize + Int64(data.count)
        if projectedSize > policy.maxSizeBytes {
            try await evictToFit(requiredSpace: Int64(data.count))
        }

        // Encrypt data
        let encryptedData = try await encryptionService.encrypt(data)

        // Generate file path
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        let filePath = cacheDirectory.appendingPathComponent(filename)

        // Write to disk
        try encryptedData.write(to: filePath)

        // Create cache entry
        let entry = CacheEntry(
            key: key,
            filePath: filePath.path,
            size: Int64(encryptedData.count),
            accessCount: 1,
            lastAccessed: Date(),
            created: Date()
        )

        entries[key] = entry
        totalSize += entry.size

        saveCacheIndex()

        print("💾 Cached \(data.count) bytes for key: \(key)")
    }

    /// Retrieve data from cache
    func retrieve(forKey key: String) async throws -> Data? {
        guard var entry = entries[key] else {
            misses += 1
            return nil
        }

        // Check if file exists
        let fileURL = URL(fileURLWithPath: entry.filePath)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            // Remove stale entry
            entries.removeValue(forKey: key)
            saveCacheIndex()
            misses += 1
            return nil
        }

        // Read and decrypt
        let encryptedData = try Data(contentsOf: fileURL)
        let decryptedData = try await encryptionService.decrypt(encryptedData)

        // Update access statistics
        entry.recordAccess()
        entries[key] = entry
        hits += 1

        saveCacheIndex()

        return decryptedData
    }

    /// Check if key exists in cache
    func contains(key: String) -> Bool {
        return entries[key] != nil
    }

    /// Remove specific entry
    func remove(forKey key: String) throws {
        guard let entry = entries[key] else { return }

        let fileURL = URL(fileURLWithPath: entry.filePath)
        try? fileManager.removeItem(at: fileURL)

        totalSize -= entry.size
        entries.removeValue(forKey: key)

        saveCacheIndex()

        print("🗑️ Removed cache entry: \(key)")
    }

    /// Clear all cache
    func clearAll() throws {
        // Remove all files
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for file in contents {
            try? fileManager.removeItem(at: file)
        }

        entries.removeAll()
        totalSize = 0
        hits = 0
        misses = 0

        saveCacheIndex()

        print("🗑️ Cache cleared")
    }

    // MARK: - Eviction

    private func evictToFit(requiredSpace: Int64) async throws {
        let targetSize = policy.maxSizeBytes - requiredSpace

        guard totalSize > targetSize else { return }

        print("♻️ Evicting cache entries to free space...")

        // Sort entries by eviction strategy
        let sortedEntries: [CacheEntry]

        switch policy.evictionStrategy {
        case .lru:
            sortedEntries = entries.values.sorted { $0.lastAccessed < $1.lastAccessed }
        case .lfu:
            sortedEntries = entries.values.sorted { $0.accessCount < $1.accessCount }
        case .fifo:
            sortedEntries = entries.values.sorted { $0.created < $1.created }
        }

        // Evict entries until we're under target
        for entry in sortedEntries {
            guard totalSize > targetSize else { break }

            try remove(forKey: entry.key)
        }

        print("✅ Evicted \(sortedEntries.count) entries")
    }

    /// Evict expired entries based on age
    func evictExpired() async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -policy.maxAgeDays, to: Date())!

        let expiredKeys = entries.filter { $0.value.created < cutoffDate }.map(\.key)

        for key in expiredKeys {
            try remove(forKey: key)
        }

        if !expiredKeys.isEmpty {
            print("♻️ Evicted \(expiredKeys.count) expired entries")
        }
    }

    // MARK: - Statistics

    func statistics() -> CacheStatistics {
        let totalRequests = hits + misses
        let hitRate = totalRequests > 0 ? Double(hits) / Double(totalRequests) : 0
        let missRate = totalRequests > 0 ? Double(misses) / Double(totalRequests) : 0

        return CacheStatistics(
            totalSize: totalSize,
            entryCount: entries.count,
            oldestEntry: entries.values.map(\.created).min(),
            newestEntry: entries.values.map(\.created).max(),
            hitRate: hitRate,
            missRate: missRate
        )
    }

    // MARK: - Persistence

    private var indexFileURL: URL {
        cacheDirectory.appendingPathComponent("cache-index.json")
    }

    private func loadCacheIndex() {
        guard let data = try? Data(contentsOf: indexFileURL),
              let decoded = try? JSONDecoder().decode([String: CacheEntry].self, from: data) else {
            return
        }

        entries = decoded
        totalSize = entries.values.reduce(0) { $0 + $1.size }

        print("📋 Loaded \(entries.count) cache entries")
    }

    private func saveCacheIndex() {
        guard let encoded = try? JSONEncoder().encode(entries) else { return }
        try? encoded.write(to: indexFileURL)
    }
}

// MARK: - Encryption Service

/// Handles encryption/decryption of cached data
actor EncryptionService {

    private let key: SymmetricKey

    init() {
        // In production, retrieve key from Keychain
        // For now, generate a random key
        self.key = SymmetricKey(size: .bits256)
    }

    func encrypt(_ data: Data) async throws -> Data {
        // TODO: Implement AES-256-GCM encryption
        // For now, return data as-is (placeholder)
        return data
    }

    func decrypt(_ data: Data) async throws -> Data {
        // TODO: Implement AES-256-GCM decryption
        // For now, return data as-is (placeholder)
        return data
    }
}

// MARK: - Symmetric Key (Placeholder)

struct SymmetricKey {
    enum KeySize {
        case bits256
    }

    init(size: KeySize) {
        // Placeholder
    }
}
