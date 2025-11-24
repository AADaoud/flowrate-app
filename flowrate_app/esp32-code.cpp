#include <Arduino.h>
#include <NimBLEDevice.h>

// ==========================================================
// CONFIGURATION
// ==========================================================

// Flip this to true when wiring up real sensors/ADC inputs.
#ifndef USE_ADC
#define USE_ADC false
#endif

// Simulation flavours for demos without hardware
#define SIM_MODE_SINE 0
#define SIM_MODE_STEP 1
#define SIM_MODE_BURST 2
#ifndef SIMULATION_MODE
#define SIMULATION_MODE SIM_MODE_SINE
#endif

const int ADC_VELOCITY_PIN = 34;
const int ADC_BATTERY_PIN = 35;

const float BATTERY_DIVIDER_RATIO = 2.0f;
const float BATTERY_FULL_VOLTAGE  = 4.20f;
const float BATTERY_EMPTY_VOLTAGE = 3.20f;

static NimBLEUUID SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static NimBLEUUID CHARACTERISTIC_UUID("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");

NimBLECharacteristic* pCharacteristic;

// ==========================================================
// SENSOR FUNCTIONS
// ==========================================================

float simulateVelocity() {
    static float phase = 0.0f;
    phase += 0.25f;

    switch (SIMULATION_MODE) {
        case SIM_MODE_STEP:
            return fmod(phase, 20.0f) > 10.0f ? 55.0f : 15.0f;
        case SIM_MODE_BURST:
            return fmod(phase, 30.0f) > 25.0f ? 95.0f : 12.0f;
        case SIM_MODE_SINE:
        default:
            return 45.0f + 25.0f * sin(phase / 10.0f);
    }
}

float readVelocity() {
    if (!USE_ADC) {
        return simulateVelocity();
    }

    int raw = analogRead(ADC_VELOCITY_PIN);
    float v = (raw / 4095.0f) * 3.3f;
    return v * 25.0f; // scale to cm/s
}

int readBatteryPercent() {
    // Slight smoothing so the UI does not jitter
    static float filtered = 92.0f;

    float samplePercent;
    if (USE_ADC) {
        int raw = analogRead(ADC_BATTERY_PIN);
        float vin = (raw / 4095.0f) * 3.3f * BATTERY_DIVIDER_RATIO;

        if (vin < BATTERY_EMPTY_VOLTAGE) {
            samplePercent = 0.0f;
        } else if (vin > BATTERY_FULL_VOLTAGE) {
            samplePercent = 100.0f;
        } else {
            samplePercent = 100.0f * (vin - BATTERY_EMPTY_VOLTAGE) /
                            (BATTERY_FULL_VOLTAGE - BATTERY_EMPTY_VOLTAGE);
        }
    } else {
        // Slowly decay then bounce back to emulate discharge/charge cycles
        const float minPercent = 35.0f;
        const float maxPercent = 99.0f;
        static bool rising = false;

        if (filtered <= minPercent) rising = true;
        if (filtered >= maxPercent) rising = false;

        samplePercent = filtered + (rising ? 0.4f : -0.25f);
    }

    filtered = (filtered * 0.92f) + (samplePercent * 0.08f);
    if (filtered < 0) filtered = 0;
    if (filtered > 100) filtered = 100;
    return (int)filtered;
}

// ==========================================================
// CALLBACKS — NimBLE 2.3.6 SAFE
// ==========================================================

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) override {
        Serial.println("[BLE] Client connected");
    }

    void onDisconnect(NimBLEServer* pServer) override {
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
    if (millis() - last >= 800) { // a little faster for smoother UI
        last = millis();

        float vel = readVelocity();
        int batt  = readBatteryPercent();

        // Compact JSON under 20 bytes: {"v":12.3,"b":95}
        char json[32];
        snprintf(json, sizeof(json), "{\"v\":%.1f,\"b\":%d}", vel, batt);

        pCharacteristic->setValue((uint8_t*)json, strlen(json));
        pCharacteristic->notify();

        Serial.println(json);
    }

    delay(10);
}
