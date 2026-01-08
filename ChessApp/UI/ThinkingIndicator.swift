//
//  ThinkingIndicator.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 20/12/25.
//
import SwiftUI
import Combine

struct ThinkingIndicator: View {
    private let barWidth: CGFloat = 80
    private let height: CGFloat = 3
    private let duration: Double = 1.1

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let progress = (time.truncatingRemainder(dividingBy: duration)) / duration

            GeometryReader { geo in
                let width = geo.size.width

                ZStack(alignment: .leading) {
                    // Track (very subtle)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: height)

                    // Moving segment
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.0),
                                    Color.accentColor.opacity(0.6),
                                    Color.accentColor.opacity(1.0),
                                    Color.accentColor.opacity(0.6),
                                    Color.accentColor.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth, height: height)
                        .offset(
                            x: (width + barWidth) * progress - barWidth
                        )
                }
                .frame(height: height)
            }
            .frame(height: height)
        }
    }
}

