//
//  UserLocationProvider.swift
//  Luma
//
//  Created by Codex on 3/24/26.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class UserLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager: CLLocationManager

    override init() {
        let locationManager = CLLocationManager()
        manager = locationManager
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestAccessAndRefresh() {
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    func refreshLocationIfAuthorized() {
        let status = manager.authorizationStatus
        authorizationStatus = status
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            return
        }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        latestLocation = location
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep silent and non-blocking: AI still works without location context.
        _ = error
    }
}
