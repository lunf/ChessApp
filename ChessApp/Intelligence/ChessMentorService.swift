//
//  ChessMentorService.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 28/12/25.
//

protocol ChessMentorService {
    func analyzeMove(_ payload: ChessMentorPayload) async throws -> String
    
    func isModelAvailable() -> Bool
}
