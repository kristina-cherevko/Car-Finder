# CarFinder

CarFinder is an iOS application that connects to a Bluetooth-enabled tracking device, retrieves location data, and displays it on an interactive map. The app supports real-time tracking and can draw routes between the user's location and the tracker. CarFinder also saves the tracker's location data securely using Keychain.

## Features

- **Bluetooth Integration**: Connects to BLE-enabled tracking devices.
- **Real-time Tracking**: Displays the tracker's location on a map.
- **Route Drawing**: Draws routes from the user's location to the tracker.
- **Persistent Storage**: Saves the tracker's location data securely in Keychain.
- **User Notifications**: Receives updates about the tracker's location.

## Screenshots

![Route in the parking lot](screenshots/IMG_1400.png)
![Route at school](screenshots/IMG_1412.png)
![Route in the parking lot](screenshots/IMG_1426.png)
![Route at mall](screenshots/IMG_1431.png)


## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/your-username/TrackerLocator.git
    ```
2. Open the project in Xcode:
    ```bash
    cd TrackerLocator
    open TrackerLocator.xcodeproj
    ```
3. Install dependencies using CocoaPods (if any):
    ```bash
    pod install
    ```
4. Build and run the app on your iOS device or simulator.

## Usage

1. **Connecting to Tracker**:
    - Ensure your tracking device is powered on and within range.
    - The app will automatically scan and connect to the device.

2. **Viewing Track Location**:
    - Once connected, the tracker's location will be displayed on the map.
    - You can see the route from your current location to the tracker's location.

3. **Saving Track Location**:
    - The app will automatically save the tracker's location in Keychain for persistent storage.
