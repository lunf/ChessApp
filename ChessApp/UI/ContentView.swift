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
            }
            .onChange(of: gameSettings.elo) { _, newValue in
                coordinator.setElo(Int(newValue))
            }
            .onChange(of: gameSettings.sideSelection) { _, newSide in
                DispatchQueue.main.async {
                    coordinator.applySideSelection(newSide)
                }
            }
            .sheet(isPresented: $showSettings, content: settingsSheet)
            .sheet(item: $coordinator.promotionContext, content: promotionSheet)
        }
    }

    private var boardView: some View {
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
        .padding(.horizontal)
        .padding(.top)
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("New Game", action: coordinator.startNewGame)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        coordinator.askMentorForPositionGuide()
                    } label: {
                        Image(systemName: "sparkles")
                    }
                    .disabled(coordinator.mentorIsThinking || !coordinator.mentorSettings.isEnabled)

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
                elo: $gameSettings.elo
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
            coordinator.promotePawn(
                from: context.from,
                to: context.to,
                toPiece: selectedType
            )
        }
    }
}
