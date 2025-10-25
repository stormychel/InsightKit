//
//  InsightKit.swift
//  InsightKit
//
//  Created by Michel Storms on 2025-10-21.
//
//  A lightweight Swift logging and diagnostics engine.
//  Features: structured file logging, rotation, compression,
//  and optional macOS system insight collection.
//

import Foundation
import os
#if canImport(Cocoa)
import Cocoa
#endif

// MARK: - Core API

#if os(macOS)
@available(macOS 11.0, *)
public final class InsightCenter {
    
    // MARK: Singleton
    
    public static let shared = InsightCenter()

    private let appName: String

    private init() {
        self.appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "InsightKit"
        Task { await prepareStorage() }
    }
    
    // MARK: Public Logging Interface
    
    public func trace(_ text: String)    { write(level: .trace, text) }
    public func info(_ text: String)     { write(level: .info, text) }
    public func notice(_ text: String)   { write(level: .notice, text) }
    public func warning(_ text: String)  { write(level: .warning, text) }
    public func error(_ text: String)    { write(level: .error, text) }
    public func critical(_ text: String) { write(level: .critical, text) }
    
    // MARK: Public Properties
    
    /// Returns the directory where InsightKit stores its log files.
    public var logDirectory: URL {
        Self.defaultDirectory(appName: appName)
    }
    
    // MARK: Internals
    
    private let queue = DispatchQueue(label: "com.insightkit.queue", qos: .utility)
    private let log = Logger(subsystem: "com.insightkit", category: "core")
    private var fileHandle: FileHandle?
    private var currentFileURL: URL?
    
    // MARK: Log Writer
    
    private func write(level: InsightLevel, _ text: String) {
        queue.async(flags: .barrier) {
            self.ensureFileHandle()
            self.rotateIfOversized()
            
            let line = "\(Self.timestamp()) [\(level.rawValue)] \(text)\n"
            
            switch level {
            case .trace:    self.log.debug("\(line, privacy: .public)")
            case .info:     self.log.info("\(line, privacy: .public)")
            case .notice:   self.log.notice("\(line, privacy: .public)")
            case .warning:  self.log.warning("\(line, privacy: .public)")
            case .error:    self.log.error("\(line, privacy: .public)")
            case .critical: self.log.critical("\(line, privacy: .public)")
            }
            
            if let data = line.data(using: .utf8), let fh = self.fileHandle {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.synchronizeFile()
            } else {
                print("[InsightKit] \(line)")
            }
        }
    }
    
    // MARK: Storage Setup
    
    private func prepareStorage() async {
        let fm = FileManager.default
        let folder = Self.defaultDirectory(appName: appName)
        let fileURL = folder.appendingPathComponent("InsightKit.log")
        
        currentFileURL = fileURL
        
        do {
            if !fm.fileExists(atPath: folder.path) {
                try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            
            if !fm.fileExists(atPath: fileURL.path) {
                fm.createFile(atPath: fileURL.path, contents: nil)
            }
            
            fileHandle = try FileHandle(forWritingTo: fileURL)
            fileHandle?.seekToEndOfFile()
        } catch {
            log.error("InsightCenter.prepareStorage() failed: \(error.localizedDescription)")
        }
    }
    
    private func ensureFileHandle() {
        if fileHandle == nil, let url = currentFileURL {
            fileHandle = try? FileHandle(forWritingTo: url)
            fileHandle?.seekToEndOfFile()
        }
    }
    
    // MARK: Rotation

    private func rotateIfOversized(limit: Int64 = 4_000_000) {
        guard let url = currentFileURL else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        do {
            let attr = try fm.attributesOfItem(atPath: url.path)
            if let size = attr[.size] as? Int64, size > limit { rotateLog() }
        } catch {
            log.error("InsightCenter.rotateIfOversized() failed: \(error.localizedDescription)")
        }
    }

    private func rotateLog() {
        queue.async(flags: .barrier) {
            guard let url = self.currentFileURL else { return }
            let fm = FileManager.default
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("InsightKit_\(Self.rotationStamp()).log")
    
            do {
                if fm.fileExists(atPath: backup.path) { try fm.removeItem(at: backup) }
                try fm.moveItem(at: url, to: backup)
                Task { await self.prepareStorage() }
            } catch {
                self.log.error("InsightCenter.rotateLog() failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: Packaging
    
    public func makeArchive() -> URL? {
        guard let url = currentFileURL else { return nil }
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let tmp = dir.appendingPathComponent("report_temp")
        let zip = dir.appendingPathComponent("insight_report.zip")
        
        do {
            if fm.fileExists(atPath: zip.path) { try fm.removeItem(at: zip) }
            if fm.fileExists(atPath: tmp.path) { try fm.removeItem(at: tmp) }
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
            
            try fm.copyItem(at: url, to: tmp.appendingPathComponent(url.lastPathComponent))
            if let short = writeShortLog(limit: 12000) {
                try fm.copyItem(at: short, to: tmp.appendingPathComponent("short_log.txt"))
            }
            #if canImport(Cocoa)
            writeSystemInsight(to: tmp)
            #endif
            
            try fm.archiveContents(of: tmp, to: zip)
            try fm.removeItem(at: tmp)
            return zip
        } catch {
            log.error("InsightCenter.makeArchive() failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func writeShortLog(limit: Int = 12000) -> URL? {
        guard let source = currentFileURL else { return nil }
        guard let contents = try? String(contentsOf: source) else { return nil }
        let snippet = String(contents.suffix(limit))
        let url = source.deletingLastPathComponent().appendingPathComponent("short_log.txt")
        try? snippet.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // MARK: macOS System Context
    
    #if canImport(Cocoa)
    private func writeSystemInsight(to dir: URL) {
        let fm = FileManager.default
        let osFile = dir.appendingPathComponent("system.txt")
        let procFile = dir.appendingPathComponent("processes.txt")
        let info = ProcessInfo.processInfo
        
        var system = """
        macOS: \(info.operatingSystemVersionString)
        Host: \(info.hostName)
        Memory: \(info.physicalMemory / (1024*1024)) MB
        CPUs: \(info.processorCount)
        Active: \(info.activeProcessorCount)
        """
        
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        system += "\nArch: \(String(cString: buf))\n"
        
        var procs = "Running Apps:\n"
        for app in NSWorkspace.shared.runningApplications {
            if let n = app.localizedName, let b = app.bundleIdentifier {
                procs += "\(n) — \(b) (pid \(app.processIdentifier))\n"
            }
        }
        try? system.write(to: osFile, atomically: true, encoding: .utf8)
        try? procs.write(to: procFile, atomically: true, encoding: .utf8)
    }
    #endif
    
    // MARK: Utilities

    private static func defaultDirectory(appName: String) -> URL {
        #if os(macOS)
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/\(appName)")
        #else
        FileManager.default.temporaryDirectory.appendingPathComponent(appName)
        #endif
    }
    
    private static func timestamp() -> String {
        let now = Date()
        let base = tsFormatter.string(from: now)
        let micros = Int((now.timeIntervalSince1970 * 1_000_000)
                         .truncatingRemainder(dividingBy: 1_000_000)) % 1000
        return "\(base)\(String(format: "%03d", micros))"
    }
    
    private static func rotationStamp() -> String {
        rotateFormatter.string(from: Date())
    }
    
    private static let tsFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
    
    private static let rotateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()
}
#endif

// MARK: - Severity Levels

public enum InsightLevel: String {
    case trace = "TRACE"
    case info = "INFO"
    case notice = "NOTICE"
    case warning = "WARN"
    case error = "ERROR"
    case critical = "CRITICAL"
}
