//
//  GameCoordinatorTests.swift
//  ChessAppTests
//

import Combine
import XCTest
@testable import ChessApp

@MainActor
final class GameCoordinatorTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        GameStorage.clear()
        cancellables.removeAll()
    }

    override func tearDown() {
        GameStorage.clear()
        cancellables.removeAll()
        super.tearDown()
    }

    func testStartStartsEngineAndSetsElo() {
        let engine = MockGameEngine()
        let coordinator = makeCoordinator(engine: engine)

        coordinator.start(elo: 1800)

        XCTAssertTrue(engine.startWasCalled)
        XCTAssertEqual(engine.eloValues, [1800])
    }

    func testUserMoveRecordsNotationSendsMoveAndRequestsEngineMove() {
        let engine = MockGameEngine()
        let coordinator = makeCoordinator(engine: engine)

        coordinator.handleUserMove(UCIMove("e2e4")!)

        XCTAssertEqual(engine.moves, ["e2e4"])
        XCTAssertEqual(coordinator.game.moveHistory, ["e2e4"])
        XCTAssertEqual(coordinator.game.moveNotations, ["e4"])
        XCTAssertEqual(engine.thinkFENs.count, 1)
        XCTAssertEqual(coordinator.game.sideToMove, .black)
    }

    func testMentorUnlocksAfterFiveHalfMoves() {
        let engine = MockGameEngine()
        let coordinator = makeCoordinator(engine: engine)

        coordinator.blackPlayer = .human
        coordinator.handleUserMove(UCIMove("e2e4")!)
        coordinator.handleUserMove(UCIMove("e7e5")!)
        coordinator.handleUserMove(UCIMove("g1f3")!)
        coordinator.handleUserMove(UCIMove("b8c6")!)

        XCTAssertFalse(coordinator.positionCanUseMentor)

        coordinator.handleUserMove(UCIMove("f1b5")!)

        XCTAssertTrue(coordinator.positionCanUseMentor)
    }

    func testStartFromFENUnlocksMentorAndSetsEnginePosition() {
        let engine = MockGameEngine()
        let coordinator = makeCoordinator(engine: engine)

        let didStart = coordinator.startFromFEN("8/8/8/8/8/8/4K3/4k3 w - - 0 1")

        XCTAssertTrue(didStart)
        XCTAssertTrue(coordinator.positionCanUseMentor)
        XCTAssertEqual(engine.setPositionFENs.last, coordinator.game.fen)
        XCTAssertTrue(coordinator.game.moveHistory.isEmpty)
        XCTAssertTrue(coordinator.game.moveNotations.isEmpty)
    }

    func testEngineBestMoveDuringResetIsIgnored() {
        let engine = MockGameEngine()
        let coordinator = makeCoordinator(engine: engine)

        coordinator.isResetting = true
        engine.publishBestMove("e7e5")

        XCTAssertTrue(coordinator.game.moveHistory.isEmpty)
        XCTAssertTrue(coordinator.game.moveNotations.isEmpty)
    }

    private func makeCoordinator(engine: MockGameEngine) -> GameCoordinator {
        GameCoordinator(
            engine: engine,
            mentorSettings: MentorSettings(),
            mentorService: MockChessMentorService(),
            game: GameState()
        )
    }
}

@MainActor
private final class MockGameEngine: GameEngineManager {
    var bestMove: String?
    var isThinking = false

    private let bestMoveSubject = CurrentValueSubject<String?, Never>(nil)
    private let isThinkingSubject = CurrentValueSubject<Bool, Never>(false)

    var bestMovePublisher: AnyPublisher<String?, Never> {
        bestMoveSubject.eraseToAnyPublisher()
    }

    var isThinkingPublisher: AnyPublisher<Bool, Never> {
        isThinkingSubject.eraseToAnyPublisher()
    }

    private(set) var startWasCalled = false
    private(set) var eloValues: [Int] = []
    private(set) var newGameCallCount = 0
    private(set) var moves: [String] = []
    private(set) var thinkFENs: [String] = []
    private(set) var setPositionFENs: [String] = []
    private(set) var stopCallCount = 0
    private(set) var shutdownWasCalled = false

    func start() {
        startWasCalled = true
    }

    func setElo(_ elo: Int) {
        eloValues.append(elo)
    }

    func newGame() {
        newGameCallCount += 1
    }

    func move(_ uci: String) {
        moves.append(uci)
    }

    func think(fen: String) {
        thinkFENs.append(fen)
    }

    func setPosition(fen: String) {
        setPositionFENs.append(fen)
    }

    func stop() {
        stopCallCount += 1
        isThinking = false
        isThinkingSubject.send(false)
    }

    func shutdown() {
        shutdownWasCalled = true
    }

    func publishBestMove(_ move: String) {
        bestMove = move
        bestMoveSubject.send(move)
    }
}

private struct MockChessMentorService: ChessMentorService {
    func analyzeMove(_ payload: ChessMentorPayload) async throws -> String {
        "Test response"
    }

    func isModelAvailable() -> Bool {
        true
    }
}
