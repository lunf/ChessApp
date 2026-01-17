//
//  MentorSettings.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 8/1/26.
//
import Combine
import Foundation
import SwiftUI

@MainActor
final class MentorSettings: ObservableObject {

    @AppStorage("mentor_enabled")
    var isEnabled: Bool = true

    /// System / mentor prompt sent to Apple Intelligence
    @AppStorage("mentor_prompt")
    var prompt: String = """
    You are a friendly chess mentor.
    Explain moves in simple language.
    Focus on ideas, not engine numbers.
    """
    
    @AppStorage("mentor_force_english")
    var forceEnglish: Bool = true
    
    var responseLanguage: String {
        if forceEnglish {
            return "English"
        } else {
            return Locale.current.localizedString(
                forLanguageCode: Locale.current.language.languageCode?.identifier ?? "en"
            ) ?? "English"
        }
    }
}
