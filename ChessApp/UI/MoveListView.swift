//
//  MoveListView.swift
//  ChessApp
//

import SwiftUI

struct MoveListView: View {
    let moves: [String]

    private var rows: [MoveListRow] {
        stride(from: 0, to: moves.count, by: 2).map { index in
            MoveListRow(
                number: (index / 2) + 1,
                whiteMove: moves[index],
                blackMove: moves.indices.contains(index + 1) ? moves[index + 1] : nil
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Moves")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if rows.isEmpty {
                Text("No moves yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(rows) { row in
                            HStack(spacing: 6) {
                                Text("\(row.number).")
                                    .foregroundStyle(.secondary)
                                Text(row.whiteMove)
                                    .fontWeight(.semibold)

                                if let blackMove = row.blackMove {
                                    Text(blackMove)
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.callout.monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

private struct MoveListRow: Identifiable {
    let number: Int
    let whiteMove: String
    let blackMove: String?

    var id: Int { number }
}
