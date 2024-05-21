//
//  MapViewController.swift
//  Parking Tracker
//
//  Created by Kristina Cherevko on 5/11/24.
//

import UIKit
import MapKit
import CoreLocation
import CoreBluetooth

class MapViewController: UIViewController {
    var mapView: MKMapView!
    let manager = CLLocationManager()
    var sheetViewController: ModalViewController!
    var centralManager: CBCentralManager!
    var peripheral : CBPeripheral?
    var locationCharacteristic: CBCharacteristic?
//    var scanningTimer = Timer()
    var trackerLongitude: Double?
    var trackerLatitude: Double?
    var trackerAltitude: Double?
    var trackerLocation: CLLocation?
    var locationStorage = KeychainManager()
    var shouldDrawRoute = false

    override func viewDidLoad() {
        super.viewDidLoad()
//        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        DispatchQueue.global(qos: .background).async {
            self.centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        setupMapView()
        addTrackerAnnotation()
        NotificationCenter.default.addObserver(self, selector: #selector(trackerLocationUpdated(_:)), name: Notification.Name("TrackerLocationUpdated"), object: nil)
        
//        if let storedLocation = locationStorage.get() {
//            trackerLocation = CLLocation(model: storedLocation)
//            print("tracker coord from Keychain: \(storedLocation)")
//            addTrackerAnnotation()
//        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            if let storedLocation = self?.locationStorage.get() {
                self?.trackerLocation = CLLocation(model: storedLocation)
                print("tracker coord from Keychain: \(storedLocation)")
                DispatchQueue.main.async {
                    self?.addTrackerAnnotation()
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showSheetViewController()
    }
    
    @objc private func trackerLocationUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let location = userInfo["trackerLocation"] as? CLLocation else { return }
        
        trackerLocation = location
//        addTrackerAnnotation()
        DispatchQueue.main.async {
           self.addTrackerAnnotation()
       }
    }

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
        
        mapView.delegate = self
        
        manager.requestWhenInUseAuthorization()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
        manager.delegate = self
        
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.setRegion(MKCoordinateRegion(center: mapView.userLocation.coordinate, latitudinalMeters: 10, longitudinalMeters: 10), animated: true)
        mapView.showsCompass = true
        mapView.showsUserTrackingButton = true
    }
    
    func addTrackerAnnotation() {
        guard let trackerLocation = trackerLocation else { return }
        // Remove previous tracker annotation
        mapView.removeAnnotations(mapView.annotations)
        
        // Add new tracker annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = trackerLocation.coordinate
        mapView.addAnnotation(annotation)
    }
    
    func showSheetViewController() {
        sheetViewController = ModalViewController()
        sheetViewController.delegate = self
        sheetViewController.trackerLocation = trackerLocation
        sheetViewController.isModalInPresentation = true
        if let sheet = sheetViewController.sheetPresentationController {
            sheet.detents = [
                .custom { _ in
                    return 75
                },
                .medium(), .large()]
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
                // Optionally, you can provide turn-by-turn navigation instructions
                for step in route.steps {
                    print(step.instructions)
                }
            }
        }
        shouldDrawRoute = false
    }
}

// MARK: - CBCentralManagerDelegate
extension MapViewController: CBCentralManagerDelegate {
    // MARK: - Scanning

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unauthorized:
            print("State is unauthorized")
        case .poweredOn:
//            central.scanForPeripherals(withServices: nil, options: nil)
//            print("Scanning...")
            DispatchQueue.global(qos: .background).async {
                central.scanForPeripherals(withServices: nil, options: nil)
                print("Scanning...")
            }
//            scanningTimer = Timer.scheduledTimer(timeInterval: 20.0, target: self, selector: #selector(stopBluetoothScanning), userInfo: nil, repeats: false)
        default:
            print("\(central.state)")
        }
    }

    @objc func stopBluetoothScanning() {
        centralManager.stopScan()
        print("Stopped...")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let peripheralName = peripheral.name else { return }

        print(peripheralName)

        if peripheralName == "DSD TECH" {
            print("Device found!")
            // Stop scan
            centralManager.stopScan()

            // Connect
            centralManager.connect(peripheral, options: nil)
            self.peripheral = peripheral
        }
    }

    // MARK: - Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected: \(peripheral.name ?? "No name")")
        // Discover all service
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
//        centralManager.scanForPeripherals(withServices: nil, options: nil)
        DispatchQueue.global(qos: .background).async {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension MapViewController : CBPeripheralDelegate {
    // MARK: - Discover services
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    // MARK: - Discover characteristics for the service

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }

        let characteristicId = CBUUID(string: "0x2AAF")

        for characteristic in characteristics {
            if characteristic.uuid == characteristicId {
                peripheral.readValue(for: characteristic)
                self.locationCharacteristic = characteristic
                print("Found characteristic - \(characteristic)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == locationCharacteristic {
            if let value = characteristic.value, let dataString = String(data: value, encoding: .utf8) {
                if dataString.hasPrefix("Lon:") {
                    trackerLongitude = parseValue(from: dataString)
                } else if dataString.hasPrefix("Lat:") {
                    trackerLatitude = parseValue(from: dataString)
                } else if dataString.hasPrefix("Alt:") {
                    trackerAltitude = parseValue(from: dataString)
                }
           }
            
            // Check if we have received all necessary information
            if let longitude = trackerLongitude, let latitude = trackerLatitude, let altitude = trackerAltitude {
                // Create a CLLocation object with the parsed values
                let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude / 10000000, longitude: longitude / 10000000), altitude: altitude, horizontalAccuracy: 1.5, verticalAccuracy: 3.5, timestamp: Date())
                
                // Reset values for the next data packet
                self.trackerLongitude = nil
                self.trackerLatitude = nil
                self.trackerAltitude = nil
                
                trackerLocation = location
                
                NotificationCenter.default.post(name: Notification.Name("TrackerLocationUpdated"), object: nil, userInfo: ["trackerLocation": location])
                saveTrackerLocationToKeychain()
            }
        }
    }
    
    func parseValue(from line: String) -> Double? {
        guard line.count >= 5 else { return Double(line) }
            
        let startIndex = line.index(line.startIndex, offsetBy: 5)
        let trimmedString = String(line[startIndex...])
        return Double(trimmedString)
    }
    
    func saveTrackerLocationToKeychain() {
        if let trackerLocation = trackerLocation {
            let locationModel = Location(latitude: trackerLocation.coordinate.latitude, longitude: trackerLocation.coordinate.longitude, altitude: trackerLocation.altitude, horizontalAccuracy: trackerLocation.horizontalAccuracy, verticalAccuracy: trackerLocation.verticalAccuracy, speed: trackerLocation.speed, course: trackerLocation.course, timestamp: trackerLocation.timestamp)
            locationStorage.save(locationModel)
            print("saved tracker location to keychain")
        }
    }
    
}

// MARK: Protocols
protocol ModalViewControllerDelegate: AnyObject {
    func didTapGoButton()
}

