//
//  HomePageView.swift
//  Luma
//
//  Created by Codex on 3/20/26.
//

import SwiftUI
import MapKit

private enum HomeDestination: Hashable {
    case search
    case nearby
    case tutorial
    case settings
    case createReview
    case localDataTools
}

private enum HomeBottomTab {
    case settings
    case home
    case createReview
}

struct HomePageView: View {
    @ObservedObject var sessionStore: SessionStore
    @StateObject private var homeLocationProvider = UserLocationProvider()
    @State private var path: [HomeDestination] = []
    @State private var isStartupChecking = true
    @State private var startupCheckFailed = false
    @State private var hasRunStartupCheck = false
    @AppStorage("home.last_visited_place_name") private var lastVisitedPlaceName = ""
    @AppStorage("home.last_searched_place_name") private var lastSearchedPlaceName = ""
    @AppStorage("home.last_searched_place_at") private var lastSearchedPlaceAt = 0.0

    private static let recentSearchPrefillWindow: TimeInterval = 24 * 60 * 60

    private var currentUsernameBadgeText: String? {
        let username = sessionStore.currentAccountProfile()?.username.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return username.isEmpty ? nil : username
    }

    private var roleTitle: String {
        sessionStore.currentRole?.title ?? L10n.tr("home.role.unknown")
    }

    private var trimmedLastVisitedPlaceName: String {
        lastVisitedPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var freshLastSearchedPlaceName: String? {
        let trimmed = lastSearchedPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard lastSearchedPlaceAt > 0 else { return nil }

        let elapsed = Date().timeIntervalSince1970 - lastSearchedPlaceAt
        guard elapsed >= 0, elapsed <= Self.recentSearchPrefillWindow else { return nil }
        return trimmed
    }

    private var reviewPrefilledPlaceName: String? {
        if let searched = freshLastSearchedPlaceName {
            return searched
        }
        return trimmedLastVisitedPlaceName.isEmpty ? nil : trimmedLastVisitedPlaceName
    }

    private var canAccessLocalDataTools: Bool {
        guard let role = sessionStore.currentRole else { return false }
        switch role {
        case .lowVisionUser:
            return false
        case .venueMaintenance, .communityManagement:
            return true
        }
    }

    private var mainButtonsDisabled: Bool {
        isStartupChecking || startupCheckFailed
    }

    private var selectedBottomTab: HomeBottomTab {
        switch path.last {
        case .settings:
            return .settings
        case .createReview:
            return .createReview
        default:
            return .home
        }
    }

    private var shouldShowBottomMenu: Bool {
        path.last != .tutorial
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("home.title"))
                            .font(.title.weight(.bold))
                            .fontDesign(.rounded)
                            .accessibilityAddTraits(.isHeader)

                        Text(L10n.format("home.current_role", roleTitle))
                            .foregroundStyle(LumaPalette.secondaryText)

                        startupStateArea
                    }
                    .lumaCardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        primaryActionButton(
                            L10n.tr("home.button.search_places"),
                            systemImage: "magnifyingglass"
                        ) {
                            path.append(.search)
                        }

                        primaryActionButton(
                            L10n.tr("home.button.nearby_places"),
                            systemImage: "map"
                        ) {
                            path.append(.nearby)
                        }

                        primaryActionButton(
                            L10n.tr("home.button.replay_tutorial"),
                            systemImage: "play.rectangle"
                        ) {
                            path.append(.tutorial)
                        }
                    }
                    .lumaCardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        secondaryActionButton(
                            L10n.tr("home.button.switch_role"),
                            systemImage: "arrow.triangle.2.circlepath"
                        ) {
                            sessionStore.beginRoleSwitch()
                            AccessibilityAnnouncer.announce(L10n.tr("announcement.role_switch_start"))
                        }

                        if canAccessLocalDataTools {
                            secondaryActionButton(
                                L10n.tr("home.button.local_data_tools"),
                                systemImage: "tray.full"
                            ) {
                                path.append(.localDataTools)
                            }
                        }
                    }
                    .lumaCardStyle()
                }
                .padding(24)
                .padding(.bottom, shouldShowBottomMenu ? 84 : 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .lumaScreenStyle()
            .scrollIndicators(.hidden)
            .navigationTitle(L10n.tr("home.nav.title"))
            .inlineNavigationTitle()
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(LumaPalette.backgroundTop, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                if let currentUsernameBadgeText {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            path = [.settings]
                        } label: {
                            usernameBadge(currentUsernameBadgeText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationDestination(for: HomeDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if shouldShowBottomMenu {
                bottomMenu
            }
        }
        .onAppear {
            homeLocationProvider.requestAccessAndRefresh()
            AccessibilityAnnouncer.announce(L10n.tr("announcement.home_page"))
            if hasRunStartupCheck == false {
                hasRunStartupCheck = true
                runStartupCheck()
            }
        }
    }

    @ViewBuilder
    private var startupStateArea: some View {
        if isStartupChecking {
            Text(L10n.tr("home.state.checking"))
                .font(.footnote)
                .foregroundStyle(LumaPalette.secondaryText)
                .accessibilityLabel(L10n.tr("home.state.checking"))
        } else if startupCheckFailed {
            VStack(alignment: .leading, spacing: 8) {
                Button(L10n.tr("home.button.retry")) {
                    runStartupCheck()
                }
                .buttonStyle(LumaSecondaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: HomeDestination) -> some View {
        switch destination {
        case .search:
            SearchAskView()
        case .nearby:
            NearbyFlowPlaceholderView { placeName in
                lastVisitedPlaceName = placeName
                AccessibilityAnnouncer.announce(L10n.format("announcement.last_place_updated", placeName))
            }
        case .tutorial:
            TutorialPageView {
                path.removeAll()
            }
        case .settings:
            SettingsPageView(sessionStore: sessionStore)
        case .createReview:
            ReviewCapturePlaceholderView(
                prefilledPlaceName: reviewPrefilledPlaceName,
                onSearchPlaceRequested: {
                    path.append(.search)
                }
            )
        case .localDataTools:
            FeaturePlaceholderView(
                title: L10n.tr("home.dest.local_data_tools.title"),
                description: L10n.tr("home.dest.local_data_tools.description")
            )
        }
    }

    private var bottomMenu: some View {
        HStack(spacing: 10) {
            bottomMenuButton(
                title: L10n.tr("home.menu.create_review"),
                systemImage: selectedBottomTab == .createReview ? "square.and.pencil.circle.fill" : "square.and.pencil.circle",
                isSelected: selectedBottomTab == .createReview,
                action: {
                    path = [.createReview]
                }
            )
            bottomMenuButton(
                title: L10n.tr("home.menu.home"),
                systemImage: selectedBottomTab == .home ? "house.fill" : "house",
                isSelected: selectedBottomTab == .home,
                action: { path.removeAll() }
            )
            bottomMenuButton(
                title: L10n.tr("home.menu.settings"),
                systemImage: selectedBottomTab == .settings ? "gearshape.fill" : "gearshape",
                isSelected: selectedBottomTab == .settings,
                action: {
                    path = [.settings]
                }
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LumaPalette.card.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LumaPalette.cardBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private func primaryActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 26)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(LumaPalette.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LumaPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LumaPalette.cardBorder.opacity(0.9), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(mainButtonsDisabled)
    }

    private func secondaryActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(LumaSecondaryButtonStyle())
    }

    private func bottomMenuButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 6)
                .foregroundStyle(isSelected ? LumaPalette.primaryText : LumaPalette.secondaryText)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? LumaPalette.accentSoft : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? LumaPalette.accent : Color.clear, lineWidth: 1)
                )
        )
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func usernameBadge(_ username: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 14, weight: .semibold))
            Text(username)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(LumaPalette.card)
                .overlay(
                    Capsule()
                        .stroke(LumaPalette.cardBorder, lineWidth: 1)
                )
        )
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.format("home.username.badge.a11y", username))
    }

    private func runStartupCheck() {
        isStartupChecking = true
        startupCheckFailed = false

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            isStartupChecking = false
            startupCheckFailed = false
        }
    }
}

struct TutorialPageView: View {
    @AppStorage("tutorial_completed") private var tutorialCompleted = false
    @AppStorage(AppLanguage.userDefaultsKey) private var appLanguageRaw = AppLanguage.deviceDefault.rawValue
    @StateObject private var speechManager = SpeechManager()

    let onCompleted: () -> Void

    private var tutorialSteps: [String] {
        [
            L10n.tr("tutorial.script.step.1"),
            L10n.tr("tutorial.script.step.2"),
            L10n.tr("tutorial.script.step.3"),
            L10n.tr("tutorial.script.step.4"),
            L10n.tr("tutorial.script.step.5"),
            L10n.tr("tutorial.script.step.6"),
            L10n.tr("tutorial.script.step.7"),
            L10n.tr("tutorial.script.step.8"),
            L10n.tr("tutorial.script.step.9"),
        ]
    }

    private var scriptNarration: String {
        let numberedSteps = tutorialSteps.enumerated().map { index, step in
            "\(index + 1). \(step)"
        }
        return [
            L10n.tr("tutorial.script.subtitle"),
            numberedSteps.joined(separator: " ")
        ].joined(separator: " ")
    }

    private var currentAppLanguage: AppLanguage {
        AppLanguage.resolve(from: appLanguageRaw) ?? .deviceDefault
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("home.dest.tutorial.title"))
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)

                    Text(L10n.tr("tutorial.script.subtitle"))
                        .font(.headline.weight(.semibold))
                        .fontDesign(.rounded)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(tutorialSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.subheadline.weight(.semibold))
                                Text(step)
                                    .font(.subheadline)
                            }
                        }
                    }
                        .foregroundStyle(LumaPalette.secondaryText)
                }
                .lumaCardStyle()

                VStack(spacing: 12) {
                    Button(speechManager.isSpeaking ? L10n.tr("tutorial.button.pause") : L10n.tr("tutorial.button.play")) {
                        if speechManager.isSpeaking {
                            speechManager.stop()
                        } else {
                            speechManager.speak(scriptNarration, language: currentAppLanguage)
                        }
                    }
                    .buttonStyle(LumaPrimaryButtonStyle())

                    Button(L10n.tr("tutorial.button.repeat")) {
                        speechManager.speak(scriptNarration, language: currentAppLanguage)
                    }
                    .buttonStyle(LumaSecondaryButtonStyle())

                    Button(L10n.tr("tutorial.button.complete")) {
                        completeTutorial()
                    }
                    .buttonStyle(LumaSecondaryButtonStyle())
                }
                .lumaCardStyle()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(24)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("home.dest.tutorial.title"))
        .inlineNavigationTitle()
        .onAppear {
            AccessibilityAnnouncer.announce(L10n.tr("announcement.tutorial_entry"))
        }
        .onDisappear {
            speechManager.stop()
        }
    }

    private func completeTutorial() {
        tutorialCompleted = true
        speechManager.stop()
        AccessibilityAnnouncer.announce(L10n.tr("announcement.tutorial_completed"))
        onCompleted()
    }
}

private struct FeaturePlaceholderView: View {
    let title: String
    let description: String
    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)
                Text(description)
                    .foregroundStyle(LumaPalette.secondaryText)
            }
            .lumaCardStyle()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .lumaScreenStyle()
        .navigationTitle(title)
        .inlineNavigationTitle()
        .onAppear {
            isTitleFocused = true
        }
    }
}

private struct NearbyFlowPlaceholderView: View {
    let onVisitedPlace: (String) -> Void
    @AccessibilityFocusState private var isTitleFocused: Bool
    @StateObject private var userLocationProvider = UserLocationProvider()
    @State private var nearbyPlaces: [NearbyPlaceResult] = []
    @State private var isFindingNearby = false
    @State private var hasAttemptedLookup = false
    @State private var loadErrorMessage: String?
    @State private var manualSearchText = ""
    @State private var manualSearchSeed = ""
    @State private var shouldOpenManualSearch = false
    @State private var lastLookupLocation: CLLocation?
    @State private var lookupTask: Task<Void, Never>?

    private static let searchRadiusMeters: CLLocationDistance = 500
    private static let fallbackNearbyQueries = [
        "restaurant",
        "cafe",
        "supermarket",
        "pharmacy",
        "地铁站",
        "商场",
    ]

    private var trimmedManualSearch: String {
        manualSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var permissionStatusText: String {
        switch userLocationProvider.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return L10n.tr("nearby.status.permission.authorized")
        case .denied:
            return L10n.tr("nearby.status.permission.denied")
        case .restricted:
            return L10n.tr("nearby.status.permission.restricted")
        case .notDetermined:
            return L10n.tr("nearby.status.permission.not_determined")
        @unknown default:
            return L10n.tr("nearby.status.permission.not_determined")
        }
    }

    private var locationStatusText: String {
        guard let location = userLocationProvider.latestLocation else {
            return L10n.tr("nearby.status.position.unavailable")
        }
        return L10n.format(
            "nearby.status.position.coordinates",
            location.coordinate.latitude,
            location.coordinate.longitude
        )
    }

    private var isLocationDenied: Bool {
        userLocationProvider.authorizationStatus == .denied ||
        userLocationProvider.authorizationStatus == .restricted
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("home.dest.nearby.title"))
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)

                    Text(L10n.tr("nearby.page.description"))
                        .foregroundStyle(LumaPalette.secondaryText)
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    statusRow(
                        title: L10n.tr("nearby.status.permission.title"),
                        value: permissionStatusText
                    )
                    statusRow(
                        title: L10n.tr("nearby.status.position.title"),
                        value: locationStatusText
                    )
                }
                .lumaCardStyle()

                if isLocationDenied {
                    deniedFallbackArea
                } else {
                    nearbyListArea
                }
            }
            .padding(24)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("home.dest.nearby.title"))
        .inlineNavigationTitle()
        .navigationDestination(isPresented: $shouldOpenManualSearch) {
            SearchAskView(initialQuery: manualSearchSeed)
        }
        .onAppear {
            isTitleFocused = true
            userLocationProvider.requestAccessAndRefresh()
            refreshNearbyPlaces(force: true)
        }
        .onChange(of: userLocationProvider.authorizationStatus) { _, _ in
            refreshNearbyPlaces(force: true)
        }
        .onChange(of: userLocationProvider.latestLocation?.timestamp) { _, _ in
            refreshNearbyPlaces(force: false)
        }
        .onDisappear {
            lookupTask?.cancel()
            lookupTask = nil
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 10)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(LumaPalette.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }

    private var deniedFallbackArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("nearby.state.location_denied"))
                .foregroundStyle(.red)

            Text(L10n.tr("nearby.manual.title"))
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            TextField(L10n.tr("nearby.manual.placeholder"), text: $manualSearchText)
                .lumaInputStyle()
                .accessibilityLabel(L10n.tr("nearby.manual.title"))
                .accessibilityHint(L10n.tr("nearby.manual.placeholder"))

            Button(L10n.tr("nearby.manual.button")) {
                manualSearchSeed = trimmedManualSearch
                shouldOpenManualSearch = true
            }
            .buttonStyle(LumaPrimaryButtonStyle())
            .disabled(trimmedManualSearch.isEmpty)
        }
        .lumaCardStyle()
    }

    private var nearbyListArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(L10n.tr("nearby.list.title"))
                    .font(.headline.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button(L10n.tr("nearby.button.refresh")) {
                    refreshNearbyPlaces(force: true)
                }
                .buttonStyle(LumaCompactButtonStyle())
            }

            if isFindingNearby {
                ProgressView(L10n.tr("nearby.state.finding"))
            }

            if let loadErrorMessage {
                Text(loadErrorMessage)
                    .foregroundStyle(.red)
            }

            if nearbyPlaces.isEmpty && hasAttemptedLookup && isFindingNearby == false && loadErrorMessage == nil {
                Text(L10n.tr("nearby.state.none_within_radius"))
                    .foregroundStyle(LumaPalette.secondaryText)
            }

            ForEach(nearbyPlaces) { place in
                NavigationLink {
                    NearbyPlaceDetailView(place: place)
                        .onAppear {
                            onVisitedPlace(place.name)
                        }
                } label: {
                    nearbyPlaceRow(for: place)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(place.voiceOverRowText())
                .accessibilityHint(L10n.tr("nearby.row.hint"))
            }
        }
        .lumaCardStyle()
    }

    private func nearbyPlaceRow(for place: NearbyPlaceResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(place.name)
                    .font(.headline)
                Spacer()
                Text(L10n.format("search.results.row.score", place.score))
                    .font(.subheadline.weight(.semibold))
            }

            Text(L10n.format("search.results.row.distance", place.distanceMeters))
                .font(.footnote)
                .foregroundStyle(LumaPalette.secondaryText)

            if place.lowConfidence {
                Text(L10n.tr("search.results.low_confidence"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumaCardStyle(padding: 12)
    }

    private func refreshNearbyPlaces(force: Bool) {
        if isLocationDenied {
            isFindingNearby = false
            hasAttemptedLookup = true
            nearbyPlaces = []
            loadErrorMessage = nil
            lookupTask?.cancel()
            lookupTask = nil
            return
        }

        if userLocationProvider.authorizationStatus == .notDetermined {
            isFindingNearby = true
            loadErrorMessage = nil
            userLocationProvider.requestAccessAndRefresh()
            return
        }

        guard
            userLocationProvider.authorizationStatus == .authorizedWhenInUse ||
            userLocationProvider.authorizationStatus == .authorizedAlways
        else {
            return
        }

        guard let latestLocation = userLocationProvider.latestLocation else {
            isFindingNearby = true
            loadErrorMessage = nil
            userLocationProvider.refreshLocationIfAuthorized()
            return
        }

        if
            force == false,
            let lastLookupLocation,
            hasAttemptedLookup,
            lastLookupLocation.distance(from: latestLocation) < 35
        {
            return
        }

        runNearbyLookup(from: latestLocation)
    }

    private func runNearbyLookup(from location: CLLocation) {
        lookupTask?.cancel()
        lookupTask = nil

        hasAttemptedLookup = true
        isFindingNearby = true
        loadErrorMessage = nil
        lastLookupLocation = location
        AccessibilityAnnouncer.announce(L10n.tr("announcement.finding_nearby_places"))

        lookupTask = Task {
            do {
                let mapItems = try await fetchNearbyMapItems(around: location.coordinate)
                guard Task.isCancelled == false else { return }
                let builtPlaces = buildNearbyPlaces(from: mapItems, origin: location)

                await MainActor.run {
                    nearbyPlaces = builtPlaces
                    isFindingNearby = false
                    AccessibilityAnnouncer.announce(
                        L10n.format("announcement.nearby_found_places", builtPlaces.count)
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    nearbyPlaces = []
                    isFindingNearby = false
                    loadErrorMessage = L10n.tr("nearby.state.load_failed")
                    AccessibilityAnnouncer.announce(L10n.tr("nearby.state.load_failed"))
                }
#if DEBUG
                print("Nearby lookup failed: \(error.localizedDescription)")
#endif
            }
        }
    }

    private func fetchNearbyMapItems(around coordinate: CLLocationCoordinate2D) async throws -> [MKMapItem] {
        var poiItems: [MKMapItem]?
        var poiError: Error?

        do {
            poiItems = try await fetchNearbyPOIItems(around: coordinate)
            if let poiItems, poiItems.isEmpty == false {
                return poiItems
            }
        } catch {
            poiError = error
        }

        let fallback = await fetchNearbyFallbackItems(around: coordinate)
        if fallback.didSucceed {
            return deduplicatedItems(from: (poiItems ?? []) + fallback.items)
        }

        if let poiItems {
            return poiItems
        }

        if let poiError {
            throw poiError
        }

        throw MKError(.serverFailure)
    }

    private func fetchNearbyPOIItems(around coordinate: CLLocationCoordinate2D) async throws -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(
            center: coordinate,
            radius: Self.searchRadiusMeters
        )
        let response = try await MKLocalSearch(request: request).start()
        return deduplicatedItems(from: response.mapItems)
    }

    private func fetchNearbyFallbackItems(around coordinate: CLLocationCoordinate2D) async -> (items: [MKMapItem], didSucceed: Bool) {
        let searchRegion = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: Self.searchRadiusMeters * 2,
            longitudinalMeters: Self.searchRadiusMeters * 2
        )

        var allItems: [MKMapItem] = []
        var didSucceed = false

        for query in Self.fallbackNearbyQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = searchRegion

            do {
                let response = try await MKLocalSearch(request: request).start()
                didSucceed = true
                allItems.append(contentsOf: response.mapItems)
            } catch {
                continue
            }
        }

        return (deduplicatedItems(from: allItems), didSucceed)
    }

    private func deduplicatedItems(from mapItems: [MKMapItem]) -> [MKMapItem] {
        var seenKeys = Set<String>()
        var deduplicated: [MKMapItem] = []

        for item in mapItems {
            guard let rawName = item.name else { continue }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.isEmpty == false else { continue }

            let location = item.location
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            let key = "\(name.lowercased())::\(latitude)::\(longitude)"
            guard seenKeys.contains(key) == false else { continue }

            seenKeys.insert(key)
            deduplicated.append(item)
        }

        return deduplicated
    }

    private func buildNearbyPlaces(from mapItems: [MKMapItem], origin: CLLocation) -> [NearbyPlaceResult] {
        let reviews = LocalReviewStore.load()
        let now = Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: now) ?? now

        let nearby = mapItems.compactMap { item -> NearbyPlaceResult? in
            guard let rawName = item.name else { return nil }
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.isEmpty == false else { return nil }

            let coordinate = item.location.coordinate
            let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distanceMeters = Int(origin.distance(from: destination).rounded())
            guard distanceMeters <= Int(Self.searchRadiusMeters) else { return nil }

            let matchedReviews = reviewsForPlace(named: name, in: reviews)
            let score = scoreForPlace(name: name, reviews: matchedReviews)
            let lowConfidence = isLowConfidence(reviews: matchedReviews)

            let lastUpdateAt = matchedReviews.map(\.createdAt).max()
            let reviewCount30d = matchedReviews.filter { $0.createdAt >= thirtyDaysAgo }.count
            let reviewCount90d = matchedReviews.filter { $0.createdAt >= ninetyDaysAgo }.count

            return NearbyPlaceResult(
                name: name,
                coordinate: coordinate,
                distanceMeters: distanceMeters,
                score: score,
                lowConfidence: lowConfidence,
                topPros: topPoints(from: matchedReviews, positive: true),
                topCons: topPoints(from: matchedReviews, positive: false),
                reviewCount30d: reviewCount30d,
                reviewCount90d: reviewCount90d,
                reviewCountTotal: matchedReviews.count,
                lastUpdateAt: lastUpdateAt
            )
        }

        return nearby.sorted {
            if $0.distanceMeters != $1.distanceMeters {
                return $0.distanceMeters < $1.distanceMeters
            }
            return $0.score > $1.score
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
}

private struct NearbyPlaceResult: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Int
    let score: Int
    let lowConfidence: Bool
    let topPros: [String]
    let topCons: [String]
    let reviewCount30d: Int
    let reviewCount90d: Int
    let reviewCountTotal: Int
    let lastUpdateAt: Date?

    func voiceOverRowText() -> String {
        var components: [String] = [
            name,
            L10n.format("search.results.voice.distance", distanceMeters),
            L10n.format("search.results.voice.score", score),
        ]

        if lowConfidence {
            components.append(L10n.tr("search.results.low_confidence"))
        }

        components.append(L10n.tr("search.results.voice.details_hint"))
        return components.joined(separator: ", ")
    }
}

private struct NearbyPlaceDetailView: View {
    let place: NearbyPlaceResult
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var lastUpdatedText: String {
        guard let lastUpdateAt = place.lastUpdateAt else {
            return L10n.tr("nearby.detail.updated_unknown")
        }
        return L10n.format("nearby.detail.updated", Self.dateFormatter.string(from: lastUpdateAt))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(place.name)
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)

                    Text(L10n.format("search.detail.score", place.score))
                        .foregroundStyle(LumaPalette.secondaryText)

                    if place.lowConfidence {
                        Text(L10n.tr("nearby.detail.low_confidence_note"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("search.detail.section.pros"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(place.topPros, id: \.self) { point in
                        Text("• \(point)")
                    }
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("search.detail.section.cons"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(place.topCons, id: \.self) { point in
                        Text("• \(point)")
                    }
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text(lastUpdatedText)
                    Text(L10n.format("nearby.detail.review_count_30d", place.reviewCount30d))
                    Text(L10n.format("nearby.detail.review_count_90d", place.reviewCount90d))
                    Text(L10n.format("nearby.detail.review_count_total", place.reviewCountTotal))

                    if place.reviewCountTotal == 0 {
                        Text(L10n.tr("nearby.detail.limited_data"))
                            .foregroundStyle(LumaPalette.secondaryText)
                    }
                }
                .font(.footnote)
                .lumaCardStyle()
            }
            .padding(24)
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
    }
}

private struct ReviewSubmissionDraft: Hashable, Identifiable {
    let id = UUID()
    let placeName: String
    let note: String
    let rating: Int
}

private struct ReviewCapturePlaceholderView: View {
    let prefilledPlaceName: String?
    let onSearchPlaceRequested: () -> Void
    @AccessibilityFocusState private var isTitleFocused: Bool
    @AppStorage("home.last_visited_place_name") private var lastVisitedPlaceName = ""
    @AppStorage("home.last_searched_place_name") private var lastSearchedPlaceName = ""
    @AppStorage("home.last_searched_place_at") private var lastSearchedPlaceAt = 0.0
    @StateObject private var speechController = SpeechInputController()

    @State private var placeNameDraft = ""
    @State private var notesDraft = ""
    @State private var rating = 4
    @State private var statusMessage: String?
    @State private var savedReviews: [LocalReviewEntry] = []
    @State private var hasSeededPlaceDraft = false
    @State private var pendingConfirmationDraft: ReviewSubmissionDraft?
    @State private var reviewVoiceSessionBaseNote = ""
    @State private var reviewVoiceStopRequestedByUser = false

    private static let recentSearchPrefillWindow: TimeInterval = 24 * 60 * 60

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var canSaveReview: Bool {
        placeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        notesDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var freshSearchedPlaceSuggestion: String? {
        let trimmed = lastSearchedPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard lastSearchedPlaceAt > 0 else { return nil }

        let elapsed = Date().timeIntervalSince1970 - lastSearchedPlaceAt
        guard elapsed >= 0, elapsed <= Self.recentSearchPrefillWindow else { return nil }
        return trimmed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("home.dest.review_capture.title"))
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)

                    if let prefilledPlaceName {
                        Text(L10n.format("home.dest.review_capture.prefilled", prefilledPlaceName))
                            .foregroundStyle(LumaPalette.secondaryText)
                    } else {
                        Text(L10n.tr("home.dest.review_capture.no_prefill"))
                            .foregroundStyle(LumaPalette.secondaryText)
                    }
                    Text(L10n.tr("home.dest.review_capture.edit_hint"))
                        .font(.footnote)
                        .foregroundStyle(LumaPalette.secondaryText)
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("home.dest.review_capture.place_label"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LumaPalette.secondaryText)
                    TextField(
                        L10n.tr("home.dest.review_capture.place_placeholder"),
                        text: $placeNameDraft
                    )
                    .lumaInputStyle()
                    .accessibilityLabel(L10n.tr("home.dest.review_capture.place_label"))
                    .accessibilityHint(L10n.tr("home.dest.review_capture.place_placeholder"))

                    Button(L10n.tr("home.dest.review_capture.search_button")) {
                        onSearchPlaceRequested()
                    }
                    .buttonStyle(LumaSecondaryButtonStyle())

                    if let freshSearchedPlaceSuggestion {
                        Button(L10n.format("home.dest.review_capture.use_recent_search", freshSearchedPlaceSuggestion)) {
                            placeNameDraft = freshSearchedPlaceSuggestion
                        }
                        .buttonStyle(LumaSecondaryButtonStyle())
                    }

                    Text(L10n.format("home.dest.review_capture.rating_value", rating))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LumaPalette.secondaryText)
                    Stepper(
                        L10n.tr("home.dest.review_capture.rating_stepper"),
                        value: $rating,
                        in: 1...5
                    )

                    HStack(spacing: 8) {
                        Text(L10n.tr("home.dest.review_capture.notes_label"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LumaPalette.secondaryText)
                        Spacer()
                        Button {
                            toggleReviewNotesVoiceInput()
                        } label: {
                            Image(systemName: speechController.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(LumaInlineIconButtonStyle())
                        .accessibilityLabel("\(L10n.tr("home.dest.review_capture.notes_label")), \(L10n.tr("speech.button.label"))")
                        .accessibilityHint(L10n.tr("speech.button.hint"))
                    }
                    ZStack(alignment: .topLeading) {
                        if notesDraft.isEmpty {
                            Text(L10n.tr("home.dest.review_capture.notes_placeholder"))
                                .foregroundStyle(LumaPalette.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 12)
                                .accessibilityHidden(true)
                        }
                        TextEditor(text: $notesDraft)
                            .foregroundStyle(.black)
                            .tint(.black)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                            .padding(6)
                            .background(Color.clear)
                            .accessibilityLabel(L10n.tr("home.dest.review_capture.notes_label"))
                            .accessibilityHint(L10n.tr("home.dest.review_capture.notes_placeholder"))
                    }
                    .background(inputBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(LumaPalette.inputBorder.opacity(0.82), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let speechError = speechController.errorMessage {
                        Text(speechError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button(L10n.tr("home.dest.review_capture.save_button")) {
                        moveToConfirmReview()
                    }
                    .buttonStyle(LumaPrimaryButtonStyle())
                    .disabled(canSaveReview == false)
                }
                .lumaCardStyle()

                if let statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                        .lumaCardStyle()
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("home.dest.review_capture.recent_title"))
                        .font(.headline)
                        .fontDesign(.rounded)
                        .accessibilityAddTraits(.isHeader)

                    if savedReviews.isEmpty {
                        Text(L10n.tr("home.dest.review_capture.no_saved"))
                            .foregroundStyle(LumaPalette.secondaryText)
                    } else {
                        ForEach(savedReviews.prefix(5)) { review in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(review.placeName)
                                    .font(.subheadline.weight(.semibold))
                                Text(L10n.format("home.dest.review_capture.rating_value", review.rating ?? 0))
                                    .font(.footnote)
                                    .foregroundStyle(LumaPalette.secondaryText)
                                Text(review.note)
                                    .font(.footnote)
                                Text(Self.dateFormatter.string(from: review.createdAt))
                                    .font(.caption2)
                                    .foregroundStyle(LumaPalette.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lumaCardStyle(padding: 10)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "\(review.placeName), \(L10n.format("home.dest.review_capture.rating_value", review.rating ?? 0)), \(review.note), \(Self.dateFormatter.string(from: review.createdAt))"
                            )
                        }
                    }
                }
                .lumaCardStyle()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("home.dest.review_capture.title"))
        .inlineNavigationTitle()
        .onAppear {
            isTitleFocused = true
            seedPlaceDraftIfNeeded()
            savedReviews = LocalReviewStore.load()
        }
        .onDisappear {
            speechController.stopRecording()
        }
        .navigationDestination(item: $pendingConfirmationDraft) { draft in
            ReviewConfirmView(
                draft: draft,
                onConfirmSave: { confirmedDraft in
                    persistConfirmedReview(confirmedDraft)
                },
                onCancelDraft: {
                    notesDraft = ""
                    rating = 4
                    statusMessage = L10n.tr("home.dest.review_capture.cancelled")
                }
            )
        }
    }

    private func seedPlaceDraftIfNeeded() {
        guard hasSeededPlaceDraft == false else { return }
        hasSeededPlaceDraft = true
        if let prefilledPlaceName {
            placeNameDraft = prefilledPlaceName
        }
    }

    private func moveToConfirmReview() {
        let placeName = placeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard placeName.isEmpty == false, note.isEmpty == false else { return }
        statusMessage = nil
        pendingConfirmationDraft = ReviewSubmissionDraft(
            placeName: placeName,
            note: note,
            rating: rating
        )
    }

    private func persistConfirmedReview(_ draft: ReviewSubmissionDraft) -> Bool {
        savedReviews = LocalReviewStore.addReview(
            placeName: draft.placeName,
            note: draft.note,
            rating: draft.rating
        )

        guard let newest = savedReviews.first else { return false }
        guard
            newest.placeName == draft.placeName,
            newest.note == draft.note,
            newest.rating == draft.rating
        else {
            return false
        }

        lastVisitedPlaceName = draft.placeName
        placeNameDraft = draft.placeName
        statusMessage = L10n.tr("home.dest.review_capture.saved")
        notesDraft = ""
        rating = 4
        return true
    }

    private func toggleReviewNotesVoiceInput() {
        if speechController.isRecording {
            reviewVoiceStopRequestedByUser = true
            speechController.stopRecording()
            return
        }

        reviewVoiceStopRequestedByUser = false
        reviewVoiceSessionBaseNote = notesDraft
        AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_started"))
        speechController.startRecording(
            onTranscript: { transcript in
                let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedTranscript.isEmpty == false else { return }
                notesDraft = mergedReviewNote(
                    baseNote: reviewVoiceSessionBaseNote,
                    dictatedText: trimmedTranscript
                )
            },
            onStopped: { didCaptureTranscript in
                if didCaptureTranscript {
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_stopped"))
                } else if reviewVoiceStopRequestedByUser {
                    AccessibilityAnnouncer.announce(L10n.tr("announcement.voice_input_cancelled"))
                }
                reviewVoiceStopRequestedByUser = false
            }
        )
    }

    private func mergedReviewNote(baseNote: String, dictatedText: String) -> String {
        let trimmedBase = baseNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedBase.isEmpty == false else {
            return dictatedText
        }
        let separator = baseNote.hasSuffix("\n") ? "" : "\n"
        return "\(baseNote)\(separator)\(dictatedText)"
    }
}

private struct ReviewConfirmView: View {
    private enum ParsedSignalType {
        case accessIssue
        case positiveAccess
        case mixed
        case general

        var localizationKey: String {
            switch self {
            case .accessIssue:
                return "home.dest.review_confirm.signal_type.access_issue"
            case .positiveAccess:
                return "home.dest.review_confirm.signal_type.positive_access"
            case .mixed:
                return "home.dest.review_confirm.signal_type.mixed"
            case .general:
                return "home.dest.review_confirm.signal_type.general"
            }
        }
    }

    let draft: ReviewSubmissionDraft
    let onConfirmSave: (ReviewSubmissionDraft) -> Bool
    let onCancelDraft: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var isTitleFocused: Bool
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    private var parsedSignalType: ParsedSignalType {
        inferSignalType(from: draft.note, rating: draft.rating)
    }

    private var suggestedScore: Int {
        max(0, min(100, draft.rating * 20))
    }

    private var originalTextBlock: String {
        [
            L10n.format("home.dest.review_confirm.place_value", draft.placeName),
            L10n.format("home.dest.review_capture.rating_value", draft.rating),
            draft.note
        ].joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.tr("home.dest.review_confirm.title"))
                    .font(.title2.weight(.bold))
                    .fontDesign(.rounded)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)
                    .lumaCardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("home.dest.review_confirm.original_text_title"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(originalTextBlock)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lumaInputStyle()
                }
                .lumaCardStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("home.dest.review_confirm.parsing_title"))
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text(
                        L10n.format(
                            "home.dest.review_confirm.signal_type_value",
                            L10n.tr(parsedSignalType.localizationKey)
                        )
                    )
                    Text(
                        L10n.format(
                            "home.dest.review_confirm.suggested_score_value",
                            suggestedScore
                        )
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lumaCardStyle()

                Button(
                    isSaving
                    ? L10n.tr("home.dest.review_confirm.confirm_saving")
                    : L10n.tr("home.dest.review_confirm.confirm_save_button")
                ) {
                    confirmSave()
                }
                .buttonStyle(LumaPrimaryButtonStyle())
                .disabled(isSaving)

                Button(L10n.tr("home.dest.review_confirm.back_to_edit_button")) {
                    dismiss()
                }
                .buttonStyle(LumaSecondaryButtonStyle())
                .disabled(isSaving)

                Button(L10n.tr("home.dest.review_confirm.cancel_button")) {
                    cancelDraft()
                }
                .buttonStyle(LumaSecondaryButtonStyle())
                .disabled(isSaving)

                if let saveErrorMessage {
                    Text(saveErrorMessage)
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .lumaScreenStyle()
        .navigationTitle(L10n.tr("home.dest.review_confirm.title"))
        .inlineNavigationTitle()
        .onAppear {
            isTitleFocused = true
        }
    }

    private func confirmSave() {
        isSaving = true
        saveErrorMessage = nil

        let didSave = onConfirmSave(draft)
        isSaving = false

        if didSave {
            AccessibilityAnnouncer.announce(L10n.tr("announcement.review_submitted"))
            dismiss()
            return
        }

        let message = L10n.tr("home.dest.review_confirm.save_failed")
        saveErrorMessage = message
        AccessibilityAnnouncer.announce(L10n.tr("announcement.review_save_failed"))
    }

    private func cancelDraft() {
        onCancelDraft()
        dismiss()
    }

    private func inferSignalType(from note: String, rating: Int) -> ParsedSignalType {
        let normalizedNote = note.lowercased()
        let negativeKeywords = [
            "blocked", "stairs", "narrow", "broken", "inaccessible", "difficult",
            "no ramp", "no elevator", "not accessible",
            "台阶", "没有坡道", "没有电梯", "不方便", "无法", "坏"
        ]
        let positiveKeywords = [
            "accessible", "ramp", "elevator", "wide", "helpful", "smooth",
            "无障碍", "坡道", "电梯", "方便", "顺畅", "友好"
        ]

        let hasNegativeSignal =
            rating <= 2 || negativeKeywords.contains(where: { normalizedNote.contains($0) })
        let hasPositiveSignal =
            rating >= 4 || positiveKeywords.contains(where: { normalizedNote.contains($0) })

        if hasNegativeSignal && hasPositiveSignal {
            return .mixed
        }
        if hasNegativeSignal {
            return .accessIssue
        }
        if hasPositiveSignal {
            return .positiveAccess
        }
        return .general
    }
}
