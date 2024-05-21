//
//  ModalViewController.swift
//  Parking Tracker
//
//  Created by Kristina Cherevko on 5/12/24.
//

import UIKit
import CoreLocation
import MapKit

protocol ModalViewControllerDelegate: AnyObject {
    func didTapGoButton()
}

class ModalViewController: UIViewController {
    private var carTitleLabel: UILabel!
    private var carLocationLabel: UILabel!
    private var userLabel: UILabel!
    private var routeTitleLabel: UILabel!
    private var routeInstructionsLabel: UILabel!
    private var trackerLabel: UILabel!
    weak var delegate: ModalViewControllerDelegate?
    private var routeInstructions: [String] = []
    private var userLocation: CLLocation?
    var trackerLocation: CLLocation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        NotificationCenter.default.addObserver(self, selector: #selector(routeUpdated(_:)), name: Notification.Name("RouteUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userLocationUpdated(_:)), name: Notification.Name("UserLocationUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(trackerLocationUpdated(_:)), name: Notification.Name("TrackerLocationUpdated"), object: nil)
        calculateDistanceAndElevation()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        carTitleLabel = UILabel()
        carTitleLabel.text = "My car"
        carTitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        carTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(carTitleLabel)
        
        carLocationLabel = UILabel()
        carLocationLabel.text = ""
        carLocationLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(carLocationLabel)
        
        routeTitleLabel = UILabel()
        routeTitleLabel.text = ""
        routeTitleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        routeTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(routeTitleLabel)
        
        routeInstructionsLabel = UILabel()
        routeInstructionsLabel.text = ""
        routeInstructionsLabel.font = .systemFont(ofSize: 18)
        routeInstructionsLabel.numberOfLines = 0
        routeInstructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(routeInstructionsLabel)
        
        let button = UIButton()
        button.setTitle("Go", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.backgroundColor = UIColor(red: 118/255, green: 214/255, blue: 114/255, alpha: 1)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(goButtonTapped), for: .touchUpInside)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            button.widthAnchor.constraint(equalToConstant: 60),
            button.heightAnchor.constraint(equalToConstant: 60),
            carTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            carTitleLabel.topAnchor.constraint(equalTo: button.topAnchor),
            carLocationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            carLocationLabel.topAnchor.constraint(equalTo: carTitleLabel.bottomAnchor, constant: 10),
            
            routeTitleLabel.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 32),
            routeTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            routeInstructionsLabel.topAnchor.constraint(equalTo: routeTitleLabel.bottomAnchor, constant: 16),
            routeInstructionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }

    @objc private func routeUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let instructions = userInfo["instructions"] as? [MKRoute.Step] else { return }
        updateInstructionsLabel(with: instructions)
        routeTitleLabel.text = "Route instructions"
    }
    
    @objc private func userLocationUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let location = userInfo["userLocation"] as? CLLocation else { return }
        print("userLocation: lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude), alt: \(location.altitude)")
        userLocation = location
        calculateDistanceAndElevation()
    }
    
    @objc private func trackerLocationUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let location = userInfo["trackerLocation"] as? CLLocation else { return }
        print("trackerLocation: lat: \(location.coordinate.latitude), lon: '\(location.coordinate.longitude), alt: \(location.altitude)")
        trackerLocation = location
        calculateDistanceAndElevation()
    }
    
    @objc private func goButtonTapped() {
        delegate?.didTapGoButton()
    }
    
    func updateInstructionsLabel(with instructions: [MKRoute.Step]) {
        let instructionsString = instructions.map{ $0.instructions }.joined(separator: "\n")
        routeInstructionsLabel.text = instructionsString
    }
    
    func calculateDistanceAndElevation() {
        guard let trackerLocation, let userLocation else {
            return
        }
        // Calculate distance
        let distance = userLocation.distance(from: trackerLocation)
        // Calculate elevation
        let userElevation = userLocation.altitude
        let trackerElevation = trackerLocation.altitude
        let elevationDifference = trackerElevation - userElevation
        
        carLocationLabel.text = "\(formatDistance(distance)) • \(elevationDifference > 0 ? "↑" : "↓") \(Double(round(1000*elevationDifference))/1000) meters"
    }
    
    func formatDistance(_ distance: CLLocationDistance) -> String {
        if (distance > 1000) {
            return "\(Double(round(100 * (distance / 1000)) / 100)) kilometers"
        } else {
            return "\(Double(round(100 * distance) / 100)) meters"
        }
    }
}



