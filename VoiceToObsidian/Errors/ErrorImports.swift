import Foundation

// This file serves as a central import point for error types
// to avoid circular dependencies

// Re-export the Error protocol for use in other files
// Error is a protocol in Swift, not a struct in Foundation
@_exported import protocol Swift.Error
