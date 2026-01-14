//
//  GameStorage.swift
//  ChessApp
//
//  Created by cuong.nguyenhat on 9/1/26.
//

import Foundation

enum GameStorage {

    private static let key = "savedGameSnapshot"

    static func save(_ snapshot: GameSnapshot) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save game:", error)
        }
    }

    static func load() -> GameSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
