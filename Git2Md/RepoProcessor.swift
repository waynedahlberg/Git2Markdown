//
//  RepoProcessor.swift
//  Git2Md
//
//  Created by Wayne Dahlberg on 11/24/25.
//

import Foundation

struct RepoProcessor {
    
    struct Configuration {
        let url: URL
        let allowedExtensions: [String] // e.g., ["swift", "py", "md"]
        let excludedFolders: [String]   // e.g., [".git", "node_modules"]
    }
    
    static func generateReport(config: Configuration) -> String {
        var output = ""
        let fileManager = FileManager.default
        
        // 1. Generate Tree Structure
        output += "Directory Structure:\n"
        output += "-------------------\n"
        output += generateTreeString(path: config.url.path, config: config)
        output += "\n\n"
        
        // 2. Generate File Contents
        output += "File Contents:\n"
        output += "--------------\n"
        
        if let enumerator = fileManager.enumerator(at: config.url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            
            for case let fileURL as URL in enumerator {
                let relativePath = fileURL.path.replacingOccurrences(of: config.url.path + "/", with: "")
                
                // Check exclusions
                if shouldSkip(path: relativePath, config: config) { continue }
                
                // Check extension
                if !config.allowedExtensions.isEmpty {
                    if !config.allowedExtensions.contains(fileURL.pathExtension) { continue }
                }
                
                // Append Content
                output += "File: \(relativePath)\n"
                output += String(repeating: "-", count: 50) + "\n"
                
                do {
                    // Attempt to read text (skip binary files)
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    output += "Content of \(relativePath):\n"
                    output += content
                    output += "\n\n"
                } catch {
                    output += "(Binary file or non-UTF8 content skipped)\n\n"
                }
            }
        }
        
        return output
    }
    
    // Helper: Generate the visual tree
    static func generateTreeString(path: String, config: Configuration, prefix: String = "") -> String {
        var result = ""
        let url = URL(fileURLWithPath: path)
        
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else { return "" }
        
        let sortedContents = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        for (index, item) in sortedContents.enumerated() {
            let isLast = index == sortedContents.count - 1
            let name = item.lastPathComponent
            
            // Skip hidden files/folders like .git
            if name.hasPrefix(".") { continue }
            
            let relativePath = item.path.replacingOccurrences(of: config.url.path + "/", with: "")
            
            // Check Exclusions (Simple check for folders)
            var isExcluded = false
            for exclusion in config.excludedFolders {
                if relativePath.contains(exclusion) { isExcluded = true }
            }
            if isExcluded { continue }

            let connector = isLast ? "└── " : "├── "
            result += "\(prefix)\(connector)\(name)\n"
            
            // Recursion for directories
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                let newPrefix = prefix + (isLast ? "    " : "│   ")
                result += generateTreeString(path: item.path, config: config, prefix: newPrefix)
            }
        }
        return result
    }
    
    static func shouldSkip(path: String, config: Configuration) -> Bool {
        for exclusion in config.excludedFolders {
            if path.contains(exclusion) { return true }
        }
        return false
    }
}
