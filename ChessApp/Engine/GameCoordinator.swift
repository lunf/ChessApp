//
//  GameCoordinator.swift
//  ChessApp
//

import Combine
import Foundation

@MainActor
final class GameCoordinator: ObservableObject {
    let engine: any GameEngineManager
    let mentorSettings: MentorSettings
    let mentor: ChessMentorManager
    let game: GameState

    @Published var gameResult: GameResult = .ongoing
    @Published var whitePlayer: PlayerType = .human
    @Published var blackPlayer: PlayerType = .engine
    @Published var boardFlipped = false
    @Published var isResetting = false
    @Published var promotionContext: PromotionContext?
    @Published var mentorMessages: [MentorMessage] = [
        MentorMessage(role: .system, text: "I'm your chess mentor. Ask me about any move.")
    ]
    @Published var mentorIsThinking = false

    private var pendingPromotionMove: UCIMove?
    private var mentorUnavailableShown = false
    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        self.init(
            engine: StockfishEngine.shared,
            mentorSettings: MentorSettings(),
            mentorService: AppleChessMentorService(),
            game: GameState()
        )
    }

    init(
        engine: any GameEngineManager,
        mentorSettings: MentorSettings,
        mentorService: ChessMentorService,
        game: GameState
    ) {
        self.engine = engine
        self.mentorSettings = mentorSettings
        self.mentor = ChessMentorManager(service: mentorService, settings: mentorSettings)
        self.game = game

        bindEngine()
    }

    func start(elo: Int) {
        engine.start()
        engine.setElo(elo)
        mentor.checkModelAvailability()
        restoreGameIfAvailable()
    }

    func setElo(_ elo: Int) {
        engine.setElo(elo)
    }

    func handleUserMove(_ move: UCIMove) {
        guard isGameOngoing() else {
            handleGameResultAfterMove()
            return
        }

        if checkAndHandlePromotion(from: move.from, to: move.to) {
            pendingPromotionMove = move
            return
        }

        engine.move(move.rawValue)
        game.recordMove(move.rawValue)
        persistGame()

        handleGameResultAfterMove()
        requestEngineMoveIfNeeded()
    }

    func promotePawn(from: Square, to: Square, toPiece type: PieceType) {
        guard let pendingMove = pendingPromotionMove else { return }

        game.promotePawn(at: to, promoteTo: type)

        let promotionMove = UCIMove(from: pendingMove.from, to: pendingMove.to, promotion: type)
        game.recordMove(promotionMove.rawValue)
        engine.move(promotionMove.rawValue)

        pendingPromotionMove = nil
        promotionContext = nil

        persistGame()
        handleGameResultAfterMove()
        requestEngineMoveIfNeeded()
    }

    func applySideSelection(_ side: SideSelection) {
        let wantsBlack = (side == .black)
        guard wantsBlack != boardFlipped else { return }

        switch side {
        case .white:
            whitePlayer = .human
            blackPlayer = .engine
            boardFlipped = false
        case .black:
            whitePlayer = .engine
            blackPlayer = .human
            boardFlipped = true
        }

        resetGameInternal()

        DispatchQueue.main.async {
            guard !self.isResetting else { return }
            self.requestEngineMoveIfNeeded()
        }
    }

    func startNewGame() {
        resetGameInternal()

        DispatchQueue.main.async {
            guard !self.isResetting else { return }
            self.requestEngineMoveIfNeeded()
        }
    }

    func askMentorForPositionGuide() {
        guard mentorSettings.isEnabled else { return }
        guard !mentorIsThinking else { return }

        mentorMessages.append(
            MentorMessage(role: .user, text: "Explain this position and guide my next move.")
        )

        mentorIsThinking = true
        Task {
            await sendMentorPayload(makeMentorPayload(requestKind: .positionGuide))
        }
    }

    func player(for color: PieceColor) -> PlayerType {
        color == .white ? whitePlayer : blackPlayer
    }

    var canHumanInteract: Bool {
        gameResult == .ongoing && !engine.isThinking && player(for: game.sideToMove) == .human
    }

    // MARK: - Engine

    private func bindEngine() {
        engine.bestMovePublisher
            .compactMap { $0 }
            .sink { [weak self] move in
                guard let self, !self.isResetting else { return }
                self.applyEngineMove(move)
            }
            .store(in: &cancellables)

        engine.isThinkingPublisher
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func applyEngineMove(_ uci: String) {
        guard isGameOngoing() else {
            handleGameResultAfterMove()
            return
        }

        guard uci != "(none)" else {
            handleGameResultAfterMove()
            return
        }

        guard let move = UCIMove(uci) else { return }

        let moveWasApplied: Bool
        if let promo = move.promotion {
            moveWasApplied = game.promotePawn(from: move.from, to: move.to, promoteTo: promo)
        } else {
            moveWasApplied = game.move(from: move.from, to: move.to)
        }

        guard moveWasApplied else {
            requestEngineMoveIfNeeded()
            return
        }

        game.recordMove(move.rawValue)
        persistGame()

        DispatchQueue.main.async {
            self.handleGameResultAfterMove()
            if self.gameResult == .ongoing {
                self.requestEngineMoveIfNeeded()
            }
        }
    }

    private func requestEngineMoveIfNeeded() {
        guard !isResetting else { return }
        guard !engine.isThinking else { return }

        guard isGameOngoing() else {
            handleGameResultAfterMove()
            return
        }

        guard player(for: game.sideToMove) == .engine else { return }

        engine.think(fen: game.fen)
    }

    // MARK: - Game State

    private func handleGameResultAfterMove() {
        let result = game.gameResult()

        switch result {
        case .checkmate(let winner):
            gameResult = .checkmate(winner: winner)
            engine.stop()
        case .stalemate:
            gameResult = .stalemate
            engine.stop()
        case .draw(let reason):
            gameResult = .draw(reason: reason)
            engine.stop()
        case .check(let color):
            gameResult = .check(color: color)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if self.gameResult.isTransient {
                    self.gameResult = .ongoing
                }
            }
        case .ongoing:
            break
        }
    }

    private func isGameOngoing() -> Bool {
        !game.gameResult().isTerminal
    }

    private func resetGameInternal() {
        isResetting = true

        GameStorage.clear()
        engine.stop()
        game.reset()
        gameResult = .ongoing
        engine.newGame()

        resetMentor()

        pendingPromotionMove = nil
        promotionContext = nil

        DispatchQueue.main.async {
            self.isResetting = false
        }
    }

    private func checkAndHandlePromotion(from: Square, to: Square) -> Bool {
        guard
            let piece = game.piece(at: to),
            piece.type == .pawn,
            to.rank == 0 || to.rank == 7,
            player(for: piece.color) == .human
        else {
            return false
        }

        promotionContext = PromotionContext(from: from, to: to, color: piece.color)
        return true
    }

    // MARK: - Mentor

    private func makeMentorPayload(requestKind: MentorRequestKind) -> ChessMentorPayload {
        ChessMentorPayload(
            fen: game.fen,
            moves: game.moveHistory,
            moveNumber: game.moveHistory.count,
            sideToMove: game.sideToMove.text,
            playerColor: whitePlayer == .human ? "white" : "black",
            engineEval: nil,
            bestMove: engine.bestMove,
            requestKind: requestKind,
            sysPrompt: mentorSettings.prompt,
            responseLanguage: mentorSettings.responseLanguage
        )
    }

    private func sendMentorPayload(_ payload: ChessMentorPayload) async {
        defer { mentorIsThinking = false }

        do {
            let response = try await mentor.sendMove(payload)
            if let response {
                appendAIResponse(response)
            } else if !mentor.modelAvailable, !mentorUnavailableShown {
                mentorUnavailableShown = true
                appendAIResponse("Chess mentor is not available on this device.")
            }
        } catch {
            appendAIResponse("I couldn't analyze the position right now.")
        }
    }

    private func appendAIResponse(_ text: String) {
        mentorMessages.append(MentorMessage(role: .ai, text: text))
    }

    private func resetMentor() {
        mentorUnavailableShown = false
        mentorMessages = [
            MentorMessage(role: .system, text: "I'm your chess mentor. Ask me about any move.")
        ]
        mentorIsThinking = false
    }

    // MARK: - Storage

    private func persistGame() {
        let snapshot = GameSnapshot(
            fen: game.fen,
            moves: game.moveHistory,
            whitePlayer: whitePlayer,
            blackPlayer: blackPlayer
        )
        GameStorage.save(snapshot)
    }

    private func restoreGameIfAvailable() {
        guard let snapshot = GameStorage.load() else { return }
        isResetting = true
        engine.stop()
        engine.newGame()

        game.load(fromFEN: snapshot.fen)
        game.setMoveHistory(snapshot.moves)

        whitePlayer = snapshot.whitePlayer
        blackPlayer = snapshot.blackPlayer

        boardFlipped = (whitePlayer == .engine)
        engine.setPosition(fen: game.fen)

        DispatchQueue.main.async {
            self.isResetting = false
            self.requestEngineMoveIfNeeded()
        }
    }
}
