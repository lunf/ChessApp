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
                maximumResponseTokens: 800
            )
        )

        return response.content
    }

    private func buildUserPrompt(from payload: ChessMentorPayload) -> String {
        switch payload.requestKind {
        case .engineMove:
            return buildEngineMovePrompt(from: payload)
        case .positionGuide:
            return buildPositionGuidePrompt(from: payload)
        }
    }

    private func buildEngineMovePrompt(from payload: ChessMentorPayload) -> String {
        """
        You are a chess mentor.
        Respond ONLY in \(payload.responseLanguage).
        You may use concise Markdown formatting and emoji when it helps clarity.
        Format as Markdown with short sections, blank lines between sections, and bullet points on separate lines. Avoid one long paragraph.
        Keep the full response under 800 tokens.
        
        The ENGINE has just played a move.
        Your job is to explain the ENGINE'S decision to the HUMAN player.
        
        Position (FEN):
        \(payload.fen)

        Full move history (UCI):
        \(payload.moves.isEmpty ? "No moves yet" : payload.moves.joined(separator: ", "))

        Human is playing \(payload.playerColor).

        Engine move to analyze:
        \(payload.bestMove ?? "none")

        Explain:
        - What is the main idea of the engine move?
        - What threat or plan does it create?
        """
    }

    private func buildPositionGuidePrompt(from payload: ChessMentorPayload) -> String {
        """
        You are a chess mentor.
        Respond ONLY in \(payload.responseLanguage).
        You may use concise Markdown formatting and emoji when it helps clarity.
        Format as Markdown with short sections, blank lines between sections, and bullet points on separate lines. Avoid one long paragraph.
        Keep the full response under 800 tokens.

        Explain the current position to the HUMAN player and guide their next move.

        Position (FEN):
        \(payload.fen)

        Full move history (UCI):
        \(payload.moves.isEmpty ? "No moves yet" : payload.moves.joined(separator: ", "))

        Side to move:
        \(payload.sideToMove)

        Human is playing \(payload.playerColor).

        Give a concise coaching answer:
        - Who is better or what is the nature of the position?
        - What are 1-2 candidate moves or plans for the human?
        - What should the human watch out for immediately?
        """
    }

}
