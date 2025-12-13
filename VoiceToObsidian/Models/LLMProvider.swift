import Foundation

/// Available LLM providers for transcript processing
enum LLMProvider: String, CaseIterable, Codable, Identifiable {
    case foundationModels = "foundation_models"
    case anthropic = "anthropic"
    case openai = "openai"
    case gemini = "gemini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .foundationModels: return "Apple Intelligence"
        case .anthropic: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini (Google)"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .foundationModels: return false
        case .anthropic, .openai, .gemini: return true
        }
    }

    /// Default model for each provider
    var defaultModel: String {
        switch self {
        case .foundationModels: return "default"
        case .anthropic: return "claude-sonnet-4-5-20250929"
        case .openai: return "gpt-4o"
        case .gemini: return "gemini-2.0-flash"
        }
    }

    /// Available models for each provider
    var availableModels: [String] {
        switch self {
        case .foundationModels: return ["default"]
        case .anthropic: return ["claude-sonnet-4-5-20250929", "claude-haiku-3-5-20240307"]
        case .openai: return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
        case .gemini: return ["gemini-2.0-flash", "gemini-1.5-pro", "gemini-1.5-flash"]
        }
    }
}
