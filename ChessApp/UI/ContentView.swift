//
//  ContentView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 14/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var engine = EngineManager.shared
    @StateObject private var mentorSettings = MentorSettings()
    @StateObject private var mentor: ChessMentorManager
    @StateObject private var game = GameState()
    
    init() {
        let settings = MentorSettings()
        _mentorSettings = StateObject(wrappedValue: settings)
        _mentor = StateObject(
            wrappedValue: ChessMentorManager(
                service: AppleChessMentorService(),
                settings: settings
            )
        )
    }
    
    @State private var showLegalMoves = true
    @State private var gameResult: GameResult = .ongoing

    @State private var whitePlayer: PlayerType = .human
    @State private var blackPlayer: PlayerType = .engine

    // default human play white == false
    @State private var boardFlipped = false

    @State private var sideSelection: SideSelection = .white
    @State private var isResetting = false

    // Elo range 1347 to 3176
    @State private var elo: Double = 1347

    @State private var showSettings = false
    @State private var confirmNewGame = false

    // Pawn promotion
    @State private var promotionContext: PromotionContext?
    @State private var pendingPromotionMove: String?
    
    @State private var mentorMessages: [MentorMessage] = [
        MentorMessage(role: .system, text: "I'm your chess mentor. Ask me about any move.")
    ]
    @State private var mentorUnavailableShown = false
    @State private var mentorMoveBuffer: [String] = []
    @State private var mentorDebounceTask: Task<Void, Never>?


    var body: some View {
        NavigationStack {
            VStack {
                boardView
                Divider()
                MentorChatView(messages: mentorMessages)
                    .frame(maxHeight:.infinity)
            }
            .padding()
            .navigationTitle("Ai Chess")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.25), value: engine.isThinking)
            .toolbar { toolbarContent }
            .onAppear {
                engine.start()
                engine.setElo(Int(elo))
                mentor.checkModelAvailability()
                restoreGameIfAvailable()
            }
            .onChange(of: elo) { _, newValue in
                engine.setElo(Int(newValue))
            }
            .onChange(of: sideSelection) { _, newSide in
                DispatchQueue.main.async {
                    applySideSelection(newSide)
                }
            }
            .onReceive(engine.$bestMove) { move in
                guard !isResetting else { return }
                guard let move else { return }
                DispatchQueue.main.async {
                    applyEngineMove(move)
                }
            }
            .sheet(isPresented: $showSettings, content: settingsSheet)
            .sheet(item: $promotionContext, content: promotionSheet)
        }
    }
    // MARK: View
    private var boardView: some View {
        ZStack(alignment: .top) {
            ChessBoardView(
                game: game,
                showLegalMoves: showLegalMoves,
                flipped: boardFlipped
            ) { move in
                handleUserMove(move)
            }
            .aspectRatio(1, contentMode: .fit)
            .allowsHitTesting(canHumanInteract)

            if engine.isThinking {
                ThinkingIndicator()
                    .shadow(radius: 2)
                    .padding(.top, -2)
            }

            if gameResult != .ongoing {
                GameOverOverlay(result: gameResult)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                    .zIndex(10)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    confirmNewGame = true
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .confirmationDialog(
                    "Start a new game?",
                    isPresented: $confirmNewGame
                ) {
                    Button("New Game", role: .destructive, action: startNewGame)
                    Button("Cancel", role: .cancel) {}
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                }
            }
        }
    }

    private func settingsSheet() -> some View {
        NavigationStack {
            SettingsView(
                mentorSettings: mentorSettings,
                sideSelection: $sideSelection,
                showLegalMoves: $showLegalMoves,
                elo: $elo,
                onSideChange: { newSide in
                    applySideSelection(newSide)
                }
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showSettings = false
                    }
                }
            }
        }
    }

    private func promotionSheet(_ context: PromotionContext) -> some View {
        PromotionSheet(color: context.color) { selectedType in
            promotePawn(
                from: context.from,
                to: context.to,
                toPiece: selectedType
            )
            promotionContext = nil
        }
    }

    // ---- End ----
    private func handleUserMove(_ uci: String) {
        // If game already ended, still show result
        guard isGameOngoing() else {
            handleGameResultAfterMove()
            return
        }

        guard let move = parseUCI(uci) else { return }

        if checkAndHandlePromotion(from: move.from, to: move.to) {
            pendingPromotionMove = uci
            return
        }

        // Normal move
        engine.move(uci)
        game.recordMove(uci)
        persistGame()
        
        handleGameResultAfterMove()
        requestEngineMoveIfNeeded()
    }

    private func promotePawn(from: Square, to: Square, toPiece type: PieceType)
    {
        guard let pendingMove = pendingPromotionMove else { return }

        // Update piece type in game board
        game.promotePawn(at: to, promoteTo: type)

        // Build full UCI move (e7e8q)
        guard let piecePromo = type.uciChar else { return }
        let promotionMove = pendingMove + piecePromo

        game.recordMove(promotionMove)
        engine.move(promotionMove)

        pendingPromotionMove = nil

        persistGame()
        handleGameResultAfterMove()
        requestEngineMoveIfNeeded()
    }

    private func parseUCI(_ uci: String) -> (
        from: Square, to: Square, promotion: PieceType?
    )? {
        guard uci.count >= 4 else { return nil }

        let chars = Array(uci)
        let files = Array("abcdefgh")

        guard
            let fromFile = files.firstIndex(of: chars[0]),
            let fromRank = Int(String(chars[1])),
            let toFile = files.firstIndex(of: chars[2]),
            let toRank = Int(String(chars[3]))
        else {
            return nil
        }

        let from = Square(file: fromFile, rank: fromRank - 1)
        let to = Square(file: toFile, rank: toRank - 1)

        // Optional promotion (5th char)
        let promotion: PieceType? =
            chars.count == 5 ? PieceType(uciChar: chars[4]) : nil

        return (from, to, promotion)
    }

    private func applyEngineMove(_ uci: String) {
        // Stockfish signals game over
        guard isGameOngoing() else {
            handleGameResultAfterMove()
            return
        }

        guard uci != "(none)" else {
            handleGameResultAfterMove()
            return
        }

        guard let move = parseUCI(uci) else { return }

        if let promo = move.promotion {
            // Update game board for the move and type
            game.promotePawn(from: move.from, to: move.to, promoteTo: promo)
        } else {
            game.move(from: move.from, to: move.to)
        }
        
        // record engine move
        game.recordMove(uci)
        persistGame()
        
        sendMoveToMentor(move: uci)

        // allow state to settle before evaluating otherwise alaways see check
        DispatchQueue.main.async {
            self.handleGameResultAfterMove()
            if self.gameResult == .ongoing {
                self.requestEngineMoveIfNeeded()
            }
        }
    }

    private func handleGameResultAfterMove() {
        let result = game.gameResult()

        switch result {
        case .checkmate(let winner):
            gameResult = .checkmate(winner: winner)
            engine.stop()

        case .stalemate:
            gameResult = .stalemate
            engine.stop()

        case .check(let color):
            gameResult = .check(color: color)

            // Auto-dismiss after 1 second
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

    // If game ongoing AND engine side to move → request engine move
    private func requestEngineMoveIfNeeded() {
        guard !isResetting else { return }
        guard !engine.isThinking else { return }

        // Check in game is over
        guard isGameOngoing() else {
            handleGameResultAfterMove()
            return
        }

        guard player(for: game.sideToMove) == .engine else { return }

        engine.think(fen: game.fen)
    }

    func player(for color: PieceColor) -> PlayerType {
        color == .white ? whitePlayer : blackPlayer
    }

    private var canHumanInteract: Bool {
        gameResult == .ongoing && !engine.isThinking
            && player(for: game.sideToMove) == .human
    }

    private func applySideSelection(_ side: SideSelection) {
        // Prevent redundant resets
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

        // Engine should move first if human chose Black
        DispatchQueue.main.async {
            guard !isResetting else { return }
            requestEngineMoveIfNeeded()
        }
    }

    private func startNewGame() {
        resetGameInternal()

        // Engine moves first if human plays Black
        requestEngineMoveIfNeeded()
    }
    
    private func resetGameInternal() {
        isResetting = true

        GameStorage.clear()
        engine.stop()
        game.reset()
        gameResult = .ongoing
        engine.newGame()

        // Mentor reset
        mentorDebounceTask?.cancel()
        mentorDebounceTask = nil
        mentorMoveBuffer.removeAll()
        mentorUnavailableShown = false
        mentorMessages = [
            MentorMessage(role: .system, text: "I'm your chess mentor. Ask me about any move.")
        ]

        // Promotion safety
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

        promotionContext = PromotionContext(
            from: from,
            to: to,
            color: piece.color
        )

        return true
    }
    
    // MARK: AI
    
    private func sendMoveToMentor(move: String) {
        guard !mentorUnavailableShown else { return }
        // Buffer the move
        mentorMoveBuffer.append(move)
        
        mentorMessages.append(
           MentorMessage(role: .user, text: "Engine played \(move)")
        )
        
        // Cancel previous debounce
        mentorDebounceTask?.cancel()
        
        // Debounce (wait for quick moves to finish)
        mentorDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000) // 2.8s

            await sendBatchedMovesToMentor()
        }
        
    }
    
    @MainActor
    private func sendBatchedMovesToMentor() async {
        guard !mentorMoveBuffer.isEmpty else { return }

        let allMoves = mentorMoveBuffer
        mentorMoveBuffer.removeAll()

        // Only last 5 moves
        let moves = Array(allMoves.suffix(5))

        let payload = ChessMentorPayload(
            fen: game.fen,
            moves: moves,
            moveNumber: moves.count,
            sideToMove: game.sideToMove.text,
            playerColor: whitePlayer == .human ? "white" : "black",
            engineEval: nil,
            bestMove: engine.bestMove,
            sysPrompt: mentorSettings.prompt
        )

        do {
            let response = try await mentor.sendMove(payload)
            if let response {
                appendAIResponse(response)
            } else if !mentorUnavailableShown {
                mentorUnavailableShown = true
                appendAIResponse("Chess mentor is not available on this device.")
            }
        } catch {
            appendAIResponse("I couldn't analyze the position right now.")
        }
    }
    
    private func appendAIResponse(_ text: String) {
        mentorMessages.append(
            MentorMessage(role: .ai, text: text)
        )
    }
    
    // MARK: Storage
    
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
