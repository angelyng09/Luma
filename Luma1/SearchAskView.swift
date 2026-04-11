//
//  SearchAskView.swift
//  Luma
//
//  Created by Codex on 3/21/26.
//

import SwiftUI
import MapKit
import CoreLocation
#if os(iOS)
import UIKit
#endif

struct SearchAskView: View {
    private enum FocusField: Hashable {
        case searchInput
        case resultsHeading
    }

    private enum SortMode: String, CaseIterable, Identifiable {
        case scoreFirst
        case distanceFirst

        var id: String { rawValue }

        var title: String {
            switch self {
            case .scoreFirst:
                return L10n.tr("search.results.sort.score_first")
            case .distanceFirst:
                return L10n.tr("search.results.sort.distance_first")
            }
        }
    }

    private static let pageSize = 5
    private let initialQuery: String?

    @StateObject private var speechController = SpeechInputController()
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var userLocationProvider = UserLocationProvider()

    @AccessibilityFocusState private var focusedField: FocusField?
    @State private var isSearchInputFocused = false

    @AppStorage("home.last_searched_place_name") private var lastSearchedPlaceName = ""
    @AppStorage("home.last_searched_place_at") private var lastSearchedPlaceAt = 0.0

    @State private var queryText = ""
    @State private var searchResults: [PlaceSearchResult] = []
    @State private var sortMode: SortMode = .scoreFirst
    @State private var pageIndex = 0
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var selectedResult: PlaceSearchResult?
    @State private var recentSearches = SearchRecentStore.load()

    private let aiService = AIAskService()
    @State private var hasSeededInitialQuery = false

    init(initialQuery: String? = nil) {
        self.initialQuery = initialQuery
    }

    private var trimmedQuery: String {
        queryText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sortedResults: [PlaceSearchResult] {
        searchResults.sorted {
            let lhsDistance = $0.distanceMeters(from: userLocationProvider.latestLocation)
            let rhsDistance = $1.distanceMeters(from: userLocationProvider.latestLocation)

            switch sortMode {
            case .scoreFirst:
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return lhsDistance < rhsDistance
            case .distanceFirst:
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                return $0.score > $1.score
            }
        }
    }

    private var pageCount: Int {
        let count = sortedResults.count
        guard count > 0 else { return 1 }
        return Int(ceil(Double(count) / Double(Self.pageSize)))
    }

    private var pageResults: [PlaceSearchResult] {
        let start = pageIndex * Self.pageSize
        guard start < sortedResults.count else { return [] }
        return Array(sortedResults.dropFirst(start).prefix(Self.pageSize))
    }

    private var canGoToPreviousPage: Bool {
        pageIndex > 0
    }

    private var canGoToNextPage: Bool {
        pageIndex + 1 < pageCount
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("home.dest.search.title"))
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilitySortPriority(90)

                    Text(L10n.tr("search.page.description"))
                        .foregroundStyle(LumaPalette.secondaryText)
                        .accessibilitySortPriority(85)
                }
                .lumaCardStyle()

                inputArea

                Button(isSearching ? L10n.tr("search.button.searching") : L10n.tr("search.button.search")) {
                    triggerSearch(using: trimmedQuery)
                }
                .buttonStyle(LumaPrimaryButtonStyle())
                .disabled(trimmedQuery.isEmpty || isSearching)
                .accessibilitySortPriority(78)

                if isSearching {
                    ProgressView(L10n.tr("search.state.searching"))
                        .accessibilitySortPriority(76)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .accessibilityLabel(errorMessage)
                }

                recentSearchesSection
                searchResultsSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard AccessibilityAnnouncer.isVoiceOverRunning == false else { return }
                dismissKeyboard()
            }
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("home.dest.search.title"))
        .inlineNavigationTitle()
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            userLocationProvider.requestAccessAndRefresh()
            focusedField = .searchInput
            isSearchInputFocused = true
            seedInitialQueryIfNeeded()
        }
        .onChange(of: speechController.errorMessage) { _, newError in
            guard let newError else { return }
            errorMessage = newError
            AccessibilityAnnouncer.announce(newError)
        }
        .onChange(of: sortedResults.count) { _, _ in
            if pageIndex >= pageCount {
                pageIndex = max(0, pageCount - 1)
            }
        }
        .sheet(item: $selectedResult) { result in
            NavigationStack {
                SearchResultDetailView(
                    result: result,
                    allReviews: LocalReviewStore.load(),
                    aiService: aiService,
                    speechManager: speechManager
                )
            }
        }
    }

    private var inputArea: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if queryText.isEmpty {
                    Text(L10n.tr("search.input.placeholder"))
                        .foregroundStyle(LumaPalette.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .accessibilityHidden(true)
                }

                SearchQuestionTextEditor(
                    text: $queryText,
                    isFocused: $isSearchInputFocused,
                    onSubmit: {
                        triggerSearch(using: trimmedQuery)
                    }
                )
                .frame(minHeight: 54)
                .padding(6)
                .background(Color.clear)
                .accessibilityLabel(L10n.tr("search.input.accessibility.label"))
                .accessibilityHint(L10n.tr("search.input.accessibility.hint"))
                .accessibilityFocused($focusedField, equals: .searchInput)
                .accessibilityDefaultFocus($focusedField, .searchInput)
            }
            .lumaInputStyle()
            .accessibilitySortPriority(100)

            Button(action: toggleVoiceInput) {
                Image(systemName: speechController.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
            }
            .buttonStyle(LumaInlineIconButtonStyle())
            .accessibilityLabel(L10n.tr("speech.button.label"))
            .accessibilityHint(L10n.tr("speech.button.hint"))
            .accessibilitySortPriority(79)
        }
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        if recentSearches.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("search.recent.title"))
                    .font(.subheadline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                ForEach(recentSearches, id: \.self) { recent in
                    Button(recent) {
                        queryText = recent
                        triggerSearch(using: recent)
                    }
                    .buttonStyle(LumaSecondaryButtonStyle())
                }
            }
            .lumaCardStyle()
            .accessibilitySortPriority(70)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if hasSearched {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr("search.results.title"))
                    .font(.headline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focusedField, equals: .resultsHeading)

                Picker(L10n.tr("search.results.sort.title"), selection: $sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(L10n.tr("search.results.sort.title"))
                .accessibilityHint(L10n.tr("search.results.sort.hint"))

                if sortedResults.isEmpty {
                    Text(L10n.tr("search.state.no_results"))
                        .foregroundStyle(LumaPalette.secondaryText)
                } else {
                    ForEach(Array(pageResults.enumerated()), id: \.element.id) { index, result in
                        resultRow(result, pageOrder: index)
                    }

                    pageControls
                }
            }
            .lumaCardStyle()
            .accessibilitySortPriority(60)
        }
    }

    private var pageControls: some View {
        HStack(spacing: 10) {
            Button(L10n.tr("search.results.page.previous")) {
                pageIndex = max(0, pageIndex - 1)
            }
            .buttonStyle(LumaCompactButtonStyle())
            .disabled(canGoToPreviousPage == false)

            Text(L10n.format("search.results.page.indicator", pageIndex + 1, pageCount))
                .font(.footnote)
                .foregroundStyle(LumaPalette.secondaryText)

            Button(L10n.tr("search.results.page.next")) {
                pageIndex = min(pageCount - 1, pageIndex + 1)
            }
            .buttonStyle(LumaCompactButtonStyle())
            .disabled(canGoToNextPage == false)
        }
    }

    private func resultRow(_ result: PlaceSearchResult, pageOrder: Int) -> some View {
        let distance = result.distanceMeters(from: userLocationProvider.latestLocation)

        return Button {
            selectedResult = result
            lastSearchedPlaceName = result.name
            lastSearchedPlaceAt = Date().timeIntervalSince1970
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(result.name)
                        .font(.headline)
                    Spacer()
                    Text(L10n.format("search.results.row.score", result.score))
                        .font(.subheadline.weight(.semibold))
                }

                Text(L10n.format("search.results.row.distance", distance))
                    .font(.footnote)
                    .foregroundStyle(LumaPalette.secondaryText)

                if result.confidenceText.isEmpty == false {
                    Text(result.confidenceText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .lumaCardStyle(padding: 12)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(result.voiceOverRowText(distanceMeters: distance))
        .accessibilityHint(L10n.tr("search.results.row.hint"))
        .accessibilitySortPriority(Double(55 - pageOrder))
    }

    private func toggleVoiceInput() {
        if speechController.isRecording {
            speechController.stopRecording()
            return
        }

        speechController.startRecording(
            onTranscript: { transcript in
                let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedTranscript.isEmpty == false else { return }
                queryText = trimmedTranscript
            },
            onStopped: { didCaptureTranscript in
                if didCaptureTranscript {
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_stopped"))
                } else {
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_cancelled"))
                }
            }
        )
        AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_started"))
    }

    private func triggerSearch(using query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = L10n.tr("search.ask.error.empty")
            return
        }

        dismissKeyboard()
        userLocationProvider.refreshLocationIfAuthorized()

        isSearching = true
        hasSearched = true
        errorMessage = nil
        pageIndex = 0
        AccessibilityAnnouncer.announce(L10n.tr("announcement.searching"))

        Task {
            do {
                let mapItems = try await fetchMapItems(for: trimmed)
                let snapshots = buildResults(from: mapItems)

                await MainActor.run {
                    searchResults = snapshots
                    isSearching = false

                    if let first = sortedResults.first {
                        lastSearchedPlaceName = first.name
                        lastSearchedPlaceAt = Date().timeIntervalSince1970
                    }

                    recentSearches = SearchRecentStore.save(trimmed)
                    AccessibilityAnnouncer.announce(L10n.format("announcement.search_found_places", snapshots.count))
                    focusedField = .resultsHeading
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    let message = L10n.tr("search.state.failed")
                    errorMessage = message
                    AccessibilityAnnouncer.announce(message)
                }
            }
        }
    }

    private func fetchMapItems(for query: String) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        if let location = userLocationProvider.latestLocation {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        } else {
            request.region = ShanghaiMapBounds.boundingRegion
        }

        let response = try await MKLocalSearch(request: request).start()

        var seenKeys = Set<String>()
        var deduplicated: [MKMapItem] = []
        for item in response.mapItems {
            guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), name.isEmpty == false else {
                continue
            }
            let location = item.location

            let coordinate = ShanghaiMapBounds.clampedCoordinate(location.coordinate)
            let key = "\(name.lowercased())::\(coordinate.latitude)::\(coordinate.longitude)"
            guard seenKeys.contains(key) == false else { continue }

            seenKeys.insert(key)
            deduplicated.append(item)
        }

        return Array(deduplicated.prefix(25))
    }

    private func buildResults(from mapItems: [MKMapItem]) -> [PlaceSearchResult] {
        let reviews = LocalReviewStore.load()

        return mapItems.compactMap { item in
            let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard name.isEmpty == false else { return nil }
            let location = item.location

            let coordinate = ShanghaiMapBounds.clampedCoordinate(location.coordinate)
            let matchedReviews = reviewsForPlace(named: name, in: reviews)
            let score = scoreForPlace(name: name, reviews: matchedReviews)
            let lowConfidence = isLowConfidence(reviews: matchedReviews)

            let factorRatings = factorRatingsForPlace(score: score, reviews: matchedReviews)
            let pros = topPoints(from: matchedReviews, positive: true)
            let cons = topPoints(from: matchedReviews, positive: false)

            return PlaceSearchResult(
                name: name,
                coordinate: coordinate,
                score: score,
                confidenceText: lowConfidence ? L10n.tr("search.results.low_confidence") : "",
                topPros: pros,
                topCons: cons,
                factorRatings: factorRatings
            )
        }
    }

    private func reviewsForPlace(named placeName: String, in reviews: [LocalReviewEntry]) -> [LocalReviewEntry] {
        let normalizedTarget = normalizedText(placeName)

        return reviews.filter { review in
            let reviewName = normalizedText(review.placeName)
            return reviewName == normalizedTarget ||
            reviewName.contains(normalizedTarget) ||
            normalizedTarget.contains(reviewName)
        }
    }

    private func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func scoreForPlace(name: String, reviews: [LocalReviewEntry]) -> Int {
        let ratings = reviews.compactMap(\.rating)
        var base: Int

        if ratings.isEmpty == false {
            let average = Double(ratings.reduce(0, +)) / Double(ratings.count)
            base = Int((average * 20).rounded())
        } else {
            let hashValue = abs(name.lowercased().unicodeScalars.map(\.value).reduce(0, +).hashValue)
            base = 55 + (hashValue % 36)
        }

        let normalizedNotes = reviews.map { $0.note.lowercased() }
        let positiveSignals = ["accessible", "ramp", "elevator", "helpful", "clean", "无障碍", "方便", "友好"]
        let negativeSignals = ["blocked", "narrow", "broken", "stairs", "unsafe", "台阶", "拥挤", "坏"]

        var sentimentDelta = 0
        for note in normalizedNotes {
            if positiveSignals.contains(where: { note.contains($0) }) {
                sentimentDelta += 1
            }
            if negativeSignals.contains(where: { note.contains($0) }) {
                sentimentDelta -= 1
            }
        }

        base += sentimentDelta * 4
        return max(0, min(100, base))
    }

    private func isLowConfidence(reviews: [LocalReviewEntry]) -> Bool {
        let now = Date()
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now
        let recent90Count = reviews.filter { $0.createdAt >= ninetyDaysAgo }.count
        return recent90Count < 3 || reviews.count < 5
    }

    private func factorRatingsForPlace(score: Int, reviews: [LocalReviewEntry]) -> [PlaceFactorRating] {
        let baseline = max(1, min(5, Int(round(Double(score) / 20.0))))
        let noteText = reviews.map { $0.note.lowercased() }.joined(separator: " ")

        func adjustedRating(
            _ value: Int,
            positiveKeywords: [String],
            negativeKeywords: [String]
        ) -> Int {
            var rating = value
            if positiveKeywords.contains(where: { noteText.contains($0) }) {
                rating += 1
            }
            if negativeKeywords.contains(where: { noteText.contains($0) }) {
                rating -= 1
            }
            return max(1, min(5, rating))
        }

        return [
            PlaceFactorRating(
                name: L10n.tr("search.detail.factor.entrance"),
                rating: adjustedRating(baseline, positiveKeywords: ["ramp", "entrance", "入口", "坡道"], negativeKeywords: ["stairs", "台阶"])
            ),
            PlaceFactorRating(
                name: L10n.tr("search.detail.factor.route"),
                rating: adjustedRating(baseline, positiveKeywords: ["clear", "route", "指引"], negativeKeywords: ["confusing", "绕", "复杂"])
            ),
            PlaceFactorRating(
                name: L10n.tr("search.detail.factor.vertical"),
                rating: adjustedRating(baseline, positiveKeywords: ["elevator", "lift", "电梯"], negativeKeywords: ["no elevator", "broken lift", "无电梯"])
            ),
            PlaceFactorRating(
                name: L10n.tr("search.detail.factor.restroom"),
                rating: adjustedRating(baseline, positiveKeywords: ["restroom", "toilet", "卫生间"], negativeKeywords: ["dirty", "not accessible", "不方便"])
            ),
            PlaceFactorRating(
                name: L10n.tr("search.detail.factor.staff"),
                rating: adjustedRating(baseline, positiveKeywords: ["staff", "helpful", "友好"], negativeKeywords: ["ignored", "rude", "无人帮助"])
            ),
        ]
    }

    private func topPoints(from reviews: [LocalReviewEntry], positive: Bool) -> [String] {
        let notes = reviews.map(\.note)
        let fallback = positive
            ? [L10n.tr("search.detail.pro.default.one"), L10n.tr("search.detail.pro.default.two")]
            : [L10n.tr("search.detail.con.default.one"), L10n.tr("search.detail.con.default.two")]

        guard notes.isEmpty == false else {
            return fallback
        }

        let filtered = notes.filter { note in
            let lowered = note.lowercased()
            if positive {
                return ["good", "easy", "smooth", "helpful", "方便", "顺畅", "友好"].contains(where: { lowered.contains($0) })
            }
            return ["hard", "blocked", "stairs", "crowded", "困难", "拥挤", "台阶"].contains(where: { lowered.contains($0) })
        }

        if filtered.isEmpty {
            return fallback
        }

        return Array(filtered.prefix(2))
    }

    private func dismissKeyboard() {
        isSearchInputFocused = false
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func seedInitialQueryIfNeeded() {
        guard hasSeededInitialQuery == false else { return }
        hasSeededInitialQuery = true

        guard let initialQuery else { return }
        let trimmed = initialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        queryText = trimmed
    }
}

private struct PlaceSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let score: Int
    let confidenceText: String
    let topPros: [String]
    let topCons: [String]
    let factorRatings: [PlaceFactorRating]

    func distanceMeters(from userLocation: CLLocation?) -> Int {
        let origin = userLocation ?? CLLocation(latitude: ShanghaiMapBounds.centerCoordinate.latitude, longitude: ShanghaiMapBounds.centerCoordinate.longitude)
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return Int(origin.distance(from: destination).rounded())
    }

    func voiceOverRowText(distanceMeters: Int) -> String {
        var components: [String] = [
            name,
            L10n.format("search.results.voice.distance", distanceMeters),
            L10n.format("search.results.voice.score", score),
        ]

        if confidenceText.isEmpty == false {
            components.append(confidenceText)
        }

        components.append(L10n.tr("search.results.voice.details_hint"))
        return components.joined(separator: ", ")
    }
}

private struct PlaceFactorRating: Identifiable {
    let id = UUID()
    let name: String
    let rating: Int
}

private enum SearchRecentStore {
    private static let storageKey = "luma.search.recent"
    private static let maxItems = 5

    static func load() -> [String] {
        let values = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    @discardableResult
    static func save(_ query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return load()
        }

        var updated = load().filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        updated.insert(trimmed, at: 0)
        if updated.count > maxItems {
            updated = Array(updated.prefix(maxItems))
        }
        UserDefaults.standard.set(updated, forKey: storageKey)
        return updated
    }
}

private struct SearchResultDetailView: View {
    private enum FocusField: Hashable {
        case title
    }

    private struct FollowUpTurn {
        let question: String
        let answer: String
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    let result: PlaceSearchResult
    let allReviews: [LocalReviewEntry]
    let aiService: AIAskService

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var speechManager: SpeechManager
    @StateObject private var speechController = SpeechInputController()
    @AccessibilityFocusState private var focusedField: FocusField?

    @State private var followUpQuestion = ""
    @State private var followUpAnswer = ""
    @State private var isAsking = false
    @State private var askError: String?
    @State private var history: [FollowUpTurn] = []

    private var oneYearRecentReviews: [LocalReviewEntry] {
        let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date.distantPast
        let normalizedResultName = normalized(result.name)

        return allReviews.filter { review in
            review.createdAt >= oneYearAgo && normalized(review.placeName).contains(normalizedResultName)
        }
    }

    private var spokenSummary: String {
        let preferenceText: String
        if speechManager.savedPreferences.isEmpty {
            preferenceText = ""
        } else {
            preferenceText = L10n.format(
                "search.detail.speech.preferences",
                speechManager.savedPreferences.joined(separator: ", ")
            )
        }

        let pros = result.topPros.joined(separator: "; ")
        let cons = result.topCons.joined(separator: "; ")
        let factors = result.factorRatings
            .map { "\($0.name) \($0.rating)/5" }
            .joined(separator: ", ")

        return [
            L10n.format("search.detail.speech.header", result.name, result.score),
            result.confidenceText.isEmpty ? "" : result.confidenceText,
            preferenceText,
            L10n.format("search.detail.speech.pros", pros),
            L10n.format("search.detail.speech.cons", cons),
            L10n.format("search.detail.speech.factors", factors),
        ]
        .filter { $0.isEmpty == false }
        .joined(separator: " ")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label(L10n.tr("common.button.back"), systemImage: "chevron.left")
                    }
                    .buttonStyle(LumaCompactButtonStyle())

                    Spacer(minLength: 0)
                }

                Text(result.name)
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focusedField, equals: .title)
                    .lumaCardStyle()

                Text(L10n.format("search.detail.score", result.score))
                    .foregroundStyle(LumaPalette.secondaryText)
                    .lumaCardStyle()

                if result.confidenceText.isEmpty == false {
                    Text(result.confidenceText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                        .lumaCardStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("search.detail.section.pros"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(result.topPros, id: \.self) { pro in
                        Text("• \(pro)")
                    }
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("search.detail.section.cons"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(result.topCons, id: \.self) { con in
                        Text("• \(con)")
                    }
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("search.detail.section.factors"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(result.factorRatings) { factor in
                        Text("\(factor.name): \(factor.rating)/5")
                    }
                }
                .lumaCardStyle()

                Button(speechManager.isSpeaking ? L10n.tr("search.detail.button.stop_speaking") : L10n.tr("search.detail.button.speak_summary")) {
                    if speechManager.isSpeaking {
                        speechManager.stop()
                    } else {
                        speechManager.speak(spokenSummary)
                    }
                }
                .buttonStyle(LumaPrimaryButtonStyle())
                .accessibilityLabel(L10n.tr("search.detail.button.speak_summary"))
                .accessibilityHint(L10n.tr("search.detail.button.speak_summary.hint"))

                Text(L10n.tr("search.detail.follow_up.title"))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .lumaCardStyle()

                TextField(L10n.tr("search.detail.follow_up.placeholder"), text: $followUpQuestion)
                    .lumaInputStyle()
                    .accessibilityLabel(L10n.tr("search.detail.follow_up.input.label"))
                    .accessibilityHint(L10n.tr("search.detail.follow_up.input.hint"))

                HStack(spacing: 10) {
                    Button(isAsking ? L10n.tr("search.detail.follow_up.asking") : L10n.tr("search.detail.follow_up.ask")) {
                        askFollowUp()
                    }
                    .buttonStyle(LumaCompactPrimaryButtonStyle())
                    .disabled(isAsking || followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(action: toggleVoiceInput) {
                        Image(systemName: speechController.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                    }
                    .buttonStyle(LumaInlineIconButtonStyle())
                    .accessibilityLabel("\(L10n.tr("search.detail.follow_up.title")), \(L10n.tr("speech.button.label"))")
                    .accessibilityHint(L10n.tr("speech.button.hint"))
                }
                .lumaCardStyle()

                if isAsking {
                    ProgressView(L10n.tr("search.detail.follow_up.asking"))
                }

                if let askError {
                    Text(askError)
                        .foregroundStyle(.red)
                }

                if followUpAnswer.isEmpty == false {
                    Text(L10n.tr("search.detail.follow_up.answer"))
                        .font(.headline)

                    Text(followUpAnswer)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lumaInputStyle()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("search.detail.nav.title"))
        .inlineNavigationTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label(L10n.tr("common.button.back"), systemImage: "chevron.left")
                }
                .accessibilityHint(L10n.tr("common.button.back.hint"))
            }
        }
        .onAppear {
            focusedField = .title
            AccessibilityAnnouncer.announce(
                "\(result.name). \(L10n.format("search.detail.score", result.score))"
            )
        }
        .onChange(of: speechController.errorMessage) { _, newError in
            guard let newError else { return }
            askError = newError
            AccessibilityAnnouncer.announce(newError)
        }
        .onDisappear {
            speechManager.stop()
        }
    }

    private func askFollowUp() {
        let question = followUpQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false else { return }

        speechManager.rememberPreferences(from: question)
        askError = nil
        isAsking = true

        let prompt = buildPrompt(question: question)

        Task {
            do {
                let answer = try await aiService.ask(
                    question: prompt,
                    context: makeAIContext()
                )

                await MainActor.run {
                    followUpAnswer = answer
                    history.append(FollowUpTurn(question: question, answer: answer))
                    isAsking = false
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.search_answer_ready"))
                    speechManager.speak(answer)
                }
            } catch {
                await MainActor.run {
                    isAsking = false
                    let message: String
                    if let aiError = error as? AIAskServiceError, let description = aiError.errorDescription {
                        message = description
                    } else {
                        message = L10n.tr("search.ask.error.server")
                    }
                    askError = message
                    AccessibilityAnnouncer.announce(message)
                }
            }
        }
    }

    private func buildPrompt(question: String) -> String {
        var parts: [String] = [
            "Place: \(result.name)",
            "Accessibility score: \(result.score)/100",
            "Pros: \(result.topPros.joined(separator: "; "))",
            "Cons: \(result.topCons.joined(separator: "; "))",
            "Factor ratings: \(result.factorRatings.map { "\($0.name) \($0.rating)/5" }.joined(separator: ", "))",
            "Use only reviews newer than 1 year in your answer.",
        ]

        if speechManager.savedPreferences.isEmpty == false {
            parts.append("Remember user preferences: \(speechManager.savedPreferences.joined(separator: ", ")).")
        }

        if history.isEmpty == false {
            let recentHistory = history.suffix(3)
                .map { "Q: \($0.question) A: \($0.answer)" }
                .joined(separator: " ")
            parts.append("Follow-up context: \(recentHistory)")
        }

        parts.append("User question: \(question)")
        return parts.joined(separator: "\n")
    }

    private func makeAIContext() -> AIAskContext? {
        let filtered = oneYearRecentReviews.prefix(12)

        let reviews = filtered.map {
            AIAskContext.Review(
                placeName: $0.placeName,
                note: $0.note,
                rating: $0.rating,
                capturedAtISO8601: Self.iso8601Formatter.string(from: $0.createdAt)
            )
        }

        let mapSelection = AIAskContext.MapSelection(
            title: result.name,
            latitude: result.coordinate.latitude,
            longitude: result.coordinate.longitude
        )

        return AIAskContext(
            contextCapturedAtISO8601: Self.iso8601Formatter.string(from: Date()),
            lastVisitedPlaceName: result.name,
            currentLocation: nil,
            mapSelection: mapSelection,
            reviews: Array(reviews)
        )
    }

    private func toggleVoiceInput() {
        if speechController.isRecording {
            speechController.stopRecording()
            return
        }

        speechController.startRecording(
            onTranscript: { transcript in
                let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedTranscript.isEmpty == false else { return }
                followUpQuestion = trimmedTranscript
            },
            onStopped: { didCaptureTranscript in
                if didCaptureTranscript {
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_stopped"))
                } else {
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_cancelled"))
                }
            }
        )
        AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_started"))
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

#if os(iOS)
private struct SearchQuestionTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = .black
        textView.tintColor = .black
        textView.returnKeyType = .search
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.text = text
        textView.isAccessibilityElement = true
        textView.accessibilityLabel = L10n.tr("search.input.accessibility.label")
        textView.accessibilityHint = L10n.tr("search.input.accessibility.hint")
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        uiView.textColor = .black
        uiView.tintColor = .black
        uiView.accessibilityLabel = L10n.tr("search.input.accessibility.label")
        uiView.accessibilityHint = L10n.tr("search.input.accessibility.hint")

        if uiView.text != text {
            uiView.text = text
        }

        if isFocused {
            if uiView.window != nil, uiView.isFirstResponder == false {
                uiView.becomeFirstResponder()
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SearchQuestionTextEditor

        init(_ parent: SearchQuestionTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }
    }
}
#else
private struct SearchQuestionTextEditor: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        TextEditor(text: $text)
            .foregroundStyle(.black)
            .tint(.black)
            .scrollContentBackground(.hidden)
    }
}
#endif
