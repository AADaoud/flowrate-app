# Flow Rate Monitor – Flutter App

A lightweight Android application for displaying real-time flow rate data from a magnetohydrodynamic (MHD) sensor system. Designed as part of the ENGR 451 final project, this app connects to a Wi-Fi-enabled microcontroller (e.g., ESP32) and displays voltage-derived flow readings sent via HTTP.

## Features

* Real-time flow rate display (in mV or computed velocity)
* Clean, minimal UI optimized for mobile screens
* Auto-refresh with low-latency HTTP polling
* Compatible with any ESP32-based device serving JSON data
* Built in Flutter (Dart), supports Android 8.0 and above

<img src="https://drive.google.com/uc?export=view&id=1oNb5nrrddFgV1KllEqvLLaJOKAd3BXO6" width="300">

## Getting Started

### Prerequisites

* [Flutter SDK](https://flutter.dev/docs/get-started/install)
* Android Studio or VS Code
* An Android device (or emulator)
* ESP32 or similar microcontroller sending flow data via HTTP in JSON format

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-username/flow-rate-monitor.git
   cd flow-rate-monitor
   ```

2. Get dependencies:

   ```bash
   flutter pub get
   ```

3. Connect an Android device and run:

   ```bash
   flutter run
   ```

4. Optionally, build APK:

   ```bash
   flutter build apk --release
   ```

## Data Format

The ESP32 should serve data at a specified IP address (e.g., `192.168.1.42`) using the following JSON structure:

```json
{
  "voltage": 0.84,
  "flow_velocity": 0.25
}
```

Edit the target IP in the app code (`lib/main.dart`) as needed.

## Folder Structure

* `lib/` – Main source files
* `android/` – Android platform configuration
* `assets/` – Icons or future visual assets
* `test/` – (optional) Unit tests

## License

MIT License. See `LICENSE` file for details.

## Credits

Developed by Abdullah Daoud Team 7 – ENGR 451, Spring 2025
