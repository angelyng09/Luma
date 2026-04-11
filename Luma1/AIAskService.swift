//
//  AIAskService.swift
//  Luma
//
//  Created by Codex on 3/21/26.
//

import Foundation

enum AIAskServiceError: LocalizedError {
    case emptyQuestion
    case emptyAnswer
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyQuestion:
            return L10n.tr("search.ask.error.empty")
        case .emptyAnswer:
            return L10n.tr("search.ask.error.server")
        case let .processingFailed(message):
            return message
        }
    }
}

struct AIAskService {
    func ask(question: String, context: AIAskContext? = nil) async throws -> String {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuestion.isEmpty == false else {
            throw AIAskServiceError.emptyQuestion
        }

        try await Task.sleep(nanoseconds: 180_000_000)
        let answer = LocalAssistantComposer.compose(question: trimmedQuestion, context: context)
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedAnswer.isEmpty == false else {
            throw AIAskServiceError.emptyAnswer
        }
        return trimmedAnswer
    }
}

struct AIAskContext: Encodable {
    struct Location: Encodable {
        let latitude: Double
        let longitude: Double
        let accuracyMeters: Double?
        let capturedAtISO8601: String?
    }

    struct MapSelection: Encodable {
        let title: String?
        let latitude: Double
        let longitude: Double
    }

    struct Review: Encodable {
        let placeName: String
        let note: String
        let rating: Int?
        let capturedAtISO8601: String
    }

    let contextCapturedAtISO8601: String
    let lastVisitedPlaceName: String?
    let currentLocation: Location?
    let mapSelection: MapSelection?
    let reviews: [Review]
}

private enum LocalAssistantComposer {
    private static let positiveSignals = [
        "accessible", "ramp", "elevator", "smooth", "helpful", "clean",
        "无障碍", "坡道", "电梯", "顺畅", "友好", "方便",
    ]
    private static let cautionSignals = [
        "stairs", "blocked", "crowded", "broken", "narrow", "unsafe",
        "台阶", "拥挤", "损坏", "狭窄", "不便",
    ]

    static func compose(question: String, context: AIAskContext?) -> String {
        let useChinese = containsCJK(question)
        let placeName = context?.mapSelection?.title ?? context?.lastVisitedPlaceName
        let displayPlace = placeName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? placeName!
            : (useChinese ? "该地点" : "this place")

        let reviews = context?.reviews ?? []
        let recentNotes = reviews.map(\.note).filter { $0.isEmpty == false }
        let averageRating: Double? = {
            let ratings = reviews.compactMap(\.rating)
            guard ratings.isEmpty == false else { return nil }
            return Double(ratings.reduce(0, +)) / Double(ratings.count)
        }()

        let positives = topSignals(in: recentNotes, signals: positiveSignals)
        let cautions = topSignals(in: recentNotes, signals: cautionSignals)
        let questionFocus = normalizedFocus(from: question, useChinese: useChinese)

        if useChinese {
            return composeChinese(
                placeName: displayPlace,
                reviewCount: reviews.count,
                averageRating: averageRating,
                positives: positives,
                cautions: cautions,
                focus: questionFocus
            )
        }

        return composeEnglish(
            placeName: displayPlace,
            reviewCount: reviews.count,
            averageRating: averageRating,
            positives: positives,
            cautions: cautions,
            focus: questionFocus
        )
    }

    private static func normalizedFocus(from question: String, useChinese: Bool) -> String {
        let q = question.lowercased()
        if q.contains("wheelchair") || q.contains("轮椅") {
            return useChinese ? "重点查看轮椅通行路径和入口坡道。" : "Focus on wheelchair route continuity and ramp access."
        }
        if q.contains("restroom") || q.contains("toilet") || q.contains("卫生间") {
            return useChinese ? "优先确认无障碍卫生间位置和可进入性。" : "Prioritize confirming accessible restroom availability and path."
        }
        if q.contains("elevator") || q.contains("lift") || q.contains("电梯") {
            return useChinese ? "重点确认电梯可用性和排队情况。" : "Prioritize elevator reliability and waiting conditions."
        }
        return useChinese ? "建议到场后先快速核验入口、通道与垂直通行条件。" : "On arrival, quickly verify entrance access, route width, and vertical mobility options."
    }

    private static func topSignals(in notes: [String], signals: [String]) -> [String] {
        var counts: [String: Int] = [:]
        let loweredNotes = notes.map { $0.lowercased() }

        for signal in signals {
            let count = loweredNotes.reduce(0) { partial, note in
                partial + (note.contains(signal) ? 1 : 0)
            }
            if count > 0 {
                counts[signal] = count
            }
        }

        let sorted = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key < rhs.key
        }
        return Array(sorted.prefix(3).map(\.key))
    }

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func composeEnglish(
        placeName: String,
        reviewCount: Int,
        averageRating: Double?,
        positives: [String],
        cautions: [String],
        focus: String
    ) -> String {
        let ratingText: String
        if let averageRating {
            ratingText = String(format: "Average recent rating: %.1f/5 from %d review(s).", averageRating, reviewCount)
        } else {
            ratingText = "No rating history yet, so confidence is limited."
        }

        let positiveText = positives.isEmpty
            ? "No recurring strengths were detected from recent notes."
            : "Frequent positive signals: \(positives.joined(separator: ", "))."

        let cautionText = cautions.isEmpty
            ? "No recurring risk keywords were detected, but verify on-site."
            : "Potential caution signals: \(cautions.joined(separator: ", "))."

        return [
            "Local accessibility assistant summary for \(placeName):",
            ratingText,
            positiveText,
            cautionText,
            focus,
        ].joined(separator: "\n")
    }

    private static func composeChinese(
        placeName: String,
        reviewCount: Int,
        averageRating: Double?,
        positives: [String],
        cautions: [String],
        focus: String
    ) -> String {
        let ratingText: String
        if let averageRating {
            ratingText = String(format: "最近评分均值：%.1f/5（共 %d 条评论）。", averageRating, reviewCount)
        } else {
            ratingText = "当前评分数据较少，建议以现场复核为主。"
        }

        let positiveText = positives.isEmpty
            ? "最近评论中未形成明显稳定优势。"
            : "高频正向信号：\(positives.joined(separator: "、"))。"

        let cautionText = cautions.isEmpty
            ? "未发现高频风险关键词，但仍建议到场复核。"
            : "潜在风险信号：\(cautions.joined(separator: "、"))。"

        return [
            "\(placeName) 的本地无障碍助手总结：",
            ratingText,
            positiveText,
            cautionText,
            focus,
        ].joined(separator: "\n")
    }
}
