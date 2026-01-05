# Flowrate App

A polished Flutter demo that visualizes a BLE flow sensor powered by an ESP32 + NimBLE firmware. The app automatically scans for `ESP32-Flow`, subscribes to compact JSON packets (`{"v":12.3,"b":95}`), and renders a modern dashboard with history and diagnostics.

## Flutter app highlights
- Material 3 dark theme with glassy cards and animated velocity gauge.
- Live sparkline of recent flow samples plus a dedicated history screen.
- Battery chip, RSSI snapshot, last-packet timer, and richer BLE status pill.
- Permission-friendly startup, auto reconnect with backoff, and safer fragmented JSON parsing.
- Optional haptic + sound feedback, developer overlay, and logging toggle.

### Running the app
```bash
flutter pub get
flutter run
```

## BLE protocol
- Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- Notify characteristic UUID: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- Notification payload: compact JSON under 20 bytes: `{"v":<raw_voltage_v>,"b":<battery_percent>}`

## ESP32 firmware
The sample firmware in `esp32-code.cpp` uses NimBLE-Arduino (do **not** upgrade the library). It advertises as `ESP32-Flow` and streams the payload above roughly every 800 ms.

### Build / flash
1. Open `esp32-code.cpp` in Arduino IDE or PlatformIO.
2. Ensure NimBLE-Arduino is installed (same version already in the repo context).
3. Optional: toggle compile-time flags at the top of the file:
   - `#define USE_ADC true` to read real sensors on pins 34 (velocity) and 35 (battery divider).
   - `SIMULATION_MODE` to `SIM_MODE_SINE`, `SIM_MODE_STEP`, or `SIM_MODE_BURST` for richer demo waveforms.
4. Flash to your ESP32 and keep advertising name `ESP32-Flow` for auto-discovery.

### Battery smoothing
Battery percent is low-pass filtered to avoid jitter. If using ADC, set the divider ratio and voltage window near the top of the file.

### Calibration-first app behavior
- The app now treats `v` as the raw ADS1115 A0-to-GND voltage. With nothing connected, expect ~0.0359 V due to floating bias and coupling.
- Velocity is hidden until the app observes a stable baseline and you capture a known reference (electrical or flow).
- A calibration screen guides the wait-for-stability ➜ capture-reference ➜ operational flow and will re-lock velocity if noise or drift rises.

## Migration notes
- BLE handling now streams typed `FlowReading` objects, keeps a bounded JSON buffer, and auto-reconnects with exponential-ish backoff.
- UI rebuilt around `FlowController` (ChangeNotifier) to keep widgets and BLE logic separate.
- Added user-facing toggles for logging, developer mode, haptics, and sound effects.
- Firmware continues to send `{ "v":..., "b":... }` but now supports multiple simulation modes and a `USE_ADC` switch for real sensors.
