//
//  ChessMentorPayload.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 28/12/25.
//

struct ChessMentorPayload: Codable {
    let fen: String
    let moves: [String]
    let moveNumber: Int
    let sideToMove: String
    let playerColor: String
    let engineEval: Double?
    let bestMove: String?
    let sysPrompt: String
    let responseLanguage: String
}
