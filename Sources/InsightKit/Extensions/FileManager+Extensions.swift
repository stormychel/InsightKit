//
//  FileManager+Extensions.swift
//  InsightKit
//
//  Created by Michel Storms on 21/10/2025.
//

import Foundation

extension FileManager {
    
    /// Creates a ZIP archive containing all flat files in the given directory.
    ///
    /// - Parameters:
    ///   - sourceDirectory: The directory whose contents should be compressed.
    ///   - destination: The path where the resulting ZIP archive should be written.
    /// - Throws: An error if the operation fails or if the system ZIP utility is unavailable.
    ///
    /// This method uses `/usr/bin/zip` with the `-j` flag to create a flat archive
    /// without folder hierarchy. Intended for use within InsightKit diagnostics.
    func archiveContents(of sourceDirectory: URL, to destination: URL) throws {
        let zipUtilityPath = "/usr/bin/zip"
        
        guard FileManager.default.isExecutableFile(atPath: zipUtilityPath) else {
            throw InsightKitError.utilityNotFound(zipUtilityPath)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zipUtilityPath)
        
        // Collect the files to be included in the archive
        let files = try contentsOfDirectory(at: sourceDirectory, includingPropertiesForKeys: nil)
        var arguments = ["-j", destination.path]
        arguments.append(contentsOf: files.map(\.path))
        process.arguments = arguments
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw InsightKitError.executionFailed(status: process.terminationStatus)
        }
    }
}
