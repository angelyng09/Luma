//
//  ShanghaiMapBounds.swift
//  Luma
//
//  Created by Codex on 3/24/26.
//

import Foundation
import MapKit

enum ShanghaiMapBounds {
    // Approximate Shanghai municipal bounds.
    static let latitudeRange: ClosedRange<CLLocationDegrees> = 30.66...31.88
    static let longitudeRange: ClosedRange<CLLocationDegrees> = 120.85...122.12

    static let minimumLatitudeDelta: CLLocationDegrees = 0.003
    static let maximumLatitudeDelta: CLLocationDegrees = 0.20
    static let minimumLongitudeDelta: CLLocationDegrees = 0.003
    static let maximumLongitudeDelta: CLLocationDegrees = 0.20

    static var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (latitudeRange.lowerBound + latitudeRange.upperBound) / 2,
            longitude: (longitudeRange.lowerBound + longitudeRange.upperBound) / 2
        )
    }

    static var defaultRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: centerCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }

    static var boundingRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: centerCoordinate,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeRange.upperBound - latitudeRange.lowerBound,
                longitudeDelta: longitudeRange.upperBound - longitudeRange.lowerBound
            )
        )
    }

    static func clampedCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: coordinate.latitude.clamped(to: latitudeRange),
            longitude: coordinate.longitude.clamped(to: longitudeRange)
        )
    }

    static func clampedRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
        let latitudeSpanLimit = latitudeRange.upperBound - latitudeRange.lowerBound
        let longitudeSpanLimit = longitudeRange.upperBound - longitudeRange.lowerBound

        let latitudeDelta = min(
            region.span.latitudeDelta.clamped(to: minimumLatitudeDelta...maximumLatitudeDelta),
            latitudeSpanLimit
        )
        let longitudeDelta = min(
            region.span.longitudeDelta.clamped(to: minimumLongitudeDelta...maximumLongitudeDelta),
            longitudeSpanLimit
        )

        let centerLatitude: CLLocationDegrees
        if latitudeDelta >= latitudeSpanLimit {
            centerLatitude = (latitudeRange.lowerBound + latitudeRange.upperBound) / 2
        } else {
            centerLatitude = region.center.latitude.clamped(
                to: (latitudeRange.lowerBound + latitudeDelta / 2)...(latitudeRange.upperBound - latitudeDelta / 2)
            )
        }

        let centerLongitude: CLLocationDegrees
        if longitudeDelta >= longitudeSpanLimit {
            centerLongitude = (longitudeRange.lowerBound + longitudeRange.upperBound) / 2
        } else {
            centerLongitude = region.center.longitude.clamped(
                to: (longitudeRange.lowerBound + longitudeDelta / 2)...(longitudeRange.upperBound - longitudeDelta / 2)
            )
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    static func regionsDiffer(
        _ lhs: MKCoordinateRegion,
        _ rhs: MKCoordinateRegion,
        tolerance: CLLocationDegrees = 0.00001
    ) -> Bool {
        abs(lhs.center.latitude - rhs.center.latitude) > tolerance ||
        abs(lhs.center.longitude - rhs.center.longitude) > tolerance ||
        abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) > tolerance ||
        abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) > tolerance
    }
}

private extension CLLocationDegrees {
    func clamped(to range: ClosedRange<CLLocationDegrees>) -> CLLocationDegrees {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
