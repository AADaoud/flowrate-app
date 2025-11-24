#include <Arduino.h>
#include <NimBLEDevice.h>
#include <math.h>

// ==========================================================
// CONFIGURATION (kept small + NimBLE compatible)
// ==========================================================

// Toggle hardware ADC sampling for velocity/battery.
// Set to 1 to read the pins defined below; keep at 0 for simulator mode.
#define USE_ADC 0

// Simulator modes when USE_ADC == 0
// 0 = ramp, 1 = sine wave, 2 = burst pulses
#define SIM_MODE 1

// Sampling pins (only used when USE_ADC == 1)
const int ADC_VELOCITY_PIN = 34;
const int ADC_BATTERY_PIN = 35;

const float BATTERY_DIVIDER_RATIO = 2.0f;
const float BATTERY_FULL_VOLTAGE  = 4.20f;
const float BATTERY_EMPTY_VOLTAGE = 3.20f;

static NimBLEUUID SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static NimBLEUUID CHARACTERISTIC_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

NimBLECharacteristic* pCharacteristic;

// ==========================================================
// SENSOR / SIMULATION HELPERS
// ==========================================================

float batteryFiltered = 88.0f;

float simulateVelocity() {
    const float t = millis() / 1000.0f;
    switch (SIM_MODE) {
        case 2: // burst
            return (fmod(t, 6) < 1.2f) ? 95.0f : 18.0f;
        case 1: // sine
            return 45.0f + 35.0f * sinf(t * 1.2f);
        case 0:
        default:
            return fmod(t * 18, 120.0f); // simple ramp
    }
}

float readVelocity() {
#if USE_ADC
    int raw = analogRead(ADC_VELOCITY_PIN);
    float v = (raw / 4095.0f) * 3.3f;
    return v * 25.0f; // scale to cm/s
#else
    return simulateVelocity();
#endif
}

int readBatteryPercent() {
#if USE_ADC
    int raw = analogRead(ADC_BATTERY_PIN);
    float vin = (raw / 4095.0f) * 3.3f * BATTERY_DIVIDER_RATIO;
    int pct = (int)(100.0f * (vin - BATTERY_EMPTY_VOLTAGE) /
                    (BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE));
#else
    // Fake a slow drift down with soft noise to test UI smoothing
    float noise = 2.5f * sinf(millis() / 5000.0f);
    int pct = 90 + (int)noise;
#endif

    pct = constrain(pct, 0, 100);
    // Exponential smoothing keeps reported % stable
    batteryFiltered = 0.88f * batteryFiltered + 0.12f * pct;
    return (int)batteryFiltered;
}

// ==========================================================
// CALLBACKS — NimBLE compatible (do not bump library version)
// ==========================================================

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) {
        Serial.println("[BLE] Client connected");
    }

    void onDisconnect(NimBLEServer* pServer) {
        Serial.println("[BLE] Client disconnected → restarting advertising");
        NimBLEDevice::startAdvertising();
    }
};

// ==========================================================
// SETUP
// ==========================================================

void setup() {
    Serial.begin(115200);
    delay(300);

    analogReadResolution(12);
    pinMode(ADC_VELOCITY_PIN, INPUT);
    pinMode(ADC_BATTERY_PIN, INPUT);

    NimBLEDevice::init("ESP32-Flow");
    NimBLEDevice::setPower(ESP_PWR_LVL_N12);

    NimBLEServer* server = NimBLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());

    NimBLEService* service = server->createService(SERVICE_UUID);

    pCharacteristic = service->createCharacteristic(
        CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );

    service->start();

    NimBLEAdvertisementData advData;
    advData.setName("ESP32-Flow");
    advData.setCompleteServices(SERVICE_UUID);

    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->setAdvertisementData(advData);
    adv->start();

    Serial.println("BLE advertising started as ESP32-Flow");
}

// ==========================================================
// LOOP
// ==========================================================

void loop() {
    static unsigned long last = 0;
    if (millis() - last >= 800) { // tighter stream for smoother UI
        last = millis();

        float vel = readVelocity();
        int batt  = readBatteryPercent();

        // Compact JSON under 20 bytes: {"v":XX,"b":YY}
        char json[28];
        snprintf(json, sizeof(json),
                "{\"v\":%.0f,\"b\":%d}", vel, batt);

        pCharacteristic->setValue((uint8_t*)json, strlen(json));
        pCharacteristic->notify();

        Serial.println(json);
    }

    delay(10);
}
