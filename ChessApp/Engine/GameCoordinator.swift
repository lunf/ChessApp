//
//  GameCoordinator.swift
//  ChessApp
//

import Combine
import Foundation

@MainActor
final class GameCoordinator: ObservableObject {
    private static let lockedMentorIntro = "AI guidance unlocks after 5 moves, or immediately when you start from a setup/FEN position."
    private static let readyMentorIntro = "AI mentor is ready. Ask for guidance when you want a position review."

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
        MentorMessage(role: .system, text: GameCoordinator.lockedMentorIntro)
    ]
    @Published var mentorIsThinking = false
    @Published private(set) var positionCanUseMentor = false
    @Published private(set) var clockPreset: ClockPreset = .off
    @Published private(set) var whiteTimeRemaining = 0
    @Published private(set) var blackTimeRemaining = 0
    @Published private(set) var activeClockColor: PieceColor?

    private var pendingPromotionMove: UCIMove?
    private var mentorUnavailableShown = false
    private var hasStarted = false
    private var startedFromSetup = false
    private var clockTimer: Timer?
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
        guard !hasStarted else {
            engine.setElo(elo)
            return
        }

        hasStarted = true
        engine.start()
        engine.setElo(elo)
        mentor.checkModelAvailability()
        restoreGameIfAvailable()
    }

    func setElo(_ elo: Int) {
        engine.setElo(elo)
    }

    func shutdown() {
        stopClock()
        engine.shutdown()
    }

    func setClockPreset(_ preset: ClockPreset) {
        guard clockPreset != preset else { return }

        clockPreset = preset
        resetClockTimes()
        persistGame()
        startClockIfNeeded()
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

        guard game.move(from: move.from, to: move.to) else { return }

        engine.move(move.rawValue)
        game.recordMove(move.rawValue)
        applyClockAfterMove(movedBy: game.sideToMove.opposite)
        updateMentorGate()
        persistGame()

        handleGameResultAfterMove()
        requestEngineMoveIfNeeded()
    }

    func promotePawn(from: Square, to: Square, toPiece type: PieceType) {
        guard let pendingMove = pendingPromotionMove else { return }

        guard game.promotePawn(from: pendingMove.from, to: pendingMove.to, promoteTo: type) else {
            pendingPromotionMove = nil
            promotionContext = nil
            return
        }

        let promotionMove = UCIMove(from: pendingMove.from, to: pendingMove.to, promotion: type)
        game.recordMove(promotionMove.rawValue)
        applyClockAfterMove(movedBy: game.sideToMove.opposite)
        updateMentorGate()
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
            self.startClockIfNeeded()
            self.requestEngineMoveIfNeeded()
        }
    }

    func startNewGame() {
        resetGameInternal()

        DispatchQueue.main.async {
            guard !self.isResetting else { return }
            self.startClockIfNeeded()
            self.requestEngineMoveIfNeeded()
        }
    }

    @discardableResult
    func startFromFEN(_ fen: String) -> Bool {
        isResetting = true

        GameStorage.clear()
        engine.stop()
        engine.newGame()

        guard game.load(fromFEN: fen) else {
            isResetting = false
            return false
        }

        game.setMoveHistory([])
        game.setMoveNotations([])
        startedFromSetup = true
        updateMentorGate()
        resetClockTimes()
        gameResult = .ongoing
        engine.setPosition(fen: game.fen)

        resetMentor()

        pendingPromotionMove = nil
        promotionContext = nil

        persistGame()

        DispatchQueue.main.async {
            self.isResetting = false
            self.handleGameResultAfterMove()
            self.startClockIfNeeded()
            self.requestEngineMoveIfNeeded()
        }

        return true
    }

    func askMentorForPositionGuide() {
        guard mentorSettings.isEnabled else { return }
        guard !mentorIsThinking else { return }
        guard positionCanUseMentor else { return }

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
        applyClockAfterMove(movedBy: game.sideToMove.opposite)
        updateMentorGate()
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
            stopClock()
        case .stalemate:
            gameResult = .stalemate
            engine.stop()
            stopClock()
        case .draw(let reason):
            gameResult = .draw(reason: reason)
            engine.stop()
            stopClock()
        case .timeout(let loser):
            gameResult = .timeout(loser: loser)
            engine.stop()
            stopClock()
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
        startedFromSetup = false
        updateMentorGate()
        resetClockTimes()
        gameResult = .ongoing
        engine.newGame()

        resetMentor()

        pendingPromotionMove = nil
        promotionContext = nil

        DispatchQueue.main.async {
            self.isResetting = false
            self.startClockIfNeeded()
        }
    }

    private func checkAndHandlePromotion(from: Square, to: Square) -> Bool {
        guard
            let piece = game.piece(at: from),
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
            MentorMessage(role: .system, text: mentorIntroText)
        ]
        mentorIsThinking = false
    }

    private func updateMentorGate() {
        let canUseMentor = startedFromSetup || game.moveHistory.count >= 5
        guard canUseMentor != positionCanUseMentor else { return }

        positionCanUseMentor = canUseMentor
        updateMentorIntroIfNeeded()
    }

    private var mentorIntroText: String {
        positionCanUseMentor ? Self.readyMentorIntro : Self.lockedMentorIntro
    }

    private func updateMentorIntroIfNeeded() {
        guard mentorMessages.count == 1,
              mentorMessages.first?.role == .system
        else {
            return
        }

        mentorMessages = [
            MentorMessage(role: .system, text: mentorIntroText)
        ]
    }

    // MARK: - Clock

    var clockIsEnabled: Bool {
        clockPreset.isEnabled
    }

    func clockDisplay(for color: PieceColor) -> String {
        ClockFormatter.display(color == .white ? whiteTimeRemaining : blackTimeRemaining)
    }

    private func resetClockTimes() {
        stopClock()
        whiteTimeRemaining = clockPreset.initialSeconds
        blackTimeRemaining = clockPreset.initialSeconds
        activeClockColor = nil
    }

    private func applyClockAfterMove(movedBy color: PieceColor) {
        guard clockPreset.isEnabled else { return }

        switch color {
        case .white:
            whiteTimeRemaining += clockPreset.incrementSeconds
        case .black:
            blackTimeRemaining += clockPreset.incrementSeconds
        }

        activeClockColor = game.sideToMove
        startClockIfNeeded()
    }

    private func startClockIfNeeded() {
        guard clockPreset.isEnabled,
              gameResult == .ongoing,
              !isResetting
        else {
            stopClock()
            return
        }

        activeClockColor = game.sideToMove

        guard clockTimer == nil else { return }

        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tickClock()
            }
        }
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
        activeClockColor = nil
    }

    private func tickClock() {
        guard clockPreset.isEnabled,
              gameResult == .ongoing,
              let activeClockColor
        else {
            stopClock()
            return
        }

        switch activeClockColor {
        case .white:
            whiteTimeRemaining = max(0, whiteTimeRemaining - 1)
            if whiteTimeRemaining == 0 {
                handleTimeout(for: .white)
            }
        case .black:
            blackTimeRemaining = max(0, blackTimeRemaining - 1)
            if blackTimeRemaining == 0 {
                handleTimeout(for: .black)
            }
        }
    }

    private func handleTimeout(for loser: PieceColor) {
        stopClock()
        engine.stop()
        gameResult = .timeout(loser: loser)
        persistGame()
    }

    // MARK: - Storage

    private func persistGame() {
        let snapshot = GameSnapshot(
            fen: game.fen,
            moves: game.moveHistory,
            moveNotations: game.moveNotations,
            whitePlayer: whitePlayer,
            blackPlayer: blackPlayer,
            startedFromSetup: startedFromSetup,
            clockPreset: clockPreset.rawValue,
            whiteTimeRemaining: whiteTimeRemaining,
            blackTimeRemaining: blackTimeRemaining
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
        game.setMoveNotations(snapshot.moveNotations ?? snapshot.moves)
        startedFromSetup = snapshot.startedFromSetup ?? false
        updateMentorGate()

        whitePlayer = snapshot.whitePlayer
        blackPlayer = snapshot.blackPlayer

        boardFlipped = (whitePlayer == .engine)
        clockPreset = ClockPreset(rawValue: snapshot.clockPreset ?? "") ?? .off
        whiteTimeRemaining = snapshot.whiteTimeRemaining ?? clockPreset.initialSeconds
        blackTimeRemaining = snapshot.blackTimeRemaining ?? clockPreset.initialSeconds
        engine.setPosition(fen: game.fen)

        DispatchQueue.main.async {
            self.isResetting = false
            self.startClockIfNeeded()
            self.requestEngineMoveIfNeeded()
        }
    }
}
