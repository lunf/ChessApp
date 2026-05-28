//
//  GameEngineManager.swift
//  ChessApp
//

import Combine
import Foundation

@MainActor
protocol GameEngineManager: AnyObject {
    var bestMove: String? { get }
    var isThinking: Bool { get }
    var bestMovePublisher: AnyPublisher<String?, Never> { get }
    var isThinkingPublisher: AnyPublisher<Bool, Never> { get }

    func start()
    func setElo(_ elo: Int)
    func newGame()
    func move(_ uci: String)
    func think(fen: String)
    func setPosition(fen: String)
    func stop()
    func shutdown()
}
