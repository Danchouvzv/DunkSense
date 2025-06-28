import Foundation

class CacheManager {
    private let cache = NSCache<NSString, NSData>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        // Setup cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("DunkSenseCache")
        
        // Create cache directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // Configure memory cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        setupCacheCleanup()
    }
    
    // MARK: - Memory Cache
    func cache<T: Codable>(_ object: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(object)
            cache.setObject(data as NSData, forKey: key as NSString)
            
            // Also save to disk for persistence
            saveToDisk(data, forKey: key)
        } catch {
            print("Failed to cache object for key \(key): \(error)")
        }
    }
    
    func retrieve<T: Codable>(forKey key: String, as type: T.Type = T.self) -> T? {
        // First try memory cache
        if let data = cache.object(forKey: key as NSString) as Data? {
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                print("Failed to decode cached object for key \(key): \(error)")
            }
        }
        
        // Then try disk cache
        return retrieveFromDisk(forKey: key, as: type)
    }
    
    func removeObject(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
        removeFromDisk(forKey: key)
    }
    
    func clearAll() {
        cache.removeAllObjects()
        clearDiskCache()
    }
    
    // MARK: - Disk Cache
    private func saveToDisk<T: Codable>(_ data: Data, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        do {
            try data.write(to: fileURL)
        } catch {
            print("Failed to save to disk for key \(key): \(error)")
        }
    }
    
    private func retrieveFromDisk<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let object = try JSONDecoder().decode(type, from: data)
            
            // Also cache in memory for faster access
            cache.setObject(data as NSData, forKey: key as NSString)
            
            return object
        } catch {
            print("Failed to retrieve from disk for key \(key): \(error)")
            // Remove corrupted file
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
    }
    
    private func removeFromDisk(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func clearDiskCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("Failed to clear disk cache: \(error)")
        }
    }
    
    // MARK: - Cache Cleanup
    private func setupCacheCleanup() {
        // Clean up old cache files on initialization
        cleanupOldCacheFiles()
        
        // Setup periodic cleanup
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.cleanupOldCacheFiles()
        }
    }
    
    private func cleanupOldCacheFiles() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey])
            let cutoffDate = Date().addingTimeInterval(-7 * 24 * 3600) // 7 days ago
            
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
                if let creationDate = resourceValues.creationDate, creationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Failed to cleanup old cache files: \(error)")
        }
    }
    
    // MARK: - Cache Statistics
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        } catch {
            print("Failed to calculate cache size: \(error)")
        }
        
        return totalSize
    }
    
    func getCacheFileCount() -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return files.count
        } catch {
            return 0
        }
    }
}

// MARK: - Cache Extensions
extension CacheManager {
    // Convenience methods for common data types
    
    func cacheString(_ string: String, forKey key: String) {
        cache(string, forKey: key)
    }
    
    func retrieveString(forKey key: String) -> String? {
        return retrieve(forKey: key, as: String.self)
    }
    
    func cacheData(_ data: Data, forKey key: String) {
        cache.setObject(data as NSData, forKey: key as NSString)
        saveToDisk(data, forKey: key)
    }
    
    func retrieveData(forKey key: String) -> Data? {
        if let data = cache.object(forKey: key as NSString) as Data? {
            return data
        }
        
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        return try? Data(contentsOf: fileURL)
    }
}

// MARK: - DataExporter
class DataExporter {
    static func export(metrics: [JumpMetric], format: ExportFormat) async throws -> URL {
        let fileName = "jump_metrics_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        switch format {
        case .csv:
            return try await exportToCSV(metrics: metrics, url: fileURL)
        case .json:
            return try await exportToJSON(metrics: metrics, url: fileURL)
        case .pdf:
            return try await exportToPDF(metrics: metrics, url: fileURL)
        }
    }
    
    private static func exportToCSV(metrics: [JumpMetric], url: URL) async throws -> URL {
        var csvContent = "Date,Height (cm),Height (in),Flight Time (s),Contact Time (s),Takeoff Velocity (m/s),Landing Force (N),Symmetry Score,Technique Score,Overall Score,Grade\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        for metric in metrics {
            let row = [
                dateFormatter.string(from: metric.timestamp),
                String(format: "%.2f", metric.jumpHeight),
                String(format: "%.2f", metric.jumpHeightInches),
                String(format: "%.3f", metric.flightTime),
                String(format: "%.3f", metric.contactTime),
                String(format: "%.2f", metric.takeoffVelocity),
                String(format: "%.0f", metric.landingForce),
                String(format: "%.3f", metric.symmetryScore),
                String(format: "%.3f", metric.techniqueScore),
                String(format: "%.3f", metric.overallScore),
                metric.grade.rawValue
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private static func exportToJSON(metrics: [JumpMetric], url: URL) async throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(metrics)
        try data.write(to: url)
        return url
    }
    
    private static func exportToPDF(metrics: [JumpMetric], url: URL) async throws -> URL {
        // This would require a PDF generation library like PDFKit
        // For now, we'll create a simple text-based PDF
        let textContent = generatePDFContent(metrics: metrics)
        try textContent.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    private static func generatePDFContent(metrics: [JumpMetric]) -> String {
        var content = "DUNKSENSE JUMP METRICS REPORT\n"
        content += "Generated: \(Date())\n\n"
        
        if !metrics.isEmpty {
            let stats = calculateBasicStats(metrics: metrics)
            content += "SUMMARY STATISTICS\n"
            content += "==================\n"
            content += "Total Jumps: \(stats.totalJumps)\n"
            content += "Average Height: \(String(format: "%.2f", stats.averageHeight)) cm\n"
            content += "Best Jump: \(String(format: "%.2f", stats.bestHeight)) cm\n"
            content += "Average Technique: \(String(format: "%.3f", stats.averageTechnique))\n"
            content += "Average Symmetry: \(String(format: "%.3f", stats.averageSymmetry))\n\n"
        }
        
        content += "DETAILED METRICS\n"
        content += "================\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        
        for (index, metric) in metrics.enumerated() {
            content += "\nJump #\(index + 1)\n"
            content += "Date: \(dateFormatter.string(from: metric.timestamp))\n"
            content += "Height: \(String(format: "%.2f", metric.jumpHeight)) cm (\(metric.jumpHeightFeet))\n"
            content += "Flight Time: \(String(format: "%.3f", metric.flightTime)) s\n"
            content += "Technique Score: \(String(format: "%.3f", metric.techniqueScore))\n"
            content += "Symmetry Score: \(String(format: "%.3f", metric.symmetryScore))\n"
            content += "Grade: \(metric.grade.rawValue) \(metric.grade.emoji)\n"
        }
        
        return content
    }
    
    private static func calculateBasicStats(metrics: [JumpMetric]) -> (totalJumps: Int, averageHeight: Double, bestHeight: Double, averageTechnique: Double, averageSymmetry: Double) {
        let totalJumps = metrics.count
        let averageHeight = metrics.map(\.jumpHeight).reduce(0, +) / Double(totalJumps)
        let bestHeight = metrics.max { $0.jumpHeight < $1.jumpHeight }?.jumpHeight ?? 0
        let averageTechnique = metrics.map(\.techniqueScore).reduce(0, +) / Double(totalJumps)
        let averageSymmetry = metrics.map(\.symmetryScore).reduce(0, +) / Double(totalJumps)
        
        return (totalJumps, averageHeight, bestHeight, averageTechnique, averageSymmetry)
    }
} 