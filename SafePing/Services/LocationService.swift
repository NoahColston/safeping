//
//  LocationService.swift
//  SafePing
//


import CoreLocation
import SwiftUI

// Manages location permission and provides the current device coordinates
// for attaching to check-in records.
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    // Nil until permission is granted and the first fix arrives,
    // or if permission is denied.
    @Published var currentLocation: CLLocation?

    // The current authorization status. Observed by SettingsView to show
    // the iOS Settings deep link when access is denied.
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Hundred-metre accuracy is sufficient for check-ins
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Permission

    // Requests When In Use permission. Called during the check-in user
    // onboarding flow. Safe to call more than once — iOS ignores repeated
    // requests after the user has already responded.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // Returns true if the app has sufficient permission to read location.
    var hasPermission: Bool {
        authorizationStatus == .authorizedWhenInUse ||
        authorizationStatus == .authorizedAlways
    }

    // MARK: - Location capture

    // Requests a single location update. The result is delivered to
    // `currentLocation` via the delegate. Call just before
    // `performCheckIn` so the fix is as fresh as possible.
    func captureLocation() {
        guard hasPermission else { return }
        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal — check-in proceeds without location if a fix can't be obtained.
        print("LocationService: failed to get location — \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            // Start receiving updates automatically once permission is granted
            if self.hasPermission {
                manager.startUpdatingLocation()
            }
        }
    }
}
