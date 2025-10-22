//
//  InsightKitError.swift
//  InsightKit
//
//  Created by Michel Storms on 21/10/2025.
//

import Foundation

/// Defines errors thrown by InsightKit operations, such as file handling or compression.
public enum InsightKitError: LocalizedError {
    case utilityNotFound(String)
    case executionFailed(status: Int32)
    
    public var errorDescription: String? {
        switch self {
        case .utilityNotFound(let path):
            return "ZIP utility not found at path: \(path)"
        case .executionFailed(let status):
            return "ZIP process failed with exit code \(status)"
        }
    }
}
