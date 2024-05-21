//
//  MapViewController.swift
//  Parking Tracker
//
//  Created by Kristina Cherevko on 5/11/24.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController {
    var mapView: MKMapView!
    let manager = CLLocationManager()
    var sheetViewController: ModalViewController!
    var bluetoothManager: BluetoothManager!
    var trackerLocation: CLLocation?
    var shouldDrawRoute = false

    
    func fetchStoredTrackerLocation() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let storedLocation = KeychainManager.shared.get() {
                self?.trackerLocation = CLLocation(model: storedLocation)
                print("tracker coord from Keychain: \(storedLocation)")
                DispatchQueue.main.async {
                    self?.addTrackerAnnotation()
                }
            }
        }
    }
    
    @objc private func trackerLocationUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
        let location = userInfo["trackerLocation"] as? CLLocation else { return }
        
        trackerLocation = location
        DispatchQueue.main.async {
           self.addTrackerAnnotation()
       }
    }

    func addTrackerAnnotation() {
        guard let trackerLocation = trackerLocation else { return }
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = trackerLocation.coordinate
        mapView.addAnnotation(annotation)
    }
}

// MARK: Lifecycle
extension MapViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        bluetoothManager = BluetoothManager(delegate: self)
        setupMapView()
        fetchStoredTrackerLocation()
        NotificationCenter.default.addObserver(self, selector: #selector(trackerLocationUpdated(_:)), name: Notification.Name("TrackerLocationUpdated"), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupSheetViewController()
    }
}

// MARK: Views setup
extension MapViewController {
    func setupMapView() {
        mapView = MKMapView()
        mapView.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
        mapView.pitchButtonVisibility = .visible
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
        manager.delegate = self
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.setRegion(MKCoordinateRegion(center: mapView.userLocation.coordinate, latitudinalMeters: 10, longitudinalMeters: 10), animated: true)
        mapView.showsCompass = true
        mapView.showsUserTrackingButton = true
    }
    
    func setupSheetViewController() {
        sheetViewController = ModalViewController()
        sheetViewController.delegate = self
        sheetViewController.trackerLocation = trackerLocation
        sheetViewController.isModalInPresentation = true
        if let sheet = sheetViewController.sheetPresentationController {
            sheet.detents = [ .custom { _ in return 75 }, .medium(), .large()]
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
        }
        present(sheetViewController, animated: true, completion: nil)
    }
}

// MARK: MKMapViewDelegate
extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(overlay: polyline)
            renderer.strokeColor = UIColor(red: 70/255, green: 115/255, blue: 222/255, alpha: 1)
            renderer.lineWidth = 10
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if let sheet = sheetViewController?.sheetPresentationController {
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = nil
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        if let sheet = sheetViewController?.sheetPresentationController {
            sheet.animateChanges {
                sheet.selectedDetentIdentifier = nil
            }
        }
    }
}

// MARK: ModalViewControllerDelegate
extension MapViewController: ModalViewControllerDelegate {
    func didTapGoButton() {
        shouldDrawRoute = true
    }
}

extension MapViewController: BluetoothManagerDelegate {
    func bluetoothManager(_ manager: BluetoothManager, didUpdateTrackerLocation location: CLLocation) {
        addTrackerAnnotation()
    }
}

// MARK: CLLocationManagerDelegate
extension MapViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let userLocation = locations.last else {return }
//        print("hello in didUpdate \(userLocation.coordinate)")
        NotificationCenter.default.post(name: Notification.Name("UserLocationUpdated"), object: nil, userInfo: ["userLocation": userLocation])
        guard let trackerLocation = trackerLocation, shouldDrawRoute else {
            return
        }
        // Draw path from user to tracker
        let userCoordinate = userLocation.coordinate
        let trackerCoordinate = trackerLocation.coordinate
        let userPlacemark = MKPlacemark(coordinate: userCoordinate)
        let trackerPlacemark = MKPlacemark(coordinate: trackerCoordinate)

        let userMapItem = MKMapItem(placemark: userPlacemark)
        let trackerMapItem = MKMapItem(placemark: trackerPlacemark)

        let directionRequest = MKDirections.Request()
        directionRequest.source = userMapItem
        directionRequest.destination = trackerMapItem
        directionRequest.transportType = .walking // Set transportType to .walking for pedestrian directions

        let directions = MKDirections(request: directionRequest)
        directions.calculate { [weak self] (response, error) in
            guard let self = self else { return }
            if let route = response?.routes.first {
                self.mapView.removeOverlays(self.mapView.overlays)
                self.mapView.addOverlay(route.polyline)
                NotificationCenter.default.post(name: Notification.Name("RouteUpdated"), object: nil, userInfo: ["instructions": route.steps])
                for step in route.steps {
                    print(step.instructions)
                }
            }
        }
        shouldDrawRoute = false
    }
}



