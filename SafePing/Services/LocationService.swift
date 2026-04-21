// SafePing  LocationService.swift

// Handles location permission and retrieves the devicecs current location
// Used to attach location data to checkcins.
//
import CoreLocation
import SwiftUI

// LocationService
// Manages location access and provides coordinates when needed.
//
// [OOP] Class uses inheritance
// [OOP] Conforms to ObservableObject
//
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    // Current device location
    @Published var currentLocation: CLLocation?

    // Current permission status
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Used for async location requests
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    // Initializer
    // Sets up location manager and delegate
    //
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }


    // Requests location permission from the user
    // [OOP] Uses system API via CLLocationManager
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // Returns true if location access is allowed
    var hasPermission: Bool {
        authorizationStatus == .authorizedWhenInUse ||
        authorizationStatus == .authorizedAlways
    }


    // Requests a single location update
    // [Procedural] step by step logic
    func captureLocation() {
        guard hasPermission else { return }
        manager.requestLocation()
    }

    // Async version of captureLocation
    // Returns location or nil if unavailable
    // [Procedural] Controls async flow
    func captureLocationAsync() async -> CLLocation? {
        guard hasPermission else { return nil }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }


    // Called when location is successfully retrieved
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        locationContinuation?.resume(returning: locations.last)
        locationContinuation = nil
    }

    // Called if location request fails
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        locationContinuation?.resume(returning: nil)
        locationContinuation = nil
    }

    // Called when permission status changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
