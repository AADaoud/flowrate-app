# 🚀 Flow Rate Monitor – ESP32 + Flutter (BLE Version)

A next-generation mobile application for **real-time flow sensing**, built with Flutter and powered by an ESP32 running a custom **BLE MHD (magnetohydrodynamic) flow sensor** firmware.

This project is the evolved version of the ENGR 451 flow-rate system, now redesigned with:

* **Bluetooth Low Energy (BLE)** streaming
* **Fragment-safe JSON parsing**
* **Realtime Rive animation** (blood-flow visualizer)
* **Live sparkline graphs**
* **Adaptive smoothing & noise handling**
* **Developer tools, debug overlay, haptics, and sound feedback**
* **ESP32 firmware sample included** (NimBLE, JSON notifications)

It is engineered for robustness, smooth UX, and compatibility with modern Android devices.

---

# Features

### **BLE Streaming (ESP32 → Flutter)**

* Reliable, low-latency BLE notifications (NimBLE on ESP32)
* Fragment handling for JSON packets under 20 bytes
* Automatic reconnect logic with safe BLE reset
* RSSI monitoring + connection diagnostics

### **Modern, Polished UI**

* Custom Rive-powered animated flow visualization
* Velocity card with sparkline graph
* Info tiles (RSSI, packet age, battery, etc.)
* Gradient UI with clean layout and no overflow

### **Smart Feedback**

* Optional haptic clicks on each packet
* Optional sound cues for connect / data events
* Error messages auto-cleaned (no long BLE dump spam)

### **Developer Features**

* Enable Dev Mode for:

  * Full debug overlay
  * Live RSSI
  * Packet inspector
  * Velocity + battery + raw JSON monitoring

### **ESP32 Firmware Included**

* NimBLE 2.3.x
* JSON packets: `{"velocity": 123.45, "battery": 87}`
* 1 Hz notification
* No packet splitting
* Dummy mode + ADC mode

---

# Screenshots
## Attempting to connect to ESP32 over BLE
<img width="576" height="1280" alt="image" src="https://github.com/user-attachments/assets/afcf0782-97b1-4ecd-83c5-ca43b28c241c" />

## Succcesfully connected and displaying received data
<img width="576" height="1280" alt="image" src="https://github.com/user-attachments/assets/55945227-374d-4aaa-9165-203df5aba4eb" />

## History with interactive charts and info
<img width="576" height="1280" alt="image" src="https://github.com/user-attachments/assets/f64d705a-b8ab-4be7-9292-262726657b58" />

## Connected device information
<img width="576" height="1280" alt="image" src="https://github.com/user-attachments/assets/ec6f8420-7baa-4017-92d4-973210bdde47" />

## Settings page with Dev options for debugging purposes
<img width="576" height="1280" alt="image" src="https://github.com/user-attachments/assets/063eadcd-d031-4b09-a347-994394bbfd7b" />


---

# Getting Started

## Prerequisites

### Software

* Flutter SDK (3.x recommended)
* Android Studio or VS Code
* Dart >= 3.2
* Rive CLI optional (for animation editing)

### Hardware

* ESP32-WROOM-32D or equivalent
* Flow sensor (or use dummy generator)
* Android phone with BLE support

---

# Installation

1. Clone the repository:

```bash
git clone https://github.com/your-user/flowrate-app.git
cd flowrate-app
```

2. Install dependencies:

```bash
flutter pub get
```

3. Connect an Android device via USB and run:

```bash
flutter run
```

4. Build release APK:

```bash
flutter build apk --release
```

---

# ESP32 Firmware (Included)

Firmware is located in:

```
/flowrate-app/esp32-code.cpp
```

It uses:

* **NimBLE-Arduino** (lightweight, stable BLE)
* JSON notification every 1 second
* Dummy velocity generator (increments by +3)
* ADC input option for velocity + battery sensing

### JSON Format Sent by ESP32

```json
{
  "velocity": 312.00,
  "battery": 87
}
```

### Notification code (ESP32)

```cpp
snprintf(json, sizeof(json),
    "{\"v\":%.2f,\"b\":%d}", vel, batt);

pCharacteristic->setValue((uint8_t*)json, strlen(json));
pCharacteristic->notify(true);
```
---

# License

MIT License. See `LICENSE`.

---

# Credits

ENGR 331 – Fall 2026
Flow Rate Monitoring System Reimagined (BLE Edition)
