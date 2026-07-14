import Foundation

enum PromptContent {
    case structured(PromptDraft)
    case compatibility(text: String, reason: String)
    case unavailable(reason: String)

    var canonicalText: String {
        switch self {
        case .structured(let draft): PromptRenderer.render(draft)
        case .compatibility(let text, _): text
        case .unavailable: ""
        }
    }
}
