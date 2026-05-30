//
//  GameSnapshot.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 9/1/26.
//

struct GameSnapshot: Codable {
    let fen: String
    let moves: [String]
    let whitePlayer: PlayerType
    let blackPlayer: PlayerType
    let startedFromSetup: Bool?
    let clockPreset: String?
    let whiteTimeRemaining: Int?
    let blackTimeRemaining: Int?
}
