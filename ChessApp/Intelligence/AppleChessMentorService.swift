//
//  AppleChessMentorService.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 28/12/25.
//

import Foundation
import FoundationModels   // iOS 18+

final class AppleChessMentorService: ChessMentorService {
    
    private var model = SystemLanguageModel.default
    
    func isModelAvailable() -> Bool {
        switch model.availability {
        case .available:
            return true
        default:
            return false
        }
    }
    
    func analyzeMove(_ payload: ChessMentorPayload) async throws -> String {
        let userPrompt = buildUserPrompt(from: payload)
        
        let session = LanguageModelSession(
            instructions: payload.sysPrompt
        )
        
        // Use the FoundationModels generation API.
        let response = try await session.respond(
            to: userPrompt,
            options: GenerationOptions(
                temperature: 0.4,
                maximumResponseTokens: 300
            )
        )

        return response.content
    }

    private func buildUserPrompt(from payload: ChessMentorPayload) -> String {
        """
        You are a chess mentor.
        Respond ONLY in English.
        
        The ENGINE has just played a move.
        Your job is to explain the ENGINE'S decision to the HUMAN player.
        
        Position (FEN):
        \(payload.fen)

        Recent moves (for context, last 5):
        \(payload.moves.joined(separator: ", "))

        Human is playing \(payload.playerColor).

        Engine move to analyze:
        \(payload.bestMove ?? "none")

        Explain:
        - What is the main idea of the engine move?
        - What threat or plan does it create?
        """
    }
}
