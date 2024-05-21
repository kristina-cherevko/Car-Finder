//
//  BluetootManager.swift
//  Parking Tracker
//
//  Created by Kristina Cherevko on 5/21/24.
//

import CoreBluetooth
import CoreLocation

protocol BluetoothManagerDelegate: AnyObject {
    func bluetoothManager(_ manager: BluetoothManager, didUpdateTrackerLocation location: CLLocation)
}

class BluetoothManager: NSObject {
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var locationCharacteristic: CBCharacteristic?
    weak var delegate: BluetoothManagerDelegate?
    private var trackerLongitude: Double?
    private var trackerLatitude: Double?
    private var trackerAltitude: Double?
    
    init(delegate: BluetoothManagerDelegate) {
        self.delegate = delegate
        super.init()
        setupCentralManager()
    }
    
    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    // MARK: - Scanning
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unauthorized:
            print("State is unauthorized")
        case .poweredOn:
            DispatchQueue.global(qos: .background).async {
                central.scanForPeripherals(withServices: nil, options: nil)
                print("Scanning...")
            }
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
        DispatchQueue.global(qos: .background).async {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager : CBPeripheralDelegate {
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
            if let longitude = trackerLongitude, let latitude = trackerLatitude, let altitude = trackerAltitude {
                let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: latitude / 10000000, longitude: longitude / 10000000), altitude: altitude, horizontalAccuracy: 1.5, verticalAccuracy: 3.5, timestamp: Date())
                
                self.trackerLongitude = nil
                self.trackerLatitude = nil
                self.trackerAltitude = nil
                                
                NotificationCenter.default.post(name: Notification.Name("TrackerLocationUpdated"), object: nil, userInfo: ["trackerLocation": location])
                saveTrackerLocationToKeychain(trackerLocation: location)
            }
        }
    }
    
    func parseValue(from line: String) -> Double? {
        guard line.count >= 5 else { return Double(line) }
        let startIndex = line.index(line.startIndex, offsetBy: 5)
        let trimmedString = String(line[startIndex...])
        return Double(trimmedString)
    }
    
    func saveTrackerLocationToKeychain(trackerLocation: CLLocation) {
            let locationModel = Location(latitude: trackerLocation.coordinate.latitude, longitude: trackerLocation.coordinate.longitude, altitude: trackerLocation.altitude, horizontalAccuracy: trackerLocation.horizontalAccuracy, verticalAccuracy: trackerLocation.verticalAccuracy, speed: trackerLocation.speed, course: trackerLocation.course, timestamp: trackerLocation.timestamp)
            KeychainManager.shared.save(locationModel)
            print("saved tracker location to keychain")
    }
}
