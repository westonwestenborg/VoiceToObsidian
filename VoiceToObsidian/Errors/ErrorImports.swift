import Foundation

// This file serves as a central import point for error types
// to avoid circular dependencies

// Re-export the AppError enum for use in other files
@_exported import struct Foundation.Error
