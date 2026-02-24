import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var currentLocation: LocationData?
    var currentVelocity: VelocityData?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var active = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start() {
        guard !active else { return }
        active = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            manager.startMonitoringSignificantLocationChanges()
        default:
            break
        }
    }

    func stop() {
        guard active else { return }
        active = false
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        currentLocation = nil
        currentVelocity = nil
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if active {
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.startUpdatingLocation()
                manager.startMonitoringSignificantLocationChanges()
            default:
                break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = LocationData(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            altitude: location.altitude,
            accuracy: location.horizontalAccuracy
        )

        currentVelocity = VelocityData(
            speed: max(0, location.speed),
            course: location.course >= 0 ? location.course : 0
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location errors are transient; keep trying
    }
}
