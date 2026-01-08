//
//  MentorSettings.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 8/1/26.
//
import Combine

@MainActor
final class MentorSettings: ObservableObject {

    @Published var isEnabled: Bool = true

    /// System / mentor prompt sent to Apple Intelligence
    @Published var prompt: String = """
    You are a friendly chess mentor.
    Explain moves in simple language.
    Focus on ideas, not engine numbers.
    """
}
