//
//  PositionSetupView.swift
//  ChessApp
//

import SwiftUI

struct PositionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var setup: PositionSetupState
    let onStart: (String) -> Bool

    private let ranks = Array((0...7).reversed())
    private let files = Array(0...7)

    init(initialFEN: String, onStart: @escaping (String) -> Bool) {
        _setup = StateObject(wrappedValue: PositionSetupState(initialFEN: initialFEN))
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Import FEN") {
                    TextEditor(text: $setup.fenText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 72)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Button("Load FEN") {
                            _ = setup.importFEN()
                        }

                        Spacer()

                        Button("Use Current Board") {
                            setup.refreshFEN()
                        }
                    }
                }

                Section("Board Setup") {
                    setupBoard
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 8)

                    piecePalette
                }

                Section("Side To Move Next") {
                    Picker("Turn", selection: $setup.sideToMove) {
                        Text("White").tag(PieceColor.white)
                        Text("Black").tag(PieceColor.black)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: setup.sideToMove) { _, _ in setup.refreshFEN() }
                }

                Section("Castling Rights") {
                    Toggle("White king-side castling", isOn: $setup.whiteCanCastleKingSide)
                    Toggle("White queen-side castling", isOn: $setup.whiteCanCastleQueenSide)
                    Toggle("Black king-side castling", isOn: $setup.blackCanCastleKingSide)
                    Toggle("Black queen-side castling", isOn: $setup.blackCanCastleQueenSide)
                }
                .onChange(of: setup.whiteCanCastleKingSide) { _, _ in setup.refreshFEN() }
                .onChange(of: setup.whiteCanCastleQueenSide) { _, _ in setup.refreshFEN() }
                .onChange(of: setup.blackCanCastleKingSide) { _, _ in setup.refreshFEN() }
                .onChange(of: setup.blackCanCastleQueenSide) { _, _ in setup.refreshFEN() }

                Section {
                    Button("Clear Board", role: .destructive) {
                        setup.clearBoard()
                    }

                    Button("Reset To Starting Position") {
                        setup.resetToStartingPosition()
                    }
                }

                if let message = setup.validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Setup Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        guard let fen = setup.validatedFEN(), onStart(fen) else { return }
                        dismiss()
                    }
                }
            }
        }
    }

    private var setupBoard: some View {
        GeometryReader { proxy in
            let squareSize = proxy.size.width / 8

            VStack(spacing: 0) {
                ForEach(ranks, id: \.self) { rank in
                    HStack(spacing: 0) {
                        ForEach(files, id: \.self) { file in
                            let square = Square(file: file, rank: rank)

                            SetupSquareView(
                                piece: setup.board[square],
                                square: square,
                                isSelected: setup.selectedSquare == square,
                                showsRank: file == 0,
                                showsFile: rank == 0
                            )
                            .frame(width: squareSize, height: squareSize)
                            .onTapGesture {
                                setup.handleTap(square)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var piecePalette: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Tool", selection: $setup.selectedTool) {
                Text("Move").tag(PositionSetupState.Tool.move)
                Text("Erase").tag(PositionSetupState.Tool.erase)
            }
            .pickerStyle(.segmented)

            ForEach([PieceColor.white, PieceColor.black], id: \.self) { color in
                HStack(spacing: 8) {
                    ForEach([PieceType.king, .queen, .rook, .bishop, .knight, .pawn], id: \.self) { type in
                        let piece = Piece(type: type, color: color)
                        Button {
                            setup.selectedTool = .piece(piece)
                            setup.selectedSquare = nil
                        } label: {
                            Image(piece.assetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(setup.selectedTool == .piece(piece) ? Color.selectedSquare : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct SetupSquareView: View {
    let piece: Piece?
    let square: Square
    let isSelected: Bool
    let showsRank: Bool
    let showsFile: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.squareColor(file: square.file, rank: square.rank))
                .overlay(isSelected ? Color.selectedSquare : Color.clear)

            if let piece {
                Image(piece.assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(5)
            }

            if showsRank {
                Text("\(square.rank + 1)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(coordinateColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(3)
            }

            if showsFile {
                Text(square.fileLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(coordinateColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(3)
            }
        }
    }

    private var coordinateColor: Color {
        (square.file + square.rank) % 2 == 0
            ? Color(red: 0.55, green: 0.40, blue: 0.25)
            : Color(red: 0.93, green: 0.89, blue: 0.85)
    }
}
