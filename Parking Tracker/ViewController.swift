//
//  ViewController.swift
//  Parking Tracker
//
//  Created by Kristina Cherevko on 5/11/24.
//

import UIKit

class ViewController: UIViewController {

    var mapViewController: MapViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        mapViewSetup()
    }

    func mapViewSetup() {
        mapViewController = MapViewController()
        // Add MapViewController as a child
        addChild(mapViewController)
        mapViewController.view.frame = view.bounds
        view.addSubview(mapViewController.view)
        mapViewController.didMove(toParent: self)
    }
    
}

