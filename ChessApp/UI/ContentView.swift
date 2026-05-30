//
//  ContentView.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 14/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var coordinator = GameCoordinator()
    @StateObject private var gameSettings = GameSettings()
    @State private var showSettings = false
    @State private var showPositionSetup = false

    var body: some View {
        NavigationStack {
            VStack {
                boardView
                Divider()
                MentorChatView(
                    messages: coordinator.mentorMessages,
                    isThinking: coordinator.mentorIsThinking
                )
                    .frame(maxHeight: .infinity)
            }
            .padding()
            .navigationTitle("Chesswise")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.25), value: coordinator.engine.isThinking)
            .toolbar { toolbarContent }
            .onAppear {
                coordinator.start(elo: Int(gameSettings.elo))
                coordinator.setClockPreset(gameSettings.clockPreset)
            }
            .onChange(of: gameSettings.elo) { _, newValue in
                coordinator.setElo(Int(newValue))
            }
            .onChange(of: gameSettings.clockPreset) { _, newPreset in
                coordinator.setClockPreset(newPreset)
            }
            .onChange(of: gameSettings.sideSelection) { _, newSide in
                DispatchQueue.main.async {
                    coordinator.applySideSelection(newSide)
                }
            }
            .sheet(isPresented: $showSettings, content: settingsSheet)
            .sheet(isPresented: $showPositionSetup, content: positionSetupSheet)
            .sheet(item: $coordinator.promotionContext, content: promotionSheet)
        }
    }

    private var boardView: some View {
        VStack(spacing: 8) {
            if coordinator.clockIsEnabled {
                clockRow
            }

            ZStack(alignment: .top) {
                ChessBoardView(
                    game: coordinator.game,
                    showLegalMoves: gameSettings.showLegalMoves,
                    flipped: coordinator.boardFlipped,
                    onMove: coordinator.handleUserMove
                )
                .aspectRatio(1, contentMode: .fit)
                .allowsHitTesting(coordinator.canHumanInteract)

                if coordinator.engine.isThinking {
                    ThinkingIndicator()
                        .shadow(radius: 2)
                        .padding(.top, -2)
                }

                if coordinator.gameResult != .ongoing {
                    GameOverOverlay(result: coordinator.gameResult)
                        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                        .zIndex(10)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }

    private var clockRow: some View {
        HStack(spacing: 10) {
            ClockPill(
                title: "White",
                time: coordinator.clockDisplay(for: .white),
                isActive: coordinator.activeClockColor == .white
            )

            ClockPill(
                title: "Black",
                time: coordinator.clockDisplay(for: .black),
                isActive: coordinator.activeClockColor == .black
            )
        }
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button {
                        coordinator.startNewGame()
                    } label: {
                        Label("New Game", systemImage: "plus.circle")
                    }

                    Button {
                        showPositionSetup = true
                    } label: {
                        Label("Setup Position", systemImage: "square.grid.3x3")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        coordinator.askMentorForPositionGuide()
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(
                        coordinator.mentorIsThinking
                        || !coordinator.mentorSettings.isEnabled
                        || !coordinator.positionCanUseMentor
                    )

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
    }

    private func settingsSheet() -> some View {
        NavigationStack {
            SettingsView(
                mentorSettings: coordinator.mentorSettings,
                sideSelection: Binding(
                    get: { gameSettings.sideSelection },
                    set: { gameSettings.updateSide($0) }
                ),
                showLegalMoves: $gameSettings.showLegalMoves,
                elo: $gameSettings.elo,
                clockPreset: Binding(
                    get: { gameSettings.clockPreset },
                    set: { gameSettings.updateClockPreset($0) }
                )
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

    private func positionSetupSheet() -> some View {
        PositionSetupView(initialFEN: coordinator.game.fen) { fen in
            coordinator.startFromFEN(fen)
        }
    }

    private func promotionSheet(_ context: PromotionContext) -> some View {
        PromotionSheet(color: context.color) { selectedType in
            coordinator.promotePawn(
                from: context.from,
                to: context.to,
                toPiece: selectedType
            )
        }
    }
}

private struct ClockPill: View {
    let title: String
    let time: String
    let isActive: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))

            Spacer(minLength: 8)

            Text(time)
                .font(.system(.body, design: .monospaced).weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isActive ? Color.green.opacity(0.18) : Color.secondary.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.green.opacity(0.7) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
