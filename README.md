# ♟️ A personal chess coach powered by Apple Intelligence.

**AI Chess** is a modern iOS chess app that combines the strength of the **Stockfish chess engine** with **Apple Intelligence** to deliver an interactive, mentor-style chess experience.

Instead of showing raw engine scores, Chat Chess explains *why* moves matter — helping players learn, reflect, and improve while they play.

---

## ✨ Features

### ♜ Strong Chess Engine (Phase 1)
- Embedded **Stockfish** engine (headless, UCI-compatible)
- Legal move validation, castling, promotion, check, checkmate, stalemate
- Adjustable engine strength via ELO slider
- Play as White or Black with board flipping
- Smooth SwiftUI chessboard UI

---

### 🧠 Apple Intelligence Chess Mentor (Phase 2)
- Every move is analyzed in context using **Apple Intelligence**
- AI provides:
  - Natural-language explanations
  - Strategic and tactical insights
  - Suggestions and alternatives
- Integrated chat interface below the board
- Rapid moves are **batched** for higher-quality feedback
- Graceful handling when the AI model is unavailable

---

## 🧩 Architecture Overview

- **Stockfish**
  - Enforces rules, calculates best moves, evaluates positions
- **Apple Intelligence**
  - Acts as a *mentor*, not a rules engine
  - Explains positions and decisions in human language
- **SwiftUI**
  - Chessboard, promotion UI, chat interface, settings

Clear separation ensures stability, performance, and extensibility.

---

## 🎯 Design Philosophy

Chat Chess is built around learning, not just winning.

- No engine noise or overwhelming numbers
- Focus on *understanding*, not memorization
- AI behaves like a coach, not a debugger

---

## 🚀 Roadmap

Planned next steps:
- Post-game AI summaries
- Concept detection (pins, forks, weak squares)
- Question-driven mentoring
- Personalized coaching based on player skill

---

## 📱 Platform

- iOS (SwiftUI)
- On-device Stockfish
- Apple Intelligence (where available)

## NNUE Files Setup

Due to their large size, the NNUE files are not included in this repository. Please download them from the following links:

- https://github.com/official-stockfish/networks/blob/master/nn-37f18f62d772.nnue
- https://github.com/official-stockfish/networks/blob/master/nn-2962dca31855.nnue

After downloading, place both files in the **ChessApp** folder, in the same directory as `stockfish_wrapper.h`.
