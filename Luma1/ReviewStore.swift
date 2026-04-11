//
//  ReviewStore.swift
//  Luma
//
//  Created by Codex on 3/24/26.
//

import Foundation

struct LocalReviewEntry: Codable, Identifiable {
    let id: UUID
    let placeName: String
    let note: String
    let rating: Int?
    let createdAt: Date
}

enum LocalReviewStore {
    private static let storageKey = "luma.local.reviews"
    private static let maximumStoredReviews = 60

    static func load() -> [LocalReviewEntry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        guard let decoded = try? JSONDecoder().decode([LocalReviewEntry].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    static func addReview(placeName: String, note: String, rating: Int?) -> [LocalReviewEntry] {
        let entry = LocalReviewEntry(
            id: UUID(),
            placeName: placeName,
            note: note,
            rating: rating,
            createdAt: Date()
        )

        var reviews = load()
        reviews.insert(entry, at: 0)
        if reviews.count > maximumStoredReviews {
            reviews = Array(reviews.prefix(maximumStoredReviews))
        }
        save(reviews)
        return reviews
    }

    private static func save(_ reviews: [LocalReviewEntry]) {
        guard let data = try? JSONEncoder().encode(reviews) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
