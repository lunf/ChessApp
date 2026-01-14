//
//  EengineManager.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 14/12/25.
//

import Combine
import Foundation

enum EngineEvent {
    case info(String)
    case bestMove(String)
}

@MainActor
final class EngineManager: ObservableObject {

    static let shared = EngineManager()

    private let queue = DispatchQueue(label: "stockfish.engine.queue")
    private var isEngineReady = false

    @Published var bestMove: String? = nil
    @Published var isThinking: Bool = false

    private var readingStarted = false
    private var searchDepth = 10

    // Default values
    let minElo = 1347
    let maxElo = 3176

    let minDepth = 3
    let maxDepth = 14

    private init() {}

    func start() {
        sf_init()
        startReading()

        send("uci")
        send("isready")
        configureNNUE()

        send("setoption name Threads value 1")
        send("setoption name Hash value 32")
    }

    func setElo(_ elo: Int) {
        let depth = depthForElo(elo)

        send("setoption name UCI_LimitStrength value true")
        send("setoption name UCI_Elo value \(elo)")
        send("isready")

        self.searchDepth = depth
    }

    func newGame() {
        send("stop")
        send("ucinewgame")
        send("isready")
    }
    
    func move(_ uci: String) {
        // No position manipulation here
        send(uci)
    }

    func think(fen: String) {
        guard !isThinking else { return }

        bestMove = nil
        isThinking = true

        send("stop")
        send("position fen \(fen)")
        send("go depth \(searchDepth)")
    }
    
    func setPosition(fen: String) {
        send("stop")
        send("position fen \(fen)")
        send("isready")
    }

    func stop() {
        send("stop")
    }

    func send(_ cmd: String) {
        print("SEND:", cmd)
        sf_send(cmd)
    }

    // MARK: Helpers

    private func startReading() {
        queue.async { [weak self] in
            guard let self else { return }

            while true {
                if let cStr = sf_read() {
                    let line = String(cString: cStr).trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    guard !line.isEmpty else { continue }

                    print("SF:", line)

                    if line.hasPrefix("bestmove") {
                        let parts = line.split(separator: " ")
                        if parts.count >= 2 {
                            let move = String(parts[1])

                            // Hop to the main actor before touching main-actor isolated state.
                            Task { @MainActor in
                                self.bestMove = move
                                self.isThinking = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func configureNNUE() {
        let big = Bundle.main.path(
            forResource: "nn-2962dca31855",
            ofType: "nnue"
        )!

        let small = Bundle.main.path(
            forResource: "nn-37f18f62d772",
            ofType: "nnue"
        )!

        send("setoption name EvalFile value \(big)")
        send("setoption name EvalFileSmall value \(small)")
    }

    private func depthForElo(_ elo: Int) -> Int {
        let clampedElo = min(max(elo, minElo), maxElo)

        let eloRange = maxElo - minElo
        let depthRange = maxDepth - minDepth

        let normalized = Double(clampedElo - minElo) / Double(eloRange)
        let depth = Double(minDepth) + normalized * Double(depthRange)

        return Int(depth.rounded())
    }
}
